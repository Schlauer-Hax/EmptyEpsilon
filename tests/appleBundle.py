"""Smoke-check a built Apple app before signing or installing it."""
import pathlib
import plistlib
import subprocess
import sys

bundle = pathlib.Path(sys.argv[1])
platform = sys.argv[2]
with (bundle / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)

assert info["CFBundleIdentifier"]
assert info["CFBundleSupportedPlatforms"] == [platform]
assert info["UIDeviceFamily"] == ([3] if platform.startswith("AppleTV") else [2])
assert info["NSLocalNetworkUsageDescription"]
scenes = info["UIApplicationSceneManifest"]["UISceneConfigurations"]
assert scenes["UIWindowSceneSessionRoleApplication"][0]["UISceneDelegateClassName"] == "EEWindowSceneDelegate"
# A root-level Resources directory prevents CoreFoundation finding Info.plist.
assert not any(path.name.lower() == "resources" for path in bundle.iterdir())
for resource in ["resources/gui/default.theme.txt", "resources/gui/fonts/RobotoMono-SemiBold.ttf",
                 "resources/shaders/basic.shader", "scripts/scenario_10_empty.lua", "packs/Angryfly.pack"]:
    assert (bundle / "data" / resource).is_file(), f"Missing bundled asset: {resource}"

executable = bundle / info["CFBundleExecutable"]
assert executable.is_file()
load_commands = subprocess.check_output(["xcrun", "vtool", "-show-build", executable], text=True)
expected = {"iPhoneOS": "IOS", "iPhoneSimulator": "IOSSIMULATOR",
            "AppleTVOS": "TVOS", "AppleTVSimulator": "TVOSSIMULATOR"}[platform]
assert f"platform {expected}\n" in load_commands, load_commands
libraries = subprocess.check_output(["otool", "-L", executable], text=True)
assert "/opt/homebrew/" not in libraries and "/usr/local/" not in libraries, libraries
print(f"Verified {platform} bundle: {bundle}")
