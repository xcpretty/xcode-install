module XcodeInstall
  class Command
    class Install < Command
      self.command = 'install'
      self.summary = 'Install a specific version of Xcode.'

      self.arguments = [
        CLAide::Argument.new('VERSION', :true)
      ]

      def self.options
        [['--no-switch', 'Don’t switch to this version after installation'],
         ['--no-install', 'Only download DMG, but do not install it.'],
         ['--no-progress', 'Don’t show download progress.'],
         ['--no-clean', 'Don’t delete DMG after installation.']].concat(super)
      end

      def initialize(argv)
        @installer = Installer.new
        @version = argv.shift_argument
        @should_clean = argv.flag?('clean', true)
        @should_install = argv.flag?('install', true)
        @should_switch = argv.flag?('switch', true)
        @progress = argv.flag?('progress', true)
        super
      end

      def validate!
        super

        return if @version.nil?
        fail Informative, "Version #{@version} already installed." if @installer.installed?(@version)
        fail Informative, "Version #{@version} doesn't exist." unless @installer.exist?(@version)
      end

      def run
        return if @version.nil?
        @installer.install_version(@version, @should_switch, @should_clean, @should_install,
          @progress)
      end
    end
  end
end
