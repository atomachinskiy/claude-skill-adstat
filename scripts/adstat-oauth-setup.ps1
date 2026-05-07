# adstat-oauth-setup.ps1 - Native PowerShell wizard for Adstat (Magnetto Cabinet) setup.
# Runs in a separate PowerShell window opened by adstat-launch-wizard.ps1.
# AI assistant must NOT call this script directly via Bash tool - it would
# capture stdin prompts where user types ADSTAT_PASSWORD.

[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$SkillDir   = Join-Path $env:USERPROFILE '.claude\skills\adstat'
$SecretsDir = Join-Path $env:USERPROFILE '.claude\secrets'
$EnvFile    = Join-Path $SkillDir 'config\.env'
$TokensFile = Join-Path $SecretsDir 'adstat-tokens'
$AdstatBase = if ($env:ADSTAT_BASE) { $env:ADSTAT_BASE } else { 'https://client.adstat.pro' }

function Write-Step($msg) { Write-Host ""; Write-Host "[>] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Die($msg)        { Write-Host "[x] $msg" -ForegroundColor Red; Read-Host "Enter чтобы закрыть"; exit 1 }

if (-not (Test-Path $SkillDir)) {
    Die "Папка $SkillDir не найдена. Сначала git clone https://github.com/atomachinskiy/claude-skill-adstat.git $SkillDir"
}

New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $SkillDir 'config') -Force | Out-Null

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  Adstat (Magnetto) - настройка (PowerShell, без Git Bash)" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# ----- Step 1: read or ask credentials -----
$useExisting = $false
if ((Test-Path $EnvFile) -and -not $Force) {
    $content = Get-Content $EnvFile -Raw
    if ($content -match 'ADSTAT_LOGIN=' -and $content -match 'ADSTAT_PASSWORD=' -and -not ($content -match 'твой@email\.ru')) {
        Write-Ok "Найден заполненный $EnvFile"
        $ans = Read-Host 'Использовать существующий логин/пароль? [Y/n]'
        if ($ans -match '^[Yy]?$') { $useExisting = $true }
    }
}

if ($useExisting) {
    $envHash = @{}
    foreach ($line in (Get-Content $EnvFile)) {
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $envHash[$Matches[1]] = $Matches[2]
        }
    }
    $login    = $envHash['ADSTAT_LOGIN']
    $password = $envHash['ADSTAT_PASSWORD']
} else {
    Write-Host "Введи свои данные от https://client.adstat.pro" -ForegroundColor Yellow
    Write-Host "(пароль не отображается - это нормально)"
    Write-Host ""

    $login = Read-Host 'Email-логин'
    if (-not $login) { Die "Логин пустой" }

    $passwordSecure = Read-Host 'Пароль' -AsSecureString
    $password = [System.Net.NetworkCredential]::new('', $passwordSecure).Password
    if (-not $password) { Die "Пароль пустой" }

    $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $envContent = @"
# Adstat (Magnetto Cabinet) credentials
# Сгенерировано $now
ADSTAT_LOGIN=$login
ADSTAT_PASSWORD=$password
"@
    [System.IO.File]::WriteAllText($EnvFile, $envContent, (New-Object System.Text.UTF8Encoding($false)))

    try {
        $acl = New-Object System.Security.AccessControl.FileSecurity
        $acl.SetAccessRuleProtection($true, $false)
        $me = "$env:USERDOMAIN\$env:USERNAME"
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM', 'FullControl', 'Allow')))
        Set-Acl -Path $EnvFile -AclObject $acl
    } catch {}
    Write-Ok "Сохранил в $EnvFile (доступ ограничен)"
}

# ----- Step 2: login to Adstat -----
Write-Step "Логинюсь в Adstat..."

try {
    $body = @{ username = $login; password = $password }
    $resp = Invoke-RestMethod -Uri "$AdstatBase/api/v2/login" `
                              -Method Post `
                              -ContentType 'application/x-www-form-urlencoded' `
                              -Body $body `
                              -TimeoutSec 30
} catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    Write-Warn "HTTP $code : $($_.Exception.Message)"
    Die "Не удалось залогиниться. Проверь логин/пароль в $EnvFile и перезапусти мастер."
}

if (-not $resp.access_token) {
    Die "В ответе нет access_token: $($resp | ConvertTo-Json)"
}

# Save tokens
$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$tokensContent = @"
# Adstat tokens (issued $now)
# access expires in 1h, refresh in 30d
ADSTAT_USER_ID=$($resp.user_id)
ADSTAT_ACCESS_TOKEN=$($resp.access_token)
ADSTAT_REFRESH_TOKEN=$($resp.refresh_token)
"@
[System.IO.File]::WriteAllText($TokensFile, $tokensContent, (New-Object System.Text.UTF8Encoding($false)))

try {
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $me = "$env:USERDOMAIN\$env:USERNAME"
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM', 'FullControl', 'Allow')))
    Set-Acl -Path $TokensFile -AclObject $acl
} catch {}

$uidShort = if ($resp.user_id) { $resp.user_id.Substring(0, [Math]::Min(8, $resp.user_id.Length)) } else { '?' }
Write-Ok "Логин успешный (uid=$uidShort...)"
Write-Ok "Токены сохранены: $TokensFile"

# ----- Step 3: sanity check -----
Write-Step "Проверяю кабинет..."

$headers = @{ Authorization = "Bearer $($resp.access_token)"; Accept = 'application/json' }
try {
    $info = Invoke-RestMethod -Uri "$AdstatBase/api/info/user" -Headers $headers -TimeoutSec 20
    $bal  = Invoke-RestMethod -Uri "$AdstatBase/api/dashboard/balances" -Headers $headers -TimeoutSec 20
} catch {
    Write-Warn "Sanity-check упал: $($_.Exception.Message)"
    Write-Warn "Конфиг сохранён, попробуй позже через cli.py"
    Read-Host "Enter чтобы закрыть"
    exit 0
}

$partners = if ($info.partner_list) { $info.partner_list.Count } else { 0 }
$balTotal = if ($bal.total.amount) { $bal.total.amount } else { 0 }
$balAvail = if ($bal.available.amount) { $bal.available.amount } else { 0 }
$cur = if ($bal.total.currency) { $bal.total.currency } else { 'EUR' }

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "  + Adstat настроен и работает" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Кабинет:        $($info.email)  ($($info.role))"
Write-Host "  Партнёров:      $partners"
Write-Host "  Баланс всего:   $balTotal $cur"
Write-Host "  Свободно:       $balAvail $cur"
Write-Host ""
Write-Host "  Конфиг:    $EnvFile"
Write-Host "  Токены:    $TokensFile"
Write-Host ""
Write-Host "Дальше в чате с Клодом можно спрашивать:"
Write-Host "  - 'Сделай отчёт по моему TG-кабинету за месяц'"
Write-Host "  - 'Покажи свободные балансы по аккаунтам'"
Write-Host "  - 'Найди в архиве креативы с высоким CTR'"
Write-Host ""
Read-Host 'Готово. Нажми Enter чтобы закрыть это окно'
