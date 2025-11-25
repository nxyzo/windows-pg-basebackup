# Einmal ausführen, um das Backup-Passwort sicher zu speichern
$cred = Get-Credential -Message "PostgreSQL Backup-User (z.B. backup_user)"

$path = "C:\_Administration\Scripts\Backup Postgres\backup_cred.xml"
$cred | Export-CliXml -Path $path

Write-Host "Credential gespeichert in: $path"
