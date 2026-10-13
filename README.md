# Bloom

A Screen Time app for iPhone (iOS 17+), built with SwiftUI and Apple's Screen Time frameworks
(FamilyControls, ManagedSettings, DeviceActivity).

- **Daily limits:** choose apps, categories or sites and give them a daily time budget. When it runs out, they're blocked until midnight.
- **Downtime:** block chosen apps during set hours, on chosen days (overnight windows work too).
- **Adult website filter, always on:** uses Apple's built-in adult content filter, the same one Screen Time uses, plus any sites you add yourself.
  Turning it off temporarily needs your **PIN**, which starts a **10 minute countdown**. After that the filter is off for **5, 10, 15 or 30 minutes** (your choice) and then turns itself back on. You can cancel the countdown at any time.
- **PIN:** any change that could loosen a rule (editing, deleting, unlocking) needs a 4-digit PIN. Making things stricter never does.
- **Usage dashboard:** screen time today or this week, pickups, and your most used apps.

## Build it

You need a Mac with Xcode 15 or newer, and a real iPhone. Screen Time features don't work in the Simulator.

1. Install XcodeGen and generate the project:
   ```sh
   brew install xcodegen
   xcodegen generate
   open Bloom.xcodeproj
   ```
2. In `project.yml`, set `DEVELOPMENT_TEAM` to your Apple team ID. If you change `BLOOM_BUNDLE_ID` or `BLOOM_APP_GROUP`, change only those values and run `xcodegen generate` again; everything else picks them up automatically.
3. In the Apple Developer portal, under Identifiers, register an App Group matching `BLOOM_APP_GROUP`. With automatic signing, Xcode usually does this for you.
4. Select the **Bloom** scheme, choose your iPhone and run.

### The Family Controls entitlement

All five targets use `com.apple.developer.family-controls`. **During development this works on your own devices without approval.**
To ship through TestFlight or the App Store, request the distribution entitlement at
<https://developer.apple.com/contact/request/family-controls-distribution> for the app **and each extension's** bundle ID.

## How it's put together

| Target | What it does |
| --- | --- |
| `Bloom` | The SwiftUI app: onboarding, Today, Limits, Downtime, Web, Settings. |
| `BloomMonitor` | DeviceActivity monitor. iOS wakes it when a limit is used up, a downtime starts or ends, or an unlock timer finishes, even when Bloom isn't running. |
| `BloomShieldConfiguration` | Draws the branded screen shown over a blocked app or site. |
| `BloomShieldAction` | Handles that screen's buttons. "Unlock with PIN" sends a notification that opens Bloom's unlock screen (extensions can't open apps directly). |
| `BloomReport` | DeviceActivityReport extension that draws the usage dashboard. Apple only gives usage data to this extension, never to the app itself. |

`Shared/Core` holds the data model and enforcement logic used by every target:

- `SharedStore` keeps all rules in the App Group so the app and extensions share one source of truth.
- `Enforcer.reconcile()` recomputes every restriction from that state. The app and the monitor both call it all the time, so state can never drift.
- `Scheduler` registers the DeviceActivity schedules. iOS needs intervals of at least 15 minutes, so short timers (like the 10 minute countdown) use an interval's end warning to fire at the exact moment.

## Limits of what iOS allows

- **Bloom never sees which apps you have.** You choose them in Apple's picker, and Bloom only gets anonymous tokens. Names and icons are drawn by the system.
- **Anyone holding the phone can turn off Screen Time access** in Settings > Screen Time, or delete Bloom. Either one removes all restrictions. iOS only blocks that for child accounts managed through Family Sharing.
- iOS lets one app track up to 20 schedules at once. Each limit uses 1, a downtime that runs every day uses 1, and a downtime on specific days uses 1 per day. Bloom warns you if a change would go over.
- The adult filter covers Safari and apps that use Apple's web views. Browsers with their own engines aren't covered. To be safe, add those browsers to a limit or downtime.

## Fonts

The brand uses Poppins SemiBold (included, under the SIL Open Font License, see `Fonts/OFL.txt`) and Canva Sans.
Canva Sans is only licensed for use inside Canva, so body text uses the system font instead.
