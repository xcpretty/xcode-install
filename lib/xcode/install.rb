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
			@devcenter = FastlaneCore::DeveloperCenter.new
		end

		def list
			parse_seedlist(@devcenter.download_seedlist)
		end

		:private

		def parse_seedlist(seedlist)
			@xcodes = seedlist['data'].select { 
				|t| t['name'].start_with?('Xcode') 
			}.map { |x| Xcode.new(x) }.sort { |a,b| a.dateModified <=> b.dateModified }

			@xcodes.map { |x| x.name }.join("\n")
		end
	end

	class Xcode
		attr_reader :dateModified
		attr_reader :name
		attr_reader :url

		def initialize(json)
			@dateModified = json['dateModified'].to_i
			@name = json['name']
			@url = "http://adcdownload.apple.com#{json['files'].first['remotePath']}"
		end
	end
end