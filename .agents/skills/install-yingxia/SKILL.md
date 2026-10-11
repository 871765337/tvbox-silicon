---
name: install-yingxia
description: Help someone install Yingxia (映匣) on a Mac, iPhone, iPad or Apple TV, using the cider CLI to sign and install the iPhone, iPad and Apple TV apps. Use when a user asks how to download, install, sideload, update or re-sign the app, or when an install fails.
---

# Install Yingxia

Yingxia runs on Mac, iPhone, iPad and Apple TV. The Mac app is a normal signed download. The iPhone, iPad and Apple TV apps aren't on the App Store, so they are sideloaded: the IPA is signed with the person's own Apple account and installed on their device. Use **[cider](https://github.com/Battzz/cider-cli)**, a command-line signer and installer, for that. Sideloadly is the fallback (see the end, and [Docs/INSTALL.md](../../../Docs/INSTALL.md)).

## 1. Find the latest downloads

The newest release is the first entry in [`website/public/releases.json`](../../../website/public/releases.json) (live at https://yingxia.getmegaportal.com/releases.json). Downloads follow one pattern:

```
https://download.getmegaportal.com/yingxia/<version>/Yingxia-<version>-macos-arm64.dmg
https://download.getmegaportal.com/yingxia/<version>/Yingxia-<version>-ios.ipa
https://download.getmegaportal.com/yingxia/<version>/Yingxia-<version>-tvos.ipa
```

Check a link before handing it out (`curl -sI <url>` returns 200).

| Device | Requirement | File | Bundle ID |
| --- | --- | --- | --- |
| Mac | macOS 26+, Apple silicon | `…-macos-arm64.dmg` | `com.tvbox.yingxia.mac` |
| iPhone / iPad | iOS / iPadOS 26+ | `…-ios.ipa` | `com.tvbox.yingxia.ios` |
| Apple TV | tvOS 26+ (Apple TV 4K) | `…-tvos.ipa` | `com.tvbox.yingxia.tv` |

The iOS and tvOS IPAs are not interchangeable.

## 2. Mac

Download the DMG, open it and drag Yingxia to Applications. It's signed with Developer ID and notarized. Newer versions announce themselves in the app (Settings → Software Update).

## 3. Install cider

Use the prebuilt binary; building from source currently fails because a dependency repository (`PlumeImpactor/plume-idevice`) was removed from GitHub.

```sh
# macOS (Homebrew)
brew tap Muonagi/cider-cli https://github.com/Muonagi/cider-cli
brew install cider

# or the install script (macOS / Linux, installs to /usr/local/bin)
curl -fsSL https://raw.githubusercontent.com/Muonagi/cider-cli/main/install.sh | sh

cider --version
```

Windows: download `cider-x86_64-pc-windows-msvc.zip` from the [releases](https://github.com/Muonagi/cider-cli/releases) and install Apple's device drivers (iTunes or Apple Devices). Linux needs `usbmuxd` running.

## 4. Sign in once

```sh
cider account login          # prompts for Apple ID, password and 2FA code
cider account team           # only asked if the account is in several teams
```

A free Apple account works. Have the person type their own password into the prompt; never ask them to paste it to you, and never pass it with `-p`.

**Certificates:** on first use cider creates a development certificate named "AltStore" for the account. If Apple says the account already has too many, cider **revokes an existing development certificate** to make room. That's routine for a free account, but on a paid developer account it can break apps signed with the revoked certificate. On a paid account, run `cider account certificates` first and warn the person before signing.

## 5. iPhone or iPad

1. Connect the device by USB, unlock it, tap **Trust**.
2. Find it and pair:
   ```sh
   cider device list
   cider device trust -u <UDID>
   ```
3. Sign and install, saving it for refresh:
   ```sh
   cider sign Yingxia-<version>-ios.ipa --apple-id --install -u <UDID> --refresh
   ```
4. On the device: **Settings → General → VPN & Device Management** → trust the developer entry; turn on **Settings → Privacy & Security → Developer Mode** if asked.
5. Open Yingxia and add a subscription.

## 6. Apple TV

Apple TV 4K has no USB data port, so it's reached over the network. Put the computer and the Apple TV on the same local network.

1. Check that cider sees it: `cider device list` shows it as `<TV name> [WiFi]` with a UDID like `00008110-…`. Use that UDID, not the MAC-address-style entry that may be listed under the same name.
2. If it isn't listed, pair it once: on the Apple TV open **Settings → Remotes and Devices → Remote App and Devices** and keep that screen open, then run `cider device trust` (or pair from Xcode's Devices window, or Sideloadly's Re-Pair button) and type the PIN shown on the TV.
3. Sign and install:
   ```sh
   cider sign Yingxia-<version>-tvos.ipa --apple-id --install -u <UDID> --refresh
   ```
4. Wait. Yingxia bundles a Java runtime of about 11,000 small files and cider copies them over Wi-Fi one by one, so the install takes several minutes (7½ min measured). It ends with `✓ Installed to <name>`.
5. Open Yingxia on the TV.

Verified on tvOS 27: `cider device list` and `cider device install` with an already-signed tvOS IPA. Not yet verified: `cider sign --apple-id` for the tvOS IPA. cider requests profiles through Apple's iOS developer endpoints; if the install fails with a provisioning-profile or platform error, use Sideloadly for the Apple TV (below).

## 7. Keep it working

A sideloaded app stops opening when its signature expires: **7 days** with a free Apple account, up to **1 year** with a paid developer account. Apps signed with `--refresh` can be renewed with:

```sh
cider refresh list
cider refresh run
```

Run it (by hand or from a scheduled job) before the signature runs out, with the device reachable. To reinstall instead, sign the same IPA again with the **same Apple account**, and don't delete the app first, or the person loses their subscriptions, favorites and history.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Device missing from `cider device list` | iPhone/iPad: replug, unlock, tap Trust. Apple TV: same network, then pair as in step 6.2. |
| `Too many certificates and failed to revoke any` | The account is at Apple's certificate limit and cider couldn't free one; revoke an unused development certificate at developer.apple.com → Certificates, then retry. |
| Apple TV install fails with a profile or platform error | Use Sideloadly on a Mac for the Apple TV (below). |
| Install seems stuck on Apple TV | It's copying ~11,000 files over Wi-Fi; give it 5–10 minutes. |
| "Wrong platform" or architecture error | Wrong IPA (iOS vs tvOS), or a simulator build. |
| App stopped opening after a week | Signature expired: `cider refresh run`, or sign and install again with the same account. |
| Installed, but a video won't play | Installing doesn't guarantee every subscription source works; try another source. |

## Other sideloading apps

If the person prefers a desktop app, or cider fails: [Impactor](https://github.com/claration/Impactor/releases) (macOS/Windows/Linux, iPhone, iPad and Apple TV; `brew install --cask impactor`; cider is built on its code), [iloader](https://iloader.app) (iPhone and iPad only; "Import IPA") or Sideloadly (below). Only link these official sources: iloader.site and plamimpactor.site are third-party sites the projects don't list.

## Fallback: Sideloadly

Steps are in [Docs/INSTALL.md](../../../Docs/INSTALL.md) (Apple TV needs Sideloadly on a Mac). One known failure: `Guru Meditation … GSA returned a non-plist response (HTTP 503)` with **"Will use Fake Local Anisette"** in its log means Sideloadly couldn't get real sign-in data from macOS (seen with 0.70.1 under Rosetta on macOS 27), not a network problem. Switch anisette to **On-device** or **Local** in Sideloadly settings (gear icon) and start again.

## For developers with a team-signed IPA

An IPA already signed by the team for a registered device doesn't need re-signing. `cider device install <signed.ipa> -u <UDID>` installs it as is. Faster: `ideviceinstaller -n -u <UDID> install <signed.ipa>` (`brew install ideviceinstaller`) sends the IPA as one file and lets the device unpack it, about 20 s instead of minutes. `xcrun devicectl device install app --device <UDID> <ipa>` also works. Build instructions are in [Docs/DEVELOPMENT.md](../../../Docs/DEVELOPMENT.md).
