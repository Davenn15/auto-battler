# Auto Battler launcher: downloads the newest build from GitHub if there is one, then
# starts the game. Players run "Play Auto Battler.cmd" (double-click) instead of the exe.
#
# Setup (once):
#   1. Set $Repo below to your GitHub repository, e.g. "your-name/auto-battler".
#   2. Private repository only: put a GitHub access token in a file named
#      github_token.txt next to this script (a fine-grained token with read access to
#      the repository's Contents is enough). Public repositories need no token.
#
# The game goes in a "game" folder next to this script. Saved settings live in the
# player's AppData, so updating never touches them.

param(
    [string]$Repo = "Davenn15/auto-battler",
    [string]$Asset = "AutoBattler-windows.zip",
    [switch]$CheckOnly   # only report whether an update is available
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # the progress bar slows downloads a lot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Here = $PSScriptRoot
$GameDir = Join-Path $Here "game"
$VersionFile = Join-Path $GameDir "version.txt"
$TokenFile = Join-Path $Here "github_token.txt"
$Exe = Join-Path $GameDir "AutoBattler.exe"

$Headers = @{ "User-Agent" = "AutoBattlerLauncher"; "Accept" = "application/vnd.github+json" }
if (Test-Path $TokenFile) {
    $Headers["Authorization"] = "Bearer " + (Get-Content $TokenFile -Raw).Trim()
}

function Get-InstalledVersion {
    if (Test-Path $VersionFile) { return (Get-Content $VersionFile -Raw).Trim() }
    return ""
}

# ---------- Check for an update ----------
$release = $null
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $Headers
} catch {
    Write-Host "Couldn't check for updates ($($_.Exception.Message))."
    if (-not (Test-Path $TokenFile)) {
        Write-Host "If the repository is private, add github_token.txt next to this script."
    }
}

if ($release -ne $null) {
    $installed = Get-InstalledVersion
    if ($release.tag_name -eq $installed) {
        Write-Host "Up to date ($installed)."
    } elseif ($CheckOnly) {
        Write-Host "Update available: $($release.tag_name) (installed: $(if ($installed) { $installed } else { 'nothing' }))."
    } else {
        $file = $release.assets | Where-Object { $_.name -eq $Asset } | Select-Object -First 1
        if ($file -eq $null) {
            Write-Host "The newest release ($($release.tag_name)) has no $Asset; keeping the installed game."
        } elseif (Get-Process -Name "AutoBattler" -ErrorAction SilentlyContinue) {
            Write-Host "Close the game first so it can be updated, then run this again."
            exit 1
        } else {
            Write-Host "Downloading $($release.tag_name)..."
            $zip = Join-Path $env:TEMP "AutoBattler-update.zip"
            if ($Headers.ContainsKey("Authorization")) {
                # Private repository: download through the API with the token.
                $download = $Headers.Clone()
                $download["Accept"] = "application/octet-stream"
                Invoke-WebRequest -Uri $file.url -Headers $download -OutFile $zip
            } else {
                Invoke-WebRequest -Uri $file.browser_download_url -Headers @{ "User-Agent" = "AutoBattlerLauncher" } -OutFile $zip
            }
            # Unpack beside the old copy first, so a failed download never breaks it.
            $staging = Join-Path $Here "game_new"
            if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
            Expand-Archive -Path $zip -DestinationPath $staging
            Remove-Item $zip
            if (Test-Path $GameDir) { Remove-Item $GameDir -Recurse -Force }
            Rename-Item $staging "game"
            Set-Content -Path $VersionFile -Value $release.tag_name
            Write-Host "Updated to $($release.tag_name)."
        }
    }
}

if ($CheckOnly) { exit 0 }

# ---------- Start the game ----------
if (-not (Test-Path $Exe)) {
    Write-Host "The game isn't installed yet and couldn't be downloaded."
    exit 1
}
Start-Process -FilePath $Exe -WorkingDirectory $GameDir
