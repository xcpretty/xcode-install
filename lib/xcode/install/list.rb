module XcodeInstall
  class Command
    class List < Command
      self.command = 'list'
      self.summary = 'List Xcodes available for download.'

      def self.options
        [['--all', 'Show all available versions. (Default, Deprecated)'],
         ['--filter', 'Filter by version requirement, e.g. "~> 12.0", or ">= 12.0, < 13.0"']].concat(super)
      end

      def initialize(argv)
        @all = argv.flag?('all', true)
        @filter = argv.option('filter')
        super
      end

      def run
        installer = XcodeInstall::Installer.new
        puts installer.list(@filter)
      end
    end
  end
end
