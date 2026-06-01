# ===== CONFIG =====
$SHA    = "<sha>"   # the flagged commit
$BRANCH = "main"    # your default branch

# ===== 1. COMMIT SHAPE & METADATA =====
Write-Host "=== Full metadata (author vs committer) ==="
git show --no-patch --format=fuller $SHA

Write-Host "=== Parent count (3 SHAs = merge commit, 2 = normal) ==="
git rev-list --parents -n 1 $SHA

Write-Host "=== Subject + identities ==="
git log -1 --format='%H%n%an <%ae>%n%cn <%ce>%n%s' $SHA

# ===== 2. HOW IT REACHED THE BRANCH =====
Write-Host "=== Graph around recent history ==="
git log --oneline --graph --decorate -n 20 $BRANCH

Write-Host "=== Mainline only (first-parent) ==="
git log --oneline --first-parent -n 20 $BRANCH

# ===== 3. TIE TO A PR =====
Write-Host "=== Merge commits on branch ==="
git log --merges --oneline $BRANCH | Select-Object -First 10

Write-Host "=== Commits referencing a PR number ==="
git log --oneline $BRANCH | Select-String -Pattern '#[0-9]+|merge pull request' | Select-Object -First 10

Write-Host "=== Branches/tags containing the commit ==="
git branch -a --contains $SHA

# ===== 4. COMMITTER IDENTITY (catches direct pushes) =====
Write-Host "=== Committer (web-flow/noreply = UI merge; personal email = likely direct push) ==="
git log -1 --format='committer: %cn <%ce>' $SHA
