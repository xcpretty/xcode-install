require "fastlane_core"
require "fastlane_core/developer_center/developer_center"
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
end

module XcodeInstall
	class Curl
		def fetch(url, directory = nil, cookies = nil)
			options = cookies.nil? ? '' : "-b #{cookies}"

			uri = URI.parse(url)
			output = File.basename(uri.path)
			output = (Pathname.new(directory) + Pathname.new(output)) if directory

			puts directory.inspect
			puts output

			IO.popen("curl #{options} -C - -# -o #{output} #{url}").each do |fd|
				puts(fd)
			end
		end
	end

	class Installer
		attr_reader :xcodes

		def initialize
			FileUtils.mkdir_p(CACHE_DIR)
		end

		def list_current
			majors = list_versions.map { |v| v.split('.')[0] }.select { |v| v.length == 1 }.uniq
			list_versions.select { |v| v.start_with?(majors.last) }.join("\n")
		end

		def list
			list_versions.join("\n")
		end

		:private

		CACHE_DIR = Pathname.new("#{ENV['HOME']}/Library/Caches/XcodeInstall")
		LIST_FILE = CACHE_DIR + Pathname.new('xcodes.bin')

		def get_seedlist
			@devcenter = FastlaneCore::DeveloperCenter.new if @devcenter.nil?
			@xcodes = parse_seedlist(@devcenter.download_seedlist)

			File.open(LIST_FILE,'w') do |f|
				f << Marshal.dump(xcodes)
			end

			xcodes
		end

		def parse_seedlist(seedlist)
			seedlist['data'].select { 
				|t| /^Xcode [0-9]/.match(t['name'])
			}.map { |x| Xcode.new(x) }.sort { |a,b| a.dateModified <=> b.dateModified }
		end

		def list_versions
			seedlist.map { |x| x.name }
		end

		def seedlist
			@xcodes = Marshal.load(File.read(LIST_FILE)) if LIST_FILE.exist? && xcodes.nil?
			xcodes || get_seedlist
		end
	end

	class Xcode
		attr_reader :dateModified
		attr_reader :name
		attr_reader :url

		def initialize(json)
			@dateModified = json['dateModified'].to_i
			@name = json['name'].gsub(/^Xcode /, '')
			@url = "http://adcdownload.apple.com#{json['files'].first['remotePath']}"
		end
	end
end