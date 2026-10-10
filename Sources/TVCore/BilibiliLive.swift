import Foundation

/// Bilibili Live as a built-in live source: the busiest rooms of each area (and, signed in, the rooms
/// the account follows) as channels. A room's stream address expires, so channels carry
/// `bilibili-live://room/<id>` and the player resolves it when it starts.
public enum BilibiliLive {
    public static let scheme = "bilibili-live"
    /// Parent areas in the order Bilibili's live home lists them.
    static let areas: [(Int, String)] = [(1, "娱乐"), (2, "网游"), (3, "手游"), (6, "单机游戏"), (9, "虚拟主播"), (10, "生活"), (11, "知识"), (13, "赛事"), (5, "电台")]

    public static func room(_ url: URL) -> Int? {
        guard url.scheme == scheme, url.host() == "room" else { return nil }
        return Int(url.lastPathComponent)
    }

    /// The playable channel for a room channel (at the `qn` its address asks for, else the original),
    /// with the room's qualities and the one served; any other channel is returned unchanged.
    public static func resolve(_ channel: Channel) async throws -> (channel: Channel, qualities: [StreamQuality], current: Int?) {
        guard let room = room(channel.url) else { return (channel, [], nil) }
        let asked = URLComponents(url: channel.url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "qn" }?.value.flatMap(Int.init)
        let live = try await Bilibili.liveStream(room: room, quality: asked ?? 10000)
        let name = channel.name.isEmpty ? live.channel.name : channel.name
        return (Channel(name: name, group: channel.group, url: live.channel.url, logo: channel.logo, headers: live.channel.headers), live.qualities, live.current)
    }

    /// A live room as the room lists show it.
    public struct Room: Identifiable, Hashable, Sendable {
        public let id: Int
        public let title: String
        public let host: String
        public let cover: URL?
        /// Viewers, as Bilibili counts them.
        public let online: Int
        public let area: String
        /// The room as a playable channel; its stream is resolved when it plays.
        public var channel: Channel {
            Channel(name: [host, title].filter { !$0.isEmpty }.joined(separator: " · "), group: area,
                    url: URL(string: "\(BilibiliLive.scheme)://room/\(id)")!, logo: cover, headers: [:])
        }
    }

    static func channels() async throws -> [Channel] { try await rooms().map(\.channel) }

    /// Followed rooms that are live first (area 关注), then each area's busiest rooms.
    public static func rooms() async throws -> [Room] {
        let signer = BilibiliSigner.shared
        let account = BilibiliAccount.load()
        let cookie = await signer.cookie(account: account.cookie)
        let groups = await withTaskGroup(of: (Int, [Room]).self) { group in
            if account.signedIn {
                group.addTask { (-1, (try? await following(cookie: cookie)) ?? []) }
            }
            for (index, area) in areas.enumerated() {
                group.addTask {
                    let url = URL(string: "https://api.live.bilibili.com/room/v1/area/getRoomList?parent_area_id=\(area.0)&page=1&page_size=40&sort_type=online")!
                    let rooms = (try? await signer.json(url, cookie: cookie))?["data"]?.array?.compactMap(\.object) ?? []
                    return (index, rooms.compactMap { room($0, area: area.1) })
                }
            }
            return await group.reduce(into: [(Int, [Room])]()) { $0.append($1) }
        }
        // A room can top two lists (its area and the followed rooms); keep its first place.
        var seen = Set<Int>()
        let rooms = groups.sorted { $0.0 < $1.0 }.flatMap(\.1).filter { seen.insert($0.id).inserted }
        guard !rooms.isEmpty else { throw TVError.unsupported(L10n.text("Bilibili Live could not be reached. Try again later.")) }
        return rooms
    }

    private static func following(cookie: String) async throws -> [Room] {
        let url = URL(string: "https://api.live.bilibili.com/xlive/web-ucenter/user/following?page=1&page_size=29&ignoreRecord=1&hit_ab=true")!
        let rooms = try await BilibiliSigner.shared.json(url, cookie: cookie)["data"]?.object?["list"]?.array?.compactMap(\.object) ?? []
        return rooms.filter { $0["live_status"]?.int == 1 }.compactMap { room($0, area: L10n.text("Following")) }
    }

    private static func room(_ room: [String: JSONValue], area: String) -> Room? {
        guard let id = (room["roomid"] ?? room["room_id"])?.int, id > 0 else { return nil }
        let cover = [room["user_cover"], room["room_cover"], room["cover"], room["system_cover"], room["keyframe"], room["face"]]
            .compactMap { $0?.string }.first { !$0.isEmpty }
        let url = cover.flatMap { URL(string: $0.hasPrefix("//") ? "https:" + $0 : $0.replacingOccurrences(of: "http://", with: "https://")) }
        return Room(id: id, title: room["title"]?.string ?? "", host: room["uname"]?.string ?? "", cover: url,
                    online: room["online"]?.int ?? room["watched_show"]?.object?["num"]?.int ?? 0, area: area)
    }
}

extension LiveSource {
    /// Offered with every subscription, after the subscription's own live playlists.
    public static let bilibili = LiveSource(name: L10n.text("Bilibili Live"), url: URL(string: "\(BilibiliLive.scheme)://rooms")!)
    public var isBuiltIn: Bool { url.scheme == BilibiliLive.scheme }
}
