require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  describe Command::Simulators do
    it 'exits if version is already installed' do
      simulator = mock
      simulator.stubs(:name).returns('nachOS 3.14')
      simulator.stubs(:installed?).returns(true)
      Command::Simulators.any_instance.stubs(:matching_simulator).returns(simulator)
      Command::Simulators.any_instance.expects(:exit).with.throws :exit
      -> { Command::Simulators.run(['--install="nachOS 3.14"']) }.should.throw :exit
    end
  end
end
