# Config Restore Design (Code, Antigravity, Obsidian)

**Objective**
- Restore missing configuration content for `Code`, `Antigravity`, and `obsidian` from local `~/.config` into this repository while avoiding full cache/runtime mirroring.

**User Decision**
- Selected restore strategy: Approach C (broad user-state sync within config-focused boundaries).

**Context**
- Previous cleanup removed app-state-heavy folders from `Config-Arch`.
- Source folders in local machine are large (`Code` ~1.3G, `Antigravity` ~274M, `obsidian` ~133M), primarily due to cache/runtime data.

**Design**
- Recreate target directories under `Config-Arch`:
  - `Config-Arch/Code`
  - `Config-Arch/Antigravity`
  - `Config-Arch/obsidian`
- Restore Code and Antigravity broad user-state under `User/`:
  - include `settings.json`, `keybindings.json`, `snippets/`, `workspaceStorage/`, `globalStorage/`, `History/`
  - include additional portable files present in Code user settings (`mcp.json`, `chatLanguageModels.json`, `sync/`)
- Restore Obsidian app-level configuration files only (not cache/runtime directories):
  - include stable top-level config files such as `obsidian.json`, `Preferences`, `id` and related small metadata files
- Keep repository `.gitignore` protections for cache/runtime artifact paths.

**Out of Scope**
- Full mirror of Electron/Chromium runtime state (`Cache`, `Code Cache`, `Crashpad`, storage DB caches, logs).
- Installer logic changes.

**Validation**
- Verify recreated directories exist in `Config-Arch`.
- Verify restored contents are present and expected.
- Verify `git status` shows restored config files without cache flood.

**Expected Result**
- Repository includes requested Code/Antigravity/Obsidian configuration content from local system while remaining manageable for Git tracking.
