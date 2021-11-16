require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  describe JSON do
    it 'can parse Xcode JSON' do
      fixture = Pathname.new('spec/fixtures/xcode.json').read
      xcode = Xcode.new(JSON.parse(fixture))

      xcode.date_modified.should == 1_572_613_080
      xcode.name.should == '9.3'
      xcode.url.should == 'https://developer.apple.com/devcenter/download.action?path=/Developer_Tools/Xcode_9.3/Xcode_9.3.xip'
    end

    it 'can parse list of all Xcodes' do
      fixture = Pathname.new('spec/fixtures/yolo.json').read
      installer = Installer.new

      seedlist = installer.send(:parse_seedlist, JSON.parse(fixture))
      installer.stubs(:installed_versions).returns([])
      installer.stubs(:xcodes).returns(seedlist)

      versions = [
        '4.3 for Lion', '4.3.1 for Lion', '4.3.2 for Lion', '4.3.3 for Lion', '4.4.1', '4.5', '4.6', '4.6.1', '4.6.2', '4.6.3',
        '5', '5.0.1', '5.0.2', '5.1', '5.1.1',
        '6.0.1', '6.1', '6.1.1', '6.2', '6.3', '6.3.1', '6.3.2', '6.4',
        '7', '7.0.1', '7.1', '7.1.1', '7.2', '7.2.1', '7.3', '7.3.1',
        '8', '8.1', '8.2', '8.2.1', '8.3', '8.3.2', '8.3.3',
        '9', '9.0.1', '9.1', '9.2', '9.3', '9.3.1', '9.4', '9.4.1',
        '10', '10.1', '10.2', '10.2.1', '10.3',
        '11', '11.1', '11.2', '11.2.1', '11.3 beta', '11.3', '11.3.1', '11.4 beta', '11.4 beta 2', '11.4 beta 3', '11.4', '11.4.1', '11.5 beta', '11.5 beta 2', '11.5 GM Seed', '11.5'
      ]
      installer.list.split("\n").should == versions
    end

    it 'raises informative error when account is not registered as a developer' do
      installer = Installer.new
      fixture = Pathname.new('spec/fixtures/not_registered_as_developer.json').read
      should.raise(Informative) { installer.send(:parse_seedlist, JSON.parse(fixture)) }.message
            .should.include fixture['You are not registered as an Apple Developer']
    end
  end
end
