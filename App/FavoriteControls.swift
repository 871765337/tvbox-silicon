import SwiftUI
import TVCore

struct FavoriteHeartButton: View {
    @Environment(Store.self) private var store
    let item: FavoriteItem
    let name: String
    /// Draws a dark badge so the heart stays readable on poster artwork.
    var onArtwork = false
    /// An empty artwork heart stays hidden until this is true. A saved heart ignores it.
    var revealed = true
    var body: some View {
        let on = store.favorites.contains(item)
        let shown = on || !onArtwork || revealed
        Button { store.favorites.toggle(item) } label: {
            Image(systemName: on ? "heart.fill" : "heart")
                .font(onArtwork ? .system(size: 13, weight: .semibold) : .title3)
                .foregroundStyle(on ? Brand.rose : (onArtwork ? Color.white : Color.secondary))
                .frame(width: onArtwork ? 28 : 44, height: onArtwork ? 28 : 44)
                .background { if onArtwork { Circle().fill(.black.opacity(0.55)) } }
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(shown)
        .accessibilityHidden(!shown)
        .accessibilityLabel(on ? L10n.text("Remove %@ from favorites", name) : L10n.text("Add %@ to favorites", name))
    }
}

struct FavoriteMenuButton: View {
    @Environment(Store.self) private var store
    let item: FavoriteItem
    let name: String
    var body: some View {
        let on = store.favorites.contains(item)
        Button(on ? L10n.text("Remove %@ from favorites", name) : L10n.text("Add %@ to favorites", name), systemImage: on ? "heart.slash" : "heart") {
            store.favorites.toggle(item)
        }
    }
}
