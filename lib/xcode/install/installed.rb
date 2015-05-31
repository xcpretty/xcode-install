module XcodeInstall
  class Command
    class Installed < Command
      self.command = 'installed'
      self.summary = 'List installed Xcodes.'

      def run
        installer = XcodeInstall::Installer.new
        installer.installed_versions.each do |xcode|
          puts "#{xcode.version}\t(#{xcode.path})"
        end
      end
    end
  end
end
