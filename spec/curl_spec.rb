require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  describe Curl do
    it 'reports failure' do
      `true`
      curl = XcodeInstall::Curl.new
      result = curl.fetch('http://0.0.0.0/test')
      result.should == false
    end
  end
end
