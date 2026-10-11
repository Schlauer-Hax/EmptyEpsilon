"""Smoke-check a built Apple app before signing or installing it."""
import pathlib
import plistlib
import re
import subprocess
import sys

bundle = pathlib.Path(sys.argv[1])
platform = sys.argv[2]
with (bundle / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)

assert info["CFBundleIdentifier"]
assert re.fullmatch(r"[1-9][0-9]{0,3}(?:\.[0-9]{1,2}){0,2}", info["CFBundleVersion"])
assert info["CFBundleSupportedPlatforms"] == [platform]
assert info["UIDeviceFamily"] == ([3] if platform.startswith("AppleTV") else [2])
assert info["NSLocalNetworkUsageDescription"]
with (bundle / "PrivacyInfo.xcprivacy").open("rb") as stream:
    privacy = plistlib.load(stream)
reasons = {entry["NSPrivacyAccessedAPIType"]: entry["NSPrivacyAccessedAPITypeReasons"]
           for entry in privacy["NSPrivacyAccessedAPITypes"]}
assert "C617.1" in reasons["NSPrivacyAccessedAPICategoryFileTimestamp"]
assert "35F9.1" in reasons["NSPrivacyAccessedAPICategorySystemBootTime"]
scenes = info["UIApplicationSceneManifest"]["UISceneConfigurations"]
assert scenes["UIWindowSceneSessionRoleApplication"][0]["UISceneDelegateClassName"] == "EEWindowSceneDelegate"
# A root-level Resources directory prevents CoreFoundation finding Info.plist.
assert not any(path.name.lower() == "resources" for path in bundle.iterdir())
if len(sys.argv) > 3 and sys.argv[3] == "Xcode":
    assert (bundle / "Assets.car").is_file(), "Missing compiled app icons"
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
             for path in [bundle / info["CFBundleExecutable"], symbols]]
    assert uuids[0] == uuids[1], "Crash symbols do not match the archived executable"
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
