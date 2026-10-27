# Fuyu Toolbox installer
# Usage (PowerShell):  irm https://raw.githubusercontent.com/SupawichZ1/fuyu-toolbox-releases/main/install.ps1 | iex
# Downloads the latest release from GitHub, checks its SHA-256, installs silently and launches the app.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is many times faster without the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'SupawichZ1/fuyu-toolbox-releases'

function Say($msg, $color = 'Cyan') { Write-Host "[Fuyu] $msg" -ForegroundColor $color }

try {
    Say 'Checking latest version...'
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'fuyu-installer' }
    $asset = $rel.assets | Where-Object { $_.name -like '*.exe' } | Select-Object -First 1
    if (-not $asset) { throw 'No installer found in the latest release.' }

    $sizeMB = [math]::Round($asset.size / 1MB)
    $out = Join-Path $env:TEMP $asset.name
    Say "Downloading Fuyu Toolbox $($rel.tag_name) ($sizeMB MB)... this can take a few minutes"
    Invoke-WebRequest $asset.browser_download_url -OutFile $out -UseBasicParsing

    # Integrity check against the SHA-256 GitHub records for the uploaded file
    if ($asset.digest -and $asset.digest -like 'sha256:*') {
        $expected = $asset.digest.Substring(7).ToLower()
        $actual = (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
        if ($expected -ne $actual) {
            Remove-Item $out -Force -ErrorAction SilentlyContinue
            throw 'Downloaded file is corrupted or was modified (SHA-256 mismatch). Please try again.'
        }
        Say 'File verified (SHA-256 OK)' 'Green'
    }

    Say 'Installing... (click Yes if Windows asks for permission)'
    $p = Start-Process $out -ArgumentList '/S' -Verb RunAs -Wait -PassThru
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) { throw "Installer exited with code $($p.ExitCode)." }

    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Fuyu Toolbox\Fuyu Toolbox.exe",
        "$env:LOCALAPPDATA\Programs\fuyu-toolbox\Fuyu Toolbox.exe",
        "$env:ProgramFiles\Fuyu Toolbox\Fuyu Toolbox.exe"
    )
    $exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    Say 'Fuyu Toolbox installed successfully!' 'Green'
    if ($exe) {
        Say 'Starting Fuyu Toolbox...'
        Start-Process $exe
    } else {
        Say 'Open "Fuyu Toolbox" from the Start menu or desktop shortcut.'
    }
}
catch {
    Say "Install failed: $($_.Exception.Message)" 'Red'
    Say "Manual download: https://github.com/$repo/releases/latest" 'Yellow'
}
