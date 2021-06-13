# Xcode::Install

[![Gem Version](http://img.shields.io/gem/v/xcode-install.svg?style=flat)](http://badge.fury.io/rb/xcode-install) [![Build Status](https://github.com/xcpretty/xcode-install/actions/workflows/ci.yml/badge.svg)](https://github.com/xcpretty/xcode-install/actions)

Install and update your Xcodes automatically.

```
$ gem install xcode-install
$ xcversion install 6.3
```

This tool uses the [Downloads for Apple Developer](https://developer.apple.com/download/more/) page.

## Installation

```
$ gem install xcode-install
```

Note: unfortunately, XcodeInstall has a transitive dependency on a gem with native extensions and this is not really fixable at this point in time. If you are installing this on a machine without a working compiler, please use these alternative instructions instead:

```
$ curl -sL -O https://github.com/neonichu/ruby-domain_name/releases/download/v0.5.99999999/domain_name-0.5.99999999.gem
$ gem install domain_name-0.5.99999999.gem
$ gem install --conservative xcode-install
$ rm -f domain_name-0.5.99999999.gem
```

## Usage

XcodeInstall needs environment variables with your credentials to access the Apple Developer
Center, they are stored using the [credentials_manager][1] of [fastlane][2]:

```
XCODE_INSTALL_USER
XCODE_INSTALL_PASSWORD
```

### List

To list available versions:

```
$ xcversion list
6.0.1
6.1
6.1.1
6.2 (installed)
6.3
```

Already installed versions are marked with `(installed)`.
(Use `$ xcversion installed` to only list installed Xcodes with their path).

To update the list of available versions, run:

```
$ xcversion update
```

### Install

To install a certain version, simply:

```
$ xcversion install 8
###########################################################               82.1%
######################################################################## 100.0%
Please authenticate for Xcode installation...

Xcode 8
Build version 6D570
```

This will download and install that version of Xcode. Then you can start it from `/Applications` as usual.
The new version will also be automatically selected for CLI commands (see below).

#### GMs and beta versions

Note: GMs and beta versions usually have special names, e.g.

```
$ xcversion list
7 GM seed
7.1 beta
```

They have to be installed using the full name, e.g. `xcversion install '7 GM seed'`.

#### `.xcode-version`

We recommend the creation of a `.xcode-version` file to explicitly declare and store the Xcode version to be used by your CI environment as well as your team.

```
12.5
```

Read [the proposal](/XCODE_VERSION.md) of `.xcode-version`.

### Select

To see the currently selected version, run
```
$ xcversion selected
```

To select a version as active, run
```
$ xcversion select 8
```

To select a version as active and change the symlink at `/Applications/Xcode`, run
```
$ xcversion select 8 --symlink
```

### Command Line Tools

XcodeInstall can also install Xcode's Command Line Tools by calling `xcversion install-cli-tools`.

### Simulators

XcodeInstall can also manage your local simulators using the `simulators` command.

```
$ xcversion simulators
Xcode 6.4 (/Applications/Xcode-6.4.app)
iOS 7.1 Simulator (installed)
iOS 8.1 Simulator (not installed)
iOS 8.2 Simulator (not installed)
iOS 8.3 Simulator (installed)
Xcode 7.2.1 (/Applications/Xcode-7.2.1.app)
iOS 8.1 Simulator (not installed)
iOS 8.2 Simulator (not installed)
iOS 8.3 Simulator (installed)
iOS 8.4 Simulator (not installed)
iOS 9.0 Simulator (not installed)
iOS 9.1 Simulator (not installed)
tvOS 9.0 Simulator (not installed)
watchOS 2.0 Simulator (installed)
```

To install a simulator, use `--install` and the beginning of a simulator name:

```
$ xcversion simulators --install='iOS 8.4'
###########################################################               82.1%
######################################################################## 100.0%
Please authenticate to install iOS 8.4 Simulator...

Successfully installed iOS 8.4 Simulator
```

## Limitations

Unfortunately, the installation size of Xcodes downloaded will be bigger than when downloading via the Mac App Store, see [#10](/../../issues/10) and feel free to dupe the radar. 📡

XcodeInstall automatically installs additional components so that it is immediately usable from the
commandline. Unfortunately, Xcode will load third-party plugins even in that situation, which leads
to a dialog popping up. Feel free to dupe [the radar][5]. 📡

XcodeInstall normally relies on the Spotlight index to locate installed versions of Xcode. If you use it while
indexing is happening, it might show inaccurate results and it will not be able to see installed
versions on unindexed volumes.

To workaround the Spotlight limitation, XcodeInstall searches `/Applications` folder to locate Xcodes when Spotlight is disabled on the machine, or when Spotlight query for Xcode does not return any results. But it still won't work if your Xcodes are not located under `/Applications` folder.

## Thanks

Thanks to [@neonichu](https://github.com/neonichu), the original (and best) author.

[This][3] downloading script which has been used for some inspiration, also [this][4]
for doing the installation. Additionally, many thanks to everyone who has contributed to this
project, especially [@henrikhodne][6] and [@lacostej][7] for making XcodeInstall C extension free.

## Contributing

1. Fork it ( https://github.com/xcpretty/xcode-install/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Running tests

```
bundle exec rake spec
```

### Running code style linter

```
bundle exec rubocop -a
```

## License

This project is licensed under the terms of the MIT license. See the [LICENSE](LICENSE) file.

> This project and all fastlane tools are in no way affiliated with Apple Inc or Google. This project is open source under the MIT license, which means you have full access to the source code and can modify it to fit your own needs. All fastlane tools run on your own computer or server, so your credentials or other sensitive information will never leave your own computer. You are responsible for how you use fastlane tools.

[1]: https://github.com/fastlane/fastlane/tree/master/credentials_manager#using-environment-variables
[2]: http://fastlane.tools
[3]: http://atastypixel.com/blog/resuming-adc-downloads-cos-safari-sucks/
[4]: https://github.com/magneticbear/Jenkins_Bootstrap
[5]: http://www.openradar.me/22001810
[6]: https://github.com/henrikhodne
[7]: https://github.com/lacostej
