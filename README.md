# windows-pg-basebackup

A small PowerShell-based helper project designed to create and manage PostgreSQL base backups on Windows systems. This repository contains scripts and guidance to run automated, reliable backups using PostgreSQL's `pg_basebackup` on Windows.

Note: This project is a wrapper/helper around standard PostgreSQL tools and focuses on using `pg_basebackup` in Windows environments (Task Scheduler, service accounts, SMB/Network shares, etc.).

## Features

- Run `pg_basebackup` on Windows via PowerShell
- Support for tar/plain backups (depending on PostgreSQL version)
- Configurable rotation/retention policy
- Recommendations for integrating with Windows Task Scheduler
- Guidance for restore procedures and WAL archiving (PITR)

## Prerequisites

- Windows Server or Windows Client with PowerShell (Windows PowerShell or PowerShell Core)
- PostgreSQL installed with access to `pg_basebackup` (ensure `pg_basebackup.exe` is in PATH or provide its path)
- A PostgreSQL user with REPLICATION privileges (e.g., a dedicated replication user)
- Sufficient disk space for backups
- Optional: destination for backups (local disk, network share / SMB, etc.)

## Installation

1. Clone the repository or download the scripts:
   ```powershell
   git clone https://github.com/nxyzo/windows-pg-basebackup.git
   cd windows-pg-basebackup
   ```

2. If required, adjust PowerShell execution policy for the current session:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

3. Ensure `pg_basebackup.exe` is reachable. Either:
   - Add PostgreSQL's bin directory to PATH, or
   - Pass the full path to `pg_basebackup.exe` in script parameters.

## Configuration

The main script (for example `windows-pg-basebackup.ps1`) should support configurable parameters such as:

- BackupDir — target directory for backups, e.g. `C:\pg_backups`
- PgHost — hostname or IP of the PostgreSQL server (default: `localhost`)
- PgPort — port (default: `5432`)
- PgUser — PostgreSQL user with replication rights
- PgPassword — (caution) avoid plaintext passwords — use Windows Credential Manager, encrypted storage, or `pgpass`
- PgBin — path to PostgreSQL binaries (optional)
- RetentionDays — how many days to retain backups
- Compression — whether to compress (e.g., create .tar.gz) after backup

Example invocation:
```powershell
.\windows-pg-basebackup.ps1 `
  -BackupDir "C:\pg_backups" `
  -PgHost "db.example.local" `
  -PgPort 5432 `
  -PgUser "replication_user" `
  -PgBin "C:\Program Files\PostgreSQL\14\bin" `
  -RetentionDays 7
```

Recommendation: use `Get-Credential` or Windows Credential Manager instead of passing plaintext passwords:
```powershell
$cred = Get-Credential
# Adjust the script to accept a PSCredential object
```

## Backup types and workflow

- Full base backup: `pg_basebackup` creates a consistent data directory snapshot (use tar mode or a data-directory extraction).
- WAL archiving: For Point-In-Time Recovery (PITR), set up WAL archiving. `pg_basebackup` alone does not guarantee PITR unless WAL segments are archived separately.

Example using tar mode and compression:
```powershell
pg_basebackup.exe -h db.example.local -U replication_user -D - -Ft -z -P > C:\pg_backups\basebackup_$(Get-Date -Format yyyyMMdd_HHmmss).tar.gz
```
(Exact invocation may vary; a wrapper script typically handles naming, paths and rotation.)

## Restore (quick guide)

1. Stop the PostgreSQL server on the target machine.
2. Move or back up the existing data directory.
3. Extract the backup into the data directory (for tar.gz use an extractor that supports the format).
4. Ensure permissions are correct (NTFS ACLs for the service account that runs PostgreSQL).
5. If WAL archiving was used: configure recovery using `recovery.signal` / `standby.signal` and a `restore_command` (or older `recovery.conf`) so WALs can be applied.
6. Start PostgreSQL and verify logs.

Note: Exact restore steps depend on PostgreSQL version. Consult PostgreSQL documentation for version-specific recovery procedures.

## Scheduling with Windows Task Scheduler (example)

1. Open Task Scheduler.
2. Create a new task running under a service account that has access to the backup target (e.g., a domain account).
3. Action: program `powershell.exe` with arguments:
   ```
   -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\windows-pg-basebackup.ps1" -BackupDir "C:\pg_backups" -PgHost "db.example.local" -PgUser "replication_user"
   ```
4. Trigger: e.g., daily at an off-peak time.
5. Optionally add pre/post actions (cleanup, upload to offsite storage, notifications).

## Logging & error handling

- The script should write log entries (timestamped) for successful backups and errors.
- Check and handle `pg_basebackup` exit codes; implement retries or notifications on failure.
- Ensure rotation does not leave partially written backups in the retention set (use atomic moves/temporary filenames).

## Security

- Store credentials securely (Windows Credential Manager, encrypted files, or `pgpass` with restricted permissions).
- Use TLS/SSL between client and server if backups are taken over untrusted networks.
- Limit replication user privileges to the minimum required.

## Troubleshooting

- pg_basebackup not found: verify PATH or PgBin parameter points to PostgreSQL bin directory.
- Permission denied writing to backup directory: check NTFS ACLs and the user account used by Task Scheduler.
- Partial/incomplete backups: inspect logs for network issues, disk space, or resource limits.
- WAL errors during restore: ensure all required WAL segments are available and restore command is correct.

## Examples

Interactive run with credential prompt:
```powershell
$cred = Get-Credential -UserName "replication_user" -Message "Replication user credentials"
.\windows-pg-basebackup.ps1 -BackupDir "C:\pg_backups" -PgHost "localhost" -PgPort 5432 -Credential $cred -RetentionDays 14
```

Task Scheduler command-line example:
```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\tools\windows-pg-basebackup\windows-pg-basebackup.ps1" -BackupDir "E:\pg_backups" -PgHost "db1" -PgUser "replication_user" -RetentionDays 7
```

## Contributing

Contributions, issues and suggestions are welcome. Please:
- Open an issue for bugs or feature requests
- Submit a pull request for changes
- Include a short description of your change and testing steps

## License

MIT License — see LICENSE file.

## Contact

If you have questions or problems, open an issue in the repository or contact the repository owner via GitHub.
