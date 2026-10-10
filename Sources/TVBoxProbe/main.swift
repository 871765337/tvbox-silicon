import Foundation
import AVFoundation
import TVCore

@main struct Probe {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            print("Usage: TVBoxProbe <jar path> [class descriptor] [static int method]")
            print("       TVBoxProbe --subscription-check <URL> [...]")
            return
        }
        if args[1] == "--cast-upgrade", args.count >= 4, let cid = Int(args[2]) {
            // --cast-upgrade <cid> <title>: finds the video a DLNA cast belongs to.
            print("aid", await Bilibili.castVideo(cid: cid, title: args[3]).map(String.init) ?? "not found")
            return
        }
        if args[1] == "--bili-chat", args.count >= 3, let room = Int(args[2]) {
            // --bili-chat <room> [seconds]: prints a live room's comments as they arrive.
            setvbuf(stdout, nil, _IONBF, 0)
            let chat = BilibiliLiveChat(room: room)
            chat.start { text, color, position in print("danmaku \(String(format: "%06x", color)) \(position) \(text)") }
            try await Task.sleep(for: .seconds(args.count > 3 ? Double(args[3]) ?? 20 : 20))
            chat.stop()
            return
        }
        if args[1] == "--bili-rooms" {
            // --bili-rooms: the built-in Bilibili Live source's channels, by group, then plays the first.
            let channels = try await HTTPClient().channels(.bilibili)
            for group in Dictionary(grouping: channels, by: \.group).sorted(by: { $0.key < $1.key }) { print(group.key, group.value.count, group.value.first?.name ?? "") }
            if let first = channels.first { let live = try await BilibiliLive.resolve(first); print("resolved", live.channel.url.absoluteString.prefix(90), "qualities", live.qualities.map { "\($0.id) \($0.label)" }, "current", live.current ?? -1) }
            return
        }
        if args[1] == "--bili-live", args.count >= 3, let room = Int(args[2]) {
            // --bili-live <room>: a live room's stream through AVPlayer for a few seconds.
            setvbuf(stdout, nil, _IONBF, 0)
            let channel = try await Bilibili.liveChannel(room: room)
            print("live \(channel.name) \(channel.url.absoluteString.prefix(100))")
            let item = AVPlayerItem(asset: AVURLAsset(url: channel.url, options: ["AVURLAssetHTTPHeaderFieldsKey": channel.headers]))
            let player = AVPlayer(playerItem: item); player.isMuted = true; player.play()
            for second in 1...8 {
                try await Task.sleep(for: .seconds(1))
                print("t=\(second) status=\(item.status.rawValue) time=\(String(format: "%.1f", player.currentTime().seconds)) size=\(Int(item.presentationSize.width))x\(Int(item.presentationSize.height)) error=\(item.error.map { "\($0)" } ?? "-")")
            }
            return
        }
        if args[1] == "--cast-listen" {
            // --cast-listen [seconds]: runs the Bilibili cast receiver and prints what phones send.
            setvbuf(stdout, nil, _IONBF, 0)
            let receiver = BilibiliCastReceiver.shared
            receiver.name = "Yingxia Probe"
            receiver.onEvent = { event in print("event \(event)") }
            receiver.start()
            receiver.update(.init(playing: true, position: 12, duration: 300))
            print("listening")
            try await Task.sleep(for: .seconds(args.count > 2 ? Double(args[2]) ?? 60 : 60))
            return
        }
        if args[1] == "--bili-play", args.count >= 3 {
            // --bili-play <BV id | season_N> [part index] [seconds]: the built-in Bilibili source end to end,
            // through its script port, playback resolution and AVPlayer.
            setvbuf(stdout, nil, _IONBF, 0)
            let client = CatalogClient(site: .bilibili, origin: URL(string: "https://example.invalid/")!)
            let video = try await client.detail(args[2])
            let episode = video.episodes[min(args.count > 3 ? Int(args[3]) ?? 0 : 0, video.episodes.count - 1)]
            print("detail \(video.name) parts=\(video.episodes.count) playing=\(episode.name) \(episode.address)")
            let channel = try await client.playback(episode)
            print("channel \(channel.url.absoluteString.prefix(120))")
            let comments = await DanmakuSource.comments(for: channel.url) ?? []
            print("danmaku \(comments.count) first=\(comments.prefix(3).map { "\(String(format: "%.1f", $0.time)) \($0.text)" })")
            let asset = BilibiliStreams.asset(for: channel.url) ?? AVURLAsset(url: channel.url, options: ["AVURLAssetHTTPHeaderFieldsKey": channel.headers])
            if channel.url.scheme == BilibiliStreams.scheme {
                for variant in try await asset.load(.variants) {
                    let video = variant.videoAttributes
                    print("variant peak=\(Int(variant.peakBitRate ?? 0)) size=\(video.map { "\(Int($0.presentationSize.width))x\(Int($0.presentationSize.height))" } ?? "-") codecs=\(video?.codecTypes.map { String(format: "%08x", $0) } ?? [])")
                }
            }
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.play()
            for second in 1...(args.count > 4 ? Int(args[4]) ?? 12 : 12) {
                try await Task.sleep(for: .seconds(1))
                let log = item.accessLog()?.events.last
                print("t=\(second) status=\(item.status.rawValue) time=\(String(format: "%.1f", player.currentTime().seconds)) size=\(Int(item.presentationSize.width))x\(Int(item.presentationSize.height)) indicated=\(Int(log?.indicatedBitrate ?? 0)) error=\(item.error.map { "\($0)" } ?? item.errorLog()?.events.last?.errorComment ?? "-")")
                if item.status == .failed { break }
            }
            // Seek near the end: fragments far from the start must resolve too.
            let duration = try await asset.load(.duration).seconds
            if duration.isFinite, duration > 30 {
                await player.seek(to: CMTime(seconds: duration - 20, preferredTimescale: 600))
                try await Task.sleep(for: .seconds(4))
                print("after seek duration=\(Int(duration)) time=\(String(format: "%.1f", player.currentTime().seconds)) status=\(item.status.rawValue)")
            }
            return
        }
        if args[1] == "--subscription-check" {
            struct Result: Encodable, Sendable {
                let address: String
                var origin: String? = nil
                var sites: Int? = nil
                var lives: Int? = nil
                var error: String? = nil
            }
            var results: [Result] = []
            let addresses = Array(args.dropFirst(2))
            for start in stride(from: 0, to: addresses.count, by: 6) {
                await withTaskGroup(of: Result.self) { group in
                    for address in addresses[start..<min(start + 6, addresses.count)] {
                        group.addTask {
                            do {
                                let config = try await HTTPClient().subscription(WebAddress.resolve(address))
                                return Result(address: address, origin: config.origin.absoluteString, sites: config.sites.count, lives: config.lives.count)
                            } catch { return Result(address: address, error: error.localizedDescription) }
                        }
                    }
                    for await result in group { results.append(result) }
                }
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(results.sorted { $0.address < $1.address }), as: UTF8.self))
            return
        }
        if args[1] == "--catalog-check", args.count >= 3 {
            // Browses sources the way the app does (CatalogClient, so lite ports with their JAR
            // fallback): home, a category when home has no videos, detail, then playback.
            let config = try await HTTPClient().subscription(WebAddress.resolve(args[2]))
            let filters = Array(args.dropFirst(3))
            let sites = config.sites.filter { site in filters.isEmpty || filters.contains { site.name.contains($0) || site.key.contains($0) } }
            var passed = 0
            for site in sites {
                let client = CatalogClient(site: site, origin: config.origin, jarURL: config.spiderURL)
                var stage = "home"
                do {
                    let home = try await client.home()
                    var videos = home.videos
                    if videos.isEmpty, let category = home.categories.first {
                        stage = "category"
                        videos = try await client.list(category: category.id, query: "", page: 1).videos
                    }
                    guard let first = videos.first else { throw TVError.unsupported("no videos") }
                    stage = "detail"
                    let video = try await client.detail(first.id)
                    guard let episode = video.episodes.first else { throw TVError.unsupported("no episodes") }
                    stage = "play"
                    let plan = try await client.preparePlayback(episode)
                    passed += 1
                    print("OK   \(site.name)  [\(site.compatibility)]  \(home.categories.count) categories, play \(plan.choices[0].address.prefix(90))")
                } catch {
                    print("FAIL \(site.name)  [\(site.compatibility)]  [\(stage)] \(error.localizedDescription)")
                }
            }
            for entry in await Diagnostics.shared.snapshot().entries where entry.category == "lite.fallback" { print("     fallback: \(entry.message)") }
            print("\(passed)/\(sites.count) sources reached playback")
            return
        }
        if args[1] == "--home-check", args.count >= 3 {
            // Loads each source's home the way the app's source page does and reports what its
            // category bar would show.
            let config = try await HTTPClient().subscription(WebAddress.resolve(args[2]))
            let filters = Array(args.dropFirst(3))
            let sites = config.sites.filter { site in filters.isEmpty || filters.contains { site.name.contains($0) || site.key.contains($0) } }
            // One at a time: the plugin runtime turns away interactive calls beyond a short queue.
            for site in sites {
                let client = CatalogClient(site: site, origin: config.origin, jarURL: config.spiderURL)
                do {
                    let home = try await client.home()
                    print("\(home.categories.isEmpty ? "NONE" : "OK  ") \(site.key)  \(site.name)  [\(site.compatibility) \(site.preferredRuntime)]  categories=\(home.categories.count) videos=\(home.videos.count)")
                } catch {
                    print("FAIL \(site.key)  \(site.name)  [\(site.compatibility) \(site.preferredRuntime)]  \(error.localizedDescription)")
                }
            }
            for entry in await Diagnostics.shared.snapshot().entries where entry.category == "lite.fallback" { print("     fallback: \(entry.message)") }
            return
        }
        if args[1] == "--script-check", args.count >= 3 {
            // Runs a subscription's JavaScript sources on the in-process QuickJS runtime (as iOS and
            // tvOS do): home, a category when home has no videos, detail, then playback.
            let config = try await HTTPClient().subscription(WebAddress.resolve(args[2]))
            let filters = Array(args.dropFirst(3))
            let sites = config.sites.filter { site in site.preferredRuntime == .javascript && (filters.isEmpty || filters.contains { site.name.contains($0) || site.key.contains($0) }) }
            var passed = 0
            for site in sites {
                func call(_ params: [String: String]) async throws -> [String: JSONValue] {
                    // Lite ports run alone here, without the JAR fallback, so the check measures the ports.
                    try await ScriptRuntime.shared.request(site: site, scriptURL: site.liteScript ?? site.scriptURL(origin: config.origin), params: params, http: HTTPClient(), origin: config.origin)
                }
                var stage = "home"
                do {
                    let home = CatalogPage(json: try await call(site.type == 4 ? ["filter": "true"] : [:]), origin: config.origin)
                    var videos = home.videos
                    if videos.isEmpty, let category = home.categories.first {
                        stage = "category"
                        videos = CatalogPage(json: try await call(["pg": "1", "ac": "detail", "t": category.id]), origin: config.origin).videos
                    }
                    guard let first = videos.first else { throw TVError.unsupported("no videos") }
                    stage = "detail"
                    let detail = CatalogPage(json: try await call(["ac": "detail", "ids": first.id]), origin: config.origin).videos.first
                    guard let episode = detail?.episodes.first else { throw TVError.unsupported("no episodes") }
                    stage = "play"
                    let play = try await call(["play": episode.address, "flag": episode.flag])
                    let address = play["url"]?.string ?? play["url"]?.array.map { "\($0.count / 2) choices" } ?? "none"
                    passed += 1
                    print("OK   \(site.name.prefix(24))  \(home.categories.count) categories, \(videos.count) videos, play \(address.prefix(80))")
                } catch {
                    print("FAIL \(site.name.prefix(24))  [\(stage)] \(error.localizedDescription.prefix(160))")
                }
            }
            print("\(passed)/\(sites.count) JavaScript sources reached playback on QuickJS")
            return
        }
        if args[1] == "--subscription-export", args.count == 3 {
            do {
                let config = try await HTTPClient().subscription(WebAddress.resolve(args[2]))
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(config), as: UTF8.self))
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
            return
        }
        if args[1] == "--live-check" {
            let origin = URL(string: "https://raw.githubusercontent.com/qist/tvbox/master/fty.json")!
            let config = try await HTTPClient().subscription(origin)
            print("Subscription: \(config.sites.count) sites, \(config.lives.count) live lists")
            await withTaskGroup(of: String.self) { group in
                for source in config.lives {
                    group.addTask {
                        do {
                            let channels = try await HTTPClient().channels(source)
                            return "\(source.name): \(channels.count) parsed channels (playback not verified)"
                        } catch { return "\(source.name): \(error.localizedDescription)" }
                    }
                }
                for await result in group { print(result) }
            }
            return
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: args[1]))
        let runtime = JarRuntime()
        let report: JarReport
        if args.count >= 4 { report = await runtime.runStaticInt(data, className: args[2], method: args[3]) }
        else { report = await runtime.inspect(data) }
        let values: [String: Any] = ["status": report.status, "dexFiles": report.dexFiles, "classes": report.classes,
                                    "nativeLibraries": report.nativeLibraries, "instructions": report.instructions,
                                    "value": report.value, "message": report.message]
        let json = try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: json, as: UTF8.self))
        if report.status != 0 { exit(1) }
    }
}
