require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
	describe JSON do
		it 'can parse Xcode JSON' do
			fixture = Pathname.new('spec/fixtures/xcode.json').read
			xcode = Xcode.new(JSON.parse(fixture))

			xcode.dateModified.should == 1413472373000
			xcode.name.should == 'Command Line Tools (OS X 10.9) for Xcode - Xcode 6.1'
			xcode.url.should == 'https://developer.apple.com//downloads/Developer_Tools/command_line_tools_os_x_10.9_for_xcode__xcode_6.1/command_line_tools_for_osx_10.9_for_xcode_6.1.dmg'
		end

		it 'can parse list of all Xcodes' do
			fixture = Pathname.new('spec/fixtures/yolo.json').read

			FastlaneCore::DeveloperCenter.stubs(:new).returns(nil)
			seedlist = Installer.new.send(:parse_seedlist, JSON.parse(fixture))
			
			seedlist.should == "Xcode 6.1\nXcode 6.1.1\nXcode 6.2"
		end
	end
end
