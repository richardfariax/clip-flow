cask "clipflow" do
  version :latest
  sha256 :no_check

  url "https://github.com/richardfariax/clip-flow/releases/latest/download/ClipFlow.dmg"
  name "ClipFlow"
  desc "Premium clipboard manager for macOS"
  homepage "https://github.com/richardfariax/clip-flow"

  depends_on macos: ">= :sonoma"

  app "ClipFlow.app"

  zap trash: [
    "~/Library/Application Support/ClipFlow",
    "~/Library/Caches/com.richadfarias.clipflow",
    "~/Library/HTTPStorages/com.richadfarias.clipflow",
    "~/Library/Preferences/com.richadfarias.clipflow.plist",
    "~/Library/Saved Application State/com.richadfarias.clipflow.savedState"
  ]
end
