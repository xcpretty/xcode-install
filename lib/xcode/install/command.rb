require 'claide'
require "xcode/install/version"

module XcodeInstall
	class PlainInformative < StandardError
		include CLAide::InformativeError
	end

	class Informative < PlainInformative
		def message
			"[!] #{super}".red
		end
	end

	class Command < CLAide::Command
		require "xcode/install/cleanup"
		require "xcode/install/install"
		require "xcode/install/installed"
		require "xcode/install/list"
		require "xcode/install/uninstall"
		require "xcode/install/update"

		self.abstract_command = true
		self.command = 'xcode-install'
		self.version = VERSION
		self.description = 'Xcode installation manager.'
	end
end