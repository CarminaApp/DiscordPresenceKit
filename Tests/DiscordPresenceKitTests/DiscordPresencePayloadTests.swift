// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import DiscordPresenceKit

private func snapshot(
	position: Double = 30, duration: Double = 180,
	state: PlaybackSnapshot.State = .playing, rate: Double = 1
) -> PlaybackSnapshot {
	PlaybackSnapshot(
		trackID: "one", title: "Song", artist: "Artist", album: "Album",
		position: position, duration: duration, rate: rate, state: state,
		capturedAt: Date(timeIntervalSince1970: 1_800_000_000))
}

private func payload(_ snapshot: PlaybackSnapshot = snapshot()) -> DiscordPresencePayload? {
	DiscordPresencePayload(snapshot: snapshot, includeAlbum: true, showTimer: true, showArtwork: true)
}

@Test func timestampsUseMillisecondsAndActualRate() throws {
	let value = try #require(payload(snapshot(rate: 2)))
	#expect(value.startMilliseconds == 1_799_999_985_000)
	#expect(value.endMilliseconds == 1_800_000_075_000)
}

@Test func stoppedAndFailedNeverPublishListening() {
	for state in [PlaybackSnapshot.State.stopped, .failed] {
		#expect(payload(snapshot(state: state)) == nil)
	}
	#expect(payload(snapshot(rate: .nan)) == nil)
	#expect(payload(snapshot(rate: 0)) == nil)
}

@Test func invalidDurationsOmitTimer() throws {
	for duration in [Double.nan, .infinity, 0, -1, 20] {
		let value = try #require(payload(snapshot(duration: duration)))
		#expect(value.startMilliseconds == nil)
		#expect(value.endMilliseconds == nil)
	}
	let value = try #require(payload(snapshot(position: .infinity)))
	#expect(value.startMilliseconds == nil)
}

@Test func privacyControlsRemoveAlbumArtworkAndTimer() throws {
	var input = snapshot()
	input.artworkURL = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/cover.jpg")
	let value = try #require(
		DiscordPresencePayload(
			snapshot: input, includeAlbum: false,
			showTimer: false, showArtwork: false, fallbackAsset: "app-icon"))
	#expect(value.state == "Artist")
	#expect(value.largeImage == nil)
	#expect(value.largeText == nil)
	#expect(value.startMilliseconds == nil)
	#expect(value.endMilliseconds == nil)
}

@Test func songArtistAndAlbumUseDistinctDiscordFields() throws {
	let value = try #require(payload())
	#expect(value.title == "Song")
	#expect(value.state == "Artist")
	#expect(value.largeText == "Album")
}

@Test func urgentSchedulingCannotBePostponedByOrdinaryUpdates() {
	let now = Date(timeIntervalSince1970: 1_800_000_000)
	var schedule = PresenceSchedule()
	#expect(schedule.request(after: 0.5, now: now) == now.addingTimeInterval(0.5))
	#expect(schedule.request(after: 0, now: now.addingTimeInterval(0.1)) == now.addingTimeInterval(0.1))
	#expect(schedule.request(after: 0.5, now: now.addingTimeInterval(0.2)) == now.addingTimeInterval(0.1))
}

@Test func trackAssemblyCoalescesMetadataArtworkAndDuration() {
	let now = Date(timeIntervalSince1970: 1_800_000_000)
	var policy = PresencePublicationPolicy()
	#expect(policy.delay(for: .selection, trackID: "a", state: .waiting, now: now) == 0.1)
	#expect(
		abs(
			policy.delay(
				for: .artwork, trackID: "a", state: .waiting,
				now: now.addingTimeInterval(0.03)) - 0.07) < 0.001)
	#expect(
		abs(
			policy.delay(
				for: .duration, trackID: "a", state: .playing,
				now: now.addingTimeInterval(0.08)) - 0.02) < 0.001)
}

@Test func pauseAndResumeBypassAssemblyWhileBufferingIsDebounced() {
	let now = Date(timeIntervalSince1970: 1_800_000_000)
	var policy = PresencePublicationPolicy()
	_ = policy.delay(for: .selection, trackID: "a", state: .waiting, now: now)
	#expect(
		policy.delay(
			for: .pause, trackID: "a", state: .paused,
			now: now.addingTimeInterval(0.02)) == 0)
	#expect(
		policy.delay(
			for: .resume, trackID: "a", state: .playing,
			now: now.addingTimeInterval(0.03)) == 0)
	#expect(
		policy.delay(
			for: .buffering, trackID: "a", state: .waiting,
			now: now.addingTimeInterval(1)) == 0.3)
}

@Test func newerSelectionReplacesOldTrackAssemblyWindow() {
	let now = Date(timeIntervalSince1970: 1_800_000_000)
	var policy = PresencePublicationPolicy()
	_ = policy.delay(for: .selection, trackID: "a", state: .waiting, now: now)
	#expect(
		policy.delay(
			for: .selection, trackID: "b", state: .waiting,
			now: now.addingTimeInterval(0.04)) == 0.1)
	#expect(
		policy.delay(
			for: .artwork, trackID: "a", state: .playing,
			now: now.addingTimeInterval(0.05)) == 0.05)
	#expect(
		abs(
			policy.delay(
				for: .duration, trackID: "b", state: .playing,
				now: now.addingTimeInterval(0.09)) - 0.05) < 0.001)
}

@Test func reconnectPreservesDiscordRetryDeadlineButDropsLocalBackoffAfterSuccess() {
	let now = Date(timeIntervalSince1970: 1_800_000_000)
	var schedule = PresenceSchedule()
	schedule.failed(retryAfter: 8, now: now)
	schedule.reconnect()
	#expect(schedule.request(after: 0, now: now.addingTimeInterval(1)) == now.addingTimeInterval(8))
	schedule.succeeded()
	schedule.consumed()
	#expect(schedule.request(after: 0, now: now.addingTimeInterval(9)) == now.addingTimeInterval(9))
}

@Test func playbackTimelineCoalescesClockJitterButRecognizesSeek() throws {
	let now = Date(timeIntervalSince1970: 1_800_000_000)
	var timeline = PresenceTimeline()
	let original = snapshot(position: 30)
	_ = timeline.normalize(original)
	var ordinary = original
	ordinary.position = 30.51
	ordinary.capturedAt = now.addingTimeInterval(0.5)
	let normalizedValue = timeline.normalize(ordinary)
	let normalized = try #require(normalizedValue)
	#expect(normalized.position == original.position)
	#expect(normalized.capturedAt == original.capturedAt)
	var seek = ordinary
	seek.position = 90
	let soughtValue = timeline.normalize(seek)
	let sought = try #require(soughtValue)
	#expect(sought.position == 90)
	#expect(sought.capturedAt == seek.capturedAt)
}

@Test func artworkNeverExposesLocalOrCredentialedURLs() {
	for raw in [
		"file:///private/music/cover.jpg", "https://server.local/art?api_key=secret",
		"https://user:password@is1.mzstatic.com/art", "https://is1.mzstatic.com/art?token=secret",
		"https://mzstatic.com.attacker.example/art", "http://is1.mzstatic.com/art",
	] {
		#expect(DiscordPresencePayload.publicArtworkURL(URL(string: raw)) == nil)
	}
	#expect(DiscordPresencePayload.publicArtworkURL(URL(string: "https://is1.mzstatic.com/art")) != nil)
}

@Test func unicodeFieldsDoNotSplitCharacters() throws {
	var input = snapshot()
	input.title = String(repeating: "🎵", count: 100) + "\n"
	let value = try #require(payload(input))
	#expect(value.title == String(repeating: "🎵", count: 32))
	#expect(value.title.utf8.count == 128)
}

@Test func clearOutranksAnOutstandingUpdate() throws {
	var state = PresenceDelivery()
	state.setDesired(payload())
	let firstValue = state.begin()
	let first = try #require(firstValue)
	state.setDesired(nil)
	state.cleared()
	state.complete(first, successful: true, retryable: false)
	#expect(state.desired == nil)
	let pending1 = state.begin()
	#expect(pending1 == nil)
	state.cleared()
	state.setDesired(payload())
	let pending2 = state.begin()
	#expect(pending2 != nil)
}

@Test func rapidSkipsKeepOnlyNewestAndSerializeUpdates() throws {
	var state = PresenceDelivery()
	state.setDesired(payload())
	let firstValue = state.begin()
	let first = try #require(firstValue)
	var newer = snapshot()
	newer.title = "Next Song"
	state.setDesired(payload(newer))
	let pending3 = state.begin()
	#expect(pending3 == nil)
	state.complete(first, successful: true, retryable: false)
	let secondValue = state.begin()
	let second = try #require(secondValue)
	#expect(second.payload.title == "Next Song")
	state.complete(second, successful: true, retryable: false)
	let pending4 = state.begin()
	#expect(pending4 == nil)
}

@Test func resumeBeforeOldCompletionRepublishesAfterClear() throws {
	var state = PresenceDelivery()
	let original = payload()
	state.setDesired(original)
	let oldValue = state.begin()
	let old = try #require(oldValue)
	state.setDesired(nil)
	state.cleared()
	state.setDesired(original)
	state.complete(old, successful: true, retryable: false)
	let resumedValue = state.begin()
	let resumed = try #require(resumedValue)
	#expect(resumed.payload == original)
	#expect(resumed.revision != old.revision)
}

@Test func reconnectRejectsOldCallbacksAndRepublishes() throws {
	var state = PresenceDelivery()
	state.setDesired(payload())
	let oldValue = state.begin()
	let old = try #require(oldValue)
	state.reconnect()
	let newValue = state.begin()
	let new = try #require(newValue)
	state.complete(old, successful: true, retryable: false)
	#expect(state.inFlight == new)
	state.complete(new, successful: true, retryable: false)
	let pending5 = state.begin()
	#expect(pending5 == nil)
}

@Test func retryableFailureRetainsDesiredButPermanentFailureStops() throws {
	var state = PresenceDelivery()
	state.setDesired(payload())
	let firstValue = state.begin()
	let first = try #require(firstValue)
	state.complete(first, successful: false, retryable: true)
	let retryValue = state.begin()
	let retry = try #require(retryValue)
	state.complete(retry, successful: false, retryable: false)
	let pending6 = state.begin()
	#expect(pending6 == nil)
}

@Test func coverArtArchiveCoversArePublicButUploadedCoversAreNot() {
	let release = "https://coverartarchive.org/release/8e2c1c2a-4b0a-4f0e-9d8a-2a3e1f6b7c90/front-500"
	#expect(DiscordPresencePayload.publicArtworkURL(URL(string: release)) != nil)
	#expect(DiscordPresencePayload.publicArtworkURL(URL(string: "https://files.catbox.moe/abc123.jpg")) == nil)
	#expect(
		DiscordPresencePayload.publicArtworkURL(URL(string: "https://coverartarchive.org.attacker.example/a")) == nil)
}
