require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
	describe InstalledXcode do
		it "finds the current Xcode version with whitespace chars" do
			InstalledXcode.any_instance.expects(:`).with("DEVELOPER_DIR='' \"/Volumes/Macintosh HD/Applications/Xcode Beta/Contents/Developer/usr/bin/xcodebuild\" -version").returns("Xcode 6.3.1\nBuild version 6D1002")
			installed = InstalledXcode.new("/Volumes/Macintosh HD/Applications/Xcode Beta")
		end
	end
end
