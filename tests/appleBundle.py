"""Smoke-check a built Apple app before signing or installing it."""
import pathlib
import plistlib
import re
import subprocess
import sys

bundle = pathlib.Path(sys.argv[1])
platform = sys.argv[2]
mac = platform == "MacOSX"
contents = bundle / "Contents" if mac else bundle
resources = contents / "Resources" if mac else bundle
data = resources if mac else bundle / "data"
with (contents / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
executable = contents / "MacOS" / info["CFBundleExecutable"] if mac else bundle / info["CFBundleExecutable"]

assert info["CFBundleIdentifier"]
assert re.fullmatch(r"[1-9][0-9]{0,3}(?:\.[0-9]{1,2}){0,2}", info["CFBundleVersion"])
assert info["CFBundleSupportedPlatforms"] == [platform]
assert info["NSLocalNetworkUsageDescription"]
with (resources / "PrivacyInfo.xcprivacy").open("rb") as stream:
    privacy = plistlib.load(stream)
reasons = {entry["NSPrivacyAccessedAPIType"]: entry["NSPrivacyAccessedAPITypeReasons"]
           for entry in privacy["NSPrivacyAccessedAPITypes"]}
assert "C617.1" in reasons["NSPrivacyAccessedAPICategoryFileTimestamp"]
assert "35F9.1" in reasons["NSPrivacyAccessedAPICategorySystemBootTime"]
if mac:
    assert info["NSMicrophoneUsageDescription"]
    assert info["LSApplicationCategoryType"] == "public.app-category.games"
    assert "CA92.1" in reasons["NSPrivacyAccessedAPICategoryUserDefaults"]
else:
    assert info["UIDeviceFamily"] == ([3] if platform.startswith("AppleTV") else [2])
    scenes = info["UIApplicationSceneManifest"]["UISceneConfigurations"]
    assert scenes["UIWindowSceneSessionRoleApplication"][0]["UISceneDelegateClassName"] == "EEWindowSceneDelegate"
    # A root-level Resources directory prevents CoreFoundation finding Info.plist.
    assert not any(path.name.lower() == "resources" for path in bundle.iterdir())
if len(sys.argv) > 3 and sys.argv[3] == "Xcode":
    assert (resources / "Assets.car").is_file(), "Missing compiled app icons"
    if mac:
        icon = pathlib.Path(info["CFBundleIconFile"]).with_suffix(".icns")
        assert (resources / icon).is_file(), "Missing Mac app icon"
    else:
        icons = info["CFBundleIcons"] if platform.startswith("AppleTV") else info["CFBundleIcons~ipad"]
        assert icons["CFBundlePrimaryIcon"], "Missing primary app icon metadata"

if bundle.parent.parent.parent.suffix == ".xcarchive":
    archive = bundle.parent.parent.parent
    with (archive / "Info.plist").open("rb") as stream:
        archive_info = plistlib.load(stream)
    assert archive_info["ApplicationProperties"]["ApplicationPath"] == "Applications/EmptyEpsilon.app"
    assert list((archive / "Products").iterdir()) == [archive / "Products/Applications"], "Archive contains non-app products"
    symbols = archive / "dSYMs/EmptyEpsilon.app.dSYM/Contents/Resources/DWARF/EmptyEpsilon"
    assert symbols.is_file(), "Missing crash symbols"
    uuids = [subprocess.check_output(["xcrun", "dwarfdump", "--uuid", path], text=True).split()[1]
             for path in [executable, symbols]]
    assert uuids[0] == uuids[1], "Crash symbols do not match the archived executable"
    if mac:
        subprocess.run(["codesign", "--verify", "--strict", bundle], check=True)
        entitlements = plistlib.loads(subprocess.check_output(
            ["codesign", "--display", "--entitlements", "-", "--xml", bundle]))
        for capability in ["app-sandbox", "network.client", "network.server", "device.microphone",
                           "device.audio-input", "device.serial"]:
            assert entitlements[f"com.apple.security.{capability}"] is True, f"Missing {capability} entitlement"
for resource in ["resources/gui/default.theme.txt", "resources/gui/fonts/RobotoMono-SemiBold.ttf",
                 "resources/shaders/basic.shader", "scripts/scenario_10_empty.lua", "packs/Angryfly.pack"]:
    assert (data / resource).is_file(), f"Missing bundled asset: {resource}"

assert executable.is_file()
load_commands = subprocess.check_output(["xcrun", "vtool", "-show-build", executable], text=True)
expected = {"MacOSX": "MACOS", "iPhoneOS": "IOS", "iPhoneSimulator": "IOSSIMULATOR",
            "AppleTVOS": "TVOS", "AppleTVSimulator": "TVOSSIMULATOR"}[platform]
assert f"platform {expected}\n" in load_commands, load_commands
libraries = subprocess.check_output(["otool", "-L", executable], text=True)
assert "/opt/homebrew/" not in libraries and "/usr/local/" not in libraries, libraries
print(f"Verified {platform} bundle: {bundle}")
