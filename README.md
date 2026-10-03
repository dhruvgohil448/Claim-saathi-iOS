# Claim Saathi (iOS)

iOS app for Claim Saathi, a health-insurance companion. Customers sign in with a mobile number, link a policy, start a cashless or reimbursement claim, upload documents, track settlement, and ask Saathi about their cover.

The app talks to the Claim Saathi API. It does not store claims on the device. The server is the source of truth.

## Requirements

- Xcode with the iOS 17 SDK or newer
- iOS 17.0 or newer
- An Apple development team for a device build
- The Claim Saathi server reachable from the simulator or phone

| Setting | Value |
|---|---|
| Display name | Claim Saathi |
| Bundle id | `com.claimsaathi.ios` |
| Deployment target | iOS 17.0 |
| Swift | 5 |
| Version | 1.0 |
| Orientation | Portrait only |
| Signing | Automatic. The project team id is `73AJY24UWM`. On another Mac, select your own team in Signing & Capabilities |

## Run

1. Open `ClaimSaathi.xcodeproj`.
2. Set the API base URL in `Info.plist` if the tunnel or host has changed.
3. Choose an iPhone simulator or a connected device.
4. Run the `ClaimSaathi` scheme.

From the command line (adjust the simulator name to one installed locally):

```bash
xcodebuild -project ClaimSaathi.xcodeproj -scheme ClaimSaathi \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

If Xcode reports missing types such as `AmountWarning`, `ChatCard`, or `PickedFile`, the source is out of date. Those types are defined in `ClaimSaathi/Features.swift`. The project uses a synchronized `ClaimSaathi` folder, so any `.swift` file in that folder is part of the target. Reset to the latest `main` and clean the build folder (Product → Clean Build Folder) before running again.

## API base URL

`Info.plist` key `API_BASE_URL` is the root the client appends paths to. It should end in `/api` (a trailing slash is optional; the client adds one).

```xml
<key>API_BASE_URL</key>
<string>https://your-host.example/api</string>
```

`API.shared` reads that key at launch. The checked-in value is a Cloudflare tunnel and will stop working when that tunnel is restarted.

## Sign-in

1. Enter a 10-digit phone number. The demo server does not send an SMS.
2. Enter the OTP. The demo code is always `111000`.
3. New users (`needsProfile`) complete name, email, date of birth (`yyyy-MM-dd`), gender, and city.
4. The JWT is stored in the Keychain under service `com.claimsaathi.auth`, account `jwt`, accessible after first unlock.
5. On the next launch, a saved token calls `GET me`. A `401` deletes the token and returns the user to login.

## Tabs and screens

Five tabs. Detail screens are pushed inside each tab's navigation stack.

| Tab or screen | What it does |
|---|---|
| Home | Greeting, paid-out and open-claim counts, active policy, current claim, pending actions, amount warnings, and shortcuts |
| Claims | Claim list |
| Chat | Saathi chat with suggestion chips, typing indicator, follow-ups, and finance cards |
| Alerts | Notifications, with an unread badge on the tab |
| Profile | Profile edit, bank, logout |
| Link a policy | Manual fields or a PDF. Empty fields are filled by the server demo cover. Room rent defaults to ₹4,000/day. Save stays enabled |
| Policy reader | Coverage summary |
| Start claim | Sample data, live amount warnings from `POST claims/preview`, then create the claim |
| Checklist | Required documents, camera / Photos / Files, and an n/7 progress bar |
| Validation | Result of the last upload |
| Claim tracking | Progress stepper, timeline, queries, settlement |
| Query reply | Explanation plus a text reply and an optional file |
| Settlement | Approved amount, deductions, payout |
| Bank | Masked payout account |
| Money | Linked accounts, monthly expenses, medical spend, and payouts from `GET me/finance` |

Ask Saathi on a claim opens Chat with that claim id so the answer stays on that case.

## Uploads

`PickedFile` in `Features.swift` accepts camera, photo library, and files.

- Camera and photo-library purpose strings are set on the target (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`).
- Images are downscaled to a 1600px long edge and saved as JPEG at quality 0.7.
- HEIC is converted to JPEG before upload.
- GET requests time out after 15 seconds. Other requests, including uploads and chat, use 90 seconds.

## Network

`ClaimSaathi/API.swift` is a small `URLSession` client:

- Bearer token on every request when the Keychain has one
- JSON nulls stripped before send
- Unknown JSON fields ignored by the models' custom decoders, which fall back to `.unknown` for unexpected enum values
- Errors use the server `error.message` when present
- `claims/{id}/summary.pdf` is opened as a URL with the token in the query string

Paths are relative to `API_BASE_URL`:

| Area | Calls |
|---|---|
| Auth | `POST auth/otp/send`, `POST auth/otp/verify` |
| Profile and home | `GET me`, `PUT`/`PATCH me/profile`, `GET me/home`, `GET me/finance` |
| Policies | list, detail, create (JSON or PDF), analyze |
| Bank | `GET me/bank`, `POST me/bank` |
| Claims | coverage check, preview, create, list, detail, preauth, checklist, document upload, timeline, settlement, summary PDF |
| Queries | list, explain, respond |
| Assistant | `GET ai/suggestions`, `POST ai/chat`, `GET demo/templates` |
| Notifications | list, mark one or all read |

## Project layout

```
ClaimSaathi.xcodeproj          synchronized ClaimSaathi source folder
Info.plist                     API_BASE_URL and launch screen
ClaimSaathi/
  ClaimSaathiApp.swift         @main, shows RootView
  API.swift                    URLSession client, Keychain, multipart
  Models.swift                 API models
  LiveRoot.swift               login, tabs, claim and policy screens
  Features.swift               warnings, chat, finance, file picking
  Theme.swift                  colors, cards, brand mark, skeletons
  Assets.xcassets              AppIcon, Logo, launch background, accent
```

The app icon and in-app mark are a cyan shield with a navy check. The launch screen centers `Logo` on `#F5F7FA`.

## Look

Background `#F5F7FA`, primary cyan `#00BAF2`, navy `#002E6E`. Cards use a 16pt continuous corner radius. First load uses skeleton cards. Empty lists use an icon and a short message.

## Related repos

- `Claim-saathi-server` — API this app calls
- `Claim-saathi-android` — the same product on Android
- `Claim-saathi-dashboard` — operator dashboard, including the demo-data switch
