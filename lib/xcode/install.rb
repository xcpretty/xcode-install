require 'fileutils'
require 'pathname'
require 'spaceship'
require 'rubygems/version'
require 'xcode/install/command'
require 'xcode/install/version'

module XcodeInstall
  class Curl
    COOKIES_PATH = Pathname.new('/tmp/curl-cookies.txt')

    def fetch(url, directory = nil, cookies = nil, output = nil, progress = true)
      options = cookies.nil? ? '' : "-b '#{cookies}' -c #{COOKIES_PATH}"
      # options += ' -vvv'

      uri = URI.parse(url)
      output ||= File.basename(uri.path)
      output = (Pathname.new(directory) + Pathname.new(output)) if directory

      progress = progress ? '-#' : '-s'
      command = "curl #{options} -L -C - #{progress} -o #{output} #{url}"
      IO.popen(command).each do |fd|
        puts(fd)
      end
      result = $CHILD_STATUS.to_i == 0

      FileUtils.rm_f(COOKIES_PATH)
      result
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

    def download(version, progress)
      return unless exist?(version)
      xcode = seedlist.find { |x| x.name == version }
      dmg_file = Pathname.new(File.basename(xcode.path))

      result = Curl.new.fetch(xcode.url, CACHE_DIR, spaceship.cookie, dmg_file, progress)
      result ? CACHE_DIR + dmg_file : nil
    end

    def exist?(version)
      list_versions.include?(version)
    end

    def install_components(xcode_path)
      `#{xcode_path}/Contents/MacOS/Xcode -installComponents`
    end

    def installed?(version)
      installed_versions.map(&:version).include?(version)
    end

    def installed_versions
      @installed ||= installed.map { |x| InstalledXcode.new(x) }.sort do |a, b|
        Gem::Version.new(a.version) <=> Gem::Version.new(b.version)
      end
    end

    def install_dmg(dmgPath, suffix = '', switch = true, clean = true, components = true)
      xcode_path = "/Applications/Xcode#{suffix}.app"

      `hdiutil mount -nobrowse -noverify #{dmgPath}`
      puts 'Please authenticate for Xcode installation...'
      source =  Dir.glob('/Volumes/Xcode/Xcode*.app').first

      if source.nil?
        $stderr.puts <<-HELP
No `Xcode.app` found in DMG. Please remove #{dmgPath} if you suspect a corrupted
download or run `xcode-install update` to see if the version you tried to install
has been pulled by Apple. If none of this is true, please open a new GH issue.
HELP
        return
      end

      `sudo ditto "#{source}" "#{xcode_path}"`
      `umount "/Volumes/Xcode"`

      if not verify_integrity(xcode_path)
        `sudo rm -f #{xcode_path}`
        return
      end

      enable_developer_mode
      `sudo xcodebuild -license accept` unless xcode_license_approved?
      install_components(xcode_path) if components

      if switch
        `sudo rm -f #{SYMLINK_PATH}` unless current_symlink.nil?
        `sudo ln -sf #{xcode_path} #{SYMLINK_PATH}` unless SYMLINK_PATH.exist?

        `sudo xcode-select --switch #{xcode_path}`
        puts `xcodebuild -version`
      end

      FileUtils.rm_f(dmgPath) if clean
    end

    def install_version(version, switch = true, clean = true, install = true, progress = true,
          components = true)
      return if version.nil?
      dmg_path = get_dmg(version, progress)
      fail Informative, "Failed to download Xcode #{version}." if dmg_path.nil?

      install_dmg(dmg_path, "-#{version.split(' ')[0]}", switch, clean, components) if install
    end

    def list_current
      stable_majors = list_versions.reject { |v| /beta/i =~ v }.map { |v| v.split('.')[0] }.map { |v| v.split(' ')[0] }
      latest_stable_major = stable_majors.select { |v| v.length == 1 }.uniq.sort.last.to_i
      list_versions.select { |v| v.split('.')[0].to_i >= latest_stable_major }.sort.join("\n")
    end

    def list
      list_versions.join("\n")
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

    private

    def spaceship
      @spaceship ||= begin
        begin
          Spaceship.login(ENV["XCODE_INSTALL_USER"], ENV["XCODE_INSTALL_PASSWORD"])
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

        if ENV.key?("XCODE_INSTALL_TEAM_ID")
          Spaceship.client.team_id = ENV["XCODE_INSTALL_TEAM_ID"]
        end
        Spaceship.client
      end
    end

    CACHE_DIR = Pathname.new("#{ENV['HOME']}/Library/Caches/XcodeInstall")
    LIST_FILE = CACHE_DIR + Pathname.new('xcodes.bin')
    MINIMUM_VERSION = Gem::Version.new('4.3')
    SYMLINK_PATH = Pathname.new('/Applications/Xcode.app')

    def enable_developer_mode
      `sudo /usr/sbin/DevToolsSecurity -enable`
      `sudo /usr/sbin/dseditgroup -o edit -t group -a staff _developer`
    end

    def get_dmg(version, progress = true)
      if ENV.key?('XCODE_INSTALL_CACHE_DIR')
        cache_path = Pathname.new(ENV['XCODE_INSTALL_CACHE_DIR']) + Pathname.new("xcode-#{version}.dmg")
        return cache_path if cache_path.exist?
      end

      download(version, progress)
    end

    def fetch_seedlist
      @xcodes = parse_seedlist(spaceship.send(:request, :get, '/services-account/QH65B2/downloadws/listDownloads.action', {
        start: "0",
        limit: "1000",
        sort: "dateModified",
        dir: "DESC",
        searchTextField: "",
        searchCategories: "",
        search: "false",
      }).body)

      names = @xcodes.map(&:name)
      @xcodes += prereleases.reject { |pre| names.include?(pre.name) }

      File.open(LIST_FILE, 'w') do |f|
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
      seeds = seedlist['downloads'].select do |t|
        /^Xcode [0-9]/.match(t['name'])
      end

      xcodes = seeds.map { |x| Xcode.new(x) }.reject { |x| x.version < MINIMUM_VERSION }.sort do |a, b|
        a.date_modified <=> b.date_modified
      end

      xcodes.select { |x| x.url.end_with?('.dmg') }
    end

    def list_versions
      installed = installed_versions.map(&:version)
      seedlist.map(&:name).reject { |x| installed.include?(x) }
    end

    def prereleases
      body=spaceship.send(:request, :get, '/xcode/download/').body
      links=body.scan(/<a.+?href="(.+?.dmg)".*>(.*)<\/a>/)

      links.map { |pre| Xcode.new_prelease(pre[1].strip.gsub(/.*Xcode /, ''), pre[0]) }
    end

    def seedlist
      @xcodes = Marshal.load(File.read(LIST_FILE)) if LIST_FILE.exist? && xcodes.nil?
      xcodes || fetch_seedlist
    end

    def verify_integrity(path)
      puts `codesign --verify --verbose #{path}`
      $?.exitstatus == 0
    end

    def xcode_license_approved?
      !(`/usr/bin/xcrun clang 2>&1` =~ /license/ && !$CHILD_STATUS.success?)
    end
  end

  class InstalledXcode
    attr_reader :path
    attr_reader :version

    def initialize(path)
      @path = Pathname.new(path)
      @version = get_version(path)
    end

    :private

    def get_version(xcode_path)
      output = `DEVELOPER_DIR='' "#{xcode_path}/Contents/Developer/usr/bin/xcodebuild" -version`
      return '0.0' if output.nil? # ¯\_(ツ)_/¯
      output.split("\n").first.split(' ')[1]
    end
  end

  class Xcode
    attr_reader :date_modified
    attr_reader :name
    attr_reader :path
    attr_reader :url
    attr_reader :version

    def initialize(json)
      @date_modified = json['dateModified'].to_i
      @name = json['name'].gsub(/^Xcode /, '')
      @path = json['files'].first['remotePath']
      @url = "https://developer.apple.com/devcenter/download.action?path=#{@path}"

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

    def self.new_prelease(version, url)
      new('name' => version,
          'dateModified' => Time.now.to_i,
          'files' => [{ 'remotePath' => url.split('=').last }])
    end
  end
end
