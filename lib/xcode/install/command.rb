require 'claide'

module XcodeInstall
    class Command < CLAide::Command
        require "xcode/install/install"
        require "xcode/install/list"

        self.abstract_command = true
        self.command = 'xcode-install'
        self.version = VERSION
        self.description = 'Xcode installation manager.'
    end
end