<div align="center">

# 🤖 droid.nvim

**Complete Android development workflow for Neovim**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-blue.svg?style=flat-square&logo=lua)](https://lua.org)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Build, run, and debug Android apps directly from Neovim with real-time logcat filtering.

</div>

## ✨ Features

- 🔧 **Gradle Integration** - Build, clean, sync, and run custom tasks with automatic `gradlew` detection
- 📱 **Smart Device Management** - Auto-detect devices/emulators with interactive selection
- 📋 **Advanced Logcat** - Real-time filtering by package, tag, log level, and regex patterns
- 🚀 **One-Command Workflow** - Build → Install → Launch → Logcat in a single `:DroidRun`
- ⚙️ **Flexible Display** - Horizontal, vertical, or floating logcat windows
- 🎯 **Smart Session Management** - Automatic logcat reuse and efficient process cleanup
- 🔄 **Progress Indicators** - Visual feedback for long-running operations
- 🏗️ **Modular Architecture** - Composable actions for custom workflows

## 📦 Installation

**Requirements:** Neovim 0.10+, Android SDK, project with `gradlew`

```lua
-- lazy.nvim
{
  "rizukirr/droid-nvim",
  config = function()
    require("droid").setup()
  end,
}
```

**Configuration (optional):**

```lua
require("droid").setup({
  logcat = {
    window_type = "horizontal", -- "horizontal" | "vertical" | "float"
    height = 12,
    width = 80,
    filters = {
      package = "mine", -- "mine" (auto-detect), specific package, or "none"
      log_level = "v", -- v, d, i, w, e, f
      tag = nil, -- specific tag or nil
      grep_pattern = nil, -- regex pattern or nil
    },
  },
  android = {
    auto_select_single_target = true, -- Auto-select if only one device
    auto_launch_app = true, -- Auto-launch after install
    device_wait_timeout_ms = 30000, -- Device wait timeout
    logcat_startup_delay_ms = 2000, -- Delay before logcat starts
    qt_qpa_platform = nil, -- Qt platform for emulator (Linux: "xcb")
  },
})
```

## 🚀 Usage

### Core Commands

| Command            | Description                                           |
| ------------------ | ----------------------------------------------------- |
| `:DroidRun`        | **Complete workflow:** Build → Install → Launch → Logcat |
| `:DroidBuildDebug` | Build debug APK only                                  |
| `:DroidLogcat`     | Open logcat viewer (device selection if needed)       |
| `:DroidLogcatStop` | Stop logcat and close window                          |

### Gradle Commands

| Command                | Description                           |
| ---------------------- | ------------------------------------- |
| `:DroidClean`          | Clean project (`./gradlew clean`)     |
| `:DroidSync`           | Sync dependencies (`--refresh-dependencies`) |
| `:DroidTask <task>`    | Run custom Gradle task with args     |
| `:DroidInstall`        | Install APK without launching         |

### Device & Emulator Management

| Command                    | Description                      |
| -------------------------- | -------------------------------- |
| `:DroidDevices`            | Show device selection dialog     |
| `:DroidEmulator`           | Launch emulator (AVD picker)     |
| `:DroidEmulatorStop`       | Stop running emulator            |
| `:DroidEmulatorWipeData`   | Wipe emulator data               |
| `:DroidStartEmulator`      | Start emulator workflow          |

### Advanced Logcat Features

| Command                                | Description                                 |
| -------------------------------------- | ------------------------------------------- |
| `:DroidLogcatFilter log_level=<level>` | Filter by log level: `v`, `d`, `i`, `w`, `e`, `f` |
| `:DroidLogcatFilter tag=<name>`        | Filter by specific tag                      |
| `:DroidLogcatFilter package=<name>`    | Filter by package (`mine` = auto-detect)   |
| `:DroidLogcatFilter grep=<pattern>`    | Filter by regex pattern                     |
| `:DroidLogcatFilterShow`               | Show currently active filters              |
| `:DroidLogcatToggleAutoScroll`         | Toggle auto-scroll to bottom                |

**Combine filters:** `:DroidLogcatFilter tag=MyTag log_level=d package=mine`

### Smart Logcat Behavior

- **Session Reuse**: Running `:DroidRun` twice preserves logcat history
- **Filter Changes**: New filters restart logcat (previous content lost)
- **Device Changes**: Switching devices restarts logcat
- **Window Management**: Logcat windows reopen automatically when needed

### Quick Setup

```lua
-- Recommended keybindings
vim.keymap.set("n", "<leader>ar", ":DroidRun<CR>", { desc = "Run Android app" })
vim.keymap.set("n", "<leader>ab", ":DroidBuildDebug<CR>", { desc = "Build debug APK" })
vim.keymap.set("n", "<leader>al", ":DroidLogcat<CR>", { desc = "Open logcat" })
vim.keymap.set("n", "<leader>ax", ":DroidLogcatStop<CR>", { desc = "Stop logcat" })
vim.keymap.set("n", "<leader>ae", ":DroidEmulator<CR>", { desc = "Launch emulator" })
vim.keymap.set("n", "<leader>ad", ":DroidDevices<CR>", { desc = "Show devices" })
```

### Typical Development Workflow

1. **`:DroidRun`** - Complete workflow: build, install, launch with logcat
2. **`:DroidLogcatFilter log_level=e`** - Filter to show only errors
3. **`:DroidLogcatFilter tag=MyActivity`** - Focus on specific component
4. **`:DroidLogcatFilter package=mine grep=API`** - Your app's API calls only
5. **`:DroidRun`** - Run again (reuses logcat, preserves history)
6. **`:DroidLogcatStop`** - Stop when done

### Real-World Examples

```vim
" Development commands
:DroidTask assembleRelease           " Build release APK
:DroidTask testDebugUnitTest         " Run unit tests
:DroidTask connectedAndroidTest      " Run instrumented tests
:DroidTask bundleRelease             " Build app bundle

" Logcat filtering examples
:DroidLogcatFilter package=mine log_level=d    " Your app, debug level+
:DroidLogcatFilter tag=NetworkManager          " Focus on network logs
:DroidLogcatFilter grep=Exception               " Show only exceptions
:DroidLogcatFilter log_level=e package=none    " All errors, all apps

" Device management
:DroidEmulator                       " Launch emulator with AVD picker
:DroidEmulatorWipeData              " Clean emulator for fresh testing
:DroidDevices                       " See available devices
```

### Power User Tips

- Use `:DroidLogcatFilterShow` to see active filters
- Logcat auto-scrolls by default, toggle with `:DroidLogcatToggleAutoScroll`
- Package `mine` automatically detects your project's package name
- Combine multiple filters for precise debugging
- Window reopens automatically if closed while logcat runs

## 🔧 Environment Setup

### Android SDK Configuration

The plugin automatically detects your Android SDK from these locations (in order):

1. `vim.g.android_sdk` (Neovim variable)
2. `ANDROID_SDK_ROOT` environment variable
3. `ANDROID_HOME` environment variable
4. Platform-specific defaults:
   - **Linux**: `/opt/android-sdk`, `/usr/lib/android-sdk`
   - **macOS**: `~/Library/Android/sdk`, `/usr/local/lib/android/sdk`
   - **Windows**: `%LOCALAPPDATA%/Android/Sdk`, `%PROGRAMFILES%/Android/Android Studio/sdk`

**Manual override:**
```lua
vim.g.android_sdk = "/path/to/android-sdk"
```

### Project Setup

1. **Make gradlew executable**: `chmod +x gradlew`
2. **Ensure ADB access**: `adb devices` should list your devices
3. **Test emulator**: `emulator -list-avds` should show available AVDs

### Linux-Specific Setup

For emulator compatibility on Linux:
```lua
require("droid").setup({
  android = {
    qt_qpa_platform = "xcb",  -- or "wayland", "offscreen"
  },
})
```

## 🛠️ Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **"gradlew not found"** | Run `chmod +x gradlew` in project root |
| **"Android SDK not found"** | Set `ANDROID_SDK_ROOT`/`ANDROID_HOME` or `vim.g.android_sdk` |
| **"No devices available"** | Check `adb devices`, ensure devices/emulators are connected |
| **"Emulator won't start"** | Set `qt_qpa_platform = "xcb"` in config (Linux) |
| **"Package not found"** | Ensure `applicationId` is in `android/app/build.gradle` |
| **Logcat not filtering** | Check filters with `:DroidLogcatFilterShow` |

### Debugging Commands

```vim
:messages                           " Check for plugin errors
:lua print(vim.inspect(require("droid.config").config))  " Show current config
:lua print(require("droid.android").get_adb_path())      " Check ADB path
:DroidTask tasks                    " List available Gradle tasks
```

### Performance Tips

- Use specific package filters to reduce logcat noise
- Close logcat windows when not needed to free resources
- Use `:DroidLogcatStop` instead of just closing windows
- Restart logcat if it becomes unresponsive

---

**License:** MIT | **Contributions:** Welcome!
