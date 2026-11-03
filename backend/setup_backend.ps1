# ============================================================
#  GOJEK POLINELA - Setup Backend (XAMPP)
#  Jalankan dari VS Code terminal:   .\backend\setup_backend.ps1
#  Prasyarat: Apache & MySQL di XAMPP Control Panel sudah START.
# ============================================================
param(
  [string]$XamppPath = "C:\xampp",
  [int]$Port = 3307,
  [switch]$SkipDatabase
)
$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $XamppPath "htdocs\gojek_polinela"

Write-Host "==> Menyalin API ke $target" -ForegroundColor Green
New-Item -ItemType Directory -Force $target | Out-Null
# /E subfolder, /XD uploads agar dokumen yang sudah terunggah tidak terhapus
robocopy (Join-Path $root "api") (Join-Path $target "api") /E /XD uploads /NFL /NDL /NJH /NJS | Out-Null
New-Item -ItemType Directory -Force (Join-Path $target "api\uploads") | Out-Null
Copy-Item (Join-Path $root "api\uploads\.htaccess") (Join-Path $target "api\uploads\.htaccess") -Force

if (-not $SkipDatabase) {
  $mysql = Join-Path $XamppPath "mysql\bin\mysql.exe"
  Write-Host "==> Import database (gojek_polinela.sql)" -ForegroundColor Green
  Get-Content (Join-Path $root "database\gojek_polinela.sql") -Raw -Encoding UTF8 | & $mysql -u root -h 127.0.0.1 -P $Port --default-character-set=utf8mb4
  if ($LASTEXITCODE -ne 0) { throw "Import database gagal. Pastikan MySQL XAMPP sudah berjalan." }
}

Write-Host ""
Write-Host "Selesai. Tes API di browser:  http://localhost/gojek_polinela/api/index.php/ping" -ForegroundColor Cyan
Write-Host "Emulator Android mengakses lewat: http://10.0.2.2/gojek_polinela/api/index.php" -ForegroundColor Cyan

