// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import DiscordPresenceKit

private let catalogURL = URL(string: "https://is1.mzstatic.com/catalog.jpg")!
private let otherCatalogURL = URL(string: "https://is2.mzstatic.com/other.jpg")!

/// Answers every song with the same cover, after an optional delay, and counts how often it was asked.
private actor FakeResolver: ArtworkResolver {
	let url: URL?
	let delay: Duration
	private(set) var calls = 0

	init(_ url: URL?, delay: Duration = .zero) {
		self.url = url
		self.delay = delay
	}

	func artworkURL(for snapshot: PlaybackSnapshot) async throws -> URL? {
		calls += 1
		try await Task.sleep(for: delay)
		return url
	}
}

private func playing(_ trackID: String = "a", artworkURL: URL? = nil) -> PlaybackSnapshot {
	PlaybackSnapshot(
		trackID: trackID, title: trackID.uppercased(), artist: "Artist", album: "Album",
		artworkURL: artworkURL, position: 1, duration: 10, rate: 1, state: .playing, artworkID: "cover-\(trackID)")
}

@MainActor
@Test func publishesTheFirstCoverAResolverFindsInOrder() async throws {
	let none = FakeResolver(nil)
	let first = FakeResolver(catalogURL)
	let later = FakeResolver(otherCatalogURL)
	let controller = DiscordArtworkController(resolvers: [none, first, later])
	controller.update(snapshot: playing(), enabled: true, allowWork: true)
	try await Task.sleep(for: .milliseconds(300))
	#expect(controller.url == catalogURL)
	#expect(controller.phase == .resolved)
	#expect(await none.calls == 1)
	#expect(await later.calls == 0)
}

@MainActor
@Test func theSourcesOwnPublicCoverIsUsedWithoutAskingResolvers() async throws {
	let resolver = FakeResolver(otherCatalogURL)
	let controller = DiscordArtworkController(resolvers: [resolver])
	controller.update(snapshot: playing(artworkURL: catalogURL), enabled: true, allowWork: true)
	#expect(controller.url == catalogURL)
	try await Task.sleep(for: .milliseconds(300))
	#expect(await resolver.calls == 0)
}

@MainActor
@Test func noCoverFromAnyResolverFails() async throws {
	let controller = DiscordArtworkController(resolvers: [FakeResolver(nil), FakeResolver(nil)])
	controller.update(snapshot: playing(), enabled: true, allowWork: true)
	try await Task.sleep(for: .milliseconds(300))
	#expect(controller.url == nil)
	#expect(controller.phase == .failed)
}

@MainActor
@Test func rapidSkipBeforeDebounceDoesNotLookUpPreviousCover() async throws {
	let resolver = FakeResolver(catalogURL)
	let controller = DiscordArtworkController(resolvers: [resolver])
	controller.update(snapshot: playing(), enabled: true, allowWork: true)
	controller.update(snapshot: nil, enabled: false, allowWork: false)
	try await Task.sleep(for: .milliseconds(300))
	#expect(await resolver.calls == 0)
	#expect(controller.url == nil)
}

@MainActor
@Test func pausingInBackgroundRetainsAlreadyFoundCover() async throws {
	let resolver = FakeResolver(catalogURL)
	let controller = DiscordArtworkController(resolvers: [resolver])
	var snapshot = playing()
	controller.update(snapshot: snapshot, enabled: true, allowWork: true)
	try await Task.sleep(for: .milliseconds(300))
	#expect(controller.url == catalogURL)
	snapshot.state = .paused
	snapshot.rate = 0
	controller.update(snapshot: snapshot, enabled: true, allowWork: false)
	#expect(controller.url == catalogURL)
	#expect(await resolver.calls == 1)
}

@MainActor
@Test func backgroundPauseLetsAnActiveLookupFinish() async throws {
	let controller = DiscordArtworkController(resolvers: [FakeResolver(catalogURL, delay: .milliseconds(300))])
	var snapshot = playing()
	controller.update(snapshot: snapshot, enabled: true, allowWork: true)
	try await Task.sleep(for: .milliseconds(200))
	snapshot.state = .paused
	snapshot.rate = 0
	controller.update(snapshot: snapshot, enabled: true, allowWork: false, allowFinishingWork: true)
	try await Task.sleep(for: .milliseconds(400))
	#expect(controller.url == catalogURL)
}

@MainActor
@Test func revisitingTrackReusesFoundCoverSynchronously() async throws {
	let resolver = FakeResolver(catalogURL)
	let controller = DiscordArtworkController(resolvers: [resolver])
	controller.update(snapshot: playing("a"), enabled: true, allowWork: true)
	try await Task.sleep(for: .milliseconds(300))
	#expect(controller.url == catalogURL)
	controller.update(snapshot: playing("b"), enabled: true, allowWork: false)
	#expect(controller.url == nil)
	controller.update(snapshot: playing("a"), enabled: true, allowWork: false)
	#expect(controller.url == catalogURL)
	#expect(await resolver.calls == 1)
}

@MainActor
@Test func aResolversCoverWithCredentialsOrFromAnUnknownHostIsNeverPublished() async throws {
	let controller = DiscordArtworkController(resolvers: [
		FakeResolver(URL(string: "https://music.example/cover.jpg")!),
		FakeResolver(URL(string: "https://is1.mzstatic.com/cover.jpg?token=secret")!),
		FakeResolver(catalogURL),
	])
	controller.update(snapshot: playing(), enabled: true, allowWork: true)
	try await Task.sleep(for: .milliseconds(300))
	#expect(controller.url == catalogURL)
}
