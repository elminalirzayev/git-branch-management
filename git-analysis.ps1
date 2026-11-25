
param(
    [int]$OlderThanDays = 0,
    [string]$Remote = "origin",
    [string]$BaseBranch = "release"
)

$baseBranchRef = "$Remote/$BaseBranch"

Write-Host "`n=== Git Branch Analysis ===" -ForegroundColor Cyan

if ($OlderThanDays -lt 0) {
    throw "OlderThanDays cannot be negative."
}

# Check Git repository
git rev-parse --is-inside-work-tree 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Git repository not found."
}

# Update remote references
git fetch $Remote --prune

if ($LASTEXITCODE -ne 0) {
    throw "Remote fetch failed."
}

# Check base branch
git show-ref --verify --quiet "refs/remotes/$baseBranchRef"

if ($LASTEXITCODE -ne 0) {
    throw "$baseBranchRef not found."
}

$cutoffDate = $null

if ($OlderThanDays -gt 0) {
    $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
}

if ($OlderThanDays -gt 0) {
    Write-Host "Date Filter : $OlderThanDays days or older"
    Write-Host "Cutoff Date : $cutoffDate"
}
else {
    Write-Host "Date Filter : Disabled"
}

# Get local branches
$localAll = @(git for-each-ref --format="%(refname:short)" refs/heads/)

$localMerged = @(git branch --merged $baseBranchRef --format="%(refname:short)")

$localNotMerged = @(git branch --no-merged $baseBranchRef --format="%(refname:short)")

# Get remote branches
$remoteAll = @(
    git for-each-ref --format="%(refname:short)" "refs/remotes/$Remote" |
    Where-Object {
        $_ -and $_ -ne "$Remote/HEAD"
    }
)

$remoteMerged = @(
    git branch -r --merged $baseBranchRef --format="%(refname:short)" |
    Where-Object {
        $_ -and $_ -ne "$Remote/HEAD"
    }
)

$remoteNotMerged = @(
    git branch -r --no-merged $baseBranchRef --format="%(refname:short)" |
    Where-Object {
        $_ -and $_ -ne "$Remote/HEAD"
    }
)

# Display summary
Write-Host "`n=== LOCAL BRANCH SUMMARY ===" -ForegroundColor Cyan

Write-Host "Total Branches       : $($localAll.Count)"
Write-Host "Merged into ${baseBranchRef}: $($localMerged.Count)" -ForegroundColor Green
Write-Host "Not Merged           : $($localNotMerged.Count)" -ForegroundColor Yellow

Write-Host "`n=== REMOTE BRANCH SUMMARY ===" -ForegroundColor Cyan

Write-Host "Remote               : $Remote"
Write-Host "Total Branches       : $($remoteAll.Count)"
Write-Host "Merged into ${baseBranchRef}: $($remoteMerged.Count)" -ForegroundColor Green
Write-Host "Not Merged           : $($remoteNotMerged.Count)" -ForegroundColor Yellow

# Analyze branch dates
function Show-BranchDates {
    param(
        [string]$Title,
        [array]$Branches
    )

    Write-Host "`n=== $Title ===" -ForegroundColor Cyan

    $count = 0

    foreach ($branch in $Branches) {

        $branch = $branch.Trim()

        if (!$branch) {
            continue
        }

        $branchDate = git log -1 --format="%cI" $branch 2>$null

        if (!$branchDate) {
            continue
        }

        $branchDate = [DateTimeOffset]::Parse($branchDate).LocalDateTime

        # Apply age filter when enabled
        if ($OlderThanDays -gt 0 -and $branchDate -gt $cutoffDate) {
            continue
        }

        Write-Host "$branch | $branchDate"
        $count++
    }

    Write-Host "Count: $count" -ForegroundColor Yellow
}

# Display branch dates
Show-BranchDates -Title "LOCAL BRANCH DATES" -Branches $localAll

Show-BranchDates -Title "REMOTE BRANCH DATES" -Branches $remoteAll

# Display branches not merged into the base branch
Write-Host "`n=== LOCAL NOT MERGED INTO $baseBranchRef ===" -ForegroundColor Yellow
$localNotMerged

Write-Host "`n=== REMOTE NOT MERGED INTO $baseBranchRef ===" -ForegroundColor Yellow
$remoteNotMerged

Write-Host "`nAnalysis completed." -ForegroundColor Cyan
