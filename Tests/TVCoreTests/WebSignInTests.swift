import Foundation
import Testing
@testable import TVCore

private func cookie(_ name: String, _ value: String, _ domain: String, expires: Date? = nil) -> HTTPCookie {
    var properties: [HTTPCookiePropertyKey: Any] = [.name: name, .value: value, .domain: domain, .path: "/"]
    if let expires { properties[.expires] = expires }
    return HTTPCookie(properties: properties)!
}

@Test func bilibiliPageSignsInWithSessionCookie() {
    #expect(WebSignIn.bilibili.result(cookies: [cookie("buvid3", "x", ".bilibili.com")]) == nil)
    let cookies = [cookie("SESSDATA", "s%2C1", ".bilibili.com"), cookie("bili_jct", "j", ".bilibili.com"), cookie("DedeUserID", "42", ".bilibili.com"),
                   cookie("buvid3", "x", ".bilibili.com"), cookie("SESSDATA", "other", ".example.com")]
    #expect(WebSignIn.bilibili.result(cookies: cookies) == .cookie("DedeUserID=42; SESSDATA=s%2C1; bili_jct=j"))
}

@Test func quarkPageSignsInWithPusAndKeepsItsTicket() {
    #expect(WebSignIn.quark.result(cookies: [cookie("__puus", "p", ".quark.cn")]) == nil)
    #expect(WebSignIn.quark.result(cookies: [cookie("__pus", "a", ".quark.cn"), cookie("__puus", "p", "pan.quark.cn")]) == .cookie("__pus=a; __puus=p"))
    #expect(WebSignIn.uc.result(cookies: [cookie("__pus", "a", ".quark.cn")]) == nil)
    #expect(WebSignIn.quark.result(cookies: [cookie("__pus", "old", ".quark.cn", expires: Date(timeIntervalSinceNow: -60))]) == nil)
    #expect(WebSignIn.quark.serviceTicket(in: URL(string: "https://pan.quark.cn/account/info?st=abc&lw=scan")!) == "abc")
    #expect(WebSignIn.quark.serviceTicket(in: URL(string: "https://evil.example/quark.cn?st=abc")!) == nil)
    #expect(WebSignIn.uc.serviceTicket(in: URL(string: "https://drive.uc.cn/account/info?st=abc")!) == nil)
}

@Test func baiduPageWaitsForTheDrivesStoken() {
    let passport = [cookie("BDUSS", "b", ".baidu.com"), cookie("PTOKEN", "p", "passport.baidu.com")]
    #expect(WebSignIn.baidu.result(cookies: passport) == nil)
    #expect(WebSignIn.baidu.needsFollowUp(cookies: passport))
    #expect(!WebSignIn.baidu.needsFollowUp(cookies: []))
    // The drive's STOKEN wins over the passport's.
    let signedIn = passport + [cookie("STOKEN", "drive", "pan.baidu.com"), cookie("STOKEN", "pass", "passport.baidu.com"), cookie("BAIDUID", "x", ".baidu.com")]
    #expect(WebSignIn.baidu.result(cookies: signedIn) == .cookie("BDUSS=b; PTOKEN=p; STOKEN=drive"))
    #expect(!WebSignIn.baidu.needsFollowUp(cookies: signedIn))
}

@Test func aliyunPageSignsInWithStoredRefreshToken() {
    #expect(WebSignIn.aliyun.result(cookies: [], stored: nil) == nil)
    #expect(WebSignIn.aliyun.result(cookies: [], stored: "{}") == nil)
    #expect(WebSignIn.aliyun.result(cookies: [], stored: #"{"access_token":"a","refresh_token":"0123456789abcdef0123456789abcdef"}"#)
            == .refreshToken("0123456789abcdef0123456789abcdef"))
    #expect(WebSignIn.aliyun.storage?.key == "token")
    #expect(WebSignIn.allCases.filter { $0.userAgent != nil } == [.quark, .uc, .aliyun])
}
