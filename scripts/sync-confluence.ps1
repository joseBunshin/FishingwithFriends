#!/usr/bin/env pwsh
# Sync docs/**/*.md to Confluence using md2cf (Python).
# Reads credentials from .confluence/credentials (gitignored).
# Page titles come from the H1 of each markdown file.
# Subdirectories under the target become parent pages (capitalized via --beautify-folders).

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$credPath = ".confluence/credentials"
if (-not (Test-Path $credPath)) {
    Write-Error "Missing $credPath. Copy .confluence/credentials.example and fill it in."
}

# Parse credentials (KEY=value, # comments allowed). Optional values like
# CONFLUENCE_PARENT_ID propagate to env vars so the parent-resolution
# logic below picks them up the same way it does an explicit env var.
$creds = @{}
Get-Content $credPath | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $val = $matches[2].Trim()
        $creds[$key] = $val
        if ($val -ne '' -and -not (Get-Item -Path "Env:$key" -ErrorAction SilentlyContinue)) {
            Set-Item -Path "Env:$key" -Value $val
        }
    }
}

foreach ($k in @("CONFLUENCE_BASE_URL", "CONFLUENCE_EMAIL", "CONFLUENCE_API_TOKEN")) {
    if (-not $creds.ContainsKey($k) -or [string]::IsNullOrWhiteSpace($creds[$k])) {
        Write-Error "Missing $k in $credPath"
    }
}

# md2cf wants the API root, not the wiki root
$apiUrl = $creds["CONFLUENCE_BASE_URL"].TrimEnd('/') + "/rest/api/"
$space = if ($env:CONFLUENCE_SPACE) { $env:CONFLUENCE_SPACE } else { "MFS" }

# Where the docs land in the space:
#   - CONFLUENCE_PARENT_ID set    → place pages under that page id
#   - CONFLUENCE_PARENT_TITLE set → place pages under the page with that title
#   - neither                     → push to the top level of the space
$parentArgs = @()
if ($env:CONFLUENCE_PARENT_ID) {
    $parentArgs = @('-A', $env:CONFLUENCE_PARENT_ID)
} elseif ($env:CONFLUENCE_PARENT_TITLE) {
    $parentArgs = @('-a', $env:CONFLUENCE_PARENT_TITLE)
} else {
    $parentArgs = @('--top-level')
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Error "python not on PATH. Install Python 3 first."
}
& python -m md2cf --help *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error "md2cf not installed. Run: pip install md2cf"
}

$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"

$target = if ($args.Count -gt 0) { $args[0] } else { "docs/" }

Write-Host "Syncing $target to Confluence space $space ($($parentArgs -join ' '))..." -ForegroundColor Cyan

$args2 = @(
    '-m', 'md2cf',
    '-o', $apiUrl,
    '-u', $creds["CONFLUENCE_EMAIL"],
    '-p', $creds["CONFLUENCE_API_TOKEN"],
    '-s', $space
) + $parentArgs + @(
    '--beautify-folders',
    '--strip-top-header',
    '--skip-empty',
    $target
)

& python @args2

if ($LASTEXITCODE -ne 0) {
    Write-Error "md2cf sync failed (exit $LASTEXITCODE)."
}

Write-Host "Done." -ForegroundColor Green
