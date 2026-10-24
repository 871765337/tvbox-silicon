import SwiftUI
import TVCore

struct FavoriteHeartButton: View {
    @Environment(Store.self) private var store
    let item: FavoriteItem
    let name: String
    var body: some View {
        let on = store.favorites.contains(item)
        Button { store.favorites.toggle(item) } label: {
            Image(systemName: on ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(on ? Brand.rose : .secondary)
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
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
