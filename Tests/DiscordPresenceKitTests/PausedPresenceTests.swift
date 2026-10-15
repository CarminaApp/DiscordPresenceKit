// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import DiscordPresenceKit

private func activity(_ state: PlaybackSnapshot.State, keep: Bool = true) -> DiscordPresencePayload? {
	let snapshot = PlaybackSnapshot(
		trackID: "one", title: "Song", artist: "Artist", album: "Album",
		artworkURL: URL(string: "https://is1.mzstatic.com/cover.jpg"), position: 42, duration: 180,
		rate: state == .playing ? 1 : 0, state: state, capturedAt: Date(timeIntervalSince1970: 1_800_000_000))
	return DiscordPresencePayload(
		snapshot: snapshot, includeAlbum: true, showTimer: true,
		showArtwork: true, keepWhenPaused: keep)
}

@Test func pausedAndBufferingRetainCoverWithoutAdvancingTimestamps() throws {
	for state in [PlaybackSnapshot.State.paused, .waiting] {
		let payload = try #require(activity(state))
		#expect(payload.title == "Song")
		#expect(payload.state == (state == .paused ? "Paused • Artist" : "Buffering • Artist"))
		#expect(payload.largeImage == "https://is1.mzstatic.com/cover.jpg")
		#expect(payload.startMilliseconds == nil)
		#expect(payload.endMilliseconds == nil)
	}
	#expect(activity(.paused, keep: false) == nil)
	#expect(activity(.playing)?.startMilliseconds == 1_799_999_958_000)
}

@Test func latePlayingUpdateIsFollowedByPausedState() throws {
	var delivery = PresenceDelivery()
	delivery.setDesired(activity(.playing))
	let initial = delivery.begin()
	let playing = try #require(initial)
	delivery.setDesired(activity(.paused))
	delivery.complete(playing, successful: true, retryable: false)
	let pending = delivery.begin()
	let paused = try #require(pending)
	#expect(paused.payload.state.hasPrefix("Paused"))
	#expect(paused.payload.endMilliseconds == nil)
	delivery.setDesired(activity(.playing))
	delivery.complete(paused, successful: true, retryable: false)
	let resumed = delivery.begin()
	#expect(resumed?.payload.endMilliseconds != nil)
}

@Test func restoredAndCompletedSessionsStaySilentWhileUserPausesRemainVisible() {
	var session = PlaybackPresenceSession()
	session.selectItem(autoPlay: false)
	#expect(session.state(isPlaying: false, waiting: false, failed: false) == .stopped)
	session.resume()
	#expect(session.state(isPlaying: false, waiting: false, failed: false) == .paused)
	session.selectItem(autoPlay: false)
	#expect(session.state(isPlaying: false, waiting: false, failed: false) == .paused)
	session.finish()
	#expect(session.state(isPlaying: false, waiting: false, failed: false) == .stopped)
	session.resume()
	#expect(session.state(isPlaying: true, waiting: true, failed: false) == .waiting)
	#expect(session.state(isPlaying: true, waiting: false, failed: true) == .failed)
	session.reset()
	#expect(session.state(isPlaying: false, waiting: false, failed: false) == .stopped)
}
