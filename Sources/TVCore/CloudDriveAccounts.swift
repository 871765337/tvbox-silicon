import Foundation

/// Kept outside disposable plugin caches; never included in subscription exports.
public struct CloudDriveAccounts: Codable, Sendable {
    public var quarkCookie = ""
    /// Quark's mobile service ticket is distinct from its web cookies; older saves omit it.
    public var quarkServiceTicket: String?
    public var ucCookie = ""
    public var ucToken = ""
    public var token = ""
    public init() {}
    /// The plugin runtime reads accounts from this file.
    public static var fileURL: URL {
        #if os(tvOS)
        // tvOS only permits Caches; `load` restores a purged copy from user defaults.
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #endif
        return base.appendingPathComponent("com.tvbox.yingxia/CloudDrive/accounts.json")
    }
    public static func load() throws -> Self {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: fileURL))
        }
        #if os(tvOS)
        if let data = UserDefaults.standard.data(forKey: defaultsKey), let accounts = try? JSONDecoder().decode(Self.self, from: data) {
            try accounts.save()
            return accounts
        }
        #endif
        return Self()
    }
    public func save() throws {
        let folder = Self.fileURL.deletingLastPathComponent()
        let data = try JSONEncoder().encode(self)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: Self.fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.fileURL.path)
        #if os(tvOS)
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        #endif
    }
    /// Changes whenever the saved accounts do; empty when nothing is saved.
    public static var revision: String {
        _ = try? load()
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return "" }
        return String(PluginChecksum.sha256(data).prefix(12))
    }
    #if os(tvOS)
    private static let defaultsKey = "cloudDriveAccounts"
    #endif
}

/// The plugin tried to open an Android-only QR login flow. The app presents its own login.
public enum CloudDriveLoginRequired: String, LocalizedError, Sendable {
    case quark, uc

    init?(envelope: [String: JSONValue]) {
        guard envelope["errorCode"]?.string == "cloud_login_required",
              let drive = envelope["drive"]?.string else { return nil }
        self.init(rawValue: drive)
    }

    public func message(language: String? = nil) -> String {
        L10n.text("Your %@ sign-in is missing or has expired. Sign in again to play this episode.",
                  L10n.text(self == .quark ? "Quark" : "UC", language: language), language: language)
    }
    public var errorDescription: String? { message() }
}
