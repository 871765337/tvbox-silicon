# Plan: install Yingxia on Apple TV from Windows and Linux

Status: proposed, not started · Updated: October 11, 2026

## Objective

Let someone with only a **Windows or Linux computer** install, update and refresh the
tvOS app on a portless Apple TV 4K over the local network, with a **free Apple account**.
Today `Docs/INSTALL.md`, the `install-yingxia` skill and the website all say Apple TV needs
a Mac. The Mac flow stays as it is; this plan adds the other two.

**Done means:** on our test TV (tvOS 27), from a Windows 11 PC with no Mac involved, a
person can discover the TV, pair it with the PIN, sign the release tvOS IPA with a free
Apple ID, install it in under 2 minutes, open it, and refresh it 7 days later without
pairing again. The same works from Debian Linux.

No single tool is proven to do all of that yet. So the plan runs several independent
tracks against one test bench and ships the first one that passes every gate. The other
tracks become fallbacks. Each track has its own pass criteria so a failure in one never
blocks the others.

## Verified facts this plan rests on

Research done October 11, 2026. Sources are listed at the end.

- **Why Windows and Linux fail today.** Since tvOS 26.4 (March 2026), a new host can pair
  with Apple TV only through Apple's **RemotePairing** protocol. On the
  **Settings → Remotes and Devices → Remote App and Devices** screen, the TV advertises
  `_remotepairing-manual-pairing._tcp`. The host proves the PIN shown on the TV with
  SRP-6a (3072-bit, SHA-512); tvOS shows no Trust prompt. The older lockdown path
  (`_apple-pairable._tcp`, `idevicepair -w`) was removed in 26.4. Yingxia needs tvOS 26 or
  later, so RemotePairing is the only path that matters.
- Apple Mobile Device Service on Windows and `usbmuxd` on Linux only speak lockdown and
  usbmux, so neither implements RemotePairing. cider lists devices only through usbmuxd
  (`crates/plume_utils/src/device.rs`), so it can't see a TV that was never paired over USB.
- **After pairing, installing is reachable.** The host opens a TCP tunnel to
  `_remotepairing._tcp`, secured with TLS 1.2 PSK keyed by the pairing secret, and carrying
  IPv6. Inside it, RSD lists `com.apple.mobile.installation_proxy.shim.remote` and
  `com.apple.afc.shim.remote`. These speak the classic service protocols. A userspace TCP
  stack is enough, so the tunnel needs no TUN driver (Wintun) and no admin rights.
- **Signing does not need a Mac, but cider can't sign for tvOS.** For a free account, the
  `addDevice` and `downloadTeamProvisioningProfile` requests must carry
  `DTDK_Platform=tvos` and `subPlatform=tvOS`. cider and upstream Impactor send iOS
  parameters only, which fails with error 8220 ("no devices") or `0xe8008015`. The device
  must also be registered by its real UDID, not the MAC-address-style entry; that fails
  with error 35.
- **Code that already does the work:**

  | Code | Pairs ATV | Signs for tvOS | Installs | Evidence |
  | --- | --- | --- | --- | --- |
  | `idevice` Rust crate (jkcoxson) | yes (`pair_apple_tv` example) | no | yes, over RSD | library behind the rows below |
  | `plumesign`, from bitxeno's PlumeImpactor fork | yes (`pair --ip --port`) | yes (commit 0eca9ba) | yes, over RSD | used by atvloadly v0.6.3; many Linux users on tvOS 26.x |
  | atvloadly v0.6.3 (Docker, Linux) | yes | yes | yes, plus auto-refresh | verified on Linux; open tvOS 27 issue #121 ("never registered") |
  | Impactor PR #226 (closed unmerged 2026-08-10) | yes, with Windows `dnsapi.dll` discovery | yes | yes | one report: author, Windows, tvOS 26.5, 444-file app in 8 s |
  | pymobiledevice3 v11.27.1 | yes (`remote pair`) | no | documented only | pairing verified on Linux (tvOS 17.5); no Apple TV install reported |
  | sideloadATV (Android app) | yes | yes | yes | its author reports it working on a real Apple TV |

- **Yingxia's size makes upload strategy matter.** The tvOS bundle has 11,228 files. cider
  uploads them one at a time and took 7½ minutes. `ideviceinstaller -n` sends the IPA as
  one file and lets the device unpack it, which took about 20 seconds. sideloadATV had to
  raise its TCP retransmit limit to survive "multi-second Apple TV stalls" on 100 MB+ IPAs.

## Tracks

Ranked by how likely each is to become the shipped Windows method.

| Track | What | Why it might win | Main unknowns |
| --- | --- | --- | --- |
| **A** | Build `plumesign` natively for Windows and Linux | Already has all three parts (RemotePairing, tvOS signing, RSD install) and is proven inside atvloadly; Rust and `idevice` run on Windows (PR #226 proves it) | Does it compile for `x86_64-pc-windows-msvc`; Windows discovery (it takes `--ip/--port`); per-file vs single-file upload |
| **B** | Build the Impactor PR #226 branch | The only Windows success on record; has GUI and Windows mDNS discovery | Abandoned upstream; not tested on tvOS 27; speed with 11k files |
| **C** | pymobiledevice3: pair, tunnel, install a pre-signed IPA | pip-installable, actively maintained, best docs; good diagnostic tool even if not shipped | No signer; `apps install --tunnel` unconfirmed for Apple TV; Windows mDNS and admin |
| **D** | atvloadly: native on Linux; on Windows through WSL2 or a bridged Linux VM; or on an always-on Linux box (Raspberry Pi, NAS, OpenWrt router) | Maintained upstream, refreshes on its own, many Linux users | tvOS 27 issue #121; multicast into WSL2/VM; heavy setup for end users |
| **E** | Our own small CLI (`yingxia-atv`) on `idevice` + the `plumesign` signing code | We control discovery, single-file upload, refresh and messages; one binary for Windows/Linux/macOS | Engineering and maintenance cost |
| **F** | Upstream: add tvOS parameters and RemotePairing to cider and/or Impactor (issue #155) | Keeps one tool for every device long term | Depends on maintainers |
| **G** | No-PC routes: sideloadATV on Android; the Mac flow | Covers people with no suitable computer | Out of our control; Android only |

## Phase 0 — Test bench and baselines

1. **Hardware.** The test Apple TV 4K (tvOS 27). A second TV still on tvOS 26.x if
   available, since tvOS 27 regressions are the biggest known risk. A Windows 11 x86-64 PC
   and a Debian Linux machine, both on the same LAN and subnet as the TV, and tested over
   both Wi-Fi and Ethernet. The Mac, for baselines.
2. **Accounts.** A **throwaway free Apple ID**, never the paid team: cider and
   Impactor-derived tools revoke a development certificate when an account is at its
   limit, and the paid team's certificate signs releases. Budget around free-account
   limits (10 App IDs per 7 days, 3 sideloaded apps per device): reuse one bundle ID per
   tool and delete test installs.
3. **Test IPAs.**
   - `hello-tvos.ipa`: a tiny app with few files, so protocol failures are not confused
     with size failures.
   - `Yingxia-<ver>-tvos.ipa`: the unsigned release.
   - `Yingxia-<ver>-tvos-signed.ipa`: team-signed for the test TV, for tracks without a
     signer (C).
4. **Baselines on the Mac.** cider install time (7½ min) and `ideviceinstaller -n` time
   (about 20 s) for the current build.
5. **Results log.** Keep `Docs/apple-tv-install-results.md` with one row per run: track,
   tool version or commit, host OS, tvOS version, account type, step, pass or fail, time,
   exact error text.

**Gate:** both test IPAs install from the Mac. With the TV on the Remote App and Devices
screen, the Linux host lists it with `avahi-browse -rt _remotepairing-manual-pairing._tcp`,
and the Windows host lists it with `pymobiledevice3 bonjour remotepairing-manual-pairing`
(or `dns-sd -B _remotepairing-manual-pairing._tcp` if Bonjour is installed). If Windows
can't see it, fix discovery first (firewall, VPN, guest-network client isolation, the
Dnscache service holding UDP 5353) because every track depends on it.

## Phase 1 — Prove the protocol on Linux (cheapest, best documented)

1. **pymobiledevice3 (track C).** Use v11.27.1 or later on Python 3.13 or later (older
   Pythons fail the TLS-PSK step with `NO_CIPHERS_AVAILABLE`, and versions before 11.26.1
   end a good pairing with a traceback).
   ```sh
   pymobiledevice3 bonjour remotepairing-manual-pairing
   pymobiledevice3 remote pair                      # type the PIN shown on the TV
   sudo pymobiledevice3 remote tunneld --wifi --no-usb --no-usbmux --no-mobdev2
   pymobiledevice3 apps list --tunnel ''             # confirm the flag; else use --rsd <host> <port>
   pymobiledevice3 apps install hello-tvos.ipa --tunnel ''
   ```
   Then try the userspace tunnel option without `sudo`. Install the team-signed Yingxia IPA
   and time it. Capture whether it uploads the IPA as one file or unpacks it on the host.
2. **atvloadly (track D).** Run v0.6.3 in Docker with host networking and
   `avahi-daemon`. Pair, sign with the throwaway Apple ID, and install `hello-tvos.ipa`,
   then Yingxia. Time it, and record whether tvOS 27 shows issue #121.
3. **plumesign on Linux (track A).** Build it from the bitxeno fork at the commit
   atvloadly v0.6.3 uses. Run pair → sign → install by hand with the IP and port from
   step 1. This is the reference run for the Windows port.

**Gate:** at least one of these installs Yingxia on tvOS 27 and it opens. If all fail only
on tvOS 27, retest on tvOS 26.x. If 26.x passes, the problem is a tvOS 27 regression: find
or file it in `idevice`/atvloadly (track F) and continue on 26.x in parallel.

## Phase 2 — Windows tracks (run in parallel)

**2A. plumesign on Windows.**
- `cargo build --release --target x86_64-pc-windows-msvc` for the `plumesign` binary.
- Expect to fix Unix-only paths, Avahi/D-Bus code, and OpenSSL linking (use a vendored
  build).
- Discovery: take the IP and port from the Phase 0 tool at first. Later, add native
  browsing with `DnsServiceBrowse` from `dnsapi.dll` (the approach PR #226 used, because
  Dnscache owns multicast DNS on Windows) or the `mdns-sd` crate.
- Pair, sign with the free account, install. Test in a normal (non-admin) PowerShell.

**2B. Impactor PR #226.**
- Fetch `pull/226/head` from `claration/impactor` and build per its README on Windows.
- Pair, sign with the free account, and install `hello-tvos.ipa`, then Yingxia, on tvOS 27.
- Read its install code to see whether it uploads per file or sends one IPA.
- Check the licence before planning to redistribute a build.

**2C. pymobiledevice3 on Windows 11.**
- Install Python 3.13 and `pip install pymobiledevice3`.
- Repeat the Phase 1 track C steps, first in a normal PowerShell, then an admin one.
- Record Wintun prompts, firewall dialogs and any port 5353 conflicts.
- Use the signed IPA from 2A, 2B or the Mac.

**2D. atvloadly from Windows.**
- First try WSL2 with `networkingMode=mirrored` in `.wslconfig`, Docker Engine inside the
  distro (not Docker Desktop), and `avahi-daemon` plus D-Bus running there. The test is
  whether multicast mDNS from the TV reaches the distro.
- If it doesn't, use a Hyper-V VM with an external (bridged) virtual switch running Debian
  and atvloadly.
- Also try an always-on Linux box (Raspberry Pi or NAS) on the LAN. That is a valid answer
  for Windows households, and it refreshes the app on its own.

**Pass criteria for every Windows track.**

| Check | Required |
| --- | --- |
| Discovers and pairs the TV on tvOS 27 with the PIN | must |
| Signs with a free Apple ID; Yingxia opens | must |
| Install time for Yingxia | must < 10 min; target < 2 min |
| Second install keeps data (same bundle ID as before) | must |
| Works after TV reboot and overnight sleep without re-pairing | must |
| Works without admin rights or extra drivers | should |
| Steps a non-technical person must follow | fewer is better |

## Phase 3 — Choose

Fill a decision matrix from the results log using the pass criteria plus maintenance
burden and licence. Then:

1. **2A passes** → ship the `plumesign`-based path. Wrap it in track E if discovery,
   upload or messages need work. One binary then covers Windows and Linux, and macOS
   users can use it without Xcode pairing.
2. **Otherwise, 2B passes** → fork PR #226 into our organisation, pin it, and ship it as
   the Windows method.
3. **Otherwise, 2D passes** → document atvloadly via WSL2, a VM or an always-on Linux box
   as the Windows method; it's heavier but maintained upstream.
4. **Only 2C passes** → document it for developers installing their own team-signed
   builds. End users stay on Mac or Linux.
5. **Nothing passes on Windows** → keep "Apple TV needs a Mac or Linux". Publish atvloadly
   as the Linux method, mention sideloadATV (track G), and push track F.

Linux ships whichever passes there first. Prefer the same tool as Windows so there is
only one set of instructions.

## Phase 4 — Install speed (single-file upload)

If the chosen tool takes more than 2 minutes for Yingxia, there are two fixes, which can
be combined:

1. **Send one file, as `ideviceinstaller -n` does.** In our fork or track E, upload the
   signed `.ipa` to AFC `PublicStaging/` as a single file, then call installation_proxy
   `Install` with that path so tvOS unpacks it. Verify that the `*.shim.remote` services
   accept this on tvOS 27. Raise the userspace TCP retransmit limit so long Wi-Fi stalls
   don't abort the transfer (as sideloadATV did).
2. **Ship fewer files.** Pack the bundled Java runtime's ~11,000 files into one archive
   and read it at runtime. This speeds up every install path, including cider on the
   Mac. It's a larger app change; scope it separately, and coordinate with
   `runtime-extraction-plan.md`.

## Phase 5 — Refresh and updates

A free-account signature lasts 7 days.

- **atvloadly** refreshes on its own.
- **Tracks A, B and E:**
  - Re-sign and reinstall must reuse the same bundle-ID suffix, so the person keeps their
    data. Ideally it also matches cider's `<original ID>.<team ID>`, so people who
    installed from a Mac don't get a second, empty copy.
  - Add a `refresh` command, and schedule it daily: Task Scheduler (`schtasks`) on
    Windows, cron or a systemd timer on Linux.
- **Test:**
  - Refresh with the TV asleep.
  - Refresh after a TV reboot.
  - Refresh after a tvOS update. Expect the tvOS update to need a new pairing, and say so
    in the docs.

## Phase 6 — Ship docs, skill and website

- **`Docs/INSTALL.md`:**
  - Change the "What you need" line.
  - Split "Install on Apple TV" into Mac, Windows and Linux, and mark the new ones
    *experimental* until about five outside users report success.
  - Add the new tools to the "Other tools" table.
  - Add troubleshooting rows for: error 8220 or `0xe8008015` (profile for the wrong
    platform), error 35 (MAC-style UDID), the PIN back-off and "pair-setup disabled after
    too many attempts" lockout, `NO_CIPHERS_AVAILABLE` (Python older than 3.13), "TV not
    found" (Remote App and Devices screen open, same subnet, no VPN, firewall), and "pair
    again after a tvOS update".
- **`.agents/skills/install-yingxia/SKILL.md`:**
  - In the device table, change Apple TV from "no" to the chosen method on Windows and
    Linux.
  - Replace the "driver can't pair" reason with the RemotePairing explanation.
  - Split step 6 by OS.
  - Say cider can't sign tvOS outside the Mac.
  - Describe refresh for each tool, and update the install-time figure.
- **Website:**
  - In `website/src/components/Install.tsx`, change the Apple TV mode and the
    "cider pairs only over USB" note.
  - Update the matching strings in `website/src/i18n/strings.ts`, in every language.
- **Binaries:** if we ship our own build (tracks A, B or E), publish it next to the IPAs
  under `download.getmegaportal.com/yingxia/tools/<version>/`. Sign the Windows `.exe` if
  possible, to avoid SmartScreen warnings. Record versions in `THIRD_PARTY_NOTICES.md`.

## Risks

| Risk | Mitigation |
| --- | --- |
| A tvOS update breaks third-party RemotePairing (26.4 precedent; atvloadly #121 on 27) | Keep the Mac path documented; pin tool versions; retest on each tvOS beta; keep a 26.x TV if possible |
| Certificate revocation hits the paid team | Throwaway free Apple ID only; never sign test runs with the release team |
| Free-account limits stall testing | Reuse bundle IDs; plan runs around 10 App IDs per 7 days and 3 apps per device |
| PIN lockout after wrong attempts | One person enters the PIN; stop after one failure and read the error |
| Windows mDNS blocked | Phase 0 discovery gate; troubleshooting row; allow manual `--ip/--port` entry |
| Upstream code is abandoned (PR #226) or changes (bitxeno fork) | Pin commits; prefer tracks we can maintain (A/E) |
| Slow or failing transfer of 11k files over Wi-Fi | Phase 4 single-file upload; Ethernet on the TV |
| Second, empty copy of the app after switching tools | Match cider's bundle-ID suffix; document how to remove the old copy |

## Open questions

- Does `pymobiledevice3 apps install` accept `--tunnel` or `--rsd` for Apple TV?
- Does tvOS installd accept a single-file IPA through `installation_proxy.shim.remote`?
- Does multicast mDNS reach WSL2 in mirrored mode?
- Does a RemotePairing record survive TV reboot, sleep and tvOS updates?
- Which bundle-ID suffix does each tool use?
- Has anyone installed Yingxia from Windows or Linux with a *free* account on tvOS 26 or
  27? No public report does yet.

## Sources

- pymobiledevice3 tunnel and Apple TV docs: https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/ios17-tunnels.md,
  https://github.com/doronz88/pymobiledevice3/blob/master/misc/RemoteXPC.md, issues #1026, #1234, PR #2009
- idevice crate: https://github.com/jkcoxson/idevice (`remote_pairing/`, `tls_psk.rs`)
- bitxeno PlumeImpactor fork (`plumesign`): https://github.com/bitxeno/PlumeImpactor
- atvloadly: https://github.com/bitxeno/atvloadly (issues #86, #96, #121, #202; PR #98)
- Impactor: https://github.com/claration/impactor (issue #155, #227; PRs #217, #226, #241)
- cider: https://github.com/Battzz/cider-cli (`crates/plume_utils/src/device.rs`)
- AltSign tvOS parameters: https://github.com/rileytestut/AltSign/blob/marketplace/AltSign/Apple%20API/ALTAppleAPI.m
- sideloadATV: https://github.com/thangaraj26/sideloadATV
- Sideloadly FAQ (portless Apple TV is macOS-only): https://sideloadly.io/faq
- go-ios issue #586 (no Apple TV network support): https://github.com/danielpaulus/go-ios/issues/586
- Apple Developer Forums 841129 (Apple TV pairing on tvOS 26.4–26.6)
