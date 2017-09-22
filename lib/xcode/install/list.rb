module XcodeInstall
  class Command
    class List < Command
      self.command = 'list'
      self.summary = 'List Xcodes available for download.'

      def self.options
        [['--all', 'Show all available versions. (Default, Deprecated)']].concat(super)
      end

      def run
        installer = XcodeInstall::Installer.new
        puts installer.list
      end
    end
  end
end
