module XcodeInstall
  class Command
    class Beta < Command
      self.command = 'ios'
      self.summary = 'Download a specific iOS beta version.'

      self.arguments = [
        CLAide::Argument.new('DEVICE', :true)
      ]

      def initialize(argv)
        @installer = Installer.new
        @device = argv.shift_argument
        super
      end

      def run
        if @device.nil?
          puts @installer.list_ios_betas.map { |beta| "#{beta.device}" }.join("\n")
        else
          beta = @installer.list_ios_betas.select { |beta| beta.device == @device }.first
          fail Informative, "OS for #{@device} doesn't exist." if beta.nil?

          result = @installer.download_beta(beta)
          fail Informative, "OS for #{@device} could not be downloaded." if result.nil?

          puts "Downloaded iOS #{beta.version} to `#{result}`."
        end
      end
    end
  end
end
