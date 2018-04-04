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
         ['--cache-url-base', 'Base URL containing the Xcode DMG (e.g. "http://10.1.1.1/XcodeCache". Overrides --url unless a failure occurs.']].concat(super)
      end

      def initialize(argv)
        @installer = Installer.new
        @version = argv.shift_argument
        @url = argv.option('url')
        @force = argv.flag?('force', false)
        @should_clean = argv.flag?('clean', true)
        @should_install = argv.flag?('install', true)
        @should_switch = argv.flag?('switch', true)
        @progress = argv.flag?('progress', true)
        @show_release_notes = argv.flag?('show-release-notes', true)
        @local_url = argv.option('cache-url-base')
        super
      end

      def validate!
        super

        help! 'A VERSION argument is required.' unless @version
        fail Informative, "Version #{@version} already installed." if @installer.installed?(@version) && !@force
        fail Informative, "Version #{@version} doesn't exist." unless @url || @installer.exist?(@version)
        fail Informative, "Invalid URL: `#{@url}`" unless !@url || @url =~ /\A#{URI.regexp}\z/
        fail Informative, "Invalid Cache URL: `#{@local_url}`" unless !@local_url || @local_url =~ /\A#{URI.regexp}\z/
      end

      def run
        @installer.install_version(@version, @should_switch, @should_clean, @should_install,
                                   @progress, @url, @show_release_notes, @local_url)
      end
    end
  end
end
