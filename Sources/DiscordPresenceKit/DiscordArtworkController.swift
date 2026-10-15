// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Finds a public cover for the playing song, which Discord fetches itself.
public protocol ArtworkResolver: Sendable {
	/// A public HTTPS cover for the song, or nil when this resolver has none.
	func artworkURL(for snapshot: PlaybackSnapshot) async throws -> URL?
}

@MainActor
public final class DiscordArtworkController {
	public enum Phase: String { case idle, lookingUp, resolved, failed }
	private struct Identity: Hashable {
		let track: String
		let title: String
		let artist: String
		let album: String
		let artworkID: String?
		let source: URL?
	}

	public private(set) var url: URL?
	public private(set) var phase: Phase = .idle
	public var hasWork: Bool { task != nil }
	public var onChange: (() -> Void)?
	private let resolvers: [any ArtworkResolver]
	private var identity: Identity?
	private var generation: UInt64 = 0
	private var task: Task<Void, Never>?
	private var resolvedURLs: [Identity: URL] = [:]
	private var resolutionOrder: [Identity] = []
	private let resolvedURLLimit = 64

	/// Asks each resolver in turn, publishing the first cover one finds.
	public init(resolvers: [any ArtworkResolver]) {
		self.resolvers = resolvers
	}

	/// Searches the iTunes catalog first, then the Cover Art Archive.
	public convenience init() {
		self.init(resolvers: [ITunesArtworkResolver(), CoverArtArchiveResolver()])
	}

	public func update(
		snapshot: PlaybackSnapshot?, enabled: Bool, allowWork: Bool, allowFinishingWork: Bool = false
	) {
		guard enabled, let snapshot, snapshot.state != .stopped, snapshot.state != .failed else {
			cancelWork()
			identity = nil
			url = nil
			return
		}
		let next = Identity(
			track: snapshot.trackID, title: snapshot.title, artist: snapshot.artist,
			album: snapshot.album, artworkID: snapshot.artworkID, source: snapshot.artworkURL)
		if next != identity {
			// Preserve a resolved cover only for the same artwork revision.
			let retained =
				identity?.track == next.track && identity?.artworkID == next.artworkID
					&& identity?.source == next.source ? url : nil
			cancelWork()
			identity = next
			url = DiscordPresencePayload.publicArtworkURL(snapshot.artworkURL) ?? resolvedURLs[next] ?? retained
		}
		guard allowWork else {
			if task != nil, !allowFinishingWork { cancelWork() }
			return
		}
		guard task == nil, phase == .idle, url == nil else { return }
		phase = .lookingUp
		let revision = generation
		task = Task { [weak self, resolvers] in
			// Match the publication assembly window, so rapid skips never start a lookup.
			try? await Task.sleep(for: .seconds(0.1))
			guard let self, !Task.isCancelled, self.generation == revision else { return }
			for resolver in resolvers {
				let found = DiscordPresencePayload.publicArtworkURL(try? await resolver.artworkURL(for: snapshot))
				guard !Task.isCancelled, self.generation == revision else { return }
				if let found {
					self.finish(url: found)
					return
				}
			}
			self.finish(url: nil)
		}
	}

	public func cancelWork() {
		if task != nil {
			PresenceDiagnostics.record("artwork generation=\(generation) cancelled phase=\(phase.rawValue)")
		}
		generation &+= 1
		task?.cancel()
		task = nil
		phase = .idle
	}

	public func retry() {
		cancelWork()
		onChange?()
	}

	private func finish(url: URL?) {
		self.url = url
		if let identity, let url { remember(url, for: identity) }
		task = nil
		phase = url != nil ? .resolved : .failed
		PresenceDiagnostics.record(
			"artwork generation=\(generation) finished phase=\(phase.rawValue) url=\(url?.absoluteString ?? "none")")
		onChange?()
	}

	private func remember(_ url: URL, for identity: Identity) {
		resolutionOrder.removeAll { $0 == identity }
		resolutionOrder.append(identity)
		resolvedURLs[identity] = url
		while resolutionOrder.count > resolvedURLLimit {
			resolvedURLs.removeValue(forKey: resolutionOrder.removeFirst())
		}
	}
}
