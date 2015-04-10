# Xcode::Install

⚠️WIP⚠️

Install and update your Xcodes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'xcode-install'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install xcode-install

## Usage

XcodeInstall will ask for your credentials to access the Apple Developer Center, they are stored
using the [CredentialsManager][1] of [Fastlane][2].

To list available versions:

```bash
$ xcode-install list
6.0.1
6.1
6.1.1
6.2
6.3
```

By default, only the latest major version is listed.

To install a certain version, simply:

```bash
$ xcode-install install 6.3
###########################################################               82.1%
```

This will download and install that version of Xcode.

## Thanks

[This][3] downloading script which has been used for some inspiration.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/xcode-install/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request


[1]: https://github.com/KrauseFx/CredentialsManager
[2]: http://fastlane.tools
[3]: http://atastypixel.com/blog/resuming-adc-downloads-cos-safari-sucks/
