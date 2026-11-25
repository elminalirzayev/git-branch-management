
param(
    [int]$OlderThanDays = 0,
    [switch]$Delete,
    [string]$Remote = "origin"
)

$baseBranch = "$Remote/release"

$protectedBranches = @(
    "main",
    "master",
    "release"
    "dev",
    "test",
    "develop",
    "development",
    "uat",
)

Write-Host "`n=== Git Remote Branch Cleanup ===" -ForegroundColor Cyan

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
git show-ref --verify --quiet "refs/remotes/$baseBranch"

if ($LASTEXITCODE -ne 0) {
    throw "$baseBranch not found."
}

$currentBranch = (git branch --show-current).Trim()

$cutoffDate = $null

if ($OlderThanDays -gt 0) {
    $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
}

Write-Host "Remote          : $Remote"
Write-Host "Base Branch     : $baseBranch"
Write-Host "Current Branch  : $currentBranch"

if ($OlderThanDays -gt 0) {
    Write-Host "Older Than      : $OlderThanDays days"
    Write-Host "Cutoff Date     : $cutoffDate"
}
else {
    Write-Host "Date Filter     : Disabled"
}

if ($Delete) {
    Write-Host "Mode            : DELETE" -ForegroundColor Red
}
else {
    Write-Host "Mode            : PREVIEW" -ForegroundColor Cyan
}

# Get all remote branches
$allBranches = @(
    git for-each-ref --format="%(refname:short)" "refs/remotes/$Remote"
)

# Get branches merged into release
$mergedBranches = @(
    git branch -r --merged $baseBranch --format="%(refname:short)"
)

$deletedCount = 0
$candidateCount = 0
$skippedCount = 0

Write-Host "`nChecking remote branches..." -ForegroundColor Yellow

foreach ($branch in $allBranches) {

    $branch = $branch.Trim()

    if (!$branch -or $branch -eq "$Remote/HEAD") {
        continue
    }

    $prefix = "$Remote/"

    if (!$branch.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        continue
    }

    $branchName = $branch.Substring($prefix.Length)

    if ([string]::IsNullOrWhiteSpace($branchName)) {
        continue
    }

    # Skip protected branches
    if ($protectedBranches -contains $branchName) {
        continue
    }

    # Only consider branches merged into release
    if ($mergedBranches -notcontains $branch) {
        $skippedCount++
        continue
    }

    # Get branch last commit date
    $branchDate = git log -1 --format="%cI" $branch 2>$null

    if (!$branchDate) {
        continue
    }

    $branchDate = [DateTimeOffset]::Parse($branchDate).LocalDateTime

    # Apply age filter when enabled
    if ($OlderThanDays -gt 0 -and $branchDate -gt $cutoffDate) {
        continue
    }

    $candidateCount++

    Write-Host "`nCandidate: $branch | $branchDate" -ForegroundColor Yellow

    if ($Delete) {

        Write-Host "Deleting remote branch..." -ForegroundColor Red

        git push $Remote --delete $branchName

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Deleted: $branch" -ForegroundColor Green
            $deletedCount++
        }
        else {
            Write-Host "Could not delete: $branch" -ForegroundColor Red
            $skippedCount++
        }
    }
    else {
        Write-Host "Preview only - not deleted" -ForegroundColor Cyan
    }
}

Write-Host "`n================================"
Write-Host "Candidates : $candidateCount"
Write-Host "Deleted    : $deletedCount" -ForegroundColor Green
Write-Host "Skipped    : $skippedCount" -ForegroundColor Yellow
Write-Host "================================"

if (!$Delete) {
    Write-Host "`nPreview mode. No remote branches were deleted." -ForegroundColor Cyan
    Write-Host "Use -Delete to delete listed branches."
}

Write-Host "`nCleanup completed." -ForegroundColor Cyan
