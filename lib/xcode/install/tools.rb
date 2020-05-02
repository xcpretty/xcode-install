require 'claide'
require 'spaceship'

module XcodeInstall
  class Command
    class Tools < Command
      self.command = 'tools'
      self.summary = 'List or install Xcode CLI tools.'

      def self.options
        [['--install=name', 'Install simulator beginning with name, e.g. \'iOS 8.4\', \'tvOS 9.0\'.'],
         ['--force', 'Install even if the same version is already installed.'],
         ['--no-install', 'Only download DMG, but do not install it.'],
         ['--no-progress', 'Don’t show download progress.']].concat(super)
      end

      def initialize(argv)
        @install = argv.option('install')
        @force = argv.flag?('force', false)
        @should_install = argv.flag?('install', true)
        @progress = argv.flag?('progress', true)
        @installer = XcodeInstall::Installer.new
        super
      end

      def run
        @install ? install : list
      end

      :private

      def download(package)
        puts("Downloading #{package}")
        url = 'https://developer.apple.com/devcenter/download.action?path=' + package
        dmg_file = File.basename(url)
        Curl.new.fetch(
          url: url,
          directory: XcodeInstall::CACHE_DIR,
          cookies: @installer.spaceship.cookie,
          output: dmg_file,
          progress: false
        )
        XcodeInstall::CACHE_DIR + dmg_file
      end

      def install
        dmg_path = download(@install)
        puts("Downloaded to from #{dmg_path}")
        mount_dir = @installer.mount(dmg_path)
        puts("Mounted to #{mount_dir}")
        pkg_path = Dir.glob(File.join(mount_dir, '*.pkg')).first
        puts("Installing from #{pkg_path}")
        prompt = "Please authenticate to install Command Line Tools.\nPassword: "
        `sudo -p "#{prompt}" installer -verbose -pkg "#{pkg_path}" -target /`
      end

      def list
        raise NotImplementedError, 'Listing is not implemented'
      end
    end
  end
end
