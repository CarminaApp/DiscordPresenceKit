// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Searches the iTunes catalog for the same song, and uses its cover.
public struct ITunesArtworkResolver: ArtworkResolver {
	private let lookup: CatalogArtworkLookup

	public init() {
		self.init(lookup: CatalogArtworkLookup())
	}

	init(lookup: CatalogArtworkLookup) {
		self.lookup = lookup
	}

	public func artworkURL(for snapshot: PlaybackSnapshot) async throws -> URL? {
		try await lookup.artwork(
			for: CatalogArtworkLookup.Identity(title: snapshot.title, artist: snapshot.artist, album: snapshot.album))
	}
}
