# CLAUDE.md — contributor & agent guide

Guidance for anyone (human or AI) working on this repo. It captures the setup,
the build flow, and the **non-obvious traps** that have already cost real debugging
time so you don't hit them again. Keep it current: when you discover a new gotcha,
add it here in the same turn you fix it.

> Do not put secrets, personal hostnames, team IDs, key IDs, device UDIDs, or tokens
> in this file. Everything here must be true for *any* developer cloning the repo.

---

## What this app is

A native SwiftUI app that turns messages from **your own backend** into iOS system
notifications, which the Even Realities Even app then mirrors to G2 glasses. It never
talks to the glasses directly. Two delivery modes:

- **Push** — your backend sends an APNs push to the device (preferred; works when the
  app is closed).
- **Poll** — the app checks your backend on a schedule (15 min minimum, iOS-enforced).

Config (backend URL + bearer token per "watcher") lives only in `UserDefaults` on the
device. See `README.md` for the user-facing overview and `docs/CONTRACT.md` for the
backend HTTP contract.

---

## Project layout

```
project.yml            # SOURCE OF TRUTH for the Xcode project (xcodegen)
Glance.entitlements    # entitlements (also generated from project.yml properties)
Glance/                # app sources
  GlanceApp.swift        # @main; requests notification auth on launch
  AppDelegate.swift      # APNs token callbacks, foreground banner
  PushManager.swift      # auth + APNs registration + POST /register-device
  PollManager.swift      # BGAppRefreshTask + POST /poll
  WatcherStore.swift     # persistence of watchers (UserDefaults JSON)
  Watcher.swift          # model
  ContentView.swift / WatcherDetailView.swift / WatcherEditView.swift  # UI
docs/CONTRACT.md       # backend endpoint contract
```

**`project.yml` is authoritative.** The `.xcodeproj` is generated — never hand-edit it.
After changing `project.yml` (or adding/removing source files), run `xcodegen generate`.

---

## Building & running

```sh
brew install xcodegen              # one-time
xcodegen generate                  # regenerate the .xcodeproj

# Build for a connected device. Pass your team at build time; do NOT commit it.
xcodebuild \
  -project Glance.xcodeproj \
  -scheme Glance \
  -configuration Debug \
  -destination 'id=<DEVICE_UDID>' \
  DEVELOPMENT_TEAM=<YOUR_TEAM_ID> \
  -allowProvisioningUpdates \
  clean build

# Install to the device
xcrun devicectl device install app --device <DEVICE_ID> <path>/Glance.app
```

`DEVELOPMENT_TEAM` is intentionally blank in `project.yml` so no one's team leaks into
git. Supply it on the command line (or via a local xcconfig you don't commit).

### Two different device ID formats — they are not interchangeable

- `xcodebuild -destination 'id=…'` wants the **traditional UDID** (from
  `xcrun xctrace list devices`, e.g. `00008130-…`).
- `xcrun devicectl device …` wants the **CoreDevice ID** (from
  `xcrun devicectl list devices`, a different UUID).

Using one where the other is expected fails with confusing errors. List both:

```sh
xcrun xctrace list devices          # traditional UDID (for xcodebuild)
xcrun devicectl list devices        # CoreDevice ID (for devicectl)
```

---

## Push notifications: the traps that actually bite

Getting an APNs device token requires **three** things to line up. If any is wrong you
get *no token* and the "Register for push" button never activates. Diagnose in order:

### 1. The entitlement key must be exactly `aps-environment`

Not `com.apple.developer.aps-environment`. The prefixed form looks plausible and even
appears in some docs, but it is **wrong**: `codesign` silently drops any entitlement the
provisioning profile doesn't authorize, and the profile authorizes the bare key. The app
then ships with no push entitlement and iOS fails registration with:

> no valid 'aps-environment' entitlement string found for application

**Always verify what actually made it into the binary** — the entitlements *file* lying
to you is exactly how this hides:

```sh
codesign -d --entitlements :- <path>/Glance.app
# must list:  <key>aps-environment</key><string>development</string>
```

`development` for debug/sideload, `production` for App Store / release. If it's missing
here, fix it before touching anything else.

### 2. Push Notifications must be enabled on the App ID (in the developer portal)

If the capability isn't enabled for the bundle ID, the generated profile won't grant
`aps-environment` and step 1's check will fail no matter what your entitlements file says.

- The **Xcode GUI** enables it automatically when you add the Push Notifications
  capability under *Signing & Capabilities* (this also registers it on the portal).
- **`xcodebuild -allowProvisioningUpdates` does NOT enable capabilities.** It only
  creates/refreshes provisioning profiles and registers devices. Enabling a *capability*
  on the App ID is a separate action — do it via the Xcode GUI or the App Store Connect
  API (`bundleIdCapabilities`).

### 3. `registerForRemoteNotifications()` must be called when already authorized

A device token only arrives after `UIApplication.registerForRemoteNotifications()` is
called *and* `didRegisterForRemoteNotificationsWithDeviceToken` fires. A common bug:
only calling it right after the permission prompt is answered. If the user already
granted notifications (e.g. enabled them in Settings after a prior denial, or reinstalled),
the prompt returns "not granted right now" and registration is skipped — so no token.

`PushManager.requestAuthorization()` handles this by checking the current authorization
status first and calling `registerForRemoteNotifications()` directly when already
authorized. Preserve that behavior.

### Debugging aids built into the app

- APNs registration failures are stored in `UserDefaults` under `glance.apnsError` and
  surfaced in the watcher detail view. Read that string first — it usually names the
  exact problem (entitlement, network, etc.).
- The device token is stored under `glance.deviceToken`. `WatcherDetailView` reads it via
  `@AppStorage` so the UI re-renders the moment the token arrives (a plain computed
  property will *not* refresh — SwiftUI only reads it once).

---

## Backend registration failures ("backend rejected")

`POST /register-device` returning non-2xx surfaces as an error with the HTTP status.
Match the status to the cause:

- **401** — the bearer token in the watcher doesn't match the backend's expected token.
  They must be byte-for-byte identical.
- **400** — malformed payload; usually the device token isn't 64 lowercase hex chars
  (i.e. no real APNs token yet — fix push registration first).
- **404 / connection errors** — the backend URL is wrong. Check scheme, host, port, path.

### URL / TLS gotchas when the backend is on a private network

- **Use the exact scheme.** If the backend serves HTTPS, an `http://` URL fails at the
  transport layer (and vice versa). The symptom of hitting an HTTPS port with plain HTTP
  is a 400 whose body reads *"Client sent an HTTP request to an HTTPS server"* — it has
  nothing to do with your payload. To reduce this footgun, `Watcher.trimmedURL` prepends
  `https://` to a **bare host** (no scheme), and the edit form previews the resolved URL
  and warns on an explicit `http://`. An explicit `http://` is still respected for
  trusted local networks — it is not silently upgraded.
- **The hostname must match the TLS certificate.** A cert is issued for a specific name.
  Connecting by IP address or a short/alias hostname triggers a TLS handshake failure
  (e.g. `tlsv1 alert internal error`) even though the server is up. Use the full hostname
  the certificate was issued for.
- **`URLSession` requires a trusted certificate.** Self-signed certs are rejected by
  default. Either use a cert from a trusted CA or a platform (e.g. a mesh VPN) that issues
  real certs for its hostnames. Don't add trust-all overrides to the app.

### Reproduce registration from the command line

Before blaming the app, confirm the backend itself with `curl` (this isolates URL/token
issues from app bugs):

```sh
# Expect 401 without a token (proves the endpoint is reachable and auth is enforced)
curl -s -o /dev/null -w '%{http_code}\n' -X POST '<BASE_URL>/register-device' \
  -H 'Content-Type: application/json' -d '{}'

# Expect 204 with the right token and a well-formed (64-hex) device token
curl -s -o /dev/null -w '%{http_code}\n' -X POST '<BASE_URL>/register-device' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"device_token":"<64 hex chars>","watcher_id":"test","watcher_name":"test"}'
```

Never paste real tokens into the shell history or this repo; read them from a secret
store or an untracked env var (`$TOKEN` above).

---

## Conventions

- Keep configuration on-device only. No analytics, no third-party services, no account.
- Don't log message `text` content; it passes straight to notification delivery.
- Match the surrounding Swift style (comment density, naming). Comments explain *why*,
  not *what*.
- When you change the backend contract, update `docs/CONTRACT.md` in the same change.
- When you fix a setup/build trap, add it to this file in the same change.

---

## Quick preflight checklist

- [ ] `xcodegen generate` run after any `project.yml` / file changes
- [ ] `codesign -d --entitlements :-` on the built `.app` shows `aps-environment`
- [ ] Push Notifications capability enabled on the App ID in the portal
- [ ] App requests notification auth **and** registers when already authorized
- [ ] Backend URL uses the correct scheme, cert-matching host, and port
- [ ] Watcher token matches the backend token exactly
- [ ] `curl` reproduces `401` (no token) and `204` (correct token) against the backend
