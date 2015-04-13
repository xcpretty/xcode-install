require "fastlane_core"
require "fastlane_core/developer_center/developer_center"
require "xcode/install/command"
require "xcode/install/version"

module FastlaneCore
	class DeveloperCenter
		def cookies
			cookie_string = ""

			page.driver.cookies.each do |key, cookie|
				cookie_string << "#{cookie.name}=#{cookie.value};"
			end

			cookie_string
		end

		def download_seedlist
			# categories: Applications%2CDeveloper%20Tools%2CiOS%2COS%20X%2COS%20X%20Server%2CSafari
			JSON.parse(page.evaluate_script("$.ajax({data: { start: \"0\", limit: \"1000\", " + 
				"sort: \"dateModified\", dir: \"DESC\", searchTextField: \"\", " + 
				"searchCategories: \"\", search: \"false\" } , type: 'POST', " + 
				"url: '/downloads/seedlist.action', async: false})")['responseText'])
		end
	end

	module Helper
		def self.is_test?
			true
		end
	end
end

module XcodeInstall
	class Curl
		COOKIES_PATH = Pathname.new('/tmp/curl-cookies.txt')

		def fetch(url, directory = nil, cookies = nil, output = nil)
			options = cookies.nil? ? '' : "-b '#{cookies}' -c #{COOKIES_PATH}"
			#options += ' -vvv'

			uri = URI.parse(url)
			output ||= File.basename(uri.path)
			output = (Pathname.new(directory) + Pathname.new(output)) if directory

			command = "curl #{options} -L -C - -# -o #{output} #{url}"
			IO.popen(command).each do |fd|
				puts(fd)
			end
			result = $?.to_i == 0

			FileUtils.rm_f(COOKIES_PATH)
			result
		end
	end

	class Installer
		attr_reader :xcodes

		def initialize
			FileUtils.mkdir_p(CACHE_DIR)
		end

		def current_symlink
			File.symlink?(SYMLINK_PATH) ? SYMLINK_PATH : nil
		end

		def download(version)
			return unless exist?(version)
			xcode = seedlist.select { |x| x.name == version }.first
			dmg_file = Pathname.new(File.basename(xcode.path))

			result = Curl.new.fetch(xcode.url, CACHE_DIR, devcenter.cookies, dmg_file)
			result ? CACHE_DIR + dmg_file : nil
		end

		def exist?(version)
			list_versions.include?(version)
		end

		def installed?(version)
			installed_versions.map { |x| x.version }.include?(version)
		end

		def installed_versions
			@installed ||= installed.map { |x| InstalledXcode.new(x) }
		end

		def install_dmg(dmgPath, suffix = '')
			xcode_path = "/Applications/Xcode#{suffix}.app"

			`hdiutil mount -nobrowse -noverify #{dmgPath}`
			puts 'Please authenticate for Xcode installation...'
			`sudo ditto "/Volumes/Xcode/Xcode.app" "#{xcode_path}"`
			`umount "/Volumes/Xcode"`

			`sudo xcode-select -s #{xcode_path}`
			puts `xcodebuild -version`
		end

		def list_current
			majors = list_versions.map { |v| v.split('.')[0] }.select { |v| v.length == 1 }.uniq
			list_versions.select { |v| v.start_with?(majors.last) }.join("\n")
		end

		def list
			list_versions.join("\n")
		end

		def symlink(version)
			xcode = installed_versions.select { |x| x.version == version }.first
			`sudo rm -f #{SYMLINK_PATH}` unless current_symlink.nil?
			`sudo ln -sf #{xcode.path} #{SYMLINK_PATH}` unless xcode.nil? || SYMLINK_PATH.exist?
		end

		def symlinks_to
			File.absolute_path(File.readlink(current_symlink), SYMLINK_PATH.dirname) if current_symlink
		end

		:private

		CACHE_DIR = Pathname.new("#{ENV['HOME']}/Library/Caches/XcodeInstall")
		LIST_FILE = CACHE_DIR + Pathname.new('xcodes.bin')
		SYMLINK_PATH = Pathname.new('/Applications/Xcode.app')

		def devcenter
			@devcenter ||= FastlaneCore::DeveloperCenter.new
		end

		def get_seedlist
			@xcodes = parse_seedlist(devcenter.download_seedlist)

			File.open(LIST_FILE,'w') do |f|
				f << Marshal.dump(xcodes)
			end

			xcodes
		end

		def installed
			`mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null`.split("\n")
		end

		def parse_seedlist(seedlist)
			seedlist['data'].select { 
				|t| /^Xcode [0-9]/.match(t['name'])
			}.map { |x| Xcode.new(x) }.sort { |a,b| a.dateModified <=> b.dateModified }
		end

		def list_versions
			installed = installed_versions.map { |x| x.version }
			seedlist.map { |x| x.name }.reject { |x| installed.include?(x) }
		end

		def seedlist
			@xcodes = Marshal.load(File.read(LIST_FILE)) if LIST_FILE.exist? && xcodes.nil?
			xcodes || get_seedlist
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
			output = `DEVELOPER_DIR='' #{xcode_path}/Contents/Developer/usr/bin/xcodebuild -version`
			output.split("\n").first.split(' ')[1]
		end
	end

	class Xcode
		attr_reader :dateModified
		attr_reader :name
		attr_reader :path
		attr_reader :url

		def initialize(json)
			@dateModified = json['dateModified'].to_i
			@name = json['name'].gsub(/^Xcode /, '')
			@path = json['files'].first['remotePath']
			@url = "https://developer.apple.com/devcenter/download.action?path=#{@path}"
		end
	end
end