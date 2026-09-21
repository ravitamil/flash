# Upstream Synchronization & Contribution Guide

This guide details how **Flash** tracks, pulls, merges, and synchronizes upstream releases from the original repository:  
**[InlitX/streak](https://github.com/InlitX/streak)**.

---

## 1. Upstream Attribution & Open-Source Ethics

Flash is an open-source productivity app licensed under the **GNU General Public License v3 (GPLv3)**.
- **Original Creator & Maintainer**: [@InlitX](https://github.com/InlitX)
- **Original Repository**: `https://github.com/InlitX/streak`
- **Core Systems**: All foundational habit tracking, the local encrypted data vault, the focus timer, and base design tokens are courtesy of InlitX and the Streak contributors.
- **Support Upstream**: Please consider starring the original repository at [github.com/InlitX/streak](https://github.com/InlitX/streak) and supporting the creator on [Ko-fi](https://ko-fi.com/inlitx).

---

## 2. Git Remote Architecture

To keep the repository clean and ensure upstream updates can be integrated smoothly:

```
[InlitX/streak] (Upstream Remote: https://github.com/InlitX/streak.git)
       │
       ▼ (git fetch upstream)
[upstream/main]  ────────────────┐ (git merge / rebase)
                                 ▼
                         [main] (Your Flash Repository)
                         • Flash Rebranding (`com.flash.app`)
                         • To-Do Recurrence Engine
                         • To-Do Notes & Duration Sheets
                         • Statistics Tasks Dashboard
                         • Unified Navigation & FAB Design
```

### Checking Your Remotes
Configure `upstream` remote if not already present:
```bash
# Add upstream remote
git remote add upstream https://github.com/InlitX/streak.git

# Verify remotes
git remote -v
```
You should see:
- `origin`: Your repository (where you push Flash)
- `upstream`: `https://github.com/InlitX/streak.git` (where upstream releases come from)

---

## 3. How to Check for New Upstream Releases

You can check whether a new version of Streak has been released by running our automated check script:

### Windows (PowerShell)
```powershell
.\scripts\check_upstream.ps1
```

### Linux / macOS (Bash)
```bash
./scripts/check_upstream.sh
```

The script queries the GitHub Releases API for `InlitX/streak` and reports:
1. The latest released version tag and release date.
2. What commits or tags exist upstream that are not in your branch.
3. The release title and changelog notes.

---

## 4. Step-by-Step Update Workflow

When a new version is released upstream (for example, `v2.0.1` or `v2.1.0`):

### Step 1: Ensure Local Work is Committed
Always ensure your current working tree is committed or stashed before merging:
```bash
git status
```

### Step 2: Fetch Upstream Releases and Tags
```bash
git fetch upstream --tags
```

### Step 3: Inspect the Upstream Changes
Review what changed upstream between your current base and the new release tag:
```bash
# Compare commit log
git log --oneline HEAD..upstream/main

# Or inspect the release tag
git show v2.1.0
```

### Step 4: Merge the Upstream Release
```bash
git merge upstream/main
# Or merge the specific tag:
# git merge v2.1.0
```

### Step 5: Resolving Any Potential Conflicts
Because Flash features are designed modularly in dedicated files:
- `lib/features/statistics/data/todo_stats.dart`
- `lib/features/statistics/widgets/todo_statistics_view.dart`
- `lib/features/todos/data/todo_recurrence.dart`
- `lib/features/todos/widgets/todo_note_sheet.dart`
- `lib/features/todos/widgets/todo_duration_sheet.dart`

Upstream conflicts will be rare and primarily isolated to:
1. **Localization files (`lib/l10n/app_*.arb`)**: Keep upstream's new translation keys while preserving Flash's custom task/stats keys.
2. **Android Manifest**: Keep `package="com.flash.app"` and single launcher `MainActivity`.

### Step 6: Verify and Run Tests
```bash
# Static analysis
flutter analyze

# Unit test suite
flutter test

# Build debug or release APK
flutter build apk --debug
```

### Step 7: Push to Your Repository
```bash
git push origin main
```
