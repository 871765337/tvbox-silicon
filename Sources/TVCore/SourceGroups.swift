import Foundation

public enum SourceLists {
    /// Sources the home row, the home picker, and the More count may use.
    public static func browsable(_ sites: [Site], jarURL: URL?, userHidden: (Site) -> Bool) -> [Site] {
        SourceStrategy.arrange(sites) { !$0.hidden && $0.canBrowse(jarURL: jarURL) && !userHidden($0) }
    }
}

public struct SourceGroup: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case pinned, builtIn, subscription(String)
    }
    public var kind: Kind
    public var title: String
    public var sites: [Site]
    public var id: String {
        switch kind {
        case .pinned: "pinned"
        case .builtIn: "builtIn"
        case .subscription(let address): address
        }
    }
}

public enum SourceGroups {
    public static func make(entries: [SubscriptionEntry], documents: [String: Subscription], builtIns: [Site], builtInOrigin: URL, pinOrder: [Site], userHidden: (Site) -> Bool, includeHidden: Bool, jarURL: URL?) -> [SourceGroup] {
        func isPinned(_ site: Site, fallback: URL) -> Bool {
            let origin = site.origin(or: fallback)
            return pinOrder.contains { $0.sourceKey == site.sourceKey && $0.origin(or: fallback) == origin }
        }
        func eligible(_ site: Site) -> Bool {
            !site.hidden && site.canBrowse(jarURL: jarURL) && (includeHidden || !userHidden(site))
        }
        var groups: [SourceGroup] = []
        let pinnedSites = pinOrder.filter(eligible)
        if !pinnedSites.isEmpty { groups.append(SourceGroup(kind: .pinned, title: "Pinned Group", sites: pinnedSites)) }
        let builtInSites = builtIns.filter { eligible($0) && !isPinned($0, fallback: builtInOrigin) }
        if !builtInSites.isEmpty { groups.append(SourceGroup(kind: .builtIn, title: "Built-in", sites: builtInSites)) }
        for entry in entries where entry.enabled {
            guard let document = documents[entry.address] else { continue }
            let own = document.sites.filter { !$0.isBuiltIn && !isPinned($0, fallback: document.origin) && eligible($0) }
            let arranged = SourceStrategy.arrange(own, where: { _ in true })
            if !arranged.isEmpty { groups.append(SourceGroup(kind: .subscription(entry.address), title: entry.title, sites: arranged)) }
        }
        return groups
    }
}

public enum SubscriptionOrder {
    public static func applying(displayed: [String], to subscriptions: [SubscriptionEntry]) -> [SubscriptionEntry] {
        let shown = Set(displayed)
        var next = displayed.makeIterator()
        return subscriptions.map { entry in
            guard shown.contains(entry.address), let address = next.next(), let replacement = subscriptions.first(where: { $0.address == address }) else { return entry }
            return replacement
        }
    }
}
