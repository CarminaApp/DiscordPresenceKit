// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct ITunesSearchClient: Sendable {
	private let session: URLSession

	init(session: URLSession = .shared) {
		self.session = session
	}

	func search(term: String, limit: Int = 15) async throws
		-> [MatchCandidate]
	{
		var comps = URLComponents(string: "https://itunes.apple.com/search")!
		comps.queryItems = [
			.init(name: "term", value: term),
			.init(name: "media", value: "music"),
			.init(name: "entity", value: "song"),
			.init(name: "limit", value: String(limit)),
		]
		guard let url = comps.url else { return [] }
		let (data, _) = try await session.data(from: url)
		return try JSONDecoder()
			.decode(SearchResponse.self, from: data)
			.results.map(\.candidate)
	}
}

private struct SearchResponse: Decodable {
	let results: [Result]

	struct Result: Decodable {
		let trackName: String?
		let artistName: String?
		let collectionName: String?
		let artworkUrl100: String?

		var candidate: MatchCandidate {
			let art = artworkUrl100?
				.replacingOccurrences(of: "100x100", with: "600x600")
			return MatchCandidate(
				title: trackName ?? "",
				artist: artistName ?? "",
				album: collectionName ?? "",
				artworkURL: art.flatMap(URL.init(string:))
			)
		}
	}
}
