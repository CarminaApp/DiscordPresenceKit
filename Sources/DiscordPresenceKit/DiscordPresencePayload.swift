// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct DiscordPresencePayload: Equatable, Sendable {
	public let title: String
	public let state: String
	public let largeImage: String?
	public let largeText: String?
	public let startMilliseconds: UInt64?
	public let endMilliseconds: UInt64?

	public init?(
		snapshot: PlaybackSnapshot, includeAlbum: Bool,
		showTimer: Bool, showArtwork: Bool, fallbackAsset: String? = nil,
		keepWhenPaused: Bool = true
	) {
		switch snapshot.state {
		case .playing:
			guard snapshot.rate.isFinite, snapshot.rate > 0 else { return nil }
		case .paused:
			guard keepWhenPaused else { return nil }
		case .waiting: break
		case .stopped, .failed: return nil
		}
		title = Self.field(snapshot.title.isEmpty ? "Unknown Song" : snapshot.title)
		let label = snapshot.state == .paused ? "Paused" : snapshot.state == .waiting ? "Buffering" : ""
		state = Self.field(
			[label, snapshot.artist]
				.filter { !$0.isEmpty }.joined(separator: " • "))
		largeText = includeAlbum && !snapshot.album.isEmpty ? Self.field(snapshot.album) : nil
		largeImage =
			showArtwork
			? Self.publicArtworkURL(snapshot.artworkURL)?.absoluteString ?? fallbackAsset
			: nil

		let now = snapshot.capturedAt.timeIntervalSince1970
		if snapshot.state == .playing, showTimer, snapshot.position.isFinite, snapshot.position >= 0,
			snapshot.duration.isFinite, snapshot.duration > 0,
			snapshot.position < snapshot.duration
		{
			startMilliseconds = Self.milliseconds(now - snapshot.position / snapshot.rate)
			endMilliseconds = Self.milliseconds(now + (snapshot.duration - snapshot.position) / snapshot.rate)
		} else {
			startMilliseconds = nil
			endMilliseconds = nil
		}
	}

	private static func milliseconds(_ seconds: Double) -> UInt64? {
		let milliseconds = seconds * 1_000
		guard milliseconds.isFinite, milliseconds >= 0,
			milliseconds < Double(UInt64.max)
		else { return nil }
		return UInt64(milliseconds.rounded(.down))
	}

	private static func field(_ text: String) -> String {
		// Bound UTF-8 bytes without splitting a character or leaking control characters.
		var result = ""
		for character in text where !character.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
			guard result.utf8.count + String(character).utf8.count <= 128 else { break }
			result.append(character)
		}
		return result
	}

	public static func publicArtworkURL(_ url: URL?) -> URL? {
		guard let url, url.scheme?.lowercased() == "https", let host = url.host,
			!host.isEmpty, url.user == nil, url.password == nil,
			url.query == nil, url.fragment == nil
		else { return nil }
		// Only opt in known public artwork providers. Credentials in private server URLs are never shared.
		guard host.hasSuffix(".mzstatic.com") || host == "coverartarchive.org" else { return nil }
		return url
	}
}
