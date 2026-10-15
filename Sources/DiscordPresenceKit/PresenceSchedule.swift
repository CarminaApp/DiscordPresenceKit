// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum PresenceUpdateReason: String, Sendable {
	case selection
	case pause
	case resume
	case duration
	case artwork
	case buffering
	case seek
	case metadata
	case itemStatus
	case finished
	case settings
	case reconnect
	case lifecycle
	case playback
}

/// Gives a selected item a brief window to collect local metadata while keeping
/// user-initiated transport changes immediate.
public struct PresencePublicationPolicy: Sendable {
	private var assemblingTrackID: String?
	private var assemblyDeadline: Date?

	public init() {}

	public mutating func delay(
		for reason: PresenceUpdateReason, trackID: String?,
		state: PlaybackSnapshot.State?, now: Date = Date()
	) -> TimeInterval {
		if reason == .selection {
			assemblingTrackID = trackID
			assemblyDeadline = now.addingTimeInterval(0.1)
			return 0.1
		}
		if reason == .pause || reason == .resume || reason == .finished
			|| reason == .settings || reason == .reconnect || reason == .lifecycle
		{
			assemblingTrackID = nil
			assemblyDeadline = nil
			return 0
		}
		if trackID == assemblingTrackID, let deadline = assemblyDeadline, deadline > now {
			return deadline.timeIntervalSince(now)
		}
		if trackID == assemblingTrackID {
			assemblingTrackID = nil
			assemblyDeadline = nil
		}
		if reason == .buffering || state == .waiting { return 0.3 }
		return 0.05
	}

	public mutating func reset() {
		assemblingTrackID = nil
		assemblyDeadline = nil
	}
}

/// Keeps an urgent deadline from being postponed by ordinary playback/artwork events.
public struct PresenceSchedule: Sendable {
	public private(set) var deadline: Date?
	public private(set) var failures = 0
	public private(set) var serverNotBefore = Date.distantPast
	private var localNotBefore = Date.distantPast
	public init() {}

	public mutating func request(after delay: TimeInterval, now: Date = Date()) -> Date {
		let candidate = now.addingTimeInterval(max(0, delay))
		let earliest = min(deadline ?? candidate, candidate)
		let next = max(earliest, max(serverNotBefore, localNotBefore))
		deadline = next
		return next
	}

	public mutating func consumed() { deadline = nil }
	public mutating func failed(retryAfter: TimeInterval, now: Date = Date()) {
		failures += 1
		if retryAfter.isFinite, retryAfter > 0 {
			serverNotBefore = max(serverNotBefore, now.addingTimeInterval(retryAfter))
		}
		localNotBefore = now.addingTimeInterval(min(60, pow(2, Double(min(failures, 6)))))
		deadline = nil
	}
	public mutating func succeeded() {
		failures = 0
		localNotBefore = .distantPast
	}
	public mutating func reconnect() {
		deadline = nil
		succeeded()
		// A new connection does not bypass an outstanding server rate limit.
	}
}

/// Reuses a playback anchor while the player follows it, avoiding millisecond-only updates.
public struct PresenceTimeline: Sendable {
	private var anchor: PlaybackSnapshot?
	public init() {}
	public mutating func normalize(_ snapshot: PlaybackSnapshot?) -> PlaybackSnapshot? {
		guard var value = snapshot, value.state == .playing,
			value.rate.isFinite, value.rate > 0, value.position.isFinite
		else {
			anchor = nil
			return snapshot
		}
		if let previous = anchor, previous.trackID == value.trackID,
			previous.rate == value.rate, previous.duration == value.duration
		{
			let elapsed = value.capturedAt.timeIntervalSince(previous.capturedAt)
			let predicted = previous.position + elapsed * previous.rate
			if elapsed >= 0, abs(predicted - value.position) < 0.25 {
				value.position = previous.position
				value.capturedAt = previous.capturedAt
				return value
			}
		}
		anchor = value
		return value
	}
}
