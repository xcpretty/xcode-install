require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  xcode_path = '/Volumes/Macintosh HD/Applications/Xcode Beta'

  describe InstalledXcode do
    it 'finds the current Xcode version with whitespace chars' do
      InstalledXcode.any_instance.expects(:`).with("/usr/libexec/PlistBuddy -c \"Print :CFBundleShortVersionString\" \"#{xcode_path}/Contents/version.plist\"").returns('6.3.1')
      installed = InstalledXcode.new(xcode_path)
      installed.version.should == '6.3.1'
    end

    it 'is robust against broken Xcode installations' do
      InstalledXcode.any_instance.expects(:`).with("/usr/libexec/PlistBuddy -c \"Print :CFBundleShortVersionString\" \"#{xcode_path}/Contents/version.plist\"").returns(nil)
      installed = InstalledXcode.new(xcode_path)
      installed.version.should == '0.0'
    end
  end
end
