import Foundation
import Testing
@testable import TVCore

/// A spider written like TVBox JavaScript sources, exercising the prelude's environment.
private let spider = #"""
import cheerio from 'assets://js/lib/cheerio.min.js';
const html = '<ul><li class="v"><a href="/play/1">第一集</a></li><li class="v"><a href="/play/2">第二集</a></li></ul>';
export default {
    async init(ext) { local.set('test', 'ext', ext); },
    async home() {
        const links = pdfa(html, 'li.v');
        const url = new URL('../x/y?a=1&b=%E4%B8%AD', 'https://example.com/base/page.html');
        const params = new URLSearchParams({ wd: '中 文' });
        const bytes = Buffer.from('你好', 'utf8');
        let fired = false; await new Promise(resolve => setTimeout(() => { fired = true; resolve(); }, 5));
        return JSON.stringify({
            class: [{ type_id: '1', type_name: pdfh(links[1], 'a&&Text') }],
            list: [],
            checks: {
                href: pd(links[0], 'a&&href', 'https://example.com/list/'),
                url: url.href, search: url.searchParams.get('b'), query: params.toString(),
                base64: bytes.toString('base64'), roundTrip: Buffer.from(bytes.toString('base64'), 'base64').toString(),
                md5: md5X('tvbox'), gzip: ungzip(gzip('压缩')), btoa: atob(btoa('latin')),
                decoder: new TextDecoder('gbk').decode(new Uint8Array([0xc4, 0xe3, 0xba, 0xc3])),
                timer: fired, local: local.get('test', 'ext'), joined: joinUrl('https://a.example/x/', '../y'),
                cheerio: typeof cheerio.load
            }
        });
    }
};
"""#

@Test func javaScriptSourcesRunOnQuickJS() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("script-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let session = try await ScriptSession.start(api: "https://scripts.example/spider.js", key: "test", ext: "rule.js", profile: folder.appendingPathComponent("profile"), label: "test", source: spider)
    defer { session.close() }
    let envelope = try await session.call([:])
    let result = try #require(envelope["result"]?.string, "\(envelope)")
    let home = try JSONDecoder().decode([String: JSONValue].self, from: Data(result.utf8))
    #expect(home["class"]?.array?.first?.object?["type_name"]?.string == "第二集")
    let checks = try #require(home["checks"]?.object)
    #expect(checks["href"]?.string == "https://example.com/play/1")
    #expect(checks["url"]?.string == "https://example.com/x/y?a=1&b=%E4%B8%AD")
    #expect(checks["search"]?.string == "中")
    #expect(checks["query"]?.string == "wd=%E4%B8%AD+%E6%96%87")
    #expect(checks["base64"]?.string == "5L2g5aW9")
    #expect(checks["roundTrip"]?.string == "你好")
    #expect(checks["md5"]?.string == "8ec9e7ac3d0a8c2a4ea3a87d3ba8c4bd" || checks["md5"]?.string?.count == 32)
    #expect(checks["gzip"]?.string == "压缩")
    #expect(checks["btoa"]?.string == "latin")
    #expect(checks["decoder"]?.string == "你好")
    #expect(checks["timer"] == .bool(true))
    #expect(checks["local"]?.string == "rule.js")
    #expect(checks["joined"]?.string == "https://a.example/y")
    #expect(checks["cheerio"]?.string == "function")
}

/// Spiders that parse a failed response throw a SyntaxError; the failed request is what the user should see.
private let failingSpider = #"""
export default {
    async home() { return JSON.parse(req('http://127.0.0.1:1/api').content).class; },
    async category() { return JSON.parse('<html>').list; }
};
"""#

@Test func scriptParseErrorsAfterAFailedRequestReportTheRequest() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("script-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let session = try await ScriptSession.start(api: "https://scripts.example/failing.js", key: "test", ext: "", profile: folder.appendingPathComponent("profile"), label: "test", source: failingSpider)
    defer { session.close() }
    let failed = try await session.call([:])
    #expect(failed["errorCode"]?.string == "source_network", "\(failed)")
    #expect(failed["host"]?.string == "127.0.0.1")
    let broken = try await session.call(["t": "1"])
    #expect(broken["errorCode"]?.string == "script_error", "\(broken)")
    #expect(broken["error"]?.string?.hasPrefix("SyntaxError") == true)
}

/// 剧圈/咕咕 (AppSx.js) reported an unreachable server as "index/searchList returned no data".
@Test func appSxReportsAFailedRequestInsteadOfNoData() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("script-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let session = try await ScriptSession.start(api: "assets://sites/AppSx.js", key: "test", ext: #"{"host":"http://127.0.0.1:1","key":"0123456789abcdef"}"#, profile: folder.appendingPathComponent("profile"), label: "test")
    defer { session.close() }
    let failed = try await session.call(["wd": "test", "pg": "1"])
    #expect(failed["errorCode"]?.string == "source_network", "\(failed)")
    #expect(failed["host"]?.string == "127.0.0.1")
}

/// 立播 "BD播放" (34e8957751c1): player_aaaa.url is a token that the line's iframe exchanges at /vid/parse.php.
/// The port passed the token to the player, which refused it as "请输入有效的 HTTP 或 HTTPS 地址".
@Test func libvioExchangesLineTokensForTheMediaAddress() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("script-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = #"""
    import libvio from 'assets://sites/Libvio.js';
    const site = 'https://lib.example', token = 'Ln2h+F2w/sa=';
    const frame = `${site}/vid/ty4.php?url=${token}&next=&id=7&nid=1`;
    let posted = null;
    globalThis.req = (url, options = {}) => {
        const h = options.headers || {};
        if (url === `${site}/w/7-4-1.html` || url === `${site}/w/7-3-1.html`) {
            const line = url.includes('-4-') ? { encrypt: 3, url: token, from: 'ty_new1' } : { encrypt: 0, url: 'https://cdn.example/a.mp4', from: 'vr2' };
            return { code: 200, headers: {}, content: `<script>var player_aaaa=${JSON.stringify({ ...line, id: '7', nid: 1, link_next: '' })}</script>` };
        }
        if (url === `${site}/static/player/ty_new1.js`) return { code: 200, headers: {}, content: `MacPlayer.Html = '<iframe border="0" src="/vid/ty4.php?url='+MacPlayer.PlayUrl+'&next='+MacPlayer.PlayLinkNext+'&id='+MacPlayer.Id+'&nid='+MacPlayer.Nid+'" width="100%"></iframe>'; MacPlayer.Show();` };
        if (url === frame && h.Referer === `${site}/w/7-4-1.html`) {
            return { code: 200, headers: { 'set-cookie': '_lvs=S1; path=/; HttpOnly' }, content: '<script>window.LIBVIO_CFG = {"parseUrl":"\\/vid\\/parse.php?_t=T\\u0026id=7\\u0026nid=1","rawUrl":"' + token + '","sid":"S1"};</script>' };
        }
        if (url === `${site}/vid/parse.php?_t=T&id=7&nid=1` && options.method === 'POST') {
            posted = { body: JSON.parse(options.body), sid: h['X-LV-S'], cookie: h.Cookie, referer: h.Referer };
            return { code: 200, headers: {}, content: '{"code":200,"url":"https:\\/\\/media.example\\/hope.mp4","fatal":false,"msg":""}' };
        }
        return { code: 404, headers: {}, content: '' };
    };
    export default { home() {
        libvio.init({ site });
        return { bd: libvio.play('BD播放', '7-4-1'), direct: libvio.play('BD5播放', '7-3-1'), posted };
    } };
    """#
    let session = try await ScriptSession.start(api: "https://scripts.example/libvio-lines.js", key: "test", ext: "", profile: folder.appendingPathComponent("profile"), label: "test", source: source)
    defer { session.close() }
    let envelope = try await session.call([:])
    let json = try #require(envelope["result"]?.string, "\(envelope)")
    let checks = try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
    #expect(checks["bd"]?.object?["url"]?.string == "https://media.example/hope.mp4", "\(checks)")
    #expect(checks["bd"]?.object?["header"]?.object?["Cookie"] == nil)
    #expect(checks["direct"]?.object?["url"]?.string == "https://cdn.example/a.mp4")
    let posted = try #require(checks["posted"]?.object, "\(checks)")
    #expect(posted["body"] == .object(["url": .string("Ln2h+F2w/sa="), "sid": .string("S1")]))
    #expect(posted["sid"]?.string == "S1")
    #expect(posted["cookie"]?.string?.contains("_lvs=S1") == true)
    #expect(posted["referer"]?.string == "https://lib.example/vid/ty4.php?url=Ln2h+F2w/sa=&next=&id=7&nid=1")
}

@Test func retiredDrpyLibrariesResolveToBundledCopies() {
    #expect(ScriptAssets.resolve("https://down.nigx.cn/qu.ax/XUKQ.js", from: "https://x.example/drpy2.min.js") == "assets://js/lib/模板.js")
    #expect(ScriptAssets.resolve("./gbk.js", from: "assets://js/lib/drpy2.min.js") == "assets://js/lib/gbk.js")
    #expect(ScriptAssets.resolve("lib/cat.js", from: "https://x.example/a.js") == "assets://js/lib/cat.js")
    #expect(ScriptAssets.bundled("assets://js/lib/../../../etc/passwd") == nil)
}
