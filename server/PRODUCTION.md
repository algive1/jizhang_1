# Production operations

The application server is designed to run behind Caddy (or an equivalent TLS reverse proxy).

## First deployment

1. Copy `.env.example` to `.env` and replace every production value.
2. Point `APP_DOMAIN` to the host running Caddy.
3. Run `docker compose -f docker-compose.production.yml up -d --build`.
4. Verify `/health` and `/ready`. Prometheus-compatible counters are available at `/metrics`.
5. Set a 24+ character `ADMIN_TOKEN`, then open `/admin`.

Do not commit `.env`, payment keys, FCM service-account keys, APNs keys, or admin tokens.

## Backup

Run this from the application container or an equivalent scheduled job:

```sh
node scripts/backup.mjs
```

The script checkpoints WAL, creates a SQLite-consistent snapshot with `VACUUM INTO`, runs `integrity_check`, and rotates old backups according to `BACKUP_KEEP`. Production storage should additionally copy the backup volume to a separate machine or object-storage bucket.

## Retention

The server prunes diagnostics, analytics, resolved support tickets, admin audit rows, and completed push-outbox rows according to environment settings. Shared-ledger change history and deleted-entity tombstones are retained for 90 days by default. The server records a retention cursor floor before pruning; clients presenting an older cursor are forced through a full snapshot reconciliation, so long-offline devices do not silently miss deletions.

## Push

Android uses FCM HTTP v1 and requires service-account environment variables. iOS uses APNs token authentication. Missing push credentials do not crash the service: queued notifications remain retryable and are visible in the admin console.

## TLS

Caddy terminates TLS and automatically manages certificates for `APP_DOMAIN`. If another reverse proxy is used, keep the Node process on a private network and terminate HTTPS at the proxy.
