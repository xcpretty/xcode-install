require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  describe Installer do
    def fixture(date)
      Nokogiri::HTML.parse(File.read("spec/fixtures/devcenter/betas-#{date}.html"))
    end

    def parse_betas(date)
      fixture = fixture(date)
      Nokogiri::HTML.stubs(:parse).returns(fixture)
    end

    before do
      devcenter = mock
      devcenter.stubs(:cookies).returns('')
      devcenter.stubs(:download_file).returns(nil)
      Installer.any_instance.stubs(:devcenter).returns(devcenter)
    end

    it 'can find iOS betas' do
      parse_betas('20150601')
      beta = Installer.new.list_ios_betas.first

      beta.device.should == 'iPad Air 2 (Model A1566)'
      beta.file_name.should == Pathname.new('iOS_8.4_beta_3__iPad_Air_2_Model_A1566__12H4098c.zip')
      beta.url.should == 'https://developer.apple.com/devcenter/download.action?path=/iOS/iOS_8.4_beta_3/iOS_8.4_beta_3__iPad_Air_2_Model_A1566__12H4098c.zip'
      beta.version.should == '8.4 beta 3'
    end

    it 'can download iOS betas' do
      installer = Installer.new
      parse_betas('20150601')
      beta = installer.list_ios_betas.first

      Curl.any_instance.expects(:fetch).with(beta.url, installer.cache_dir, '', beta.file_name)
      installer.download_beta(beta)
    end
  end
end
