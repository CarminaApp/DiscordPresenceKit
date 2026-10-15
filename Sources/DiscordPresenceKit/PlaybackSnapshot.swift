// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct PlaybackSnapshot: Equatable, Sendable {
	public enum State: Sendable { case playing, paused, waiting, stopped, failed }

	public var trackID: String
	public var title: String
	public var artist: String
	public var album: String
	public var artworkURL: URL?
	public var artworkID: String?
	/// The MusicBrainz release the song was tagged with, which finds its cover on the Cover Art Archive.
	public var musicBrainzReleaseID: String?
	public var position: Double
	public var duration: Double
	public var rate: Double
	public var state: State
	public var capturedAt: Date

	public init(
		trackID: String, title: String, artist: String, album: String,
		artworkURL: URL? = nil, position: Double, duration: Double,
		rate: Double, state: State, capturedAt: Date = Date(), artworkID: String? = nil,
		musicBrainzReleaseID: String? = nil
	) {
		self.trackID = trackID
		self.title = title
		self.artist = artist
		self.album = album
		self.artworkURL = artworkURL
		self.artworkID = artworkID
		self.musicBrainzReleaseID = musicBrainzReleaseID
		self.position = position
		self.duration = duration
		self.rate = rate
		self.state = state
		self.capturedAt = capturedAt
	}
}
