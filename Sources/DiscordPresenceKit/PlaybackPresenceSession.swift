// SPDX-License-Identifier: GPL-3.0-or-later

public struct PlaybackPresenceSession: Sendable {
	private var started = false
	private var finished = false
	public init() {}
	public mutating func selectItem(autoPlay: Bool) {
		finished = false
		if autoPlay { started = true }
	}
	public mutating func resume() { started = true; finished = false }
	public mutating func finish() { finished = true }
	public mutating func reset() { started = false; finished = false }
	public func state(isPlaying: Bool, waiting: Bool, failed: Bool) -> PlaybackSnapshot.State {
		if failed { return .failed }
		if !started || finished { return .stopped }
		if !isPlaying { return .paused }
		return waiting ? .waiting : .playing
	}
}
