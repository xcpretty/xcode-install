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
				return if @version.nil?
				raise Informative, "Version #{@version} already installed." if @installer.installed?(@version)
				raise Informative, "Version #{@version} doesn't exist." unless @installer.exist?(@version)
			end

			def run
				return if @version.nil?
				dmg_path = get_dmg(@version)
				raise Informative, "Failed to download Xcode #{@version}." if dmg_path.nil?

				@installer.install_dmg(dmg_path, "-#{@version.split(' ')[0]}", @should_switch, @should_clean)
			end
			
			private
			
			def get_dmg(version)
				if ENV.key?("XCODE_INSTALL_CACHE_DIR")
					cache_path = Pathname.new(ENV["XCODE_INSTALL_CACHE_DIR"]) + Pathname.new("xcode-#{version}.dmg")
					if cache_path.exist?
						return cache_path
					end
				end
				
				return @installer.download(@version)
			end
		end
	end
end
