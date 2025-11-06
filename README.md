# altoolalt plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-altoolalt)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-altoolalt`, add it to your project by running:

```bash
fastlane add_plugin altoolalt
```

Or add to your `Gemfile`:

```ruby
gem 'fastlane-plugin-altoolalt'
```

## Pre-requisite

This plugin has configurable Apple ID and password but you probably don't want to hardcode that. You need to have Fastlane setup with `FASTLANE_USER` and `FASTLANE_PASSWORD` environmenal varibales setup. Fastlane will ask it when you run `fastlane init` but if not you have to set these variables.

You can set that easily for bash shell

```
$ export FASTLANE_USER="your_apple_id@yourcompany.com";
$ export FASTLANE_PASSWORD="your_super_xecret_password";
```

You can do the same for your choice of shell if you aren't using bash.


## About

This plugin provides an alternative way to upload IPA files to App Store Connect (formerly iTunes Connect) using Apple's `altool` command-line tool instead of the standard iTMSTransporter.

### Why use altool?

- **Faster uploads** - altool is often faster than iTMSTransporter
- **Modern API support** - Supports both legacy and modern upload methods
- **Flexible authentication** - Username/password or API Key authentication
- **Auto-extraction** (v1.3.0+) - Automatically extracts bundle metadata from IPA

### Features

- ✅ Support for both `--upload-app` (legacy) and `--upload-package` (modern) methods
- ✅ Automatic extraction of bundle_id, bundle_version, and bundle_short_version_string from IPA
- ✅ API Key authentication (recommended) or username/password
- ✅ Support for iOS, macOS, tvOS, and visionOS apps
- ✅ Multi-provider account support
- ✅ Comprehensive error handling and validation
- ✅ Backwards compatible with older Xcode versions (v1.3.1+)


## Usage

### Basic Usage (Legacy Method)

Use the traditional `--upload-app` method with username/password:

```ruby
altoolalt(
    username: ENV["FASTLANE_USER"],
    password: ENV["FASTLANE_PASSWORD"],
    app_type: "ios",
    ipa_path: "./build/Your-ipa.ipa",
    output_format: "xml"
)
```

Or with API Key authentication (recommended):

```ruby
altoolalt(
    api_key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
    api_issuer: ENV["APP_STORE_CONNECT_ISSUER_ID"],
    app_type: "ios",
    ipa_path: "./build/Your-ipa.ipa",
    output_format: "xml"
)
```

### Modern Method (v1.3.0+) - with Auto-Extraction

Use the newer `--upload-package` method with automatic bundle metadata extraction:

```ruby
altoolalt(
    use_upload_package: true,
    api_key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
    api_issuer: ENV["APP_STORE_CONNECT_ISSUER_ID"],
    apple_id: "1234567890",  # Your App's Apple ID from App Store Connect
    ipa_path: "./build/Your-ipa.ipa"
    # bundle_id, bundle_version, and bundle_short_version_string
    # are automatically extracted from the IPA!
)
```

The plugin will automatically extract `bundle_id`, `bundle_version`, and `bundle_short_version_string` from your IPA's Info.plist. You can still override these if needed:

```ruby
altoolalt(
    use_upload_package: true,
    api_key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
    api_issuer: ENV["APP_STORE_CONNECT_ISSUER_ID"],
    apple_id: "1234567890",
    ipa_path: "./build/Your-ipa.ipa",
    bundle_id: "com.example.app",  # Optional: override auto-extraction
    bundle_version: "1.0",
    bundle_short_version_string: "1.0.0"
)
```

**Security Note:**
This might print the username and password to build console in the commands. For username/password authentication, consider using API Keys instead, or pipe the output to `/dev/null`.

## Available Parameters

### Common Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `ipa_path` | Path to your IPA file | Yes | Most recent .ipa in current directory |
| `api_key_id` | App Store Connect API Key ID | Yes* | `ENV["ALTOOL_API_KEY"]` |
| `api_issuer` | App Store Connect API Issuer ID | Yes* | - |
| `username` | Apple ID username | Yes* | `ENV["FASTLANE_USER"]` |
| `password` | Apple ID password | Yes* | `ENV["FASTLANE_PASSWORD"]` |
| `output_format` | Output format (normal, xml, json) | No | `normal` |

\* Either `api_key_id`+`api_issuer` OR `username`+`password` is required

### Legacy Method Parameters (use_upload_package: false)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app_type` | Platform type (ios, osx, appletvos) | `ios` |

### Modern Method Parameters (use_upload_package: true)

| Parameter | Description | Required | Auto-extracted |
|-----------|-------------|----------|----------------|
| `use_upload_package` | Enable modern upload method | No (false) | - |
| `apple_id` | App's Apple ID from App Store Connect | Yes | ❌ No |
| `platform` | Platform (ios, macos, appletvos, visionos) | No (ios) | - |
| `bundle_id` | Bundle identifier | No | ✅ Yes |
| `bundle_version` | CFBundleVersion | No | ✅ Yes |
| `bundle_short_version_string` | CFBundleShortVersionString | No | ✅ Yes |
| `provider_public_id` | Provider ID (for multi-provider accounts) | No | - |

## Example Project Repo

This is an example project [Altool-Demo](https://github.com/Shashikant86/Altool-Demo) available on GitHub which has its own README.

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Changelog

### v1.3.1 (2025-11-06)
- 🐛 **Fixed**: API key parameter compatibility with older Xcode versions
  - Changed to use `--apiKey`/`--apiIssuer` (camelCase) instead of `--api-key`/`--api-issuer` (kebab-case)
  - Ensures compatibility with Xcode versions before 16.2 that only accept camelCase parameters
  - Works with both `--upload-app` and `--upload-package` methods

### v1.3.0 (2025-10-30)
- ✨ **New**: Support for modern `--upload-package` method with automatic bundle metadata extraction
- ✨ **New**: Auto-extracts bundle_id, bundle_version, and bundle_short_version_string from IPA
- ✨ **New**: Support for visionOS platform
- 📝 Added comprehensive test suite with 7 test cases
- 📝 Added CLAUDE.md with detailed architecture documentation

### v1.2.0
- ✨ **New**: API Key authentication support (`api_key_id` and `api_issuer`)
- ♻️ Renamed plugin from `fastlane-plugin-altool` to `fastlane-plugin-altoolalt`
- ♻️ Renamed action from `altool` to `altool_alt`

### v1.1.0
- 🔧 Use `xcrun -f altool` for better Xcode compatibility
- 🔧 Improved path handling with quotation marks
- ♻️ Dropped `altool_` prefix from action parameters

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
