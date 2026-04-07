# Config Restore Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore requested Code, Antigravity, and Obsidian configuration content from `~/.config` into `Config-Arch` without reintroducing full cache/runtime bloat.

**Architecture:** Recreate the three target directories and copy selected source content from local `~/.config` using deterministic shell copy commands. For Code and Antigravity, restore `User/` state as selected in Approach C. For Obsidian, restore only top-level config files and skip cache/runtime subdirectories. Validate via directory listings, size checks, and git status.

**Tech Stack:** Git, shell commands (`mkdir`, `cp`, `rsync`, `ls`, `du`), repository `.gitignore`.

---

### Task 1: Verify Source and Destination Paths

**Files:**
- Modify: none
- Test: command output only

**Step 1: Verify source directories exist**

Run: `ls -la /home/jain/.config/Code /home/jain/.config/Antigravity /home/jain/.config/obsidian`
Expected: all three source paths exist.

**Step 2: Verify destination base exists**

Run: `ls -la Config-Arch`
Expected: `Config-Arch` exists and does not yet contain `Code`, `Antigravity`, `obsidian`.

### Task 2: Recreate Destination Folders

**Files:**
- Create: `Config-Arch/Code/`
- Create: `Config-Arch/Antigravity/`
- Create: `Config-Arch/obsidian/`
- Test: command output only

**Step 1: Create destination directories**

Run: `mkdir -p Config-Arch/Code Config-Arch/Antigravity Config-Arch/obsidian`
Expected: command succeeds with no errors.

**Step 2: Verify new directories**

Run: `ls -la Config-Arch`
Expected: all three new directories are present.

### Task 3: Restore Code User State (Approach C)

**Files:**
- Create: `Config-Arch/Code/User/**`
- Test: command output only

**Step 1: Copy Code User directory recursively**

Run: `rsync -a /home/jain/.config/Code/User/ Config-Arch/Code/User/`
Expected: `Config-Arch/Code/User` contains settings, keybindings, snippets, workspace/global storage, history, and sync data.

**Step 2: Verify restored structure**

Run: `ls -la Config-Arch/Code/User`
Expected: includes `settings.json`, `keybindings.json`, `snippets/`, `workspaceStorage/`, `globalStorage/`, `History/`, `mcp.json`, `chatLanguageModels.json`, `sync/`.

### Task 4: Restore Antigravity User State (Approach C)

**Files:**
- Create: `Config-Arch/Antigravity/User/**`
- Test: command output only

**Step 1: Copy Antigravity User directory recursively**

Run: `rsync -a /home/jain/.config/Antigravity/User/ Config-Arch/Antigravity/User/`
Expected: `Config-Arch/Antigravity/User` contains settings, keybindings, snippets, workspace/global storage, and history.

**Step 2: Verify restored structure**

Run: `ls -la Config-Arch/Antigravity/User`
Expected: includes `settings.json`, `keybindings.json`, `snippets/`, `workspaceStorage/`, `globalStorage/`, `History/`.

### Task 5: Restore Obsidian Config Files

**Files:**
- Create: `Config-Arch/obsidian/obsidian.json`
- Create: `Config-Arch/obsidian/Preferences`
- Create: `Config-Arch/obsidian/id`
- Create: `Config-Arch/obsidian/f8bb96da1fa09244.json` (if present)
- Test: command output only

**Step 1: Copy selected Obsidian top-level config files**

Run: `cp -f /home/jain/.config/obsidian/obsidian.json /home/jain/.config/obsidian/Preferences /home/jain/.config/obsidian/id /home/jain/.config/obsidian/f8bb96da1fa09244.json Config-Arch/obsidian/`
Expected: files copied successfully.

**Step 2: Verify Obsidian target content**

Run: `ls -la Config-Arch/obsidian`
Expected: target contains only selected config files, not cache/runtime folders.

### Task 6: Validate and Commit

**Files:**
- Modify: none
- Test: command output only

**Step 1: Validate directory sizes**

Run: `du -sh Config-Arch/Code Config-Arch/Antigravity Config-Arch/obsidian`
Expected: restored sizes reflect selected state and remain below full source mirror sizes.

**Step 2: Validate git scope**

Run: `git status --short`
Expected: shows newly restored config content and no cache/runtime flood from ignored paths.

**Step 3: Commit restore changes**

Run: `git add Config-Arch/Code Config-Arch/Antigravity Config-Arch/obsidian docs/plans/2026-04-07-config-restore-design.md docs/plans/2026-04-07-config-restore.md && git commit -m "Restore Code, Antigravity, and Obsidian configs from local system"`
Expected: single commit created.

**Step 4: Push branch**

Run: `git push origin main`
Expected: remote branch updated successfully.
