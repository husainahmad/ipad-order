# ipad-order

Harmoni POS iPad is the landscape iPad checkout client for the Harmoni POS platform. It is a native SwiftUI app that talks to the gateway at `http://<host>:<port>/api/v1/**`; it does not connect to any database directly.

The default server is `http://103.150.197.7:8080/`. On another network, set the gateway host and port in **Settings**. The app currently builds HTTP-only base URLs and `Info.plist` sets `NSAllowsArbitraryLoads` to true.

## What it does

- **Login and session handling**: username/password login via `POST /api/v1/auth/login`, profile lookup via `GET /api/v1/user/{username}`, single-flight refresh via `POST /api/v1/auth/refresh-token`, and 401-only token refresh. A 403 is treated as a permission error, not a sign-out.
- **Catalogue browsing**: tier-scoped categories, SKUs by category with keyset paging, product images, and product customizations resolved lazily and memoised for the session.
- **Multi-order checkout**: several order tabs, each with its own cart, customer, discount, remark, service type and idempotency key. Open tabs are saved per cashier and restored after sign-out or restart.
- **Customer lookup**: debounced phone search and customer registration through the customer service; walk-in sales stay unlinked (`customerId = -1`).
- **Order lifecycle**: confirm `POST /api/v1/order` with `Idempotency-Key`, pay `PUT /api/v1/order`, void `PUT /api/v1/order/{id}/void`, and browse today's orders with `GET /api/v1/order/page`.
- **Payments and printing**: cash, QR and card payment selection, cash denominations/change calculation, receipt printing after payment, and separate settlement, test print and Unicode test print flows.
- **Reports**: settlement, sales, daily and order-volume data backed by `/api/v1/reports/**`.
- **Settings**: server host/port, appearance (light, dark or café), app language (system, English or Bahasa Indonesia), network or Bluetooth ESC/POS printer configuration, test print, Unicode test print and logout.

The menu service also exposes `GET /api/v1/devices/configuration?address=...` for device-specific configuration by globally unique live address. This client does not consume that endpoint yet.

## Tech stack

- Swift 5 and SwiftUI; app deployment target iPadOS 15.6, test targets iPadOS 18.5.
- iPad-only target (`TARGETED_DEVICE_FAMILY = 2`), bundle identifier `com.harmoni.pos.ipad-order`.
- `URLSession` transport, `Combine` observable objects, `Codable` models and `UserDefaults` state.
- CoreBluetooth and Network.framework for BLE and TCP thermal printing; in-app `L10n` for English/Indonesian strings and receipts.
- Shared Xcode schemes for the app, unit tests and UI tests; `ipad-order.xctestplan` lists both test targets.
- No CocoaPods or Swift Package dependencies; networking and printing are implemented in-repo.

## Code layout

```text
ipad-order/
├── ipad_orderApp.swift             # @main SwiftUI app
├── ContentView.swift               # login vs order shell, environment objects, draft restore
├── App/                            # AppSession, L10n, AppLanguage, Theme
├── ViewModels/                     # Login, OrderForm, Orders, CustomerPicker, report VMs
├── Views/                          # login, order pager/form, orders, reports, settings, dialogs
│   └── Components/                 # cart rows, product cards, order rows, sheets, toasts
├── Models/                         # API envelopes, menu, order, customer, report and cart models
├── Networking/                     # APIClient, ConfigManager, TokenManager, JsonCache, MenuRepository
├── Printing/                       # PrinterManager, ESC/POS encoder, Unicode renderer, page renderer
└── Utilities/                      # currency, time, JWT, image cache, receipts, keyboard helpers
```

Tests live in `ipad-orderTests/` and `ipad-orderUITests/`. The checked-in `.ipa` files at the repository root are built artifacts, not source inputs.

## Backend contract

`APIClient` is a singleton. Menu/order/auth responses use the `RestAPIResponse` envelope (`data` is unwrapped by the app); customer endpoints return the resource directly.

| Service | Endpoints |
| --- | --- |
| Auth | `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh-token` |
| Menu | `GET /api/v1/category/tier`, `GET /api/v1/product/category/{id}/price`, `GET /api/v1/product/category/{id}/price/page?limit&beforeId`, `GET /api/v1/product/{id}/customization`, `GET /api/v1/user/{username}` |
| Order | `GET /api/v1/order`, `GET /api/v1/order/page?limit&beforeId`, `POST /api/v1/order`, `PUT /api/v1/order`, `PUT /api/v1/order/{id}/void` |
| Reports | `GET /api/v1/reports/settlement`, `GET /api/v1/reports/sales`, `GET /api/v1/reports/daily`, `GET /api/v1/reports/order-volume` |
| Customer | `GET /api/v1/customers?search&page&size`, `POST /api/v1/customers` |

`Authorization: Bearer <accessToken>` is added to every non-auth request. Auth endpoints are excluded from refresh handling. Error bodies with a `message` are surfaced directly (for example, duplicate phone registration).

## Local state

| Store | Purpose |
| --- | --- |
| `server_host`, `server_port` | gateway host/port; all service base URLs are `http://\(host):\(port)/` |
| `pos_access_token`, `pos_refresh_token` | auth tokens stored in `UserDefaults` (not Keychain) |
| `pos_username`, `pos_store_id`, `pos_store_name`, `pos_chain_id`, `pos_chain_name`, `pos_brand_id`, `pos_brand_name` | cached cashier/store/chain/brand profile shown in Settings |
| `pos_order_drafts_v1_<username>` | open order tabs keyed by cashier so another login cannot see the previous cart |
| `JsonCache` | cached categories and first page of products per category; cleared on login |
| `printer_type`, `printer_address`, `printer_port`, `printer_name` | selected printer config; network defaults to port `9100` |
| `appTheme` | light, dark or café appearance |
| `app_language` | system, English or Bahasa Indonesia; also drives receipt language |

## Setup

1. Open `ipad-order.xcodeproj` in Xcode with an iPadOS SDK installed. The project targets iPadOS 15.6 (tests 18.5) and uses automatic signing with the configured development team.
2. Choose the `ipad-order` scheme and an iPad or iPad Simulator destination.
3. On a physical iPad, open **Settings** and enter the gateway LAN host and port. The default host is `103.150.197.7`, port `8080`.
4. For HTTP development on a new host, keep `NSAllowsArbitraryLoads` in `Info.plist` or move the gateway behind HTTPS with a trusted certificate.
5. Bluetooth printing requires local-network and Bluetooth usage approval. Network printers need TCP reachability to the configured address and port.

## Build and test

Run from this directory:

```bash
xcodebuild -project ipad-order.xcodeproj -scheme ipad-order \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iPad Simulator' build

xcodebuild test -project ipad-order.xcodeproj -scheme ipad-order \
  -destination 'platform=iPad Simulator,name=<installed simulator>'
```

The separate `ipad-orderTests` and `ipad-orderUITests` schemes can also be selected in Xcode. Build and archive use the `Release` configuration.

## Gotchas

- The app uses plain HTTP base URLs; there is no HTTPS toggle in Settings. `Info.plist` currently allows arbitrary loads.
- Tokens and cached drafts live in `UserDefaults`, so they are not Keychain-protected. Drafts are keyed by username, not by device.
- `APIClient` refreshes only on 401. A 403 stays an error so permission failures do not clear the cart.
- Concurrent 401 refreshes are coalesced; network/5xx refresh failures keep the session, while an explicit rejection clears tokens and returns to login.
- Each order tab owns its idempotency key. Any cart/customer/discount/remark/service edit rotates it; confirming once reuses the order instead of creating a duplicate.
- Product pages are cursor-based (`beforeId`), not offset-based, so inserts between requests cannot repeat rows. Only the first page is cached.
- The payment UI uses payment ids `1` cash, `2` QR and `3` card. QR/card panels are placeholders; the backend call sends the selected id.
- Bluetooth mode targets ESC/POS printers exposing BLE services (for example KT6368A-based printers). Network mode targets TCP ESC/POS printers, commonly port `9100`.
- Unicode text is rasterised for 58 mm printers; ASCII/Latin text goes through the ESC/POS encoder.
- The app relies on backend report scoping; it does not send explicit store IDs to `/api/v1/reports/**`.
- The root `.ipa` files are prebuilt artifacts. Rebuild from the Xcode project rather than editing or shipping those files directly.
