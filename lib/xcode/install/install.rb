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
         ['--retry-download-count', 'Count of retrying download when curl is failed.']].concat(super)
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
        @retry_download_count = argv.option('retry-download-count', '3')
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
        fail Informative, "Invalid Retry: `#{@retry_download_count} is not positive number.`" if (@retry_download_count =~ /\A[0-9]*\z/).nil?
      end

      def run
        @installer.install_version(@version, @should_switch, @should_clean, @should_install,
                                   @progress, @url, @show_release_notes, nil, @retry_download_count.to_i)
      end
    end
  end
end
