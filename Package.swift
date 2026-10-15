// swift-tools-version: 6.2
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
	name: "DiscordPresenceKit",
	platforms: [.iOS(.v16), .macOS(.v13)],
	products: [
		.library(name: "DiscordPresenceKit", targets: ["DiscordPresenceKit"])
	],
	targets: [
		.target(name: "DiscordPresenceKit"),
		.testTarget(name: "DiscordPresenceKitTests", dependencies: ["DiscordPresenceKit"]),
	]
)
