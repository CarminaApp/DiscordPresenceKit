// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Tracks desired state separately from an outstanding network update.
public struct PresenceDelivery: Sendable {
	public struct Ticket: Equatable, Sendable {
		public let revision: UInt64
		public let payload: DiscordPresencePayload
	}

	public private(set) var desired: DiscordPresencePayload?
	public private(set) var inFlight: Ticket?
	public private(set) var revision: UInt64 = 0
	private var delivered: DiscordPresencePayload?
	private var needsDelivery = true

	public init() {}

	public mutating func setDesired(_ payload: DiscordPresencePayload?) {
		guard payload != desired else { return }
		desired = payload
		revision &+= 1
		needsDelivery = true
	}

	public mutating func reconnect() {
		inFlight = nil
		delivered = nil
		needsDelivery = true
		revision &+= 1
	}

	public mutating func begin() -> Ticket? {
		guard inFlight == nil, needsDelivery, let desired else { return nil }
		if delivered == desired { needsDelivery = false; return nil }
		let ticket = Ticket(revision: revision, payload: desired)
		inFlight = ticket
		return ticket
	}

	public mutating func complete(_ ticket: Ticket, successful: Bool, retryable: Bool) {
		guard inFlight == ticket else { return }
		inFlight = nil
		if successful && ticket.revision == revision { delivered = ticket.payload }
		needsDelivery = ticket.revision != revision || (!successful && retryable)
	}

	public mutating func cleared() {
		delivered = nil
		// Keep the outstanding ticket so a late completion can be followed by another clear.
		if desired == nil { needsDelivery = false }
	}
}
