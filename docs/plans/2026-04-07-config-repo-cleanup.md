# Config Repo Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove non-portable app-state/cache bloat from the repo and enforce ignore rules so future commits only contain real configuration files.

**Architecture:** This cleanup uses a two-layer approach: (1) delete known high-volume app-state directories that are not portable configuration, and (2) define repository-level ignore patterns for cache/runtime artifacts that should never be committed. Validation is command-driven with `du` and `git status` checkpoints after each change block.

**Tech Stack:** Git, shell utilities (`du`, `rm`), repository `.gitignore` rules.

---

### Task 1: Baseline Snapshot

**Files:**
- Modify: none
- Test: command output only

**Step 1: Record current top-level sizes**

Run: `du -sh ./* ./.git 2>/dev/null | sort -h`
Expected: `Config-Arch` is the dominant directory.

**Step 2: Record current `Config-Arch` subdirectory sizes**

Run: `du -sh Config-Arch/* 2>/dev/null | sort -h`
Expected: `Config-Arch/Code`, `Config-Arch/Antigravity`, and `Config-Arch/obsidian` appear as major size outliers.

**Step 3: Record current Git state**

Run: `git status --short --untracked-files=all`
Expected: extensive untracked runtime artifacts under app-state folders.

### Task 2: Add Ignore Guardrails

**Files:**
- Create: `.gitignore`
- Test: command output only

**Step 1: Create root `.gitignore` with runtime artifact patterns**

```gitignore
# Python bytecode
__pycache__/
*.pyc
*.pyo

# Logs and dumps
*.log
*.dmp

# Generic app/runtime cache and state
**/Cache/
**/Code Cache/
**/GPUCache/
**/DawnGraphiteCache/
**/DawnWebGPUCache/
**/CachedData/
**/CachedConfigurations/
**/CachedProfilesData/
**/CachedExtensionVSIXs/
**/Crashpad/
**/blob_storage/
**/Service Worker/
**/Session Storage/
**/Local Storage/
**/WebStorage/
**/IndexedDB/
**/shared_proto_db/

# Chromium/Electron sqlite and journaling artifacts
**/Cookies
**/Cookies-journal
**/Network Persistent State
**/Trust Tokens
**/Trust Tokens-journal
```

**Step 2: Verify ignore impact**

Run: `git status --short`
Expected: untracked flood is reduced; tracked config changes remain visible.

### Task 3: Remove App-State Directories

**Files:**
- Delete: `Config-Arch/Code`
- Delete: `Config-Arch/Antigravity`
- Delete: `Config-Arch/obsidian`
- Test: command output only

**Step 1: Remove app-state directories**

Run: `rm -rf Config-Arch/Code Config-Arch/Antigravity Config-Arch/obsidian`
Expected: command completes without prompts/errors.

**Step 2: Confirm directories are removed**

Run: `ls Config-Arch`
Expected: those three paths are absent while real config directories remain.

### Task 4: Verify Cleanup and Commit Readiness

**Files:**
- Modify: none
- Test: command output only

**Step 1: Re-check `Config-Arch` size distribution**

Run: `du -sh Config-Arch/* 2>/dev/null | sort -h`
Expected: major size outliers are gone.

**Step 2: Re-check Git diff scope**

Run: `git status --short`
Expected: concise list with meaningful config edits and new `.gitignore` only.

**Step 3: Optional staged review for commit**

Run: `git add .gitignore Config-Arch/i3/config Config-Arch/opencode/opencode.json Config-Arch/opencode/package.json`
Expected: only intended files staged.

**Step 4: Optional commit**

Run: `git commit -m "chore: remove app-state bloat and ignore runtime artifacts"`
Expected: commit created with cleanup-focused message.
