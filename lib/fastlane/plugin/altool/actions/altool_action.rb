require 'fastlane/action'
require_relative '../helper/altool_helper'

module Fastlane
  module Actions
    class AltoolAction < Action
      def self.run(params)
        altool = `xcrun -f altool`.chomp
        UI.message("altool binary doesn't exist at path: #{altool}") unless File.exist?(altool)

        UI.message(" ----altool binary exists on your machine----- ")

        app_type = params[:app_type]
        ipa_path = "\"#{params[:ipa_path]}\""
        output_format = params[:output_format]

        UI.message("========Validating and Uploading your IPA file to iTunes Connect=========")
        command = [
          altool,
          '--upload-app',
          '-t',
          app_type,
          '-f',
          ipa_path,
          output_format
        ]

        api_key_id = params[:api_key_id]
        api_issuer = params[:api_issuer]
        if !api_key_id.to_s.empty? && !api_issuer.to_s.empty?
          command += ['--apiKey', api_key_id, '--apiIssuer', api_issuer]
        else
          username = params[:username]
          ENV["ALTOOL_PASSWORD"] = params[:password]
          password = "@env:ALTOOL_PASSWORD"
          if username.to_s.empty? || password.to_s.empty?
            UI.user_error!("You must provide either api_key and api_issuer or username and password")
          end
          command += ['--username', username, '--password', password]
        end

        Actions.sh(command.join(' '))
        UI.message("========It might take long time to fully upload your IPA file=========")
      end

      def self.description
        "Upload IPA to iTunes Connect using altool"
      end

      def self.authors
        ["Shashikant Jagtap"]
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
          FastlaneCore::ConfigItem.new(key: :app_type,
                                    env_name: "ALTOOL_APP_TYPE",
                                    description: "Type or platform of application e.g osx, ios, appletvos ",
                                    default_value: "ios",
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

          FastlaneCore::ConfigItem.new(key: :output_format,
                                    env_name: "ALTOOL_OUTPUT_FORMAT",
                                    description: "Output formal xml or normal ",
                                    default_value: "normal",
                                    is_string: true,
                                    optional: true)

        ]
      end

      def self.example_code
        ['   altool(
            username: ENV["FASTLANE_USER"],
            password: ENV["FASTLANE_PASSWORD"],
            app_type: "ios",
            ipa_path: "./build/Your-ipa.ipa",
            output_format: "xml",
        )
       ',
         '   altool(
            api_key: "<YOUR_API_KEY_ID>",
            api_issuer: "<YOUR_API_ISSUER>",
            app_type: "ios",
            ipa_path: "./build/Your-ipa.ipa",
            output_format: "xml",
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
