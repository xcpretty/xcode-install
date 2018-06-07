require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  describe Command::List do
    before do
      installer.stubs(:exists).returns(true)
      installer.stubs(:installed_versions).returns([])
    end

    def installer
      @installer ||= Installer.new
    end

    def fake_xcode(name)
      fixture = Pathname.new('spec/fixtures/xcode_63.json').read
      xcode = Xcode.new(JSON.parse(fixture))
      xcode.stubs(:name).returns(name)
      xcode
    end

    def fake_xcodes(*names)
      xcodes = names.map { |name| fake_xcode(name) }
      installer.stubs(:xcodes).returns(xcodes)
    end

    describe '#list' do
      it 'lists all versions' do
        fake_xcodes '1', '2.3', '2.3.1', '2.3.2', '3 some', '4 beta', '10 beta'
        installer.list.should == "1\n2.3\n2.3.1\n2.3.2\n3 some\n4 beta\n10 beta"
      end
    end
  end
end
