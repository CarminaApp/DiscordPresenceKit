# DiscordPresenceKit

Shows what you're listening to as a Discord activity, from a Swift music app. Built for [Carmina](https://github.com/CarminaApp/Carmina), usable by any app.

It takes care of the parts that are the same in every app:

- **Payload:** turns a `PlaybackSnapshot` into the activity's song, artist, album, cover and progress, within Discord's field limits, with privacy switches for album, cover and timer.
- **Timing:** coalesces the burst of events around a track change, keeps pause and resume immediate, and backs off on failures and Discord's rate limits (`PresencePublicationPolicy`, `PresenceSchedule`, `PresenceTimeline`).
- **Delivery:** sends only the newest activity, one update at a time, so a slow request never shows a stale song (`PresenceDelivery`).
- **Covers:** Discord needs a public HTTPS image, so covers are found, never uploaded. `DiscordArtworkController` uses the source's own public cover when there is one, and otherwise asks its resolvers in order: by default the iTunes catalog, then the Cover Art Archive for songs tagged with a MusicBrainz release ID. Apps can supply their own `ArtworkResolver`s. Private server URLs and credentials are never sent.

## What it doesn't include

The connection to Discord. On iOS that requires Discord's closed-source Social SDK, which you obtain from Discord under its own terms. Your app wraps the SDK and feeds it the payloads this package produces; this package never links or ships the SDK.

## Requirements

iOS 16 or macOS 13, Swift 6.2.

```swift
.package(url: "https://github.com/CarminaApp/DiscordPresenceKit", branch: "main")
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
