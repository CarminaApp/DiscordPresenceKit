// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import DiscordPresenceKit

private let cover = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/cover/600x600bb.jpg")!
private let identity = CatalogArtworkLookup.Identity(
	title: "Bohemian Rhapsody", artist: "Panic! At the Disco", album: "Suicide Squad: The Album")

private func candidate(
	artist: String = "Panic! At the Disco",
	album: String = "Suicide Squad: The Album"
) -> MatchCandidate {
	MatchCandidate(title: "Bohemian Rhapsody", artist: artist, album: album, artworkURL: cover)
}

@Test func findsCatalogCoverWithoutLocalArtworkOrDuration() {
	// Both imported files and device-library items may have local covers but no public URL.
	#expect(CatalogArtworkLookup.artwork(in: [candidate()], for: identity) == cover)
}

@Test func rejectsAnotherArtistAndAnotherAlbum() {
	#expect(CatalogArtworkLookup.artwork(in: [candidate(artist: "Queen")], for: identity) == nil)
	#expect(CatalogArtworkLookup.artwork(in: [candidate(album: "Greatest Hits")], for: identity) == nil)
}

@Test func normalizesCasePunctuationAndWhitespace() {
	let variant = CatalogArtworkLookup.Identity(
		title: " BOHEMIAN  RHAPSODY ",
		artist: "Panic At The Disco", album: "Suicide Squad The Album")
	#expect(variant == identity)
	#expect(CatalogArtworkLookup.artwork(in: [candidate()], for: variant) == cover)
}

@Test func doesNotGuessWhenArtistIsMissing() {
	let missing = CatalogArtworkLookup.Identity(title: "Bohemian Rhapsody", artist: "", album: "")
	#expect(CatalogArtworkLookup.artwork(in: [candidate()], for: missing) == nil)
}

private actor SearchCounter {
	var calls = 0
	func search(found: Bool) -> [MatchCandidate] { calls += 1; return found ? [candidate()] : [] }
}

@Test func cachesCoverAcrossRepeatedPlaybackEvents() async throws {
	let counter = SearchCounter()
	let lookup = CatalogArtworkLookup { _ in await counter.search(found: true) }
	#expect(try await lookup.artwork(for: identity) == cover)
	#expect(try await lookup.artwork(for: identity) == cover)
	#expect(await counter.calls == 1)
}

@Test func cachesMissingCoverToAvoidRepeatedSearches() async throws {
	let counter = SearchCounter()
	let lookup = CatalogArtworkLookup { _ in await counter.search(found: false) }
	#expect(try await lookup.artwork(for: identity) == nil)
	#expect(try await lookup.artwork(for: identity) == nil)
	#expect(await counter.calls == 1)
}

@Test func canceledLookupDoesNotStartNetworkRequest() async throws {
	let counter = SearchCounter()
	let lookup = CatalogArtworkLookup { _ in await counter.search(found: true) }
	let task = Task {
		withUnsafeCurrentTask { $0?.cancel() }
		return try await lookup.artwork(for: identity)
	}
	do { _ = try await task.value; Issue.record("Canceled request unexpectedly succeeded") } catch is CancellationError
	{}
	#expect(await counter.calls == 0)
}
