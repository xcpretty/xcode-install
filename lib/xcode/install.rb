require 'fileutils'
require 'pathname'
require 'rexml/document'
require 'spaceship'
require 'json'
require 'rubygems/version'
require 'xcode/install/command'
require 'xcode/install/version'
require 'shellwords'
require 'open3'
require 'fastlane'
require 'fastlane/helper/sh_helper'
require 'fastlane/action'
require 'fastlane/actions/verify_xcode'

module XcodeInstall
  CACHE_DIR = Pathname.new("#{ENV['HOME']}/Library/Caches/XcodeInstall")
  class Curl
    COOKIES_PATH = Pathname.new('/tmp/curl-cookies.txt')

    # @param url: The URL to download
    # @param directory: The directory to download this file into
    # @param cookies: Any cookies we should use for the download (used for auth with Apple)
    # @param output: A PathName for where we want to store the file
    # @param progress: parse and show the progress?
    # @param progress_block: A block that's called whenever we have an updated progress %
    #                        the parameter is a single number that's literally percent (e.g. 1, 50, 80 or 100)
    # @param retry_download_count: A count to retry the downloading Xcode dmg/xip
    def fetch(url: nil,
              directory: nil,
              cookies: nil,
              output: nil,
              progress: nil,
              progress_block: nil,
              retry_download_count: 3)
      options = cookies.nil? ? [] : ['--cookie', cookies, '--cookie-jar', COOKIES_PATH]

      uri = URI.parse(url)
      output ||= File.basename(uri.path)
      output = (Pathname.new(directory) + Pathname.new(output)) if directory

      # Piping over all of stderr over to a temporary file
      # the file content looks like this:
      #  0 4766M    0 6835k    0     0   573k      0  2:21:58  0:00:11  2:21:47  902k
      # This way we can parse the current %
      # The header is
      #  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
      #
      # Discussion for this on GH: https://github.com/KrauseFx/xcode-install/issues/276
      # It was not easily possible to reimplement the same system using built-in methods
      # especially when it comes to resuming downloads
      # Piping over stderror to Ruby directly didn't work, due to the lack of flushing
      # from curl. The only reasonable way to trigger this, is to pipe things directly into a
      # local file, and parse that, and just poll that. We could get real time updates using
      # the `tail` command or similar, however the download task is not time sensitive enough
      # to make this worth the extra complexity, that's why we just poll and
      # wait for the process to be finished
      progress_log_file = File.join(CACHE_DIR, "progress.#{Time.now.to_i}.progress")
      FileUtils.rm_f(progress_log_file)

      retry_options = ['--retry', '3']
      command = [
        'curl',
        '--disable',
        *options,
        *retry_options,
        '--location',
        '--continue-at',
        '-',
        '--output',
        output,
        url
      ].map(&:to_s)

      command_string = command.collect(&:shellescape).join(' ')
      command_string += " 2> #{progress_log_file}" # to not run shellescape on the `2>`

      # Run the curl command in a loop, retry when curl exit status is 18
      # "Partial file. Only a part of the file was transferred."
      # https://curl.haxx.se/mail/archive-2008-07/0098.html
      # https://github.com/KrauseFx/xcode-install/issues/210
      retry_download_count.times do
        wait_thr = poll_file(command_string: command_string, progress_log_file: progress_log_file, progress: progress, progress_block: progress_block)
        return wait_thr.value.success? if wait_thr.value.success?
      end
      false
    ensure
      FileUtils.rm_f(COOKIES_PATH)
      FileUtils.rm_f(progress_log_file)
    end

    def poll_file(command_string:, progress_log_file:, progress: nil, progress_block: nil)
      # Non-blocking call of Open3
      # We're not using the block based syntax, as the bacon testing
      # library doesn't seem to support writing tests for it
      stdin, stdout, stderr, wait_thr = Open3.popen3(command_string)

      # Poll the file and see if we're done yet
      while wait_thr.alive?
        sleep(0.5) # it's not critical for this to be real-time
        next unless File.exist?(progress_log_file) # it might take longer for it to be created

        progress_content = File.read(progress_log_file).split("\r").last || ''

        # Print out the progress for the CLI
        if progress
          print "\r#{progress_content}%"
          $stdout.flush
        end

        # Call back the block for other processes that might be interested
        matched = progress_content.match(/^\s*(\d+)/)
        next unless matched && matched.length == 2
        percent = matched[1].to_i
        progress_block.call(percent) if progress_block
      end

      # as we're not making use of the block-based syntax
      # we need to manually close those
      stdin.close
      stdout.close
      stderr.close

      wait_thr
    end
  end

  # rubocop:disable Metrics/ClassLength
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

    def download(version, progress, url = nil, progress_block = nil, retry_download_count = 3)
      xcode = find_xcode_version(version) if url.nil?
      return if url.nil? && xcode.nil?

      dmg_file = Pathname.new(File.basename(url || xcode.path))

      result = Curl.new.fetch(
        url: url || xcode.url,
        directory: CACHE_DIR,
        cookies: url ? nil : spaceship.cookie,
        output: dmg_file,
        progress: progress,
        progress_block: progress_block,
        retry_download_count: retry_download_count
      )
      result ? CACHE_DIR + dmg_file : nil
    end

    def find_xcode_version(version)
      # By checking for the name and the version we have the best success rate
      # Sometimes the user might pass
      #   "4.3 for Lion"
      # or they might pass an actual Gem::Version
      #   Gem::Version.new("8.0.0")
      # which should automatically match with "Xcode 8"

      begin
        parsed_version = Gem::Version.new(version)
      rescue ArgumentError
        nil
      end

      seedlist.each do |current_seed|
        return current_seed if current_seed.name == version
      end

      seedlist.each do |current_seed|
        return current_seed if parsed_version && current_seed.version == parsed_version
      end

      nil
    end

    def exist?(version)
      return true if find_xcode_version(version)
      false
    end

    def installed?(version)
      installed_versions.map(&:version).include?(version)
    end

    def installed_versions
      installed.map { |x| InstalledXcode.new(x) }.sort do |a, b|
        Gem::Version.new(a.version) <=> Gem::Version.new(b.version)
      end
    end

    # Returns an array of `XcodeInstall::Xcode`
    #   <XcodeInstall::Xcode:0x007fa1d451c390
    #     @date_modified=2015,
    #     @name="6.4",
    #     @path="/Developer_Tools/Xcode_6.4/Xcode_6.4.dmg",
    #     @url=
    #      "https://developer.apple.com/devcenter/download.action?path=/Developer_Tools/Xcode_6.4/Xcode_6.4.dmg",
    #     @version=Gem::Version.new("6.4")>,
    #
    # the resulting list is sorted with the most recent release as first element
    def seedlist
      @xcodes = Marshal.load(File.read(LIST_FILE)) if LIST_FILE.exist? && xcodes.nil?
      all_xcodes = (xcodes || fetch_seedlist)

      # We have to set the `installed` value here, as we might still use
      # the cached list of available Xcode versions, but have a new Xcode
      # installed in the mean-time
      cached_installed_versions = installed_versions.map(&:bundle_version)
      all_xcodes.each do |current_xcode|
        current_xcode.installed = cached_installed_versions.include?(current_xcode.version)
      end

      all_xcodes.sort_by { |seed| [seed.version, -seed.date_modified] }.reverse
    end

    def install_dmg(dmg_path, suffix = '', switch = true, clean = true)
      prompt = "Please authenticate for Xcode installation.\nPassword: "
      xcode_path = "/Applications/Xcode#{suffix}.app"

      if dmg_path.extname == '.xip'
        `xip -x #{dmg_path}`
        xcode_orig_path = File.join(Dir.pwd, 'Xcode.app')
        xcode_beta_path = File.join(Dir.pwd, 'Xcode-beta.app')
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

      xcode = InstalledXcode.new(xcode_path)

      unless xcode.verify_integrity
        `sudo rm -rf #{xcode_path}`
        return
      end

      enable_developer_mode
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

    # rubocop:disable Metrics/ParameterLists
    def install_version(version, switch = true, clean = true, install = true, progress = true, url = nil, show_release_notes = true, progress_block = nil, retry_download_count = 3)
      dmg_path = get_dmg(version, progress, url, progress_block, retry_download_count)
      fail Informative, "Failed to download Xcode #{version}." if dmg_path.nil?

      if install
        install_dmg(dmg_path, "-#{version.to_s.split(' ').join('.')}", switch, clean)
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
      installed = installed_versions.map(&:appname_version)

      xcodes_list.map do |x|
        xcode_version = x.split(' ') # split version and "beta N", "for Lion"
        xcode_version[0] << '.0' unless xcode_version[0].include?('.')

        # to match InstalledXcode.appname_version format
        version = Gem::Version.new(xcode_version.join('.'))

        installed.include?(version) ? "#{x} (installed)" : x
      end.join("\n")
    end

    def list
      list_annotated(list_versions.sort { |first, second| compare_versions(first, second) })
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
          raise 'The specified Apple developer account credentials are incorrect.'
        rescue Spaceship::Client::NoUserCredentialsError
          raise <<-HELP
Please provide your Apple developer account credentials via the
XCODE_INSTALL_USER and XCODE_INSTALL_PASSWORD environment variables.
HELP
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

    def get_dmg(version, progress = true, url = nil, progress_block = nil, retry_download_count = 3)
      if url
        path = Pathname.new(url)
        return path if path.exist?
      end
      if ENV.key?('XCODE_INSTALL_CACHE_DIR')
        Pathname.glob(ENV['XCODE_INSTALL_CACHE_DIR'] + '/*').each do |fpath|
          return fpath if /^xcode_#{version}\.dmg|xip$/ =~ fpath.basename.to_s
        end
      end

      download(version, progress, url, progress_block, retry_download_count)
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
      result = `mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null`.split("\n")
      if result.empty?
        result = `find /Applications -maxdepth 1 -name '*.app' -type d -exec sh -c \
        'if [ "$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
        "{}/Contents/Info.plist" 2>/dev/null)" == "com.apple.dt.Xcode" ]; then echo "{}"; fi' ';'`.split("\n")
      end
      result
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
        link = body.scan(%r{<button .*"(.+?.(dmg|xip))".*</button>}).first.first
        notes = body.scan(%r{<a.+?href="(/go/\?id=xcode-.+?)".*>(.*)</a>}).first.first
        links << Xcode.new(version, link, notes)
      end

      links
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def compare_versions(first, second)
      # Sort by version number
      numeric_comparation = first.to_f <=> second.to_f
      return numeric_comparation if numeric_comparation != 0

      # Return beta versions before others
      is_first_beta = first.include?('beta')
      is_second_beta = second.include?('beta')
      return -1 if is_first_beta && !is_second_beta
      return 1 if !is_first_beta && is_second_beta

      # Return GM versions before others
      is_first_gm = first.include?('GM')
      is_second_gm = second.include?('GM')
      return -1 if is_first_gm && !is_second_gm
      return 1 if !is_first_gm && is_second_gm

      # Return Release Candidate versions before others
      is_first_rc = first.include?('RC') || first.include?('Release Candidate')
      is_second_rc = second.include?('RC') || second.include?('Release Candidate')
      return -1 if is_first_rc && !is_second_rc
      return 1 if !is_first_rc && is_second_rc

      # Sort alphabetically
      first <=> second
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

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

    def download(progress, progress_block = nil, retry_download_count = 3)
      result = Curl.new.fetch(
        url: source,
        directory: CACHE_DIR,
        progress: progress,
        progress_block: progress_block,
        retry_download_count: retry_download_count
      )
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
      @bundle_version ||= Gem::Version.new(bundle_version_string)
    end

    def appname_version
      appname = @path.basename('.app').to_s
      version_string = appname.split('-').last
      begin
        Gem::Version.new(version_string)
      rescue ArgumentError
        puts 'Unable to determine Xcode version from path name, installed list may not correctly identify installed betas'
        Gem::Version.new(nil)
      end
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
      if Gem::Version.new(version) < Gem::Version.new('7.3')
        license_info_path = File.join(@path, 'Contents/Resources/LicenseInfo.plist')
        license_id = `/usr/libexec/PlistBuddy -c 'Print :licenseID' #{license_info_path}`
        license_type = `/usr/libexec/PlistBuddy -c 'Print :licenseType' #{license_info_path}`
        license_plist_path = '/Library/Preferences/com.apple.dt.Xcode.plist'
        `sudo rm -rf #{license_plist_path}`
        if license_type == 'GM'
          `sudo /usr/libexec/PlistBuddy -c "add :IDELastGMLicenseAgreedTo string #{license_id}" #{license_plist_path}`
          `sudo /usr/libexec/PlistBuddy -c "add :IDEXcodeVersionForAgreedToGMLicense string #{version}" #{license_plist_path}`
        else
          `sudo /usr/libexec/PlistBuddy -c "add :IDELastBetaLicenseAgreedTo string #{license_id}" #{license_plist_path}`
          `sudo /usr/libexec/PlistBuddy -c "add :IDEXcodeVersionForAgreedToBetaLicense string #{version}" #{license_plist_path}`
        end
      else
        `sudo #{@path}/Contents/Developer/usr/bin/xcodebuild -license accept`
      end
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
      if Gem::Version.new(version) >= Gem::Version.new('9')
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

    def fetch_version
      output = `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "#{@path}/Contents/version.plist"`
      return '0.0' if output.nil? || output.empty? # ¯\_(ツ)_/¯
      output.sub("\n", '')
    end

    def verify_integrity
      verify_app_security_assessment && verify_app_cert
    end

    :private

    def bundle_version_string
      digits = plist_entry(':DTXcode').to_i.to_s
      if digits.length < 3
        digits.split(//).join('.')
      else
        "#{digits[0..-3]}.#{digits[-2]}.#{digits[-1]}"
      end
    end

    def plist_entry(keypath)
      `/usr/libexec/PlistBuddy -c "Print :#{keypath}" "#{path}/Contents/Info.plist"`.chomp
    end

    def verify_app_security_assessment
      puts `/usr/bin/codesign --verify --verbose #{@path}`
      $?.exitstatus.zero?
    end

    def verify_app_cert
      Fastlane::Actions::VerifyXcodeAction.run(xcode_path: @path.to_s)
      true
    rescue
      false
    end
  end

  # A version of Xcode we fetched from the Apple Developer Portal
  # we can download & install.
  #
  # Sample object:
  # <XcodeInstall::Xcode:0x007fa1d451c390
  #    @date_modified=1573661580,
  #    @name="6.4",
  #    @path="/Developer_Tools/Xcode_6.4/Xcode_6.4.dmg",
  #    @url=
  #     "https://developer.apple.com/devcenter/download.action?path=/Developer_Tools/Xcode_6.4/Xcode_6.4.dmg",
  #    @version=Gem::Version.new("6.4")>,
  class Xcode
    attr_reader :date_modified

    # The name might include extra information like "for Lion" or "beta 2"
    attr_reader :name
    attr_reader :path
    attr_reader :url
    attr_reader :version
    attr_reader :release_notes_url

    # Accessor since it's set by the `Installer`
    attr_accessor :installed

    alias installed? installed

    def initialize(json, url = nil, release_notes_url = nil)
      if url.nil?
        @date_modified = DateTime.strptime(json['dateModified'], '%m/%d/%y %H:%M').strftime('%s').to_i
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
          'dateModified' => '01/01/70 00:00',
          'files' => [{ 'remotePath' => url.split('=').last }],
          'release_notes_path' => release_notes_path)
    end
  end
end
