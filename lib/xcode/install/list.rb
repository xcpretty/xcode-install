module XcodeInstall
  class Command
    class List < Command
      self.command = 'list'
      self.summary = 'List Xcodes available for download.'

      def run
        installer = XcodeInstall::Installer.new
        puts installer.list
      end
    end
  end
end
