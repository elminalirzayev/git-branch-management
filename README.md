# Git Branch Management

This repository contains PowerShell scripts for analyzing and cleaning up local and remote Git branches.

## Repository Contents

| Script | Purpose |
| --- | --- |
| `git-analysis.ps1` | Reports local and remote branch statistics and last-commit dates. |
| `git-cleanup.ps1` | Previews or deletes eligible local branches. |
| `git-cleanup-remote.ps1` | Previews or deletes eligible remote branches. |

The scripts use `origin/release` as the default integration branch.

## Common Configuration

### Integration Branch

The default base branch is:

``` text
origin/release
```

Cleanup scripts use this as their default integration branch. Use `-BaseBranch` to select another branch name on the configured remote.

### Protected Branches

The following branch names are excluded from cleanup:

- `main`
- `master`
- `release`
- `dev`
- `test`
- `develop`
- `development`
- `uat`

### Date Filtering

The scripts use the `OlderThanDays` parameter to filter branches by their latest commit date.

| Value | Behavior |
| --- | --- |
| `0` (default) | Date filtering is disabled. |
| `100` | Includes branches whose latest commit is 100 days old or older. |
| `365` | Includes branches whose latest commit is 365 days old or older. |

The cutoff date is calculated as follows:

``` powershell
$cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
```

**Important:** Git does not reliably record a branch's creation date.
The scripts use the latest commit date (`%cI`), not the branch creation date.

### Preview and Deletion

Cleanup scripts run in preview mode by default:

- Without `-Delete`, eligible branches are listed but not deleted.
- With `-Delete`, eligible branches are deleted.
- The local cleanup script also supports `-Force`, which uses `git branch -D` instead of `git branch -d`. `-Force` requires `-Delete`.

Always review the preview output before performing deletions.

------------------------------------------------------------------------

## 1. Local Branch Cleanup

Script: `git-cleanup.ps1`

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `OlderThanDays` | `0` | Include branches whose latest commit is this many days old or older. `0` disables date filtering. |
| `Delete` | Off | Delete eligible local branches. |
| `Force` | Off | Force-delete eligible local branches. Requires `-Delete`. |
| `BaseBranch` | `release` | Branch on `origin` used to determine which branches are merged. |

### Examples 1

Preview all eligible local branches:

``` powershell
.\git-cleanup.ps1
```

Preview local branches whose latest commit is at least 100 days old:

``` powershell
.\git-cleanup.ps1 -OlderThanDays 100
```

Delete eligible local branches whose latest commit is at least 100 days
old:

``` powershell
.\git-cleanup.ps1 -OlderThanDays 100 -Delete
```

Force-delete eligible local branches whose latest commit is at least 100
days old:

``` powershell
.\git-cleanup.ps1 -OlderThanDays 100 -Delete -Force
```

Delete all eligible local branches without a date filter:

``` powershell
.\git-cleanup.ps1 -Delete
```

Use a different base branch:

``` powershell
.\git-cleanup.ps1 -BaseBranch develop
```

### Local Cleanup Eligibility

A local branch is considered for cleanup when it:

1. Is not the currently checked-out branch.
2. Is not in the protected branch list.
3. Is merged into `origin/<BaseBranch>` (default: `origin/release`).
4. Meets the age filter, if enabled.

The script runs `git fetch --prune origin` before checking branches to
refresh remote-tracking references.

------------------------------------------------------------------------

## 2. Remote Branch Cleanup

Script: `git-cleanup-remote.ps1`

### Parameters 2

| Parameter | Default | Description |
| --- | --- | --- |
| `OlderThanDays` | `0` | Include branches whose latest commit is this many days old or older. `0` disables date filtering. |
| `Delete` | Off | Delete eligible remote branches. |
| `Remote` | `origin` | Git remote to inspect and use for deletion. |
| `BaseBranch` | `release` | Branch on the selected remote used to determine which branches are merged. |

### Examples 2

Preview all eligible remote branches:

``` powershell
.\git-cleanup-remote.ps1
```

Preview remote branches whose latest commit is at least 100 days old:

``` powershell
.\git-cleanup-remote.ps1 -OlderThanDays 100
```

Delete eligible remote branches whose latest commit is at least 100 days
old:

``` powershell
.\git-cleanup-remote.ps1 -OlderThanDays 100 -Delete
```

Delete all eligible remote branches without a date filter:

``` powershell
.\git-cleanup-remote.ps1 -Delete
```

Use a different remote:

``` powershell
.\git-cleanup-remote.ps1 -Remote upstream -OlderThanDays 100
```

Use a different base branch on the selected remote:

``` powershell
.\git-cleanup-remote.ps1 -BaseBranch develop
```

Combine a different remote and base branch:

``` powershell
.\git-cleanup-remote.ps1 -Remote upstream -BaseBranch develop
```

### Remote Cleanup Eligibility

A remote branch is considered for cleanup when it:

1. Belongs to the selected remote.
2. Is not the remote `HEAD` reference.
3. Is not in the protected branch list.
4. Is merged into `<Remote>/<BaseBranch>` (default: `<Remote>/release`).
5. Meets the age filter, if enabled.

Remote deletion is performed with:

``` powershell
git push <Remote> --delete <BranchName>
```

This script deletes remote branches; it does not delete local branches.

------------------------------------------------------------------------

## 3. Git Branch Analysis

Script: `git-analysis.ps1`

This script reports local and remote branch statistics and lists branch
latest-commit dates.

### Parameters 3

| Parameter | Default | Description |
| --- | --- | --- |
| `OlderThanDays` | `0` | Filters the displayed date lists to branches whose latest commit is this many days old or older. `0` disables date filtering. |
| `Remote` | `origin` | Remote to inspect. |
| `BaseBranch` | `release` | Branch on the selected remote used to determine which branches are merged. |

### Examples 3

Analyze all local and remote branches:

``` powershell
.\git-analysis.ps1
```

Show only branches whose latest commit is at least 100 days old in the
date lists:

``` powershell
.\git-analysis.ps1 -OlderThanDays 100
```

Analyze a different remote:

``` powershell
.\git-analysis.ps1 -Remote upstream
```

Analyze using a different base branch:

``` powershell
.\git-analysis.ps1 -BaseBranch develop
```

Combine a different remote and base branch:

``` powershell
.\git-analysis.ps1 -Remote upstream -BaseBranch develop
```

### Report Contents

The analysis script displays:

- Total local branch count.
- Local branches merged into `<Remote>/<BaseBranch>`.
- Local branches not merged into `<Remote>/<BaseBranch>`.
- Total remote branch count, excluding `<Remote>/HEAD`.
- Remote branches merged into `<Remote>/<BaseBranch>`.
- Remote branches not merged into `<Remote>/<BaseBranch>`.
- Local branch latest-commit dates.
- Remote branch latest-commit dates.
- Separate lists of local and remote branches not merged into the integration branch.

The date filter applies to the branch-date lists. Merged and not-merged
summary counts are independent of the date filter.

------------------------------------------------------------------------

## 4. Recommended Workflow

Before deleting branches, follow this sequence:

1. Run the analysis script to review branch counts and merge status.
2. Run local cleanup in preview mode.
3. Run remote cleanup in preview mode.
4. Review the candidate branch names and dates.
5. If the candidates are correct, run the relevant cleanup script with `-Delete`.
6. Use `-Force` for local branches only when force deletion is intentional.

Example:

``` powershell
# 1. Analyze branches
.\git-analysis.ps1 -OlderThanDays 100

# 2. Preview local cleanup
.\git-cleanup.ps1 -OlderThanDays 100

# 3. Preview remote cleanup
.\git-cleanup-remote.ps1 -OlderThanDays 100

# 4. Delete eligible local branches after reviewing the preview
.\git-cleanup.ps1 -OlderThanDays 100 -Delete

# 5. Delete eligible remote branches after reviewing the preview
.\git-cleanup-remote.ps1 -OlderThanDays 100 -Delete
```

------------------------------------------------------------------------

## 5. Important Notes and Limitations

- **Latest commit date is not branch creation date.** A branch created a long time ago but updated recently will not match an old-commit filter.
- **Merge status is checked against the configured base branch.** A branch not merged into `<Remote>/<BaseBranch>` (default: `<Remote>/release`) is excluded from cleanup, even if it has been merged elsewhere.
- **Remote deletion requires permission.** Azure DevOps permissions, branch policies, or repository rules may reject a remote deletion.
- **Preview is the default.** Do not use `-Delete` until you have reviewed the candidate list.
- **Force deletion is local-only.** The local script's `-Force` option uses `git branch -D`; it does not apply to remote deletion.
- **The scripts fetch before analysis or cleanup.** This refreshes remote-tracking references but does not modify remote branch contents.

## 6. Quick Reference

| Task | Command |
| --- | --- |
| Analyze all branches | `.\git-analysis.ps1` |
| Analyze branches with latest commit 100+ days old | `.\git-analysis.ps1 -OlderThanDays 100` |
| Analyze using another base branch | `.\git-analysis.ps1 -BaseBranch develop` |
| Analyze with another remote and base branch | `.\git-analysis.ps1 -Remote upstream -BaseBranch develop` |
| Preview local cleanup | `.\git-cleanup.ps1` |
| Preview local cleanup (100+ days) | `.\git-cleanup.ps1 -OlderThanDays 100` |
| Preview local cleanup using another base branch | `.\git-cleanup.ps1 -BaseBranch develop` |
| Delete eligible local branches | `.\git-cleanup.ps1 -Delete` |
| Force-delete eligible local branches | `.\git-cleanup.ps1 -Delete -Force` |
| Preview remote cleanup | `.\git-cleanup-remote.ps1` |
| Preview remote cleanup (100+ days) | `.\git-cleanup-remote.ps1 -OlderThanDays 100` |
| Preview remote cleanup with another base branch | `.\git-cleanup-remote.ps1 -BaseBranch develop` |
| Delete eligible remote branches | `.\git-cleanup-remote.ps1 -Delete` |
| Use another remote | `.\git-cleanup-remote.ps1 -Remote upstream` |
| Use another remote and base branch | `.\git-cleanup-remote.ps1 -Remote upstream -BaseBranch develop` |
