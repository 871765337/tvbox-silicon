import Foundation
import Testing
@testable import TVCore

struct DouyuStreamsTests {
    let origin = URL(string: "https://edge.example.com/openhls/live/100r_2000.m3u8?sid=1&sub_m3u8=true")!

    @Test func addressesRoundTripThroughTheLoaderScheme() {
        let url = URL(string: "https://openhls-hw.douyucdn2.cn/live/100r_2000.m3u8?txSecret=a&token=b")!
        let address = DouyuStreams.address(url)
        #expect(address.absoluteString == "tvbox-douyu://openhls-hw.douyucdn2.cn/live/100r_2000.m3u8?txSecret=a&token=b")
        #expect(DouyuStreams.upstream(address) == url)
        #expect(DouyuStreams.upstream(url) == nil)
        #expect(DouyuStreams.asset(for: url) == nil && DouyuStreams.asset(for: address) != nil)
    }

    @Test func masterSendsVariantsBackThroughTheLoader() {
        let master = "#EXTM3U\n#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=2560000\nhttps://edge.example.com/openhls/live/100r_2000.m3u8?sid=2&sub_m3u8=true\n"
        let lines = DouyuStreams.rewrite(master, origin: origin).components(separatedBy: "\n")
        #expect(lines.contains("tvbox-douyu://edge.example.com/openhls/live/100r_2000.m3u8?sid=2&sub_m3u8=true"))
    }

    /// A room's first playlist from a cold edge: the discontinuity before segment 0 comes and goes
    /// between reloads, which AVPlayer rejects (-12312), so it never reaches the player.
    @Test func dropsTheDiscontinuityBeforeTheStreamsFirstSegment() {
        let playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-TARGETDURATION:2
        #EXT-X-DISCONTINUITY
        #EXTINF:1.966,
        100r_2000_hw_0.ts?vhost=a&edge_slice=true
        #EXTINF:2.000,
        100r_2000_hw_1.ts?vhost=a&edge_slice=true
        """
        let lines = DouyuStreams.rewrite(playlist, origin: origin).components(separatedBy: "\n")
        #expect(!lines.contains("#EXT-X-DISCONTINUITY"))
        // Segments load from the CDN directly, not through the loader.
        #expect(lines.contains("https://edge.example.com/openhls/live/100r_2000_hw_0.ts?vhost=a&edge_slice=true"))
        #expect(lines.filter { $0.hasPrefix("#EXTINF") }.count == 2)
    }

    @Test func keepsRealDiscontinuities() {
        // Later in the stream, or between segments, a discontinuity means something.
        let later = "#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:7\n#EXT-X-DISCONTINUITY\n#EXTINF:2.0,\na_7.ts\n"
        #expect(DouyuStreams.rewrite(later, origin: origin).contains("#EXT-X-DISCONTINUITY"))
        let between = "#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:2.0,\na_0.ts\n#EXT-X-DISCONTINUITY\n#EXTINF:2.0,\na_1.ts\n"
        #expect(DouyuStreams.rewrite(between, origin: origin).contains("#EXT-X-DISCONTINUITY"))
    }

    @Test func resolvesAttributeAddresses() {
        let playlist = "#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:3\n#EXT-X-KEY:METHOD=AES-128,URI=\"key.bin?k=1\"\n#EXTINF:2.0,\na_3.ts\n"
        #expect(DouyuStreams.rewrite(playlist, origin: origin).contains("URI=\"https://edge.example.com/openhls/live/key.bin?k=1\""))
    }
}
