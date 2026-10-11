---
name: install-yingxia
description: Help someone install Yingxia (映匣) on a Mac, iPhone, iPad or Apple TV. Use when a user asks how to download, install, sideload, update or re-sign the app, or when an install fails (Sideloadly errors, the app stops opening, the Apple TV isn't found).
---

# Install Yingxia

Yingxia runs on Mac, iPhone, iPad and Apple TV. The Mac app is a normal signed download. The iPhone, iPad and Apple TV apps aren't on the App Store, so people sideload an IPA and sign it with their own Apple account. The full user guide is [Docs/INSTALL.md](../../../Docs/INSTALL.md); this skill is the short version plus the fixes we've learned the hard way.

## 1. Find the latest downloads

The newest release is the first entry in [`website/public/releases.json`](../../../website/public/releases.json) (live at https://yingxia.getmegaportal.com/releases.json). Downloads follow one pattern:

```
https://download.getmegaportal.com/yingxia/<version>/Yingxia-<version>-macos-arm64.dmg
https://download.getmegaportal.com/yingxia/<version>/Yingxia-<version>-ios.ipa
https://download.getmegaportal.com/yingxia/<version>/Yingxia-<version>-tvos.ipa
```

Check a link before you hand it out (`curl -sI <url>` should return 200). The website's install section is https://yingxia.getmegaportal.com/#install (`#install-ios`, `#install-tv` open a tab).

| Device | Requirement | File | Bundle ID |
| --- | --- | --- | --- |
| Mac | macOS 26+, Apple silicon | `…-macos-arm64.dmg` | `com.tvbox.yingxia.mac` |
| iPhone / iPad | iOS / iPadOS 26+ | `…-ios.ipa` | `com.tvbox.yingxia.ios` |
| Apple TV | tvOS 26+ (Apple TV 4K) | `…-tvos.ipa` | `com.tvbox.yingxia.tv` |

The iOS and tvOS IPAs are not interchangeable.

## 2. Mac

Download the DMG, open it and drag Yingxia to Applications. It's signed with Developer ID and notarized, so it opens without warnings. Later versions announce themselves in the app (Settings → Software Update).

## 3. iPhone or iPad (Sideloadly)

1. Install [Sideloadly](https://sideloadly.io/) on a Mac or Windows PC.
2. Connect the device by USB, unlock it, tap **Trust**.
3. In Sideloadly, pick the device, drag in the **iOS IPA**, type the Apple account email, click **Start**, and finish the password / 2FA prompts.
4. On the device: **Settings → General → VPN & Device Management** → trust the developer entry. Turn on **Settings → Privacy & Security → Developer Mode** if asked.
5. Open Yingxia and add a subscription.

## 4. Apple TV (Sideloadly on a Mac)

Apple TV 4K has no USB data port, so the install goes over the network, and Sideloadly supports that only on a Mac.

1. Mac and Apple TV on the same local network.
2. On the Apple TV: **Settings → Remotes and Devices → Remote App and Devices**, and leave that screen open.
3. In Sideloadly, click the **Re-Pair** button (second icon right of the device list), choose the Apple TV, type the PIN shown on the TV.
4. Pick the Apple TV in the device list, drag in the **tvOS IPA**, enter the Apple account, click **Start**.
5. Expect it to take several minutes (see "Slow installs" below), then open Yingxia on the TV.

## 5. Keep it working

A sideloaded app stops opening when its signature expires: **7 days** with a free Apple account, up to **1 year** with a paid developer account. Turn on Sideloadly's automatic refresh (it only runs while the computer is on and the device is reachable). To renew by hand, install the same IPA again with the **same Apple account**; don't delete the app first or the user loses subscriptions, favorites and history.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `Guru Meditation … GSA returned a non-plist response (HTTP 503 …)`, and the log says **"Will use Fake Local Anisette"** | Sideloadly couldn't get real device-identity data ("anisette") from macOS and sent made-up values; Apple's sign-in server answers those with 503. It isn't the network or a proxy, despite the message. Open Sideloadly settings (gear icon, Alt+G) and switch anisette to **On-device Anisette** (or **Local Anisette**, which asks for the Mac admin password), then Start again. Seen with Sideloadly 0.70.1 (Intel build under Rosetta) on macOS 27. |
| Apple TV doesn't appear in Sideloadly | Same network for both; keep **Remote App and Devices** open on the TV; click Re-Pair. |
| Install sits at a few percent for minutes on Apple TV | Normal. Sideloadly and similar tools unzip the IPA and copy every file separately; Yingxia bundles a Java runtime of about 11,000 small files, so a Wi-Fi install takes several minutes (7½ min measured with cider). Let it finish. |
| "Wrong platform" or architecture error | Wrong IPA (iOS vs tvOS), or a simulator build. |
| App stopped opening after a week | Signature expired: refresh or reinstall with the same account. |
| Installed, but a video won't play | Installing doesn't guarantee every subscription source works; try another source. |

## Other tools

- **cider-cli** (github.com/Battzz/cider-cli, prebuilt binaries at github.com/Muonagi/cider-cli releases): `cider device list` finds an Apple TV over Wi-Fi and `cider device install <signed.ipa> -u <udid>` installs an already-signed IPA. Don't use `cider sign --apple-id` for the Apple TV app: it only asks Apple for iOS provisioning profiles, and when an account has too many certificates it **revokes an existing development certificate**, which can break the person's other signed apps. Ask before running it on anyone's account.
- **Developers with the team's signed IPA** (the build already carries a provisioning profile for the device): `ideviceinstaller -n -u <udid> install <signed.ipa>` (`brew install ideviceinstaller`) sends the IPA as one file and the TV unpacks it — about 20 s instead of minutes. `xcrun devicectl device install app --device <udid> <app or ipa>` works too. A team-signed IPA only installs on devices registered to that team.

## Building it yourself

See [Docs/DEVELOPMENT.md](../../../Docs/DEVELOPMENT.md). The signed and notarized Mac release is built with `Scripts/package-mac-release.sh`.
