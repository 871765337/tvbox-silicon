import Foundation

public enum SourceLists {
    /// Sources the home row, the home picker, and the More count may use.
    public static func browsable(_ sites: [Site], jarURL: URL?, userHidden: (Site) -> Bool) -> [Site] {
        SourceStrategy.arrange(sites) { !$0.hidden && $0.canBrowse(jarURL: jarURL) && !userHidden($0) }
    }
}
