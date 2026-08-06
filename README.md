# Myseum

A native iOS app that turns your photos into a museum of your past — the photos and
videos you take during a calendar event automatically appear grouped under that
event, like a visual diary. Inspired by Slopes' ski-trip photo grouping.

## Stack
- **SwiftUI**, iOS 18+, Swift 5 language mode
- Project generated with **[XcodeGen](https://github.com/yonyz/XcodeGen)** from `project.yml` (the `.xcodeproj` is generated, not committed)
- **EventKit** (Apple Calendar) + **Google Calendar** (read-only) for events
- **PhotoKit** for matching photos/videos to events by timestamp
- **[Supabase](https://supabase.com)** for accounts, friends, shared events, and push tokens
- **GoogleSignIn** for Google sign-in + calendar
- **APNs** push via a Supabase Edge Function

## The core idea

You already keep a calendar. You already take photos. Myseum is the thread between
them.

Whatever you capture during an event's time window — brunch with a friend, a
weekend trip, someone's birthday — is automatically gathered under that event. No
albums to make, no tagging, no sorting. You just live the day; the photos and
videos find their way home to the moment they belong to.

The result is a calendar that remembers. Each event becomes an exhibit, and your
past turns into a museum you can walk back through — a diary written entirely in
the pictures you were already taking.

## Getting started
1. Install XcodeGen: `brew install xcodegen`
2. Copy `Secrets.example.swift` → `Sources/Config/Secrets.swift` and fill in your
   Supabase URL/anon key and Google client IDs (this file is gitignored).
3. Run the Supabase SQL in `supabase/*.sql` on your project, and deploy the
   `supabase/functions/notify-invite` Edge Function (see its `SETUP.md`).
4. `xcodegen generate` then open `Myseum.xcodeproj`.

## Build / distribute
```sh
xcodegen generate
xcodebuild -project Myseum.xcodeproj -scheme Myseum \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
TestFlight builds use `xcodebuild archive` + `-exportArchive` with an App Store
Connect API key (see `ExportOptions.plist`).
