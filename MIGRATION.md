# This project is being sunset

A brief history of `xcode-install` aka `xcversion`, as well as a guide on how to migrate from it, to a more modern tool.

<sub>For brevity sake I'm going to refer to this project always as `xcode-install` in this document.</sub>

## Overview

The more time goes by, the more we realized this project had already provided the community the value it needed, served its purpose, and become obsolete. We believe it was the time to officially sunset this project, and this document will guide you to use a more modern and well maintained tool.

## Some Context

`xcode-install` (originally a @neonichu's project, which got transferred to @KrauseFx, which got transferred to the @xcpretty GitHub organization), had been around since April 2015, back when there were no other good options to manage multiple versions of Xcode.

Fast forward to Feb 2019, [`xcodes`](https://github.com/RobotsAndPencils/xcodes) was born to provide a more user friendly experience. It based itself off of this project to figure out the complex Xcode downloading logic, but has since then been actively maintained and new features are incorporated into it on a regular basis. To name a few, that are not present in `xcode-install`:

- GUI (via [`Xcodes.app`](https://github.com/RobotsAndPencils/XcodesApp))
- Support to `aria2` (which has been requested in https://github.com/xcpretty/xcode-install/issues/425 but we never got to implement it), which uses up to 16 connections to download Xcode 3-5x faster
- Support to [`unxip`](https://github.com/saagarjha/unxip), providing unxipping up to 70% faster
- New in Xcode 14: Sessionless downloads, just announced by [@xcodesapp](https://twitter.com/xcodesapp): https://twitter.com/xcodesapp/status/1570991082359627779?s=46&t=qVETxqxGI7ZZsFLLrledIg, available in https://github.com/RobotsAndPencils/XcodesApp/releases/tag/v1.8.0b16

These features, plus the fact that this project wasn't getting the attention it needed to keep supporting newer versions of Xcode and bug fixes, made us believe it was time to sunset this project.

# Migrating _fastlane_ actions that depend on the `xcode-install` gem, to use `xcodes`

As of https://github.com/fastlane/fastlane/pull/20672, a new action was introduced to _fastlane_ called `xcodes`. You can find its full documentation here: https://docs.fastlane.tools/actions/xcodes

There are 3 actions that depend on `xcode-install` gem. Below you can find how to migrate each one of them:

## 1. `xcode_install`

`xcode_install` used to receive an Xcode version and "install if needed", which the new `xcodes` action's main purpose.

Before:

```ruby
xcode_install(
  version: '14',
  username: 'example@example.com',
  team_id: 'ABCD1234',
  download_retry_attempts: 5,
)
```

Now:

The `team_id` and `download_retry_attempts` options are no longer needed (nor supported).

```ruby
xcodes(
  version: '14',
  username: 'example@example.com',
)
```

## 2. `xcversion`

`xcversion` used to receive an Xcode version and select it for the current build steps, which in `xcodes` action that's the `select_for_current_build_only` option.

Before:

```ruby
xcversion(version: '14')
```

Now:

```ruby
xcodes(
  version: '14',
  select_for_current_build_only: true,
)
```

## 3. `ensure_xcode_version`

This action wasn't migrated to use `xcodes` within _fastlane_ yet, mainly because of the somewhat complex logic around the non-strict version checking. This document as well as fastlane's `ensure_xcode_version` action documentation will be updated when the new `xcodes` action officially deprecates the `ensure_xcode_version` action. For now, if you don't use the `strict: false` option of `ensure_xcode_version`, you can migrate to `xcodes` action by passing `select_for_current_build_only: true`, which will raise an error if the given version can't be selected:

Before:

```ruby
ensure_xcode_version(
  version: '14',
  strict: false,
)
```

```ruby
ensure_xcode_version(version: '14')
```

Now:

```ruby
xcodes(
  version: '14',
  select_for_current_build_only: true,
)
```

## Advanced Usage

If there are other use cases that you don't see covered so far, check out the full documentation here: https://docs.fastlane.tools/actions/xcodes

All the lanes that supported `.xcode-version` still support it :tada:

# Migrating `xcode-install` CLI to `xcodes`

If you're using `xcode-install` as a CLI, the process to migrate to `xcodes` is more straightforward: simply visit https://github.com/RobotsAndPencils/xcodes and check their installation and usage guide.

`xcode-install` CLI supported `.xcode-version` and so does `xcodes` :tada:

# Known limitations

Unfortunately, managing Simulators runtime (a feature available only via `xcode-install` CLI) isn't supported in `xcodes` yet. You can follow this issue to be notified when there are new developments around this feature: https://github.com/RobotsAndPencils/xcodes/issues/91

## Shout Outs & Mentions

Huge shout out to @neonichu, @KrauseFx, @mrcljx, @jpsim, @timsutton, and many other contributors (which you can check here: https://github.com/xcpretty/xcode-install/graphs/contributors) for the work they put into this project! It advanced the state of the art in its field, and the community benefitted a lot from it! `xcodes` wouldn't be where it is today without your effort into this project 💟

Thank you all, and see you on the other side!
