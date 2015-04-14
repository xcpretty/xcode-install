require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
	describe Command::Install do
		before do
			Installer.any_instance.stubs(:exists).returns(true)
			Installer.any_instance.stubs(:installed).returns([])
			Installer.any_instance.expects(:download).with("6.3").returns("/some/path")
		end

		it "downloads and installs" do
			Installer.any_instance.expects(:install_dmg).with("/some/path", "-6.3", true)
			Command::Install.run(["6.3"])
		end

		it "downloads and installs and does not switch if --no-switch given" do
			Installer.any_instance.expects(:install_dmg).with("/some/path", "-6.3", false)
			Command::Install.run(["6.3", "--no-switch"])
		end
	end
end
