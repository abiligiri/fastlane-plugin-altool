require 'fastlane/action'
require_relative '../helper/altoolalt_helper'

module Fastlane
  module Actions
    class AltoolaltAction < Action
      def self.run(params)
        altool = `xcrun -f altool`.chomp
        UI.message("altool binary doesn't exist at path: #{altool}") unless File.exist?(altool)

        UI.message(" ----altool binary exists on your machine----- ")

        app_type = params[:app_type]
        ipa_path = "\"#{params[:ipa_path]}\""
        output_format = params[:output_format]
        use_upload_package = params[:use_upload_package]

        UI.message("========Validating and Uploading your IPA file to iTunes Connect=========")

        # Build command based on upload method
        if use_upload_package
          command = build_upload_package_command(altool, params, ipa_path, output_format)
        else
          command = build_upload_app_command(altool, params, ipa_path, app_type, output_format)
        end

        Actions.sh(command.join(' '))
        UI.message("========It might take long time to fully upload your IPA file=========")
      end

      def self.build_upload_app_command(altool, params, ipa_path, app_type, output_format)
        command = [
          altool,
          '--upload-app',
          '-f',
          ipa_path,
          '-t',
          app_type,
          '--output-format',
          output_format
        ]

        add_authentication(command, params)
        command
      end

      def self.build_upload_package_command(altool, params, ipa_path, output_format)
        # Get parameters - will try to extract from IPA if not provided
        apple_id = params[:apple_id]
        bundle_version = params[:bundle_version]
        bundle_short_version = params[:bundle_short_version_string]
        bundle_id = params[:bundle_id]
        platform = params[:platform]

        # Auto-extract bundle metadata from IPA if not all parameters provided
        if bundle_version.to_s.empty? || bundle_short_version.to_s.empty? || bundle_id.to_s.empty?
          UI.message("Attempting to extract bundle metadata from IPA...")
          extracted = extract_bundle_metadata_from_ipa(ipa_path)

          if extracted
            bundle_id ||= extracted[:bundle_id]
            bundle_version ||= extracted[:bundle_version]
            bundle_short_version ||= extracted[:bundle_short_version_string]
          end
        end

        # Validate required parameters (after potential extraction)
        if apple_id.to_s.empty?
          UI.user_error!("--upload-package requires apple_id parameter (App ID from App Store Connect)")
        end

        if bundle_version.to_s.empty? || bundle_short_version.to_s.empty? || bundle_id.to_s.empty?
          UI.user_error!("--upload-package requires: bundle_version, bundle_short_version_string, and bundle_id. " \
                         "These can be provided as parameters or will be auto-extracted from the IPA.")
        end

        command = [
          altool,
          '--upload-package',
          ipa_path,
          '-t',
          platform || 'ios',
          '--apple-id',
          apple_id,
          '--bundle-version',
          bundle_version,
          '--bundle-short-version-string',
          bundle_short_version,
          '--bundle-id',
          bundle_id,
          '--output-format',
          output_format
        ]

        # Add provider-public-id if specified (required for multi-provider accounts with username/password)
        provider_id = params[:provider_public_id]
        if !provider_id.to_s.empty?
          command.concat(['--provider-public-id', provider_id])
        end

        add_authentication(command, params)
        command
      end

      def self.add_authentication(command, params)
        api_key_id = params[:api_key_id]
        api_issuer = params[:api_issuer]

        if !api_key_id.to_s.empty? && !api_issuer.to_s.empty?
          command.concat(['--api-key', api_key_id, '--api-issuer', api_issuer])
        else
          username = params[:username]
          ENV["ALTOOL_PASSWORD"] = params[:password]
          password = "@env:ALTOOL_PASSWORD"
          if username.to_s.empty? || password.to_s.empty?
            UI.user_error!("You must provide either api_key_id and api_issuer or username and password")
          end
          command.concat(['--username', username, '--password', password])
        end
      end

      def self.extract_bundle_metadata_from_ipa(ipa_path)
        require 'tmpdir'
        require 'json'

        # Remove quotes from ipa_path if present
        clean_ipa_path = ipa_path.gsub(/^"|"$/, '')

        Dir.mktmpdir do |temp_dir|
          # Extract IPA (which is a ZIP archive)
          unzip_command = "unzip -q \"#{clean_ipa_path}\" -d \"#{temp_dir}\" 2>/dev/null"
          system(unzip_command)

          # Find Info.plist in the Payload directory
          info_plist_path = Dir.glob("#{temp_dir}/Payload/*.app/Info.plist").first

          unless info_plist_path
            UI.important("Could not find Info.plist in IPA, will require manual bundle parameters")
            return nil
          end

          # Convert Info.plist to JSON using plutil
          json_output = `plutil -convert json -o - "#{info_plist_path}" 2>/dev/null`

          if $?.exitstatus != 0
            UI.important("Failed to parse Info.plist with plutil")
            return nil
          end

          plist_data = JSON.parse(json_output)

          metadata = {
            bundle_id: plist_data['CFBundleIdentifier'],
            bundle_version: plist_data['CFBundleVersion'],
            bundle_short_version_string: plist_data['CFBundleShortVersionString']
          }

          UI.message("Extracted bundle metadata from IPA:")
          UI.message("  Bundle ID: #{metadata[:bundle_id]}")
          UI.message("  Bundle Version: #{metadata[:bundle_version]}")
          UI.message("  Short Version: #{metadata[:bundle_short_version_string]}")

          metadata
        rescue => e
          UI.important("Error extracting bundle metadata: #{e.message}")
          nil
        end
      end

      def self.description
        "Upload IPA to iTunes Connect using altool"
      end

      def self.authors
        ["Shashikant Jagtap", "Anand Biligiri", "Maksym Grebenets"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "This plugin can be used for uploading ipa files to iTunes Connect using altool rather than using ITMSTransporter.. Currently Fastlane deliver upload an ipa file using iTMSTransporter tool. There is another slick command line too called altool that can be used to upload ipa files as well"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :use_upload_package,
                                    env_name: "ALTOOL_USE_UPLOAD_PACKAGE",
                                    description: "Use --upload-package instead of --upload-app (newer method, requires additional parameters)",
                                    default_value: false,
                                    is_string: false,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :app_type,
                                    env_name: "ALTOOL_APP_TYPE",
                                    description: "Type or platform of application e.g osx, ios, appletvos (used with --upload-app)",
                                    default_value: "ios",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :platform,
                                    env_name: "ALTOOL_PLATFORM",
                                    description: "Platform for --upload-package: macos, ios, appletvos, visionos (defaults to ios if not specified)",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :ipa_path,
                                    env_name: "ALTOOL_IPA_PATH",
                                    description: "Path to IPA file ",
                                    is_string: true,
                                    default_value: Dir["*.ipa"].sort_by { |x| File.mtime(x) }.last,
                                    optional: false,
                                    verify_block: proc do |value|
                                      value = File.expand_path(value)
                                      UI.user_error!("Could not find ipa file at path '#{value}'") unless File.exist?(value)
                                      UI.user_error!("'#{value}' doesn't seem to be an ipa file") unless value.end_with?(".ipa")
                                    end),

          FastlaneCore::ConfigItem.new(key: :username,
                                    env_name: "ALTOOL_USERNAME",
                                    description: "Your Apple ID for iTunes Connects. This usually FASTLANE_USER environmental variable",
                                    is_string: true,
                                    default_value: ENV["FASTLANE_USER"],
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :password,
                                    env_name: "ALTOOL_PASSWORD",
                                    description: "Your Apple ID Password for iTunes Connects. This usually FASTLANE_PASSWORD environmental variable",
                                    is_string: true,
                                    default_value: ENV["FASTLANE_PASSWORD"],
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :api_key_id,
                                    env_name: "ALTOOL_API_KEY_ID",
                                    description: "Only specify the Key ID without the AuthKey_ and .p8. Place the file in ~/private_keys/ or ~/.private_keys/ or ~/.appstoreconnect/private_keys/ or private_keys/ in directory where altool is excuted",
                                    is_string: true,
                                    default_value: ENV["ALTOOL_API_KEY"],
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :api_issuer,
                                    env_name: "ALTOOL_API_ISSUER",
                                    description: "API Issuer ID for App Store Connect API",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :apple_id,
                                    env_name: "ALTOOL_APPLE_ID",
                                    description: "The Apple ID (App ID) of the app (required for --upload-package)",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :bundle_version,
                                    env_name: "ALTOOL_BUNDLE_VERSION",
                                    description: "The CFBundleVersion of the app (required for --upload-package, auto-extracted from IPA if not provided)",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :bundle_short_version_string,
                                    env_name: "ALTOOL_BUNDLE_SHORT_VERSION_STRING",
                                    description: "The CFBundleShortVersionString of the app (required for --upload-package, auto-extracted from IPA if not provided)",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :bundle_id,
                                    env_name: "ALTOOL_BUNDLE_ID",
                                    description: "The bundle identifier of the app (required for --upload-package, auto-extracted from IPA if not provided)",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :provider_public_id,
                                    env_name: "ALTOOL_PROVIDER_PUBLIC_ID",
                                    description: "Provider ID (required for --upload-package with username/password when account has multiple providers)",
                                    is_string: true,
                                    optional: true),

          FastlaneCore::ConfigItem.new(key: :output_format,
                                    env_name: "ALTOOL_OUTPUT_FORMAT",
                                    description: "Output formal xml or normal ",
                                    default_value: "normal",
                                    is_string: true,
                                    optional: true)

        ]
      end

      def self.example_code
        [
          '# Legacy method using --upload-app (still supported)
          altool_alt(
            username: ENV["FASTLANE_USER"],
            password: ENV["FASTLANE_PASSWORD"],
            app_type: "ios",
            ipa_path: "./build/Your-ipa.ipa",
            output_format: "xml"
          )',
          '# Legacy method with API Key authentication
          altool_alt(
            api_key_id: "<YOUR_API_KEY_ID>",
            api_issuer: "<YOUR_API_ISSUER>",
            app_type: "ios",
            ipa_path: "./build/Your-ipa.ipa",
            output_format: "xml"
          )',
          '# Newer method using --upload-package with auto-extraction of bundle metadata
          altool_alt(
            use_upload_package: true,
            api_key_id: "<YOUR_API_KEY_ID>",
            api_issuer: "<YOUR_API_ISSUER>",
            platform: "ios",
            ipa_path: "./build/Your-ipa.ipa",
            apple_id: "1234567890"
          )',
          '# Newer method with explicit bundle metadata (if auto-extraction fails)
          altool_alt(
            use_upload_package: true,
            username: ENV["FASTLANE_USER"],
            password: ENV["FASTLANE_PASSWORD"],
            platform: "ios",
            ipa_path: "./build/Your-ipa.ipa",
            apple_id: "1234567890",
            bundle_version: "1.0",
            bundle_short_version_string: "1.0.0",
            bundle_id: "com.example.app",
            output_format: "xml"
          )'
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
