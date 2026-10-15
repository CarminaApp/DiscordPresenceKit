// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OSLog

/// Development-only, structured events. Never pass credentials, response bodies or audio data.
public enum PresenceDiagnostics {
	private static let logger = Logger(subsystem: "DiscordPresenceKit", category: "DiscordPresence")
	private static let startedAt = ContinuousClock.now
	public static func record(_ message: @autoclosure () -> String) {
		#if DEBUG
		let text = message()
		let elapsed = startedAt.duration(to: .now).components
		let milliseconds = elapsed.seconds * 1_000 + elapsed.attoseconds / 1_000_000_000_000_000
		logger.notice("[DiscordPresence] t_ms=\(milliseconds) \(text, privacy: .public)")
		#endif
	}
}
