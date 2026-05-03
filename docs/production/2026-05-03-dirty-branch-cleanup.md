# Dirty Branch Cleanup Backup Record - 2026-05-03

## Scope

This record documents the cleanup of the original interactive workspace after the WuKongIM token-redaction and production-template work was completed in the isolated implementation worktree.

- Original workspace: `C:/Users/COLORFUL/Desktop/WuKong`
- Original branch: `codex/customer-service-entry-personal-routing`
- Backup directory: `C:/Users/COLORFUL/Desktop/WuKong-cleanup-backups/20260503-wukong-dirty-branch`
- Stash message: `backup before wukongim token redaction cleanup 2026-05-03`
- Stash identity at cleanup time: `c63c276941b2a2a1b42d73fd96508f96a1783f7a`
- Cleanup time: `2026-05-03 21:45:03` local time

## What Was Preserved

Before stashing, the original workspace state was saved outside the repository:

| Artifact | Purpose |
| --- | --- |
| `status-before.txt` | Full short status before cleanup |
| `staged.patch` | Staged tracked changes as a patch |
| `unstaged.patch` | Unstaged tracked changes as a patch |
| `staged-name-status.txt` | Staged file list and status codes |
| `unstaged-name-status.txt` | Unstaged file list and status codes |
| `untracked-files.txt` | Original untracked file list |
| `untracked-files-utf8.txt` | Untracked file list regenerated with `core.quotePath=false` for Chinese paths |
| `untracked-copy/` | File-by-file copy of untracked files |
| `untracked-copy.zip` | Zip archive of the copied untracked files |
| `stash-list-after.txt` | Stash list immediately after cleanup |
| `status-after-stash.txt` | Short status immediately after cleanup |

Backup copy result: `copied=10 skipped=0` for untracked files.

Pre-cleanup inventory summary:

- Short-status non-empty lines: `68`
- Staged name-status lines: `59`
- Unstaged name-status lines: `3`
- Untracked files copied: `10`

## Cleanup Result

After `git stash push --include-untracked`, the original workspace short status was:

```text
## codex/customer-service-entry-personal-routing
```

This means the original workspace no longer has tracked or untracked working-tree entries visible to `git status --short --branch` at the time of cleanup.

## Recovery Commands

Prefer the stash for normal recovery:

```powershell
$main = 'C:/Users/COLORFUL/Desktop/WuKong'
git -C $main stash list --date=local | Select-String 'backup before wukongim token redaction cleanup 2026-05-03'
git -C $main stash show --stat c63c276941b2a2a1b42d73fd96508f96a1783f7a
git -C $main stash apply --index c63c276941b2a2a1b42d73fd96508f96a1783f7a
```

If the stash entry is removed or rewritten, use the filesystem backup as a fallback:

```powershell
$main = 'C:/Users/COLORFUL/Desktop/WuKong'
$backup = 'C:/Users/COLORFUL/Desktop/WuKong-cleanup-backups/20260503-wukong-dirty-branch'

# Review first. These patch files may include local-only or sensitive development data.
git -C $main apply --check (Join-Path $backup 'staged.patch')
git -C $main apply --check (Join-Path $backup 'unstaged.patch')

# Restore tracked changes if the checks are acceptable.
git -C $main apply --index (Join-Path $backup 'staged.patch')
git -C $main apply (Join-Path $backup 'unstaged.patch')

# Restore untracked files from the archive if needed.
Expand-Archive -LiteralPath (Join-Path $backup 'untracked-copy.zip') -DestinationPath $main -Force
```

## Safety Notes

- The backup directory is intentionally outside the repository and should not be committed.
- Do not publish the backup patches or copied untracked files without a separate secret review.
- If applying the stash later, re-run the project test matrix before continuing feature work on `codex/customer-service-entry-personal-routing`.
