describe Fastlane::Actions::AltoolAltAction do
  describe '#run' do
    it 'prints a message' do
      plugin_description = Fastlane::Actions::AltoolAltAction.description
      expect(plugin_description).to include("Upload IPA to iTunes Connect using altool")
    end
  end
end
