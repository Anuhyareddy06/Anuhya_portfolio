# ============================================================
# watch-and-push.ps1
# Watches the portfolio folder for changes and auto-commits
# + pushes to GitHub whenever a file is saved.
# Usage: Right-click > "Run with PowerShell"  OR
#        In terminal: .\watch-and-push.ps1
# ============================================================

$watchPath = $PSScriptRoot   # watches the folder this script lives in
$debounceSeconds = 5         # wait 5s after last change before committing

Write-Host "👁  Watching for changes in: $watchPath" -ForegroundColor Cyan
Write-Host "   Press Ctrl+C to stop.`n" -ForegroundColor Gray

# Set up FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path                = $watchPath
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter        = [System.IO.NotifyFilters]'LastWrite, FileName'
$watcher.Filter              = "*.*"
$watcher.EnableRaisingEvents = $true

$lastEvent = [datetime]::MinValue

while ($true) {
    $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)

    if (-not $change.TimedOut) {
        $changedFile = $change.Name

        # Ignore the script itself, git internals, and temp editor files
        if ($changedFile -match '(watch-and-push\.ps1|\.git|~|\.tmp|\.swp)') {
            continue
        }

        $now = [datetime]::Now
        $elapsed = ($now - $lastEvent).TotalSeconds

        if ($elapsed -ge $debounceSeconds) {
            $lastEvent = $now

            Write-Host "`n📝 Change detected in: $changedFile" -ForegroundColor Yellow
            Write-Host "   Committing and pushing..." -ForegroundColor Gray

            Set-Location $watchPath

            git add .

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $commitMsg = "Auto-update: $changedFile ($timestamp)"

            $status = git status --porcelain
            if ($status) {
                git commit -m $commitMsg
                git push origin main

                Write-Host "✅ Pushed: $commitMsg`n" -ForegroundColor Green
            } else {
                Write-Host "   No changes to commit (file already up to date).`n" -ForegroundColor DarkGray
            }
        }
    }
}
