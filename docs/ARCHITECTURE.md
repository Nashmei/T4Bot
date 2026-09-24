# Architecture

## Responsibility boundary

T4Bot is a presentation and control client. Mtbot is the source of truth.

### iOS owns

- Securely storing the API bearer token in Keychain.
- Rendering account, engine, analysis, positions, readiness, and settings state.
- Sending explicit user commands.
- Confirming destructive actions.
- Refreshing state after WebSocket events and on a conservative polling fallback.

### Mtbot owns

- DEMO-only enforcement.
- Account-scoped settings.
- Risk and R:R validation.
- Strategy selection and analysis.
- MT5 lifecycle and order execution.
- Position management.
- Audit logging.
- Credential persistence on the server.

## Transport

Production traffic is:

```text
iPhone
  └─ HTTPS (TLS)
      └─ reverse proxy / private tunnel
          └─ 127.0.0.1:7099
              └─ Mtbot Control API
```

The API should remain bound to loopback and should not expose port 7099 directly to the public Internet.

## State model

The app requests `GET /v1/snapshot` as the canonical screen state. WebSocket messages are invalidation/event hints; after receiving an event, the app refreshes the canonical snapshot rather than attempting to reconstruct trading state locally.

This avoids split-brain state between iOS and the engine.

## Failure model

- If the app closes, Mtbot continues independently.
- If WebSocket disconnects, HTTPS polling continues.
- If Telegram is unavailable, T4Bot and Mtbot API remain independent.
- If the API is unreachable, the app becomes read-only/unavailable and does not infer engine state.
- If MT5 is unavailable, the server reports readiness and preserves server-side safety behavior.

## Security

The client never stores MT5 passwords. Account login credentials are submitted over HTTPS directly to Mtbot, which persists them in its existing protected server credential file only after a successful DEMO login.

Bearer tokens are stored in Keychain and are never printed by the app.
