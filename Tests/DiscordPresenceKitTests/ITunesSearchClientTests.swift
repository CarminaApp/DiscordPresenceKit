// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import DiscordPresenceKit

@Suite struct ITunesSearchClientTests {
	@Test func decodesAndUpscalesArtwork() async throws {
		let json = """
			{"resultCount":1,"results":[{
			  "trackId":123,"trackName":"Bohemian Rhapsody","artistName":"Queen",
			  "collectionName":"A Night at the Opera","trackTimeMillis":354947,
			  "artworkUrl100":"https://example.com/a/100x100bb.jpg"}]}
			"""
		MockURLProtocol.stubData = Data(json.utf8)
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [MockURLProtocol.self]
		let client = ITunesSearchClient(
			session: URLSession(configuration: config)
		)

		let results = try await client.search(term: "queen bohemian rhapsody")
		#expect(results.count == 1)
		#expect(results[0].title == "Bohemian Rhapsody")
		#expect(
			results[0].artworkURL?.absoluteString.contains("600x600bb") == true
		)
	}
}

final class MockURLProtocol: URLProtocol {
	nonisolated(unsafe) static var stubData: Data?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest {
		request
	}
	override func startLoading() {
		if let data = MockURLProtocol.stubData {
			let response = HTTPURLResponse(
				url: request.url!,
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			)!
			client?.urlProtocol(
				self,
				didReceive: response,
				cacheStoragePolicy: .notAllowed
			)
			client?.urlProtocol(self, didLoad: data)
		}
		client?.urlProtocolDidFinishLoading(self)
	}
	override func stopLoading() {}
}
