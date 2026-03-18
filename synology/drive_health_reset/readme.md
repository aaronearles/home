# Synology NAS: Clearing False "Critical" Drive Health Status After Power Failure

## What Happened

A Synology DS215j NAS with two WD Red 6TB drives (WD60EFRX) began reporting both drives as **Critical** in Storage Manager following an abnormal power failure caused by a failing aftermarket external PSU.

The PSU was replaced and the NAS came back online successfully. The filesystem check passed, and extended S.M.A.R.T. tests on both drives returned completely healthy results (zero reallocated sectors, zero pending sectors, zero uncorrectable errors). Despite this, DSM continued to flag both drives as Critical and recommended replacing them.

The drives were not failing. The Critical status was an artifact of the power failure events being logged — and DSM has no built-in UI mechanism to clear this status once it is set.

---

## How DSM Records Drive Health

DSM uses a layered system to track and display drive health:

### 1. Runtime Status Files (`/run/synostorage/disks/<dev>/`)
The `synostoraged` daemon (specifically the `synostgd-disk` thread) writes per-drive status and weight files into a tmpfs directory at boot and updates them as events occur. Key files:

- `unc_status` — uncorrectable error status (`normal` or `critical`)
- `unc_weight` — numeric severity weight for UNC errors
- `timeout_status` — I/O timeout status (`normal` or `critical`)
- `timeout_weight` — numeric severity weight for timeout errors

These files are what the Storage Manager UI reads to display drive health. They are **not** the persistent source of truth — they are regenerated from the database at every boot.

### 2. Persistent Event Log (`/var/log/synolog/.SYNODISKDB`)
This is a SQLite database with a `logs` table. Every disk event is recorded here with a message type (`msg`), severity level, timestamp, and device serial number. The relevant error message types that contribute to Critical status are:

| `msg` value | Meaning |
|---|---|
| `unc` | Uncorrectable read error |
| `timeout` | I/O command timeout |
| `other_kernel_err` | SATA PHY/link errors (serror bitmask) |
| `timeout_notify` | Timeout notification event |
| `unc_notify` | UNC notification event |
| `status_critical` | Written by the daemon *after* it has already set Critical status |

At boot, `synostgd-disk` reads this database, counts and weights the error events per drive, and uses that to calculate the current health status. It then writes the result into the runtime files.

**This means editing the runtime files directly has no persistent effect** — they are overwritten on every restart from the database.

### 3. Overview XML (`/var/log/disk_overview.xml`)
This XML file tracks aggregate error counts (UNC, timeout, ICRC, etc.) per drive by serial number. It is updated by `libhwcontrol.so` as events occur. While it looks like a candidate for the persistent source, in testing it turned out to be secondary — the `logs` table in `.SYNODISKDB` is the true authoritative source for health status recalculation.

### 4. Health Database (`/var/log/synolog/.SYNODISKHEALTHDB`)
A separate SQLite database with a `disk_error` table tracking aggregate error counts (BadSector, UNC, ICRC, etc.) by serial number. In this incident, this database already showed zero for all error fields and was not the source of the Critical status.

---

## What We Learned

- DSM calculates drive health status **from the raw event log**, not from aggregate counters or SMART data.
- Passing a S.M.A.R.T. extended test does **not** automatically clear Critical status. The historical error events in the log remain and continue to drive the status calculation.
- The `synodisk --reset_health_status` command documented in some community posts **does not exist** in DSM 7.1.1.
- The `synostoraged` service holds its state **in memory** after boot — editing the runtime files while the service is running has no effect because the daemon writes from memory, not from the files.
- The correct fix is to remove the power-failure-related error events from `.SYNODISKDB`, then restart `synostoraged`. The daemon recalculates from the now-clean log and sets weights to 0, resulting in Normal status.
- The `disk_overview.xml` file can also accumulate stale error counts and should be zeroed as part of the cleanup for completeness.

---

## The Fix

See `reset_drive_health.sh` for a script that automates this process.

**Prerequisites:**
- SSH access to the NAS (enable in Control Panel → Terminal & SNMP)
- Admin account with sudo privileges
- Extended S.M.A.R.T. tests should be run and confirmed healthy **before** using this script
- Know the serial numbers of the affected drives (visible in Storage Manager → HDD/SSD)

**Manual steps (if not using the script):**

```bash
# 1. Identify drive serials
sudo sqlite3 /var/log/synolog/.SYNODISKDB "SELECT DISTINCT serial FROM logs;"

# 2. Back up the database
sudo cp /var/log/synolog/.SYNODISKDB /var/log/synolog/.SYNODISKDB.bak

# 3. Delete power-failure error events for affected drives
sudo sqlite3 /var/log/synolog/.SYNODISKDB "DELETE FROM logs WHERE msg IN ('unc','timeout','other_kernel_err','timeout_notify','unc_notify','status_critical') AND serial IN ('YOUR-SERIAL-1', 'YOUR-SERIAL-2');"

# 4. Checkpoint the WAL
sudo sqlite3 /var/log/synolog/.SYNODISKDB "PRAGMA wal_checkpoint(TRUNCATE);"

# 5. Zero out the overview XML counts
sudo sed -i 's/<unc>[0-9]*<\/unc>/<unc>0<\/unc>/g' /var/log/disk_overview.xml
sudo sed -i 's/<timeout>[0-9]*<\/timeout>/<timeout>0<\/timeout>/g' /var/log/disk_overview.xml

# 6. Restart the storage daemon
sudo systemctl restart synostoraged.service

# 7. Verify
cat /run/synostorage/disks/sda/unc_weight
cat /run/synostorage/disks/sda/timeout_weight
```

---

## Important Caveats

- **Only do this if S.M.A.R.T. tests confirm the drives are genuinely healthy.** This procedure removes real error records. If drives are actually failing, you want those records to remain.
- This procedure was developed and tested on **DSM 7.1.1** on a DS215j. Internal paths and database schemas may differ on other models or DSM versions.
- After clearing the log, Storage Manager's disk event history will no longer show the power failure events. This is expected.
- The `disk_deactivate` and `plugout` log entries are left intact intentionally — they are informational and do not contribute to health weight calculation.