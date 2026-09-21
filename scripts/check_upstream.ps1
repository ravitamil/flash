# Check for upstream releases of InlitX/streak
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "Checking for latest upstream releases from InlitX/streak..." -ForegroundColor Cyan

try {
    $headers = @{ "User-Agent" = "Flash-Upstream-Checker" }
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/InlitX/streak/releases" -Headers $headers
    
    if (-not $response -or $response.Count -eq 0) {
        Write-Host "No releases found." -ForegroundColor Yellow
        exit 0
    }

    $latest = $response[0]
    Write-Host "`n--------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Latest Upstream Release: " -NoNewline
    Write-Host "$($latest.tag_name)" -ForegroundColor Green
    Write-Host "Published Date:          $($latest.published_at)" -ForegroundColor White
    Write-Host "Release Title:           $($latest.name)" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------`n" -ForegroundColor DarkGray

    # Check local tags
    $localTags = git tag -l
    if ($localTags -contains $latest.tag_name) {
        Write-Host "[OK] You already have tag $($latest.tag_name) locally." -ForegroundColor Green
    } else {
        Write-Host "[NEW RELEASE DETECTED] Upstream has release $($latest.tag_name) which is not yet present locally!" -ForegroundColor Magenta
        Write-Host "Run the following commands to update:" -ForegroundColor Yellow
        Write-Host "  git fetch upstream --tags" -ForegroundColor White
        Write-Host "  git merge $($latest.tag_name)" -ForegroundColor White
    }

    Write-Host "`nTop 3 Recent Upstream Releases:" -ForegroundColor Cyan
    $response | Select-Object -First 3 | ForEach-Object {
        Write-Host "  - $($_.tag_name) ($($_.published_at)): $($_.name)" -ForegroundColor Gray
    }
} catch {
    Write-Host "Failed to check upstream releases: $_" -ForegroundColor Red
}
