// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Uses the front cover the Cover Art Archive holds for the song's MusicBrainz release, without searching.
public struct CoverArtArchiveResolver: ArtworkResolver {
	private let session: URLSession

	public init(session: URLSession = .shared) {
		self.session = session
	}

	public func artworkURL(for snapshot: PlaybackSnapshot) async throws -> URL? {
		guard let id = snapshot.musicBrainzReleaseID.flatMap(UUID.init(uuidString:)) else { return nil }
		let url = URL(string: "https://coverartarchive.org/release/\(id.uuidString.lowercased())/front-500")!
		// Check the release has a front cover, so Discord isn't handed a link that leads nowhere.
		var request = URLRequest(url: url)
		request.httpMethod = "HEAD"
		let (_, response) = try await session.data(for: request)
		switch (response as? HTTPURLResponse)?.statusCode {
		case 200: return url
		case 404: return nil
		default: throw URLError(.badServerResponse)
		}
	}
}
