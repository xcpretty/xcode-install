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
				raise Informative, "Version #{@version} already installed." if @installer.installed?(@version)
				raise Informative, "Version #{@version} doesn't exist." unless @installer.exist?(@version)
			end

			def run
				dmgPath = @installer.download(@version)
				raise Informative, "Failed to download Xcode #{@version}." if dmgPath.nil?

				@installer.install_dmg(dmgPath, "-#{@version}")
			end
		end
	end
end