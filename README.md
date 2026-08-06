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

## Features
- Events, Calendar, and Account tabs with a Liquid-Glass floating nav
- Photos/videos matched to events by capture time; remove a photo from an event
- Create / edit / delete events (Apple Calendar, or an in-app local store when there's no calendar)
- Calendar month grid with a pull-up day sheet; expand an event to see its photos
- Search events by name and date
- Hide individual events, multi-select, and hide whole recurring series
- Accounts, profile photo + username, friends via link/QR, shared event invites
- Push notifications on event invites
- Theme color, custom app icon

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
