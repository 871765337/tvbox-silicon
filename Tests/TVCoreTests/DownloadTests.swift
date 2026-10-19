import Foundation
import Testing
@testable import TVCore

@Test func hlsPlaylistsAreRewrittenToLocalParts() throws {
    let text = """
    #EXTM3U
    #EXT-X-VERSION:6
    #EXT-X-TARGETDURATION:6
    #EXT-X-KEY:METHOD=AES-128,URI="https://keys.example.com/k1",IV=0x01
    #EXT-X-MAP:URI="init.mp4",BYTERANGE="720@0"
    #EXTINF:6.0,
    #EXT-X-BYTERANGE:1000@720
    media.mp4
    #EXTINF:6.0,
    #EXT-X-BYTERANGE:500
    media.mp4
    #EXT-X-KEY:METHOD=AES-128,URI="https://keys.example.com/k1",IV=0x02
    #EXTINF:4.0,
    https://cdn.example.com/seg/3.png?token=a
    #EXT-X-ENDLIST
    """
    let local = try HLS.localize(text, base: URL(string: "https://example.com/v/index.m3u8")!)
    #expect(local.parts.map(\.name) == ["parts/key-0.key", "parts/init-1.mp4", "parts/00000.mp4", "parts/00001.mp4", "parts/00002.ts"])
    #expect(local.parts[1].range == 0...719)
    #expect(local.parts[2].range == 720...1719)
    // A byte range without an offset continues where the previous one of the same file ended.
    #expect(local.parts[3].range == 1720...2219)
    #expect(local.parts[2].url.absoluteString == "https://example.com/v/media.mp4")
    #expect(local.parts.map(\.transportStream) == [false, false, false, false, true])
    #expect(local.playlist.contains("#EXT-X-KEY:METHOD=AES-128,URI=\"parts/key-0.key\",IV=0x02"))
    #expect(local.playlist.contains("#EXT-X-MAP:URI=\"parts/init-1.mp4\"\n"))
    #expect(!local.playlist.contains("BYTERANGE"))
    #expect(local.playlist.hasSuffix("parts/00002.ts\n#EXT-X-ENDLIST\n"))
}

@Test func liveAndProtectedPlaylistsAreRefused() {
    let base = URL(string: "https://example.com/live.m3u8")!
    #expect(throws: TransferError.live) { try HLS.localize("#EXTM3U\n#EXTINF:6,\na.ts\n", base: base) }
    #expect(throws: TransferError.protected) {
        try HLS.localize("#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI=\"skd://key\"\n#EXTINF:6,\na.ts\n#EXT-X-ENDLIST\n", base: base)
    }
}

@Test func theBestVariantIsChosenByBandwidth() {
    let text = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360\nlow/index.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS=\"avc1.640028,mp4a.40.2\"\nhigh/index.m3u8\n"
    let variants = HLS.variants(text, base: URL(string: "https://example.com/master.m3u8")!)
    let best = variants.max { $0.bandwidth < $1.bandwidth }
    #expect(variants.count == 2)
    #expect(best?.url.absoluteString == "https://example.com/high/index.m3u8")
    #expect(best?.height == 1080)
}

@Test func rangedFilesSplitIntoChunks() {
    let file = TransferPlan.RemoteFile(urls: [], name: "media.part", length: Transfer.chunk * 2 + 10, ranged: true, done: [0, 2])
    #expect(file.chunks == 3)
    #expect(file.range(2) == Transfer.chunk * 2...Transfer.chunk * 2 + 9)
    #expect(file.saved == Transfer.chunk + 10)
}

@Test func theLocalServerAnswersRangesInsideItsFolderOnly() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "downloads-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root.appending(path: "item/parts"), withIntermediateDirectories: true)
    try Data("0123456789".utf8).write(to: root.appending(path: "item/parts/00000.ts"))
    defer { try? FileManager.default.removeItem(at: root) }
    let url = try await LocalMediaServer.shared.address(of: root.appending(path: "item/parts/00000.ts"), root: root)
    var request = URLRequest(url: url)
    request.setValue("bytes=2-5", forHTTPHeaderField: "Range")
    let (data, response) = try await URLSession.shared.data(for: request)
    #expect((response as? HTTPURLResponse)?.statusCode == 206)
    #expect(String(decoding: data, as: UTF8.self) == "2345")
    #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") == "video/mp2t")
    let outside = url.deletingLastPathComponent().appending(path: "../../../etc/hosts")
    let (_, refused) = try await URLSession.shared.data(from: outside)
    #expect((refused as? HTTPURLResponse)?.statusCode == 404)
}

@Test func songFilesAreNamedByTheirFirstBytes() {
    let bare = URL(string: "https://music.example.com/stream?id=1")!
    #expect(Transfer.fileExtension(bare, mime: "application/octet-stream", head: Data("fLaC\0\0\0\"".utf8)) == "flac")
    #expect(Transfer.fileExtension(bare, mime: "", head: Data("ID3\u{4}\0\0\0\0\0\0\0\0".utf8)) == "mp3")
    #expect(Transfer.fileExtension(bare, mime: "", head: Data([0xFF, 0xFB, 0x90, 0x64])) == "mp3")
    #expect(Transfer.fileExtension(bare, mime: "", head: Data([0xFF, 0xF1, 0x50, 0x80])) == "aac")
    #expect(Transfer.fileExtension(bare, mime: "audio/x-flac") == "flac")
    // Video detection is unchanged.
    #expect(Transfer.fileExtension(bare, mime: "", head: Data([0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D])) == "mp4")
}

@Test func savedLyricsReadBackTheSame() throws {
    let lyrics = try #require(MusicLyrics.parse("[00:01.00]故事的小黄花\n[00:05.50]从出生那年就飘着", platform: .qq))
    let decoded = try JSONDecoder().decode(MusicLyrics.self, from: JSONEncoder().encode(lyrics))
    #expect(decoded == lyrics)
    #expect(decoded.index(at: 6) == 1)
}

@MainActor @Test func musicDownloadsKeepTheirAlbumsAndPlaylistsAndPauseTogether() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "music-downloads-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let songs = (1...3).map { MusicTrack(platform: .qq, songID: "s\($0)", title: "Song \($0)", artists: ["A"]) }
    let album = MusicCollection(kind: .album, platform: .qq, collectionID: "a1", title: "Album")
    let playlist = MusicCollection(kind: .playlist, platform: .qq, collectionID: "p1", title: "Mix")
    let library = MusicDownloadLibrary(root: root)
    library.download(Array(songs.prefix(2)), from: album)
    library.download([songs[2], songs[0]], from: playlist)
    // Most recent first, each in its own order; a song in both is saved once.
    #expect(library.collections.map(\.id) == [playlist.id, album.id])
    #expect(library.items(in: try #require(library.collection(id: playlist.id))).map(\.id) == [songs[2].id, songs[0].id])
    #expect(library.items.count == 3)

    library.pauseAll()
    #expect(library.items.allSatisfy { $0.status == .paused })
    #expect(library.isPaused)
    // Still paused, and still grouped, when the app opens again.
    let reopened = MusicDownloadLibrary(root: root)
    #expect(reopened.items.allSatisfy { $0.status == .paused })
    #expect(reopened.collections.map(\.id) == [playlist.id, album.id])

    // Removing the album keeps the song the playlist shares.
    library.remove(collection: album.id)
    #expect(Set(library.items.map(\.id)) == [songs[0].id, songs[2].id])
    #expect(library.collections.map(\.id) == [playlist.id])
    library.resumeAll()
    #expect(!library.isPaused)
    library.remove(library.items.map(\.id))
    #expect(library.collections.isEmpty)
}
