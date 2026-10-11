# Apple builds and TestFlight

These experimental ports use the existing Empty Epsilon menus and station screens.
On Apple TV, connect to a server and select its main screen. Text fields use SDL's
system keyboard when focused. Remote-specific navigation is not implemented.

Requirements: macOS, Xcode with the iOS/tvOS SDKs, CMake 3.24+, Git, and Python 3.
Simulator presets target Apple Silicon Macs. The deployment target is iOS/tvOS 15.
Dependencies are built from source; no Homebrew SDL or FreeType libraries are linked.
The `macos-testflight` preset builds the native desktop app for Apple Silicon and
macOS 12+, with App Sandbox enabled for distribution through TestFlight.

## Build

From the repository root:

```sh
cmake --preset ipad -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=YOUR_TEAM_ID
cmake --build --preset ipad
ctest --test-dir _build_ipad -C Release --output-on-failure

cmake --preset appletv -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=YOUR_TEAM_ID
cmake --build --preset appletv
ctest --test-dir _build_appletv -C Release --output-on-failure
```

Set `-DEE_APPLE_BUNDLE_ID=your.unique.identifier` when configuring for your signing
team. Open `_build_ipad/EmptyEpsilon.xcodeproj` or
`_build_appletv/EmptyEpsilon.xcodeproj` to select a device and manage provisioning.
For compilation without a signing account, configure with
`-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO`. Unsigned device builds cannot be
installed directly; sign them with your team in Xcode.

The apps are in `_build_ipad/Release/EmptyEpsilon.app` and
`_build_appletv/Release/EmptyEpsilon.app`.

For a simulator (the corresponding runtime must be installed in Xcode):

```sh
cmake --preset ipad-simulator
cmake --build --preset ipad-simulator
ctest --test-dir _build_ipad_simulator -C Release --output-on-failure
xcrun simctl install YOUR_IPAD_UDID _build_ipad_simulator/Release/EmptyEpsilon.app
xcrun simctl launch YOUR_IPAD_UDID sh.mgp.emptyepsilon
```

Use `appletv-simulator` for tvOS. Its output directory is
`_build_appletv_simulator/Release`.

Host and clients must have the same Empty Epsilon version number. Builds default
to the build date; when building on different days, set the same
`CPACK_PACKAGE_VERSION_MAJOR`, `CPACK_PACKAGE_VERSION_MINOR`, and
`CPACK_PACKAGE_VERSION_PATCH` at configure time on all platforms.

## First-device checks

- Join a desktop server by IP, select a ship and station, and verify rendering and touch input.
- Focus the name and server-address fields and enter text with the system keyboard.
- Dismiss the Apple TV keyboard with Menu or Done, then click the same field again.
- Background the app and reopen it; check that settings survive and reconnect if needed.
- Rotate the main-screen camera and engage warp; check the starfield for missing triangles.
- On Apple TV, select the main screen and verify remote/pointer input on hardware.

iOS local server discovery uses multicast and needs Apple's approved multicast
entitlement. Direct-IP connections require only the local-network permission.
Configure `-DEE_APPLE_MULTICAST=ON` only with a provisioning profile that grants it.
See [Apple's local network privacy guidance](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).

Preferences are stored using `SDL_GetPrefPath` and saved when the app backgrounds.
Voice recording and desktop serial hardware are disabled on these targets.
Xcode builds generate iPad icons and Apple TV layered icons/top-shelf images from
the existing logo artwork. Other CMake generators do not package these icons.
The privacy manifest declares file metadata access within the app container and
elapsed-time measurements used by SDL and the game.

## TestFlight

The **Apple builds** GitHub Actions workflow runs on pull requests, pushes to
`master`, and manual dispatches. Each platform is compiled and archived once.
The workflow checks the native macOS, iPad, and Apple TV apps and saves downloadable
artifacts before signing and uploading those same archives with
`xcodebuild -exportArchive`. TestFlight uploads run only on `master`; pull requests
build and publish artifacts without requiring Apple secrets.
It uses Apple's cloud-managed distribution certificates; no certificate or
provisioning-profile files need to be stored in GitHub.

One-time setup:

1. Register a bundle ID in your paid Apple Developer team and create its App Store
   Connect app with **macOS**, **iOS**, and **tvOS** platforms. This workflow uses the
   same bundle ID for all three platforms. Accept any outstanding Apple agreements.
2. Create an App Store Connect **team API key** with the App Manager role and
   access to Certificates, Identifiers & Profiles. Have the Account Holder or an
   Admin grant **Access to Cloud Managed Distribution Certificate** as well.
   That permission is separate from the role; without it automatic signing fails.
3. Under the repository's **Settings → Secrets and variables → Actions**, set:

   | Kind | Name | Value |
   | --- | --- | --- |
   | Variable | `APPLE_TEAM_ID` | `H8563U643B` |
   | Variable | `APPLE_BUNDLE_ID` | `sh.mgp.emptyepsilon` |
   | Secret | `APP_STORE_CONNECT_KEY_ID` | The API key ID |
   | Secret | `APP_STORE_CONNECT_ISSUER_ID` | The team key's issuer ID |
   | Secret | `APP_STORE_CONNECT_PRIVATE_KEY` | The complete `.p8` file contents, including its header and footer |

Push builds use the UTC build date as the game version, matching the desktop CI.
For a specific server version, run **Actions → Apple builds → Run workflow** on `master` and enter
that version, such as `2026.10.11`. Commits marked `[skip ci]` do not start push builds.
The workflow assigns a distinct Apple build
number from the run number and retry attempt (`1.1`, `1.2`, `2.1`, …), leaving the
game's network version unchanged. For local builds, override this number with
`-DEE_APPLE_BUILD_NUMBER=1.1`.

After Apple finishes processing, the builds appear under the app's TestFlight
tab. Select tester groups there; external testing may require Apple's beta review.
The workflow does not configure tester groups or submit an App Store release.
Build artifacts retain each archive, crash symbols, and build log, plus an unsigned
app ZIP for iPad/tvOS or a standalone DMG for Mac. These are uploaded before
TestFlight signing, so a signing/upload failure still leaves downloadable builds.
Upload logs and any exported IPA or PKG are saved separately. Artifacts are kept
for seven days. Mac archives use ad-hoc signing to preserve sandbox entitlements
before distribution signing. The API key is written only to a temporary file
during upload and removed when that step exits.

If signing fails with a cloud-signing or missing-profile error, check the separate
cloud-certificate permission first. An upload is not verified until a run succeeds
with your team's credentials and Apple processes the resulting build.

See Apple's [cloud-managed certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/)
and [uploading builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

### Native macOS

```sh
cmake --preset macos-testflight -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
xcodebuild archive -project _build_macos-testflight/EmptyEpsilon.xcodeproj \
  -scheme EmptyEpsilon -configuration Release -destination 'generic/platform=macOS' \
  -archivePath /tmp/EmptyEpsilon-Mac.xcarchive \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual
python3 tests/appleBundle.py \
  /tmp/EmptyEpsilon-Mac.xcarchive/Products/Applications/EmptyEpsilon.app MacOSX Xcode
```

The sandbox permits incoming and outgoing game connections, microphone input for
voice chat, and serial bridge hardware. Preferences and user resources live inside
the app's container. The standalone DMG is made from a copy of the same compiled
app, re-signed without the sandbox so it keeps the regular desktop permissions and
configuration location. The original archive stays sandboxed for TestFlight.
The camera and slider tests are built alongside the Mac archive and run before upload.
The Mac privacy manifest also covers SDL's application-local Cocoa preferences.
See Apple's [sandbox entitlements](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html).

## Verification and known issues

Unsigned iPad and Apple TV device builds and their bundle checks pass with Xcode 27.
Device archives also pass checks for app icons, privacy manifests, game assets,
and matching crash-symbol UUIDs. Cloud signing and export have also been verified
with the configured team API key; upload status is recorded in GitHub Actions.
The native Mac archive passes the same packaging checks plus signature and sandbox
entitlement checks, and exports a cloud-signed App Store PKG. A sandboxed runtime
check from the build host is blocked before `main` by a user-session mismatch in
macOS's `secinitd`; interactive launch, voice chat, and serial hardware still need
testing from TestFlight on a logged-in Mac.
The standalone DMG reuses the archive binary, passes signature and disk-image
checks, and its app loads a scenario and accepts a local game connection. Both
Mac unit tests pass when built as dependencies of the archive.
The iPad simulator joins a desktop server, selects a ship and main screen, accepts
text input, and resumes after backgrounding with preferences saved. The existing
macOS camera test also passes.

The tvOS 27 simulator build and bundle check pass. An Apple TV 4K simulator at
1080p launches the default menus, discovers the desktop server, connects by IP,
joins a ship, and displays its main screen. The name and address fields open the
native keyboard; typing, dismissal, reopening the same field, and saving the player
name across relaunch have been checked. Background/resume also works.

The custom game controls expose no native accessibility elements, so tvOS XCTest
cannot click them. These menu clicks were injected through SDL using LLDB; the
native keyboard was driven with XCTest typing and remote buttons. Physical remote
and pointer navigation, accessibility, and physical devices remain unverified.

The skybox's black triangles were caused by vertex attribute arrays left enabled
by the 2D renderer. Those arrays referenced a four-vertex UI buffer while the
skybox indexed eight vertices. The dependency patch disables the arrays after UI
and post-processing draws. Both simulators now render the test scene correctly;
debugger checks confirm only the skybox's position input is enabled at its draw.
The reproduction scene used an Atlantis at (0, 0), a Medium Station at (2000, 0),
and ship rotations of 0 and 90 degrees.

Warp rendering also requires clamping the screen-sized post-processing texture:
GLES2 cannot sample non-power-of-two textures with the default repeat wrapping
([texture completeness rules](https://registry.khronos.org/OpenGL/specs/es/2.0/es_full_spec_2.0.pdf)).
The dependency patch sets both wrap axes to `GL_CLAMP_TO_EDGE`.

The app declares landscape in both Info.plist and SDL's orientation hint. The
iOS 27 simulator still rotates the native keyboard to portrait when the device
is held upright, even while the app's scene stays in landscape. An explicit
UIKit scene orientation lock also reproduced the mismatch. Use landscape for
input testing; a landscape declaration alone does not resolve this issue.
Physical-device verification remains necessary.

## Dependency patches

The Apple builds pin SDL 2.32.8 and SeriousProton commit
`b137f0f287a6378a1284057eb588a5d43f2468e2`, then apply the patches in this directory
to private build-directory copies. The sibling SeriousProton checkout and desktop
build dependencies are unaffected.

- `sdl2.patch` adds the single-window scene lifecycle required by the iOS/tvOS 27 SDKs
  and resets keyboard visibility when tvOS dismisses its native editor, allowing
  the same textbox to reopen it.
- `seriousproton.patch` selects GLES, preserves UIKit framebuffer bindings, suspends
  rendering in the background, runs frames through UIKit's animation callback,
  fixes bundled FreeType's Apple typedef, cleans up vertex attribute arrays after
  2D rendering, clamps offscreen textures for GLES2, and uses a static archive to
  avoid Xcode's duplicate object-filename issue.

Delete the affected preset's build directory when changing either dependency patch,
so CMake reapplies it to a fresh source tree. The renderer still uses deprecated
OpenGL ES; a future SDL3/Metal migration is separate work.
