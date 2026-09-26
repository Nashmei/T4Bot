# T4Bot

T4Bot is the native iOS control surface for the private **Mtbot** trading engine.

The iPhone app is intentionally a **thin client**. It does not contain trading strategies, MetaTrader credentials, risk logic, order execution code, or broker connectivity. Those responsibilities remain on the Mtbot server.

## Architecture

```text
T4Bot (SwiftUI)
   │ HTTPS + Bearer token
   │ WebSocket for live invalidation/events
   ▼
Mtbot Control API (server)
   │
   ├─ Engine
   ├─ Analyzer / Risk
   ├─ MT5Gateway
   ├─ SQLite settings + audit
   └─ MetaTrader 5 (Demo or Real)
```

The API contract is versioned under `/v1`. T4Bot never writes directly to `storage/bot.db` and never talks to MetaTrader 5 directly.

## Product principles

- Native SwiftUI interface using system materials, SF Symbols, Dynamic Type, and standard navigation patterns.
- Arabic-first RTL experience.
- No trading secrets in source code, UserDefaults, workflow logs, or the IPA.
- API token stored in iOS Keychain.
- HTTPS required for remote servers.
- Destructive engine stop requires explicit confirmation because current Mtbot `Engine.stop()` closes tracked positions.
- The server remains authoritative for validation and safety limits.
- The app remains usable if Telegram is disabled or rate-limited.

## Repository layout

```text
T4Bot/
├─ App/                 App entry point and global model
├─ DesignSystem/        Reusable native UI components
├─ Models/              Versioned API DTOs
├─ Networking/          HTTPS client, Keychain, WebSocket
└─ Views/               Dashboard, analysis, positions, settings, account

.github/workflows/
├─ build-ipa.yml        Reproducible unsigned IPA artifact for sideload signing
└─ validate.yml         Xcode compile validation

docs/
├─ API_CONTRACT.md
├─ ARCHITECTURE.md
└─ SIGNING.md
```

## Local development

1. Install Xcode and XcodeGen.
2. Run `xcodegen generate`.
3. Open `T4Bot.xcodeproj`.
4. Run on an iPhone or simulator.
5. In the app, enter the HTTPS URL of the Mtbot control endpoint and its bearer token.

No secrets are committed to this repository.

## IPA workflow

The `Build IPA` workflow builds the iPhoneOS app with code signing disabled and packages the result as `T4Bot-unsigned.ipa`. This artifact is suitable for a separate signing/sideload flow.

A normal install on a non-jailbroken iPhone still requires valid Apple signing. See `docs/SIGNING.md`.

## Server compatibility

T4Bot targets the Mtbot control API introduced on the companion Mtbot feature branch. Trading logic and risk behavior remain server-owned and unchanged by the iOS client.

**Current scope:** MT5 Demo and Real accounts. Real accounts can be linked for monitoring while order execution remains locked until a separate explicit Live activation. Live is re-locked on account changes and server restarts.
