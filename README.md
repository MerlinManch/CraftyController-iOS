# Crafty Native

Native iPhone client for Crafty Controller 4, built with SwiftUI and URLSession. No WebView, JavaScript runtime, proxy server, or third-party dependencies.

## Open in Xcode

Open `CraftyNative.xcodeproj` with Xcode 15 or newer, choose an iPhone simulator or device, set your own signing team and bundle identifier if needed, then run. The deployment target is iOS 17.

The GitHub Actions workflow **Unsigned iOS IPA** runs on each push to `main` and can also be started manually. Download its `CraftyNative-unsigned-ipa` artifact from the run page. This IPA has no signature or provisioning profile and must be signed before installation on an ordinary iPhone.

Connect to an HTTPS Crafty Controller 4 instance with a trusted certificate. In Crafty, create an API key for your user with the permissions required for the operations you want, then enter the instance URL and key in the app. Username/password login is also supported when the instance permits API login. Credentials are stored in the iOS Keychain. A publicly trusted certificate or an explicitly trusted private CA is required; certificate validation is never disabled.

## Coverage

- Native connection and authentication, credential storage, logout.
- Server list, statistics, start/stop/restart, console logs and commands.
- Native file browser, text viewing/editing, folder creation and deletion.
- Backups, scheduled tasks, webhooks, server settings, users and roles through native collection and JSON editors.
- Native API workspace for version-specific endpoints and payloads.

The management screens use Crafty API v2. The API has changed across Crafty releases; the route field in management screens can be adjusted to match an installation. This project is a usable starting client, but exact parity with every web UI feature and compatibility with a particular Crafty installation require integration testing with that installation. See `FEATURES.md` for the explicit coverage matrix. In particular, binary uploads/downloads, backup restore and a guided server creation flow need dedicated implementations before they can be considered complete. API permissions are enforced by Crafty.

## Architecture

`CraftyAPI` wraps URLSession and checks Crafty's status envelope. `SessionStore` holds app state. `KeychainStore` owns the secret. SwiftUI views make direct native API requests through the store; no separate backend is needed because Crafty itself is the backend.

## Notes

- Server power actions ask for confirmation when destructive.
- In settings, use **Abmelden** to remove saved credentials.
- The API workspace may execute destructive requests. Enter trusted paths and review the request before sending.
