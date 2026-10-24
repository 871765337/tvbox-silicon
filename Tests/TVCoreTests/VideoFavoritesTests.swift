import Foundation
import Testing
@testable import TVCore

@Test @MainActor func videoFavoritesToggleAndPersistShowsWithoutEpisodeAddresses() throws {
    let suite = "video-favorites-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let origin = URL(string: "https://example.com/sub.json")!
    let site = Site(key: "movies", name: "Movies", type: 1, api: "https://api.example/movies", raw: ["key": .string("movies")])
    let other = Site(key: "shows", name: "Shows", type: 1, api: "https://api.example/shows", raw: ["key": .string("shows")])
    let video = Video(id: "42", name: "Series", poster: URL(string: "https://img.example/42.jpg"), year: "2024", remarks: "更新至10集",
                      synopsis: "Plot", episodes: [Episode(id: "0-0", name: "第1集", address: "https://cdn.example/1.m3u8?sign=x", flag: "line")])

    let favorites = VideoFavorites(defaults: defaults)
    favorites.toggle(VideoFavorite(origin: origin, site: site, video: video))
    favorites.toggle(VideoFavorite(origin: origin, site: other, video: video))
    #expect(favorites.items.map(\.sourceKey) == ["shows", "movies"])
    #expect(favorites.contains(VideoFavorite.id(origin: origin, site: site, video: video)))
    #expect(String(decoding: try #require(defaults.data(forKey: "videoFavorites")), as: UTF8.self).contains("m3u8") == false)

    let restored = VideoFavorites(defaults: defaults)
    #expect(restored.items.count == 2)
    let saved = try #require(restored.items.last)
    #expect(saved.video.name == "Series" && saved.video.remarks == "更新至10集" && saved.video.episodes.isEmpty)
    #expect(saved.id == PlaybackHistoryContext(origin: origin, site: site, video: video, episode: video.episodes[0]).id)

    restored.toggle(saved)
    #expect(VideoFavorites(defaults: defaults).items.map(\.sourceKey) == ["shows"])
}
