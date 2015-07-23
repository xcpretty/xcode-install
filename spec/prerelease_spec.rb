require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  describe Installer do
    def fixture(date)
      File.read("spec/fixtures/devcenter/xcode-#{date}.html")
    end

    def parse_prereleases(date)
      fixture = fixture(date)
      @result.stubs(:body).returns(fixture)

      installer = Installer.new
      installer.send(:prereleases)
    end

    before do
      devcenter = mock
      devcenter.stubs(:download_file).returns(nil)
      Installer.any_instance.stubs(:devcenter).returns(devcenter)

      @result = mock
      @result.stubs(:body).returns(nil)
      client = mock
      client.stubs(:request).returns(@result)
      Spaceship::Client.stubs(:login).returns(client)
    end

    it 'can parse prereleases from 20150414' do
      prereleases = parse_prereleases('20150414')

      prereleases.should == [Xcode.new_prelease('6.4', '/Developer_Tools/Xcode_6.4_Beta/Xcode_6.4_beta.dmg')]
    end

    it 'can parse prereleases from 20150427' do
      prereleases = parse_prereleases('20150427')

      prereleases.should == [Xcode.new_prelease('6.4 beta 2', '/Developer_Tools/Xcode_6.4_beta_2/Xcode_6.4_beta_2.dmg')]
    end

    it 'can parse prereleases from 20150508' do
      prereleases = parse_prereleases('20150508')

      prereleases.count.should == 2
      prereleases.first.should == Xcode.new_prelease('6.3.2 GM seed', '/Developer_Tools/Xcode_6.3.2_GM_seed/Xcode_6.3.2_GM_seed.dmg')
      prereleases.last.should == Xcode.new_prelease('6.4 beta 2', '/Developer_Tools/Xcode_6.4_beta_2/Xcode_6.4_beta_2.dmg')
    end

    it 'can parse prereleases from 20150608' do
      prereleases = parse_prereleases('20150608')

      prereleases.count.should == 2
      prereleases.first.should == Xcode.new_prelease('7 beta', '/WWDC_2015/Xcode_7_beta/Xcode_7_beta.dmg')
      prereleases.last.should == Xcode.new_prelease('6.4 beta 3', '/Developer_Tools/Xcode_6.4_beta_3/Xcode_6.4_beta_3.dmg')
    end

    it 'can parse prereleases from 20150624' do
      prereleases = parse_prereleases('20150624')

      prereleases.count.should == 2
      prereleases.first.should == Xcode.new_prelease('7 beta 2', '/Developer_Tools/Xcode_7_beta_2/Xcode_7_beta_2.dmg')
      prereleases.last.should == Xcode.new_prelease('6.4 beta 4', '/WWDC_2015/Xcode_6.4_beta_4/Xcode_6.4_beta_4.dmg')
    end
  end
end
