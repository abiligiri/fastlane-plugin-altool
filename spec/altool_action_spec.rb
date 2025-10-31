require 'tmpdir'
require 'zip'
require 'plist'

describe Fastlane::Actions::AltoolaltAction do
  describe '#run' do
    it 'prints a message' do
      plugin_description = Fastlane::Actions::AltoolaltAction.description
      expect(plugin_description).to include("Upload IPA to iTunes Connect using altool")
    end
  end

  describe '#extract_bundle_metadata_from_ipa' do
    let(:test_bundle_id) { 'com.test.myapp' }
    let(:test_bundle_version) { '42' }
    let(:test_bundle_short_version) { '1.2.3' }

    # Helper method to create a dummy IPA file
    def create_dummy_ipa(temp_dir, bundle_id:, bundle_version:, bundle_short_version:)
      # Create the directory structure: Payload/MyApp.app/
      app_dir = File.join(temp_dir, 'Payload', 'MyApp.app')
      FileUtils.mkdir_p(app_dir)

      # Create Info.plist with test data
      info_plist_path = File.join(app_dir, 'Info.plist')
      plist_data = {
        'CFBundleIdentifier' => bundle_id,
        'CFBundleVersion' => bundle_version,
        'CFBundleShortVersionString' => bundle_short_version,
        'CFBundleName' => 'MyApp'
      }

      # Write plist file (using plutil to ensure proper format)
      require 'json'
      json_data = JSON.generate(plist_data)
      system("echo '#{json_data}' | plutil -convert xml1 - -o \"#{info_plist_path}\"")

      # Create IPA (ZIP file) with Payload directory
      ipa_path = File.join(temp_dir, 'test.ipa')

      # Use Ruby's built-in zip if available, otherwise use system zip
      Dir.chdir(temp_dir) do
        system("zip -q -r test.ipa Payload")
      end

      ipa_path
    end

    it 'extracts bundle metadata from a valid IPA' do
      Dir.mktmpdir do |temp_dir|
        ipa_path = create_dummy_ipa(
          temp_dir,
          bundle_id: test_bundle_id,
          bundle_version: test_bundle_version,
          bundle_short_version: test_bundle_short_version
        )

        # Add quotes to match how the action handles paths
        quoted_ipa_path = "\"#{ipa_path}\""

        metadata = Fastlane::Actions::AltoolaltAction.extract_bundle_metadata_from_ipa(quoted_ipa_path)

        expect(metadata).not_to be_nil
        expect(metadata[:bundle_id]).to eq(test_bundle_id)
        expect(metadata[:bundle_version]).to eq(test_bundle_version)
        expect(metadata[:bundle_short_version_string]).to eq(test_bundle_short_version)
      end
    end

    it 'returns nil for invalid IPA path' do
      metadata = Fastlane::Actions::AltoolaltAction.extract_bundle_metadata_from_ipa('"/nonexistent/file.ipa"')
      expect(metadata).to be_nil
    end

    it 'returns nil for IPA without Info.plist' do
      Dir.mktmpdir do |temp_dir|
        # Create an empty ZIP file
        ipa_path = File.join(temp_dir, 'empty.ipa')
        Dir.chdir(temp_dir) do
          FileUtils.mkdir_p('Payload')
          system("zip -q -r empty.ipa Payload")
        end

        quoted_ipa_path = "\"#{ipa_path}\""
        metadata = Fastlane::Actions::AltoolaltAction.extract_bundle_metadata_from_ipa(quoted_ipa_path)
        expect(metadata).to be_nil
      end
    end
  end

  describe '#build_upload_package_command' do
    let(:test_bundle_id) { 'com.test.integration' }
    let(:test_bundle_version) { '100' }
    let(:test_bundle_short_version) { '2.0.0' }
    let(:test_apple_id) { '1234567890' }

    def create_dummy_ipa(temp_dir, bundle_id:, bundle_version:, bundle_short_version:)
      app_dir = File.join(temp_dir, 'Payload', 'MyApp.app')
      FileUtils.mkdir_p(app_dir)

      info_plist_path = File.join(app_dir, 'Info.plist')
      plist_data = {
        'CFBundleIdentifier' => bundle_id,
        'CFBundleVersion' => bundle_version,
        'CFBundleShortVersionString' => bundle_short_version,
        'CFBundleName' => 'MyApp'
      }

      require 'json'
      json_data = JSON.generate(plist_data)
      system("echo '#{json_data}' | plutil -convert xml1 - -o \"#{info_plist_path}\"")

      ipa_path = File.join(temp_dir, 'test.ipa')
      Dir.chdir(temp_dir) do
        system("zip -q -r test.ipa Payload")
      end

      ipa_path
    end

    it 'builds command with auto-extracted metadata' do
      Dir.mktmpdir do |temp_dir|
        ipa_path = create_dummy_ipa(
          temp_dir,
          bundle_id: test_bundle_id,
          bundle_version: test_bundle_version,
          bundle_short_version: test_bundle_short_version
        )

        quoted_ipa_path = "\"#{ipa_path}\""

        # Mock params with only apple_id provided
        params = {
          apple_id: test_apple_id,
          api_key_id: 'test_key',
          api_issuer: 'test_issuer',
          platform: nil,
          bundle_version: nil,
          bundle_short_version_string: nil,
          bundle_id: nil,
          provider_public_id: nil
        }

        # Mock the params object - must return actual values, not doubles
        params_obj = double('params')
        allow(params_obj).to receive(:[]) do |key|
          params[key]
        end

        command = Fastlane::Actions::AltoolaltAction.build_upload_package_command(
          '/usr/bin/altool',
          params_obj,
          quoted_ipa_path,
          'normal'
        )

        # Verify command contains extracted values
        expect(command).to include('--bundle-id', test_bundle_id)
        expect(command).to include('--bundle-version', test_bundle_version)
        expect(command).to include('--bundle-short-version-string', test_bundle_short_version)
        expect(command).to include('--apple-id', test_apple_id)
      end
    end

    it 'uses explicitly provided parameters over extraction' do
      Dir.mktmpdir do |temp_dir|
        ipa_path = create_dummy_ipa(
          temp_dir,
          bundle_id: 'com.extracted.app',
          bundle_version: '1',
          bundle_short_version: '1.0'
        )

        quoted_ipa_path = "\"#{ipa_path}\""

        # Mock params with explicit values that differ from IPA
        explicit_bundle_id = 'com.explicit.override'
        explicit_version = '999'
        explicit_short_version = '9.9.9'

        params = {
          apple_id: test_apple_id,
          api_key_id: 'test_key',
          api_issuer: 'test_issuer',
          platform: nil,
          bundle_version: explicit_version,
          bundle_short_version_string: explicit_short_version,
          bundle_id: explicit_bundle_id,
          provider_public_id: nil
        }

        params_obj = double('params')
        allow(params_obj).to receive(:[]) do |key|
          params[key]
        end

        command = Fastlane::Actions::AltoolaltAction.build_upload_package_command(
          '/usr/bin/altool',
          params_obj,
          quoted_ipa_path,
          'normal'
        )

        # Verify command uses explicit values, not extracted ones
        expect(command).to include('--bundle-id', explicit_bundle_id)
        expect(command).to include('--bundle-version', explicit_version)
        expect(command).to include('--bundle-short-version-string', explicit_short_version)
      end
    end

    it 'raises error when apple_id is missing' do
      Dir.mktmpdir do |temp_dir|
        ipa_path = create_dummy_ipa(
          temp_dir,
          bundle_id: test_bundle_id,
          bundle_version: test_bundle_version,
          bundle_short_version: test_bundle_short_version
        )

        quoted_ipa_path = "\"#{ipa_path}\""

        params = {
          apple_id: nil,  # Missing apple_id
          api_key_id: 'test_key',
          api_issuer: 'test_issuer',
          platform: nil,
          bundle_version: nil,
          bundle_short_version_string: nil,
          bundle_id: nil,
          provider_public_id: nil
        }

        params_obj = double('params')
        allow(params_obj).to receive(:[]) do |key|
          params[key]
        end

        expect do
          Fastlane::Actions::AltoolaltAction.build_upload_package_command(
            '/usr/bin/altool',
            params_obj,
            quoted_ipa_path,
            'normal'
          )
        end.to raise_error(/requires apple_id/)
      end
    end
  end
end
