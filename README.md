# Glance for iOS

Receive short messages from **your own backend** as iOS notifications that mirror
to your [Even Realities G2](https://www.evenrealities.com/) smart glasses via the
Even app's notification forwarding.

Glance does not connect to the glasses directly. It receives a push or polls your
backend, surfaces the result as a standard iOS system notification, and the Even
app forwards it to the lens.

- **Push by default:** your backend sends APNs pushes directly to the device.
  No shared relay, no intermediary service.
- **Your backend:** you configure the URL and token. Nothing is sent to any service
  this project operates.
- **Multiple watchers:** separate backends with independent credentials.
- **Optional polling:** scheduled checks at a minimum of 15 minutes (iOS-enforced).
- **All local:** configuration stays in iOS UserDefaults. No account, no sync,
  no telemetry.

---

## Requirements

- iOS 17.0+
- [Xcode 15+](https://developer.apple.com/xcode/)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An [Apple Developer](https://developer.apple.com/) account (for push; free
  account works for TestFlight / personal use)

---

## Setup

### 1. Generate the Xcode project

```bash
git clone https://github.com/toladele/glance-ios
cd glance-ios
xcodegen generate
open Glance.xcodeproj
```

### 2. Configure signing

In Xcode, select the **Glance** target → **Signing & Capabilities** → set your
**Team**. Automatic signing handles the rest.

Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` (and regenerate) if you need
a different bundle ID — for example if you already have `dev.glance.ios` registered.

### 3. Enable push entitlement (for push mode)

The `Glance.entitlements` file ships with `aps-environment: development`. This is
correct for TestFlight and direct device installs. For App Store distribution,
change it to `production` before archiving.

### 4. Configure your backend

Add a watcher in the app: **+** → enter name, backend URL, token, and mode. For
push mode, tap **Register for push** after adding the watcher. See
[`docs/CONTRACT.md`](docs/CONTRACT.md) for the full backend API.

---

## Regimen backend

If you run [Regimen](https://github.com/toladele/regimen), APNs push is built in.
Add to your `.env`:

```
APNS_TEAM_ID=XXXXXXXXXX
APNS_KEY_ID=XXXXXXXXXX
APNS_PRIVATE_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
APNS_BUNDLE_ID=dev.glance.ios
# APNS_SANDBOX=true   # uncomment for development builds
```

Get the key from [Apple Developer → Certificates → Keys](https://developer.apple.com/account/resources/authkeys/list).
The Regimen server will store registered device tokens and deliver the daily
summons via APNs.

---

## How it works

```
backend → APNs → Glance (iOS) → system notification → Even app → G2 lens
```

Push mode requires your backend to construct and sign the APNs HTTP/2 request
with a key from your Apple Developer account. The backend contract is in
[`docs/CONTRACT.md`](docs/CONTRACT.md).

Poll mode periodically hits `POST /poll` and shows any returned content as a
local notification. The iOS system enforces a minimum interval of 15 minutes
and may run it later — it is best-effort.

---

## Licence

MIT. See `LICENSE`.
