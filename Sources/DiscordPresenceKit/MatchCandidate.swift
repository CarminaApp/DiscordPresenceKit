// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A song from the iTunes catalog that may share a cover with the song being played.
struct MatchCandidate: Sendable {
	let title: String
	let artist: String
	let album: String
	/// Upscaled to 600 × 600.
	let artworkURL: URL?
}
