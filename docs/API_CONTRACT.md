# Mtbot Control API v1

All `/v1` endpoints require:

```
Authorization: Bearer <CONTROL_API_TOKEN>
```

except where explicitly documented by the server.

## Snapshot

`GET /v1/snapshot`

Returns the authoritative UI snapshot:

- `server_time`
- `engine`
- `account`
- `positions`
- `settings`
- `analysis`
- `readiness`

The iOS decoder uses snake_case conversion.

## Engine

- `POST /v1/engine/start`
- `POST /v1/engine/stop`

Important: current Mtbot `Engine.stop()` attempts to close tracked positions. T4Bot therefore presents a destructive confirmation before sending Stop.

## Account

`POST /v1/account/login`

```json
{
  "server": "MetaQuotes-Demo",
  "login": 123456789,
  "password": "secret"
}
```

The password is never persisted by T4Bot.

## Settings

`PATCH /v1/settings`

Supported fields and server-compatible ranges:

| Field | Range |
|---|---:|
| `risk_pct` | 0.25–50 |
| `rr` | 0.5–10 |
| `min_confidence` | 50–95 |
| `protection_pct` | 5–90 |
| `max_trade_minutes` | 3–240 |
| `max_positions` | 1–10 |
| `max_consecutive_losses` | 0–20 |
| `daily_loss_limit_pct` | 0–100 |

The server is authoritative even if the client validates first.

## Symbols

- `GET /v1/symbols`
- `PUT /v1/symbols`

`PUT` body:

```json
{"symbols":["EURUSD","GBPUSD"]}
```

The server resolves names against the connected MT5 terminal.

## Analysis

`POST /v1/analysis/run`

Runs the same Analyzer inputs used by Mtbot for the currently selected symbols and returns structured results. It does not place orders.

## Audit

`GET /v1/audit?limit=100`

Read-only recent audit stream.

## Realtime

`GET wss://<host>/v1/ws` using the same Authorization header.

Snapshot events remain authoritative state updates. Mtbot also emits explicit trade lifecycle events:

- `trade_opened`
- `trade_closed`
- `profit_protection`

These events carry structured fields such as `symbol`, `side`, `trade_ticket`, `trade_result`, and `trade_result_reason` when available.

T4Bot does **not** require APNs for these alerts. While the process is able to receive the WebSocket event, the iOS app creates its own local notification and transient Live Activity. iOS may suspend the app in the background, so APNs would still be required for guaranteed delivery while the process is suspended or terminated.
