module XcodeInstall
	class PlainInformative < StandardError
    	include CLAide::InformativeError
  	end

	class Informative < PlainInformative
    	def message
      		"[!] #{super}".red
    	end
  	end

	class Command
		class Install < Command
			self.command = 'install'
			self.summary = 'Install a specific version of Xcode.'

			self.arguments = [
				CLAide::Argument.new('VERSION', :true),
			]

			def initialize(argv)
				@installer = Installer.new
				@version = argv.shift_argument
			end

			def validate!
				raise Informative, "Version #{@version} doesn't exist." unless @installer.exist?(@version)
			end

			def run
				@installer.download(@version)
			end
		end
	end
end