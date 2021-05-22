require 'uri'

module XcodeInstall
  class Command
    class Install < Command
      self.command = 'install'
      self.summary = 'Install a specific version of Xcode.'

      self.arguments = [
        CLAide::Argument.new('VERSION', :true)
      ]

      def self.options
        [['--url', 'Custom Xcode DMG file path or HTTP URL.'],
         ['--force', 'Install even if the same version is already installed.'],
         ['--no-switch', 'Don’t switch to this version after installation'],
         ['--no-install', 'Only download DMG, but do not install it.'],
         ['--no-progress', 'Don’t show download progress.'],
         ['--no-clean', 'Don’t delete DMG after installation.'],
         ['--no-show-release-notes', 'Don’t open release notes in browser after installation.'],
         ['--retry-count', 'How many times try to download DMG file if downloading fails. Default is 10.']].concat(super)
      end

      def initialize(argv)
        @installer = Installer.new
        @version = argv.shift_argument
        @version ||= File.read('.xcode-version').strip if File.exist?('.xcode-version')
        @url = argv.option('url')
        @force = argv.flag?('force', false)
        @should_clean = argv.flag?('clean', true)
        @should_install = argv.flag?('install', true)
        @should_switch = argv.flag?('switch', true)
        @progress = argv.flag?('progress', true)
        @show_release_notes = argv.flag?('show-release-notes', true)
        @number_of_try = argv.option('retry-count', '10')
        super
      end

      def validate!
        super

        help! 'A VERSION argument is required.' unless @version
        if @installer.installed?(@version) && !@force
          print "Version #{@version} already installed."
          exit(0)
        end
        fail Informative, "Version #{@version} doesn't exist." unless @url || @installer.exist?(@version)
        fail Informative, "Invalid URL: `#{@url}`" unless !@url || @url =~ /\A#{URI.regexp}\z/
        fail Informative, "Invalid Retry: `#{@number_of_try} is not positive number.`" if (@number_of_try =~ /\A[0-9]*\z/).nil?
      end

      def run
        @installer.install_version(@version, @should_switch, @should_clean, @should_install,
                                   @progress, @url, @show_release_notes, nil, @number_of_try.to_i)
      end
    end
  end
end
