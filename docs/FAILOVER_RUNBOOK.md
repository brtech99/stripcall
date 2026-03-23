# StripCall Failover Runbook

## Architecture

- **Primary**: Supabase Cloud (`wpytorahphbnzgikowgz.supabase.co`)
- **Secondary**: Self-hosted Supabase on Hetzner (`supabase.stripcall.us`)
- **Dual-write**: App writes to both; reads prefer primary, fall back to secondary
- **Health checks**: Every 30 seconds, query `crewtypes` table on both
- **Transaction replay**: Failed writes are queued and replayed when target recovers

## Night Before Tournament

### 1. Run pre-flight check
```bash
./scripts/failover_preflight.sh
```
Fix any FAIL items. WARN items are acceptable but review them.

### 2. Enable tournament mode
```bash
ssh root@supabase.stripcall.us '/opt/stripcall/tournament_toggle.sh on'
```
This switches auth sync from weekly (Wednesday) to daily.

### 3. Run a manual auth sync
```bash
ssh root@supabase.stripcall.us '. /etc/stripcall-backup.env && /opt/stripcall/sync_auth_to_secondary.sh'
```

### 4. Verify secondary has current data
Check that row counts in the pre-flight output are close to matching.

### 5. Verify deployed apps include secondary URL
The pre-flight check does this for web. For iOS/Android, verify the build was done with the updated deploy scripts (which now pass `SUPABASE_SECONDARY_URL`).

## Morning Of Tournament

### Quick health check
```bash
# Secondary API
curl -s https://supabase.stripcall.us/rest/v1/crewtypes?select=id\&limit=1 \
  -H "apikey: <SECONDARY_KEY>" -H "Authorization: Bearer <SECONDARY_KEY>"

# Edge functions
curl -s https://supabase.stripcall.us/functions/v1/keep-alive
```

## During an Outage

### What happens automatically
- **SupabaseManager** detects primary is down within 30 seconds
- **Health indicator** in the app turns orange (degraded) or red (all down)
- **Reads** automatically route to secondary
- **Writes** go to secondary; primary writes are queued for replay
- **Edge functions** fail over via `EdgeFunctionClient` (tries primary, then secondary)

### What needs manual action

Run the failover activation script:
```bash
./scripts/failover_activate.sh
```

This does:
1. Verifies secondary is healthy
2. Enables tournament mode
3. Updates Twilio SMS webhook URLs to point at Hetzner
4. Runs a final auth sync if primary is still partially reachable

### What's degraded during failover
- **New user signups** — auth goes through Supabase Cloud only
- **Password resets** — email delivery via Supabase Cloud
- **Email confirmations** — same reason
- Push notifications should still work if FCM secrets are on Hetzner

### Monitoring during outage
Watch the app's health indicator:
- **Green**: Both healthy
- **Orange**: One instance down (failover active)
- **Red**: Both down

Check pending transactions:
- The app queues failed writes and replays them every 30 seconds
- Check `SupabaseManager.pendingTransactionCount` in debug mode

## After Tournament (Failback)

When primary recovers:

```bash
./scripts/failover_deactivate.sh
```

This does:
1. Verifies primary is healthy
2. Compares row counts between secondary and primary
3. Dumps delta data from secondary (rows created during outage)
4. Optionally applies reconciliation SQL to primary
5. Restores Twilio webhooks to primary URLs
6. Disables tournament mode

### Manual reconciliation
If the automatic dump doesn't capture everything, you can query secondary directly:
```bash
ssh root@supabase.stripcall.us
export PGPASSWORD='<secondary_db_pass>'
psql -h localhost -U postgres -d postgres
```

Look for rows created during the outage window:
```sql
SELECT * FROM problems WHERE created_at > '2026-03-22 18:00:00' ORDER BY created_at;
SELECT * FROM sms_messages WHERE created_at > '2026-03-22 18:00:00' ORDER BY created_at;
```

## Quick Reference

| Script | Purpose |
|--------|---------|
| `scripts/failover_preflight.sh` | Pre-tournament readiness check |
| `scripts/failover_activate.sh` | Switch to secondary during outage |
| `scripts/failover_deactivate.sh` | Restore to primary after recovery |
| `scripts/deploy_edge_functions_hetzner.sh` | Deploy edge functions to Hetzner |
| `scripts/setup_auth_sync_cron.sh` | Install auth sync cron (one-time) |

| Hetzner Command | Purpose |
|-----------------|---------|
| `/opt/stripcall/tournament_toggle.sh on/off` | Toggle daily auth sync |
| `. /etc/stripcall-backup.env && /opt/stripcall/sync_auth_to_secondary.sh` | Manual auth sync |
| `docker restart supabase-edge-functions` | Restart edge functions |
| `tail -20 /var/backups/supabase/auth_sync.log` | Check sync status |
