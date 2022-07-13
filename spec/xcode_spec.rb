require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  describe Xcode do
    it 'can covert version to semantic version' do
        Xcode.to_semver('13.2').should == '13.2'
        Xcode.to_semver('13.2 Beta').should == '13.2-beta'
        Xcode.to_semver('13.2 beta 1').should == '13.2-beta.1'
        Xcode.to_semver('13 Release Candidate').should == '13-release.candidate'
    end

    it 'can covert version requirement to semantic version requirement' do
        Xcode.to_semver('13.2').should == '13.2'
        Xcode.to_semver('>13.2 beta').should == '>13.2-beta'
        Xcode.to_semver('> 13.2 Beta').should == '> 13.2-beta'
        Xcode.to_semver('>=13.2 Beta 1').should == '>=13.2-beta.1'
        Xcode.to_semver('>= 13.2 beta 1').should == '>= 13.2-beta.1'
        Xcode.to_semver('~>13 Release Candidate').should == '~>13-release.candidate'
        Xcode.to_semver('~> 13 Release Candidate').should == '~> 13-release.candidate'
    end
  end
end
