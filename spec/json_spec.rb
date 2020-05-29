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

      # rubocop:disable Metrics/LineLength
      installer.list.should == '4.3 for Lion\n4.3.1 for Lion\n4.3.2 for Lion\n4.3.3 for Lion\n4.4.1\n4.5\n4.6.2\n4.6\n4.6.1\n4.6.3\n5.0.1\n5\n5.0.2\n5.1\n5.1.1\n6.0.1\n6.1\n6.1.1\n6.2\n6.3\n6.3.1\n6.3.2\n6.4\n7\n7.0.1\n7.1\n7.1.1\n7.2.1\n7.2\n7.3\n7.3.1\n8\n8.1\n8.2\n8.2.1\n8.3.2\n8.3.3\n8.3\n9\n9.0.1\n9.1\n9.2\n9.3\n9.3.1\n9.4\n9.4.1\n10\n10.1\n10.2.1\n10.2\n10.3\n11\n11.1\n11.2\n11.2.1\n11.3 beta\n11.3\n11.3.1\n11.4 beta\n11.4\n11.4 beta 3\n11.4 beta 2\n11.4.1\n11.5 beta 2\n11.5\n11.5 GM Seed\n11.5 beta'
    end

    it 'raises informative error when account is not registered as a developer' do
      installer = Installer.new
      fixture = Pathname.new('spec/fixtures/not_registered_as_developer.json').read
      should.raise(Informative) { installer.send(:parse_seedlist, JSON.parse(fixture)) }.message
            .should.include fixture['You are not registered as an Apple Developer']
    end
  end
end
