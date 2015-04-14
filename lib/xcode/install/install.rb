module XcodeInstall
	class Command
		class Install < Command
			self.command = 'install'
			self.summary = 'Install a specific version of Xcode.'

			self.arguments = [
				CLAide::Argument.new('VERSION', :true),
			]

			def self.options
				[['--no-switch', 'Don’t switch to this version after installation'],
				 ['--no-clean', 'Don’t delete DMG after installation.']].concat(super)
			end

			def initialize(argv)
				@installer = Installer.new
				@version = argv.shift_argument
				@should_clean = argv.flag?('clean', true)
				@should_switch = argv.flag?('switch', true)
				super
			end

			def validate!
				raise Informative, "Version #{@version} already installed." if @installer.installed?(@version)
				raise Informative, "Version #{@version} doesn't exist." unless @installer.exist?(@version)
			end

			def run
				dmgPath = @installer.download(@version)
				raise Informative, "Failed to download Xcode #{@version}." if dmgPath.nil?

				@installer.install_dmg(dmgPath, "-#{@version.split(' ')[0]}", @should_switch, @should_clean)
			end
		end
	end
end
