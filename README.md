# ClearSMS

A clean, ad-free SMS app for Android. Samsung Messages-style interface with
Microsoft SMS Organizer-style smart inbox — all classification runs on-device,
nothing leaves the phone.

## Features

- **Smart inbox** — messages are automatically sorted into four tabs:
  - **Personal** — people and saved contacts
  - **Transactions** — bank alerts, bills, deliveries, services
  - **OTP** — verification codes and one-time passwords
  - **Promotions** — offers and marketing, **silenced by default**
- **Smart OTP notifications** — the code is surfaced in the notification title
  with a one-tap **Copy code** action; no need to open the app
- **No ads, no tracking** — the rule-based classifier runs entirely on-device
- **Default SMS app** — full send/receive support via the Android SMS role
  (Telephony provider, `SMS_DELIVER` receiver, respond-via-message service)
- One UI-inspired look: large collapsing header, category chips with unread
  counts, search, chat bubbles with day headers, light + dark themes

## Architecture

- **Flutter UI** ([lib/](lib/)) — home, thread, compose and settings screens;
  a single `SmsStore` (ChangeNotifier) talks to the platform over the
  `clear_sms/core` method channel.
- **Kotlin core** ([android/.../clear_sms/](android/app/src/main/kotlin/com/dhivalabs/clear_sms/)) —
  - `SmsRepository` — Telephony provider queries, sending, contact lookup
  - `SmsClassifier` — category rules + OTP extraction (shared by UI and notifications)
  - `SmsDeliverReceiver` — persists incoming SMS and posts categorized notifications
  - `NotificationHelper` — four channels: Personal/OTP (high), Transactions
    (default), Promotions (low/silent)

## Building

```sh
flutter build apk --release
```

Requires Android 8.0+ (API 26). On first launch, grant SMS/contacts/notification
permissions and set ClearSMS as the default SMS app from the banner or Settings.

## RCS

Not supported — and not possible: Android exposes no RCS API to third-party
apps (Google restricts RCS to Google Messages; the only third-party API is a
hidden allowlist used by Samsung's own apps). While ClearSMS is the default
SMS app, RCS conversations pause and senders fall back to SMS. Settings
explains this and offers a one-tap shortcut to Android's default-apps screen
to switch back to Google Messages temporarily when RCS is needed.

## Not yet implemented

- MMS receiving/sending (receiver stub exists for the default-app role)
- Dual-SIM selection, scheduled send, backup

## Sponsors

Dhiva Labs is an independent, self-funded lab. [Sponsorships](https://github.com/sponsors/Dhiva-Labs) help bring this project and the rest of Dhiva Labs to every platform, iPhone and Mac included.

[![Sponsor Dhiva Labs](https://img.shields.io/badge/Sponsor-Dhiva%20Labs-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Dhiva-Labs)

Monthly sponsors at $10 and up are listed here:

<!-- sponsors -->
*Be the first: [sponsor Dhiva Labs](https://github.com/sponsors/Dhiva-Labs).*
<!-- sponsors -->
