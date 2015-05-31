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
        fail Informative, "Version #{@version} already installed." if @installer.installed?(@version)
        fail Informative, "Version #{@version} doesn't exist." unless @installer.exist?(@version)
      end

      def run
        return if @version.nil?
        @installer.install_version(@version, @should_switch, @should_clean)
      end
    end
  end
end
