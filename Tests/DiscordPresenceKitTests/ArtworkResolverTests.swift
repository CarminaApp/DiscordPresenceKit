// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import DiscordPresenceKit

private func snapshot(
	title: String = "Blue Monday", artist: String = "New Order", album: String = "Power, Corruption & Lies",
	releaseID: String? = nil
) -> PlaybackSnapshot {
	PlaybackSnapshot(
		trackID: "a", title: title, artist: artist, album: album,
		position: 0, duration: 10, rate: 1, state: .playing, musicBrainzReleaseID: releaseID)
}

@Test func iTunesFindsTheCatalogCoverOfTheSameSong() async throws {
	let cover = URL(string: "https://is1.mzstatic.com/blue-monday.jpg")!
	let resolver = ITunesArtworkResolver(
		lookup: CatalogArtworkLookup { _ in
			[
				MatchCandidate(title: "Blue Monday '88", artist: "New Order", album: "Substance", artworkURL: nil),
				MatchCandidate(
					title: "Blue Monday", artist: "New Order", album: "Power, Corruption & Lies", artworkURL: cover),
			]
		})
	#expect(try await resolver.artworkURL(for: snapshot()) == cover)
}

private let releaseID = "8e2c1c2a-4b0a-4f0e-9d8a-2a3e1f6b7c90"

/// Answers every request with the status in the session's X-Test-Status header, and records the requests.
private final class CoverArtArchiveProtocol: URLProtocol, @unchecked Sendable {
	private static let lock = NSLock()
	nonisolated(unsafe) private static var requests: [String: [URLRequest]] = [:]

	static func requests(_ id: String) -> [URLRequest] {
		lock.lock()
		defer { lock.unlock() }
		return requests[id] ?? []
	}

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
	override func startLoading() {
		Self.lock.lock()
		Self.requests[request.value(forHTTPHeaderField: "X-Test-ID") ?? "", default: []].append(request)
		Self.lock.unlock()
		let status = Int(request.value(forHTTPHeaderField: "X-Test-Status") ?? "") ?? 200
		let response = HTTPURLResponse(
			url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "image/jpeg"])!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocolDidFinishLoading(self)
	}
	override func stopLoading() {}
}

private func coverArtArchive(status: Int = 200, id: String) -> CoverArtArchiveResolver {
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [CoverArtArchiveProtocol.self]
	configuration.httpAdditionalHeaders = ["X-Test-ID": id, "X-Test-Status": String(status)]
	return CoverArtArchiveResolver(session: URLSession(configuration: configuration))
}

@Test func coverArtArchiveUsesTheReleaseFrontCover() async throws {
	let id = UUID().uuidString
	let url = try await coverArtArchive(id: id).artworkURL(for: snapshot(releaseID: releaseID))
	#expect(url == URL(string: "https://coverartarchive.org/release/\(releaseID)/front-500"))
	#expect(CoverArtArchiveProtocol.requests(id).map(\.httpMethod) == ["HEAD"])
}

@Test func coverArtArchiveIsNotAskedWithoutAValidReleaseID() async throws {
	for releaseID in [nil, "", "not-an-id", "../../admin", "8E2C1C2A-4B0A-4F0E-9D8A-2A3E1F6B7C90?x=1"] {
		let id = UUID().uuidString
		#expect(try await coverArtArchive(id: id).artworkURL(for: snapshot(releaseID: releaseID)) == nil)
		#expect(CoverArtArchiveProtocol.requests(id).isEmpty)
	}
}

@Test func aReleaseWithoutACoverOnCoverArtArchiveHasNone() async throws {
	let url = try await coverArtArchive(status: 404, id: UUID().uuidString)
		.artworkURL(for: snapshot(releaseID: releaseID))
	#expect(url == nil)
}
