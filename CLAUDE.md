# Bloom: CLAUDE.md

An iOS 17+ Screen Time app (SwiftUI + FamilyControls / ManagedSettings / DeviceActivity). See README.md for build steps and architecture.
Keep this file up to date when you learn a new project fact, brand decision or platform constraint.

## Product rules (decided with the owner)
- Single user, self-control: `AuthorizationCenter.requestAuthorization(for: .individual)`.
- Features: daily app limits, downtime schedules, usage dashboard, and an adult website filter that is **always on**.
- Adult filter unlock: PIN, then a **10 minute countdown**, then off for **5, 10, 15 or 30 minutes only** (nothing longer), then it turns back on by itself. Cancelling or relocking early never needs the PIN.
- Limits and downtime: the PIN unlocks immediately for 15, 30 or 60 minutes. Editing, deleting or pausing an existing rule needs the PIN. Creating rules or making them stricter does not.
- The values live in `Shared/Core/BloomConfig.swift`.

## Architecture invariants
- All state lives in `BloomData` (App Group UserDefaults, via `SharedStore`). Never keep rule state anywhere else.
- `Enforcer.reconcile(now:)` must stay idempotent and derive everything from `BloomData` plus the time. Callbacks only record facts (e.g. "limit reached today"), then reconcile.
- One ManagedSettingsStore per rule (`limit.<uuid>`, `downtime.<uuid>`), plus `web` for the content filter.
- DeviceActivity intervals must be at least 15 minutes, so use `Scheduler.scheduleWakeUp` (end warning trick) for shorter timers. Apps are limited to 20 monitored activities.
- The monitor and shield extensions have tight memory limits. They compile only `Shared/Core` (+ `Shared/Palette` for the shield). Never import SwiftUI there.
- Unlocking from the shield happens through a notification plus `pendingUnlockRequestAt`, because extensions can't open the app.

## Brand (from the Bloom brand guidelines PDF)
- Name: **Bloom**. Mark: white line-art tulip on a lavender rounded square (`BloomMark` asset, `AppIcon`).
- Colors: lavender `#D1A0F3` (primary), white, cream `#EDE1B6`, soft gray canvas `#E8E8E8`, near-black ink. `lavenderInk` `#7A45B0` is only for small lavender text and icons that need contrast. Tokens are in `Shared/Palette` and `Shared/UI/BloomTheme.swift`. Don't add raw hex values in views.
- Type: Poppins SemiBold for headings (bundled in `Fonts/`). Canva Sans is the body face but can't be licensed outside Canva, so the body uses the system font.
- Look: oversized uppercase titles with tight tracking, a hairline rule, and a short description aligned right; big softly rounded slabs (radius 32), the thin up-right arrow motif on hero cards. Black and white logo variant means dark mode is supported.
- Tone: approachable, professional, uplifting. Text on lavender or cream is near-black (`bloomOnAccent`); large display text may be white on lavender.
- Copy: short, warm, no guilt. No em dashes.
