require 'fileutils'
require 'pathname'
require 'rexml/document'
require 'spaceship'
require 'json'
require 'rubygems/version'
require 'xcode/install/command'
require 'xcode/install/version'

module XcodeInstall
  CACHE_DIR = Pathname.new("#{ENV['HOME']}/Library/Caches/XcodeInstall")
  class Curl
    COOKIES_PATH = Pathname.new('/tmp/curl-cookies.txt')

    def fetch(url, directory = nil, cookies = nil, output = nil, progress = true)
      options = cookies.nil? ? [] : ['--cookie', cookies, '--cookie-jar', COOKIES_PATH]
      # options << ' -vvv'

      uri = URI.parse(url)
      output ||= File.basename(uri.path)
      output = (Pathname.new(directory) + Pathname.new(output)) if directory

      retry_options = ['--retry', '3']
      progress = progress ? '--progress-bar' : '--silent'
      command = ['curl', *options, *retry_options, '--location', '--continue-at', '-', progress, '--output', output, url].map(&:to_s)

      # Run the curl command in a loop, retry when curl exit status is 18
      # "Partial file. Only a part of the file was transferred."
      # https://curl.haxx.se/mail/archive-2008-07/0098.html
      # https://github.com/KrauseFx/xcode-install/issues/210
      3.times do
        io = IO.popen(command)
        io.each { |line| puts line }
        io.close

        exit_code = $?.exitstatus
        return exit_code.zero? unless exit_code == 18
      end
      false
    ensure
      FileUtils.rm_f(COOKIES_PATH)
    end
  end

  class Installer
    attr_reader :xcodes

    def initialize
      FileUtils.mkdir_p(CACHE_DIR)
    end

    def cache_dir
      CACHE_DIR
    end

    def current_symlink
      File.symlink?(SYMLINK_PATH) ? SYMLINK_PATH : nil
    end

    def download(version, progress, url = nil, local_url = nil)
      return unless url || exist?(version)
      xcode = seedlist.find { |x| x.name == version } unless url
      dmg_file = Pathname.new(File.basename(url || xcode.path))
      result = false
      unless local_url.nil?
        local_url += dmg_file.to_s
        result = Curl.new.fetch(local_url, CACHE_DIR, local_url ? nil : spaceship.cookie, dmg_file, progress)
      end
      if result == false
        # Attempt download again using original url passed in.
        result = Curl.new.fetch(url || xcode.url, CACHE_DIR, url ? nil : spaceship.cookie, dmg_file, progress)
      end
      result ? CACHE_DIR + dmg_file : nil
    end

    def exist?(version)
      list_versions.include?(version)
    end

    def installed?(version)
      installed_versions.map(&:version).include?(version)
    end

    def installed_versions
      installed.map { |x| InstalledXcode.new(x) }.sort do |a, b|
        Gem::Version.new(a.version) <=> Gem::Version.new(b.version)
      end
    end

    def install_dmg(dmg_path, suffix = '', switch = true, clean = true)
      archive_util = '/System/Library/CoreServices/Applications/Archive Utility.app/Contents/MacOS/Archive Utility'
      prompt = "Please authenticate for Xcode installation.\nPassword: "
      xcode_path = "/Applications/Xcode#{suffix}.app"

      if dmg_path.extname == '.xip'
        `'#{archive_util}' #{dmg_path}`
        xcode_orig_path = dmg_path.dirname + 'Xcode.app'
        xcode_beta_path = dmg_path.dirname + 'Xcode-beta.app'
        if Pathname.new(xcode_orig_path).exist?
          `sudo -p "#{prompt}" mv "#{xcode_orig_path}" "#{xcode_path}"`
        elsif Pathname.new(xcode_beta_path).exist?
          `sudo -p "#{prompt}" mv "#{xcode_beta_path}" "#{xcode_path}"`
        else
          out = <<-HELP
No `Xcode.app(or Xcode-beta.app)` found in XIP. Please remove #{dmg_path} if you
suspect a corrupted download or run `xcversion update` to see if the version
you tried to install has been pulled by Apple. If none of this is true,
please open a new GH issue.
HELP
          $stderr.puts out.tr("\n", ' ')
          return
        end
      else
        mount_dir = mount(dmg_path)
        source = Dir.glob(File.join(mount_dir, 'Xcode*.app')).first

        if source.nil?
          out = <<-HELP
No `Xcode.app` found in DMG. Please remove #{dmg_path} if you suspect a corrupted
download or run `xcversion update` to see if the version you tried to install
has been pulled by Apple. If none of this is true, please open a new GH issue.
HELP
          $stderr.puts out.tr("\n", ' ')
          return
        end

        `sudo -p "#{prompt}" ditto "#{source}" "#{xcode_path}"`
        `umount "/Volumes/Xcode"`
      end

      unless verify_integrity(xcode_path)
        `sudo rm -rf #{xcode_path}`
        return
      end

      enable_developer_mode
      xcode = InstalledXcode.new(xcode_path)
      xcode.approve_license
      xcode.install_components

      if switch
        `sudo rm -f #{SYMLINK_PATH}` unless current_symlink.nil?
        `sudo ln -sf #{xcode_path} #{SYMLINK_PATH}` unless SYMLINK_PATH.exist?

        `sudo xcode-select --switch #{xcode_path}`
        puts `xcodebuild -version`
      end

      FileUtils.rm_f(dmg_path) if clean
    end

    def install_version(version, switch = true, clean = true, install = true, progress = true, url = nil, show_release_notes = true, local_url = nil)
      dmg_path = get_dmg(version, progress, url, local_url)
      fail Informative, "Failed to download Xcode #{version}." if dmg_path.nil?

      if install
        install_dmg(dmg_path, "-#{version.split(' ')[0]}", switch, clean)
      else
        puts "Downloaded Xcode #{version} to '#{dmg_path}'"
      end

      open_release_notes_url(version) if show_release_notes && !url
    end

    def open_release_notes_url(version)
      return if version.nil?
      xcode = seedlist.find { |x| x.name == version }
      `open #{xcode.release_notes_url}` unless xcode.nil? || xcode.release_notes_url.nil?
    end

    def list_annotated(xcodes_list)
      installed = installed_versions.map(&:version)
      xcodes_list.map { |x| installed.include?(x) ? "#{x} (installed)" : x }.join("\n")
    end

    def list
      list_annotated(list_versions.sort)
    end

    def rm_list_cache
      FileUtils.rm_f(LIST_FILE)
    end

    def symlink(version)
      xcode = installed_versions.find { |x| x.version == version }
      `sudo rm -f #{SYMLINK_PATH}` unless current_symlink.nil?
      `sudo ln -sf #{xcode.path} #{SYMLINK_PATH}` unless xcode.nil? || SYMLINK_PATH.exist?
    end

    def symlinks_to
      File.absolute_path(File.readlink(current_symlink), SYMLINK_PATH.dirname) if current_symlink
    end

    def mount(dmg_path)
      plist = hdiutil('mount', '-plist', '-nobrowse', '-noverify', dmg_path.to_s)
      document = REXML::Document.new(plist)
      node = REXML::XPath.first(document, "//key[.='mount-point']/following-sibling::*[1]")
      fail Informative, 'Failed to mount image.' unless node
      node.text
    end

    private

    def spaceship
      @spaceship ||= begin
        begin
          Spaceship.login(ENV['XCODE_INSTALL_USER'], ENV['XCODE_INSTALL_PASSWORD'])
        rescue Spaceship::Client::InvalidUserCredentialsError
          $stderr.puts 'The specified Apple developer account credentials are incorrect.'
          exit(1)
        rescue Spaceship::Client::NoUserCredentialsError
          $stderr.puts <<-HELP
Please provide your Apple developer account credentials via the
XCODE_INSTALL_USER and XCODE_INSTALL_PASSWORD environment variables.
HELP
          exit(1)
        end

        if ENV.key?('XCODE_INSTALL_TEAM_ID')
          Spaceship.client.team_id = ENV['XCODE_INSTALL_TEAM_ID']
        end
        Spaceship.client
      end
    end

    LIST_FILE = CACHE_DIR + Pathname.new('xcodes.bin')
    MINIMUM_VERSION = Gem::Version.new('4.3')
    SYMLINK_PATH = Pathname.new('/Applications/Xcode.app')

    def enable_developer_mode
      `sudo /usr/sbin/DevToolsSecurity -enable`
      `sudo /usr/sbin/dseditgroup -o edit -t group -a staff _developer`
    end

    def get_dmg(version, progress = true, url = nil, local_url = nil)
      if url
        path = Pathname.new(url)
        return path if path.exist?
      end
      if ENV.key?('XCODE_INSTALL_CACHE_DIR')
        cache_path = Pathname.new(ENV['XCODE_INSTALL_CACHE_DIR']) + Pathname.new("xcode-#{version}.dmg")
        return cache_path if cache_path.exist?
      end

      download(version, progress, url, local_url)
    end

    def fetch_seedlist
      @xcodes = parse_seedlist(spaceship.send(:request, :post,
                                              '/services-account/QH65B2/downloadws/listDownloads.action').body)

      names = @xcodes.map(&:name)
      @xcodes += prereleases.reject { |pre| names.include?(pre.name) }

      File.open(LIST_FILE, 'wb') do |f|
        f << Marshal.dump(xcodes)
      end

      xcodes
    end

    def installed
      unless (`mdutil -s /` =~ /disabled/).nil?
        $stderr.puts 'Please enable Spotlight indexing for /Applications.'
        exit(1)
      end

      `mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null`.split("\n")
    end

    def parse_seedlist(seedlist)
      fail Informative, seedlist['resultString'] unless seedlist['resultCode'].eql? 0

      seeds = Array(seedlist['downloads']).select do |t|
        /^Xcode [0-9]/.match(t['name'])
      end

      xcodes = seeds.map { |x| Xcode.new(x) }.reject { |x| x.version < MINIMUM_VERSION }.sort do |a, b|
        a.date_modified <=> b.date_modified
      end

      xcodes.select { |x| x.url.end_with?('.dmg') || x.url.end_with?('.xip') }
    end

    def list_versions
      seedlist.map(&:name)
    end

    def prereleases
      body = spaceship.send(:request, :get, '/download/').body

      links = body.scan(%r{<a.+?href="(.+?/Xcode.+?/Xcode_(.+?)\.(dmg|xip))".*>(.*)</a>})
      links = links.map do |link|
        parent = link[0].scan(%r{path=(/.*/.*/)}).first.first
        match = body.scan(/#{Regexp.quote(parent)}(.+?.pdf)/).first
        if match
          link + [parent + match.first]
        else
          link + [nil]
        end
      end
      links = links.map { |pre| Xcode.new_prerelease(pre[1].strip.tr('_', ' '), pre[0], pre[4]) }

      if links.count.zero?
        rg = %r{platform-title.*Xcode.* beta.*<\/p>}
        scan = body.scan(rg)

        if scan.count.zero?
          rg = %r{Xcode.* GM.*<\/p>}
          scan = body.scan(rg)
        end

        return [] if scan.empty?

        version = scan.first.gsub(/<.*?>/, '').gsub(/.*Xcode /, '')
        link = body.scan(%r{<button .*"(.+?.xip)".*</button>}).first.first
        notes = body.scan(%r{<a.+?href="(/go/\?id=xcode-.+?)".*>(.*)</a>}).first.first
        links << Xcode.new(version, link, notes)
      end

      links
    end

    def seedlist
      @xcodes = Marshal.load(File.read(LIST_FILE)) if LIST_FILE.exist? && xcodes.nil?
      xcodes || fetch_seedlist
    end

    def verify_integrity(path)
      puts `/usr/sbin/spctl --assess --verbose=4 --type execute #{path}`
      $?.exitstatus.zero?
    end

    def hdiutil(*args)
      io = IO.popen(['hdiutil', *args])
      result = io.read
      io.close
      unless $?.exitstatus.zero?
        file_path = args[-1]
        if `file -b #{file_path}`.start_with?('HTML')
          fail Informative, "Failed to mount #{file_path}, logging into your account from a browser should tell you what is going wrong."
        end
        fail Informative, 'Failed to invoke hdiutil.'
      end
      result
    end
  end

  class Simulator
    attr_reader :version
    attr_reader :name
    attr_reader :identifier
    attr_reader :source
    attr_reader :xcode

    def initialize(downloadable)
      @version = Gem::Version.new(downloadable['version'])
      @install_prefix = apply_variables(downloadable['userInfo']['InstallPrefix'])
      @name = apply_variables(downloadable['name'])
      @identifier = apply_variables(downloadable['identifier'])
      @source = apply_variables(downloadable['source'])
    end

    def installed?
      # FIXME: use downloadables' `InstalledIfAllReceiptsArePresentOrNewer` key
      File.directory?(@install_prefix)
    end

    def installed_string
      installed? ? 'installed' : 'not installed'
    end

    def to_s
      "#{name} (#{installed_string})"
    end

    def xcode
      Installer.new.installed_versions.find do |x|
        x.available_simulators.find do |s|
          s.version == version
        end
      end
    end

    def download(progress)
      result = Curl.new.fetch(source, CACHE_DIR, nil, nil, progress)
      result ? dmg_path : nil
    end

    def install(progress, should_install)
      dmg_path = download(progress)
      fail Informative, "Failed to download #{@name}." if dmg_path.nil?

      return unless should_install
      prepare_package unless pkg_path.exist?
      puts "Please authenticate to install #{name}..."
      `sudo installer -pkg #{pkg_path} -target /`
      fail Informative, "Could not install #{name}, please try again" unless installed?
      source_receipts_dir = '/private/var/db/receipts'
      target_receipts_dir = "#{@install_prefix}/System/Library/Receipts"
      FileUtils.mkdir_p(target_receipts_dir)
      FileUtils.cp("#{source_receipts_dir}/#{@identifier}.bom", target_receipts_dir)
      FileUtils.cp("#{source_receipts_dir}/#{@identifier}.plist", target_receipts_dir)
      puts "Successfully installed #{name}"
    end

    :private

    def prepare_package
      puts 'Mounting DMG'
      mount_location = Installer.new.mount(dmg_path)
      puts 'Expanding pkg'
      expanded_pkg_path = CACHE_DIR + identifier
      FileUtils.rm_rf(expanded_pkg_path)
      `pkgutil --expand #{mount_location}/*.pkg #{expanded_pkg_path}`
      puts "Expanded pkg into #{expanded_pkg_path}"
      puts 'Unmounting DMG'
      `umount #{mount_location}`
      puts 'Setting package installation location'
      package_info_path = expanded_pkg_path + 'PackageInfo'
      package_info_contents = File.read(package_info_path)
      File.open(package_info_path, 'w') do |f|
        f << package_info_contents.sub('pkg-info', %(pkg-info install-location="#{@install_prefix}"))
      end
      puts 'Rebuilding package'
      `pkgutil --flatten #{expanded_pkg_path} #{pkg_path}`
      FileUtils.rm_rf(expanded_pkg_path)
    end

    def dmg_path
      CACHE_DIR + Pathname.new(source).basename
    end

    def pkg_path
      CACHE_DIR + "#{identifier}.pkg"
    end

    def apply_variables(template)
      variable_map = {
        '$(DOWNLOADABLE_VERSION_MAJOR)' => version.to_s.split('.')[0],
        '$(DOWNLOADABLE_VERSION_MINOR)' => version.to_s.split('.')[1],
        '$(DOWNLOADABLE_IDENTIFIER)' => identifier,
        '$(DOWNLOADABLE_VERSION)' => version.to_s
      }.freeze
      variable_map.each do |key, value|
        next unless template.include?(key)
        template.sub!(key, value)
      end
      template
    end
  end

  class InstalledXcode
    attr_reader :path
    attr_reader :version
    attr_reader :bundle_version
    attr_reader :uuid
    attr_reader :downloadable_index_url
    attr_reader :available_simulators

    def initialize(path)
      @path = Pathname.new(path)
    end

    def version
      @version ||= fetch_version
    end

    def bundle_version
      @bundle_version ||= Gem::Version.new(plist_entry(':DTXcode').to_i.to_s.split(//).join('.'))
    end

    def uuid
      @uuid ||= plist_entry(':DVTPlugInCompatibilityUUID')
    end

    def downloadable_index_url
      @downloadable_index_url ||= begin
        if Gem::Version.new(version) >= Gem::Version.new('8.1')
          "https://devimages-cdn.apple.com/downloads/xcode/simulators/index-#{bundle_version}-#{uuid}.dvtdownloadableindex"
        else
          "https://devimages.apple.com.edgekey.net/downloads/xcode/simulators/index-#{bundle_version}-#{uuid}.dvtdownloadableindex"
        end
      end
    end

    def approve_license
      license_path = "#{@path}/Contents/Resources/English.lproj/License.rtf"
      license_id = IO.read(license_path).match(/\bEA\d{4}\b/)
      license_plist_path = '/Library/Preferences/com.apple.dt.Xcode.plist'
      `sudo rm -rf #{license_plist_path}`
      `sudo /usr/libexec/PlistBuddy -c "add :IDELastGMLicenseAgreedTo string #{license_id}" #{license_plist_path}`
      `sudo /usr/libexec/PlistBuddy -c "add :IDEXcodeVersionForAgreedToGMLicense string #{@version}" #{license_plist_path}`
    end

    def available_simulators
      @available_simulators ||= JSON.parse(`curl -Ls #{downloadable_index_url} | plutil -convert json -o - -`)['downloadables'].map do |downloadable|
        Simulator.new(downloadable)
      end
    rescue JSON::ParserError
      return []
    end

    def install_components
      # starting with Xcode 9, we have `xcodebuild -runFirstLaunch` available to do package
      # postinstalls using a documented option
      if Gem::Version.new(@version) >= Gem::Version.new('9')
        `sudo #{@path}/Contents/Developer/usr/bin/xcodebuild -runFirstLaunch`
      else
        Dir.glob("#{@path}/Contents/Resources/Packages/*.pkg").each do |pkg|
          `sudo installer -pkg #{pkg} -target /`
        end
      end
      osx_build_version = `sw_vers -buildVersion`.chomp
      tools_version = `/usr/libexec/PlistBuddy -c "Print :ProductBuildVersion" "#{@path}/Contents/version.plist"`.chomp
      cache_dir = `getconf DARWIN_USER_CACHE_DIR`.chomp
      `touch #{cache_dir}com.apple.dt.Xcode.InstallCheckCache_#{osx_build_version}_#{tools_version}`
    end

    :private

    def plist_entry(keypath)
      `/usr/libexec/PlistBuddy -c "Print :#{keypath}" "#{path}/Contents/Info.plist"`.chomp
    end

    def fetch_version
      output = `DEVELOPER_DIR='' "#{@path}/Contents/Developer/usr/bin/xcodebuild" -version`
      return '0.0' if output.nil? || output.empty? # ¯\_(ツ)_/¯
      output.split("\n").first.split(' ')[1]
    end
  end

  class Xcode
    attr_reader :date_modified
    attr_reader :name
    attr_reader :path
    attr_reader :url
    attr_reader :version
    attr_reader :release_notes_url

    def initialize(json, url = nil, release_notes_url = nil)
      if url.nil?
        @date_modified = json['dateModified'].to_i
        @name = json['name'].gsub(/^Xcode /, '')
        @path = json['files'].first['remotePath']
        url_prefix = 'https://developer.apple.com/devcenter/download.action?path='
        @url = "#{url_prefix}#{@path}"
        @release_notes_url = "#{url_prefix}#{json['release_notes_path']}" if json['release_notes_path']
      else
        @name = json
        @path = url.split('/').last
        url_prefix = 'https://developer.apple.com/'
        @url = "#{url_prefix}#{url}"
        @release_notes_url = "#{url_prefix}#{release_notes_url}"
      end

      begin
        @version = Gem::Version.new(@name.split(' ')[0])
      rescue
        @version = Installer::MINIMUM_VERSION
      end
    end

    def to_s
      "Xcode #{version} -- #{url}"
    end

    def ==(other)
      date_modified == other.date_modified && name == other.name && path == other.path && \
        url == other.url && version == other.version
    end

    def self.new_prerelease(version, url, release_notes_path)
      new('name' => version,
          'files' => [{ 'remotePath' => url.split('=').last }],
          'release_notes_path' => release_notes_path)
    end
  end
end
