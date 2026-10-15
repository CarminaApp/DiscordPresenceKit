// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Finds a public catalog cover without replacing the user's local artwork or tags.
actor CatalogArtworkLookup {
	struct Identity: Hashable, Sendable {
		let title: String
		let artist: String
		let album: String

		init(title: String, artist: String, album: String) {
			self.title = CatalogArtworkLookup.normalize(title)
			self.artist = CatalogArtworkLookup.normalize(artist)
			self.album = CatalogArtworkLookup.normalize(album)
		}
	}

	private struct Entry {
		let url: URL?
		let expires: Date
	}

	private let search: @Sendable (String) async throws -> [MatchCandidate]
	private var cache: [Identity: Entry] = [:]
	private var nextRequest = Date.distantPast

	init(
		search: @escaping @Sendable (String) async throws -> [MatchCandidate] = {
			try await ITunesSearchClient().search(term: $0, limit: 25)
		}
	) {
		self.search = search
	}

	func artwork(for identity: Identity) async throws -> URL? {
		guard !identity.title.isEmpty, !identity.artist.isEmpty else { return nil }
		if let entry = cache[identity], entry.expires > Date() { return entry.url }
		// Bound request frequency even while the user skips through the queue.
		while nextRequest > Date() {
			try await Task.sleep(for: .seconds(max(0, nextRequest.timeIntervalSinceNow)))
		}
		try Task.checkCancellation()
		nextRequest = Date().addingTimeInterval(3)
		let candidates = try await search(
			[identity.artist, identity.title, identity.album]
				.filter { !$0.isEmpty }.joined(separator: " "))
		try Task.checkCancellation()
		let url = Self.artwork(in: candidates, for: identity)
		if cache.count >= 128 { cache.removeAll(keepingCapacity: true) }
		cache[identity] = Entry(url: url, expires: Date().addingTimeInterval(url == nil ? 300 : 86_400))
		return url
	}

	static func artwork(in candidates: [MatchCandidate], for identity: Identity) -> URL? {
		guard !identity.title.isEmpty, !identity.artist.isEmpty else { return nil }
		return candidates.first { candidate in
			let match = Identity(title: candidate.title, artist: candidate.artist, album: candidate.album)
			return match.title == identity.title && match.artist == identity.artist
				&& (identity.album.isEmpty || match.album == identity.album)
				&& candidate.artworkURL != nil
		}?.artworkURL
	}

	/// Lowercased, without diacritics or punctuation, and with single spaces.
	static func normalize(_ text: String) -> String {
		let folded = text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
		let allowed = CharacterSet.alphanumerics.union(.whitespaces)
		return String(folded.unicodeScalars.filter { allowed.contains($0) }).split(separator: " ").joined(
			separator: " ")
	}
}
