<# 
    PostgreSQL base backup script for Windows
    - Creates a timestamped folder under E:\Backup
    - Runs pg_basebackup
    - Deletes backup folders older than 7 days
#>

param(
    [string]$PgBaseBackup = "C:\Program Files\PostgreSQL\17\bin\pg_basebackup.exe",

    [string]$PgHost      = "localhost",
    [int]   $Port        = 5432,
    [string]$User        = "backup_user",

    [string]$BackupRoot  = "E:\Backup",

    [int]$RetentionDays  = 3,

    # NEU: Pfad zur verschlüsselten Credential-Datei
    [string]$CredentialFile = "C:\_Administration\Scripts\Backup Postgres\backup_cred.xml"
)

Write-Host "Starting PostgreSQL base backup..." -ForegroundColor Cyan

if (-not (Test-Path -Path $CredentialFile)) {
    Write-Host "Credential file not found: $CredentialFile" -ForegroundColor Red
    exit 1
}

# Credential laden
$cred = Import-CliXml -Path $CredentialFile

# Passwort im Klartext holen (nur im RAM)
$plainPwd = $cred.GetNetworkCredential().Password

# Passwort per Env-Var für pg_basebackup setzen
$env:PGPASSWORD = $plainPwd

# Ensure backup root exists
if (-not (Test-Path -Path $BackupRoot)) {
    Write-Host "Creating backup root folder: $BackupRoot"
    New-Item -ItemType Directory -Path $BackupRoot | Out-Null
}

# Create timestamped backup folder
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$targetDir = Join-Path $BackupRoot $timestamp

Write-Host "Creating backup folder: $targetDir"
New-Item -ItemType Directory -Path $targetDir | Out-Null

# Build pg_basebackup command
$arguments = @(
    "-h", $PgHost,     # <--- use PgHost here
    "-p", $Port,
    "-U", $User,
    "-D", $targetDir,
    "-Fp",
    "-Xs",
    "-P",
    "-v"
)

Write-Host "Running pg_basebackup..." -ForegroundColor Yellow
& "$PgBaseBackup" @arguments 2>&1 | ForEach-Object {
    Write-Host $_
}
$exitCode = $LASTEXITCODE

# Clean up password memory + environment
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
$plainPwd = $null
$cred = $null

if ($exitCode -eq 0) {
    Write-Host "Base backup completed successfully." -ForegroundColor Green
    Write-Host "Backup stored in: $targetDir"
} else {
    Write-Host "Base backup FAILED. Exit code: $exitCode" -ForegroundColor Red
    exit $exitCode
}

# ----------------------------
# Retention: Delete old backups
# ----------------------------

Write-Host "Applying retention policy: $RetentionDays days..." -ForegroundColor Cyan

$cutoff = (Get-Date).AddDays(-$RetentionDays)

Get-ChildItem -Path $BackupRoot -Directory | ForEach-Object {
    if ($_.LastWriteTime -lt $cutoff) {
        Write-Host "Deleting old backup folder: $($_.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $_.FullName -Recurse -Force
    }
}

Write-Host "Retention cleanup complete." -ForegroundColor Green
