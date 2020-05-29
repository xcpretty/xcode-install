require File.expand_path('../spec_helper', __FILE__)

module XcodeInstall
  #
  # FIXME: This test randomely fail on GitHub Actions.
  #
  # describe '#fetch' do
  #   before do
  #     client = mock
  #     client.stubs(:cookie).returns('customCookie')
  #     Spaceship::PortalClient.stubs(:login).returns(client)
  #   end

  #   it 'downloads the file and calls the `progress_block` with the percentage' do
  #     installer = Installer.new

  #     xcode = XcodeInstall::Xcode.new('name' => 'Xcode 9.3',
  #                                     'files' => [{
  #                                       'remotePath' => '/Developer_Tools/Xcode_9.3/Xcode_9.3.xip'
  #                                     }])

  #     installer.stubs(:fetch_seedlist).returns([xcode])

  #     stdin = 'stdin'
  #     stdout = 'stdout'
  #     stderr = 'stderr'
  #     wait_thr = 'wait_thr'

  #     stdin.stubs(:close)
  #     stdout.stubs(:close)
  #     stderr.stubs(:close)

  #     current_time = '123123'
  #     Time.stubs(:now).returns(current_time)

  #     xip_path = File.join(File.expand_path('~'), '/Library/Caches/XcodeInstall/Xcode_9.3.xip')
  #     progress_log_file = File.join(File.expand_path('~'), "/Library/Caches/XcodeInstall/progress.#{current_time}.progress")

  #     command = [
  #       'curl',
  #       '--disable',
  #       '--cookie customCookie',
  #       '--cookie-jar /tmp/curl-cookies.txt',
  #       '--retry 3',
  #       '--location',
  #       '--continue-at -',
  #       "--output #{xip_path}",
  #       'https://developer.apple.com/devcenter/download.action\\?path\\=/Developer_Tools/Xcode_9.3/Xcode_9.3.xip',
  #       "2> #{progress_log_file}"
  #     ]
  #     Open3.stubs(:popen3).with(command.join(' ')).returns([stdin, stdout, stderr, wait_thr])

  #     wait_thr.stubs(:alive?).returns(true)

  #     thr_value = 'thr_value'
  #     wait_thr.stubs(:value).returns(thr_value)
  #     thr_value.stubs(:success?).returns(true)

  #     installer.stubs(:install_dmg).with(Pathname.new(xip_path), '-9.3', false, false)

  #     Thread.new do
  #       sleep(1)
  #       File.write(progress_log_file, '  0 4766M    0 6835k    0     0   573k      0  2:21:58  0:00:11  2:21:47  902k')
  #       sleep(1)
  #       File.write(progress_log_file, ' 5 4766M    0 6835k    0     0   573k      0  2:21:58  0:00:11  2:21:47  902k')
  #       sleep(1)
  #       File.write(progress_log_file, '50 4766M    0 6835k    0     0   573k      0  2:21:58  0:00:11  2:21:47  902k')
  #       sleep(1)
  #       File.write(progress_log_file, '100 4766M    0 6835k    0     0   573k      0  2:21:58  0:00:11  2:21:47  902k')
  #       sleep(0.5)
  #       wait_thr.stubs(:alive?).returns(false)
  #     end

  #     percentages = []
  #     installer.install_version(
  #       # version: the version to install
  #       '9.3',
  #       # `should_switch
  #       false,
  #       # `should_clean`
  #       false, # false for now for faster debugging
  #       # `should_install`
  #       true,
  #       # `progress`
  #       false,
  #       # `url` is nil, as we don't have a custom source
  #       nil,
  #       # `show_release_notes` is `false`, as this is a non-interactive machine
  #       false,
  #       # `progress_block` be updated on the download progress
  #       proc do |percent|
  #         percentages << percent
  #       end
  #     )

  #     percentages.each do |current_percent|
  #       # Verify all reported percentages are between 0 and 100
  #       current_percent.should.be.close(50, 50)
  #     end
  #     # Verify we got a good amount of percentages reported
  #     percentages.count.should.be.close(8, 4)
  #   end
  # end

  describe '#find_xcode_version' do
    it 'should find the one with the matching name' do
      installer = Installer.new

      xcodes = [
        XcodeInstall::Xcode.new('name' => '11.4 beta 2',
                                'dateModified' => '12/11/19 14:28',
                                'files' => [{
                                  'remotePath' => '/Developer_Tools/Xcode_11.4_beta_2/Xcode_11.4_beta_2.xip'
                                }]),
        XcodeInstall::Xcode.new('name' => '11.4',
                                'dateModified' => '12/15/19 11:28',
                                'files' => [{
                                  'remotePath' => '/Developer_Tools/Xcode_11.4/Xcode_11.4.xip'
                                }])
      ]

      installer.stubs(:fetch_seedlist).returns(xcodes)
      installer.find_xcode_version('11.4').name.should.be.equal('11.4')
    end
  end
end
