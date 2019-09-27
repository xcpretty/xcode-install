module XcodeInstall
  class Command
    class Select < Command
      self.command = 'select'
      self.summary = 'Select installed Xcode via `xcode-select`.'

      self.arguments = [
        CLAide::Argument.new('VERSION', :true)
      ]

      def self.options
        [['--symlink', 'Update symlink in /Applications with selected Xcode']].concat(super)
      end

      def initialize(argv)
        @installer = Installer.new
        @version = argv.shift_argument
        @should_symlink = argv.flag?('symlink', false)
        super
      end

      def validate!
        super

        fail Informative, 'Please specify a version to select.' if @version.nil?
        fail Informative, "Version #{@version} not installed." unless @installer.installed?(@version)
      end

      def run
        xcode = @installer.installed_versions.detect { |v| v.version == @version }
        `sudo xcode-select --switch "#{xcode.path}"`
        @installer.symlink xcode.version if @should_symlink
      end
    end
  end
end
