
param(
    [int]$OlderThanDays = 0,
    [switch]$Delete,
    [switch]$Force,
    [string]$BaseBranch = "release"
)

$baseBranchRef = "origin/$BaseBranch"

$protectedBranches = @(
    "main",
    "master",
    "release"
    "dev",
    "test",
    "develop",
    "development",
    "uat"
)

Write-Host "`n=== Git Local Branch Cleanup ===" -ForegroundColor Cyan

if ($OlderThanDays -lt 0) {
    throw "OlderThanDays cannot be negative."
}

if ($Force -and !$Delete) {
    throw "Force can only be used together with Delete."
}

# Check Git repository
git rev-parse --is-inside-work-tree 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Git repository not found."
}

# Update remote references
git fetch --prune origin

if ($LASTEXITCODE -ne 0) {
    throw "Git fetch failed."
}

# Check base branch
git show-ref --verify --quiet "refs/remotes/$baseBranchRef"

if ($LASTEXITCODE -ne 0) {
    throw "$baseBranchRef not found."
}

$currentBranch = (git branch --show-current).Trim()

$cutoffDate = $null

if ($OlderThanDays -gt 0) {
    $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
}

Write-Host "Current Branch  : $currentBranch"
Write-Host "Base Branch     : $baseBranchRef"

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

# Get merged local branches
$mergedBranches = @(
    git branch --format="%(refname:short)" --merged $baseBranchRef
)

$deletedCount = 0
$candidateCount = 0
$skippedCount = 0

Write-Host "`nChecking local branches..." -ForegroundColor Yellow

foreach ($branch in $mergedBranches) {

    $branch = $branch.Trim()

    # Skip current and protected branches
    if (
        !$branch -or
        $branch -eq $currentBranch -or
        $protectedBranches -contains $branch
    ) {
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

        # Delete branch
        if ($Force) {
            git branch -D -- $branch
        }
        else {
            git branch -d -- $branch
        }

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
    Write-Host "`nPreview mode. No branches were deleted." -ForegroundColor Cyan
    Write-Host "Use -Delete to delete listed branches."
}

# Show branches not merged into the base branch
Write-Host "`nBranches NOT merged into ${baseBranchRef}:" -ForegroundColor Cyan

git branch --no-merged $baseBranchRef

Write-Host "`nCleanup completed." -ForegroundColor Cyan
