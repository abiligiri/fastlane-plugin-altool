# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Fastlane plugin that provides an alternative method for uploading IPA files to iTunes Connect (App Store Connect) using Apple's `altool` command-line tool instead of the standard iTMSTransporter. The plugin is named `fastlane-plugin-altoolalt` but is often referred to as `altool` in documentation.

## Development Commands

### Running Tests
```bash
# Run all tests (default rake task)
rake

# Run tests only
rspec

# Run specific test file
rspec spec/altool_action_spec.rb
```

### Code Quality
```bash
# Run RuboCop for style validation
rubocop

# Auto-fix RuboCop issues
rubocop -a
```

### Building the Gem
```bash
# Build the gem (creates .gem file in current directory)
bundle exec rake build

# Install the gem locally for testing
bundle exec rake install
```

### Installing Dependencies
```bash
# Install all development dependencies
bundle install

# Install with vendor directory (current setup)
bundle install --path vendor/bin
```

## Architecture

### Plugin Structure

The plugin follows Fastlane's standard plugin architecture:

- **Entry point**: `lib/fastlane/plugin/altoolalt.rb` - Auto-loads all actions and helpers
- **Main action**: `lib/fastlane/plugin/altoolalt/actions/altoolalt_action.rb` - The `altool_alt` action
- **Helper**: `lib/fastlane/plugin/altoolalt/helper/altoolalt_helper.rb` - Utility functions (currently minimal)
- **Version**: `lib/fastlane/plugin/altoolalt/version.rb` - Version constant

### Upload Methods

The plugin supports both legacy and modern altool upload commands:

1. **Legacy method (`--upload-app`)**: Default behavior
   - Simpler, requires only IPA path and authentication
   - Uses `app_type` parameter (ios, osx, appletvos)
   - Command built in `build_upload_app_command()` (altoolalt_action.rb:31-44)

2. **Modern method (`--upload-package`)**: Opt-in with `use_upload_package: true`
   - Requires `apple_id` (App Store Connect App ID)
   - Auto-extracts `bundle_version`, `bundle_short_version_string`, and `bundle_id` from IPA's Info.plist
   - Manual override: Can explicitly provide bundle parameters if auto-extraction fails
   - Uses `platform` parameter (ios, macos, appletvos, visionos)
   - Supports `provider_public_id` for multi-provider accounts
   - Command built in `build_upload_package_command()` (altoolalt_action.rb:46-101)
   - Validates required parameters after extraction at altoolalt_action.rb:66-74

The upload method is selected at runtime based on the `use_upload_package` parameter (altoolalt_action.rb:21-25).

### Authentication Methods

Both upload methods support two mutually exclusive authentication methods:

1. **API Key authentication** (preferred):
   - Parameters: `api_key_id` and `api_issuer`
   - Key file must be placed in standard locations: `~/private_keys/`, `~/.private_keys/`, `~/.appstoreconnect/private_keys/`, or `private_keys/`

2. **Username/Password authentication**:
   - Parameters: `username` and `password`
   - Password is passed via environment variable `ALTOOL_PASSWORD` for security
   - Defaults to `FASTLANE_USER` and `FASTLANE_PASSWORD` environment variables

Authentication logic is centralized in `add_authentication()` method (altoolalt_action.rb:87-102) and validates that one method is provided.

### Command Execution

The action uses `xcrun -f altool` to locate the altool binary (altoolalt_action.rb:8), ensuring compatibility across different Xcode installations. The command is built as an array and executed via `Actions.sh()` (altoolalt_action.rb:27).

### Configuration Options

All configuration options use FastlaneCore::ConfigItem with:
- Environment variable fallbacks (e.g., `ALTOOL_APP_TYPE`, `ALTOOL_IPA_PATH`)
- Default values where appropriate
- Validation blocks for critical parameters (e.g., IPA file existence check at altoolalt_action.rb:78-82)

## Key Implementation Details

### IPA Path Handling
- Default behavior finds the most recently modified `.ipa` file in the current directory
- Path is quoted to handle spaces (altoolalt_action.rb:14)
- Validated to ensure file exists and has `.ipa` extension

### Bundle Metadata Auto-Extraction
When using `--upload-package` mode, the plugin automatically extracts bundle metadata from the IPA:

1. **Extraction Process** (altoolalt_action.rb:104-150):
   - Creates temporary directory
   - Unzips IPA (which is a ZIP archive)
   - Locates `Info.plist` in `Payload/*.app/`
   - Uses `plutil` to convert plist to JSON
   - Extracts: `CFBundleIdentifier`, `CFBundleVersion`, `CFBundleShortVersionString`

2. **Fallback Behavior**:
   - If extraction fails or parameters are explicitly provided, uses provided values
   - Only attempts extraction when bundle parameters are missing (altoolalt_action.rb:55-64)
   - Provides clear error messages if required parameters still missing after extraction

3. **Benefits**:
   - Simplifies usage - only requires `apple_id` parameter
   - Ensures consistency between IPA contents and upload metadata
   - Reduces user error from mismatched version strings

### Output Formats
- Supports `normal` (default) or `xml` output formats
- Controlled by the `output_format` parameter

### Platform Support
- Primary use case is iOS apps (`app_type: "ios"` or `platform: "ios"`)
- Also supports `osx`/`macos`, `appletvos`, and `visionos` platforms

### Choosing Between Upload Methods

**Use `--upload-app` (default)** when:
- You want the simplest implementation with minimal parameters
- You're maintaining existing integrations
- You don't need the additional metadata validation

**Use `--upload-package` (set `use_upload_package: true`)** when:
- You want to use the newer altool API
- You want automatic extraction of bundle metadata from the IPA
- You need explicit validation of bundle metadata before upload
- You're working with multi-provider accounts (via `provider_public_id`)
- You want to future-proof against potential `--upload-app` deprecation

**Simplified usage example** with auto-extraction:
```ruby
altool_alt(
  use_upload_package: true,
  api_key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
  api_issuer: ENV["APP_STORE_CONNECT_ISSUER_ID"],
  ipa_path: "./build/MyApp.ipa",
  apple_id: "1234567890"  # Only non-extractable parameter required
)
```

## Testing Notes

The test suite is minimal (spec/altool_action_spec.rb) and only verifies the action description. When adding functionality, expand tests to cover:
- Authentication method validation
- Command construction for both auth methods
- IPA file validation
- Error handling

## Naming Convention

Note the naming discrepancy:
- Gem/plugin name: `fastlane-plugin-altoolalt` (with "alt" suffix)
- Action name in Fastlane: `altool_alt` (underscore, not `altoolalt`)
- Module name: `Altoolalt` (single word)

This stems from renaming the plugin while maintaining backwards compatibility.
