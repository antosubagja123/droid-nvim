<div align="center">

# 🤖 droid.nvim

**Android development workflow for Neovim**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-blue.svg?style=flat-square&logo=lua)](https://lua.org)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Build, run, and debug Android apps directly from Neovim.

</div>

## ✨ Features

- 🚀 **One-Command Workflow** - Build → Install → Launch → Logcat with `:DroidRun`
- 📱 **Smart Device Management** - Auto-detect devices/emulators
- 📋 **Real-time Logcat** - Filter by package, tag, log level, and patterns
- 🔧 **Gradle Integration** - Build, clean, sync with automatic `gradlew` detection
- ⚙️ **Flexible Windows** - Horizontal, vertical, or floating displays
- 🎯 **Simple Configuration** - Minimal setup required

## 📦 Installation

**Requirements:** Neovim 0.10+, Android SDK with `adb` in PATH

```lua
-- lazy.nvim
{
  "rrxxyz/droid-nvim",
  config = function()
    require("droid").setup()
  end,
}
```

**Optional Configuration:**

```lua
require("droid").setup({
  logcat = {
    mode = "horizontal", -- "horizontal" | "vertical" | "float"
    height = 15,
    filters = {
      package = "mine", -- "mine" (auto-detect) or specific package
      log_level = "d", -- v, d, i, w, e, f
    },
  },
  android = {
    auto_launch_app = true, -- Launch app after install
    qt_qpa_platform = "xcb", -- Linux: "xcb" or "wayland"
  },
})
```

## 🚀 Usage

### Essential Commands

| Command            | Description                           |
| ------------------ | ------------------------------------- |
| `:DroidRun`        | Build → Install → Launch → Logcat    |
| `:DroidLogcat`     | Show logcat for selected device      |
| `:DroidBuildDebug` | Build debug APK only                 |
| `:DroidInstall`    | Install APK without launching        |
| `:DroidDevices`    | Show available devices/emulators     |
| `:DroidEmulator`   | Start emulator from AVD list         |

### Gradle Commands

| Command             | Description                     |
| ------------------- | ------------------------------- |
| `:DroidClean`       | Clean project                  |
| `:DroidSync`        | Sync dependencies              |
| `:DroidTask <task>` | Run custom Gradle task         |

### Logcat Filtering

| Command                                | Description                      |
| -------------------------------------- | -------------------------------- |
| `:DroidLogcatFilter log_level=d`      | Show debug level and above       |
| `:DroidLogcatFilter tag=MyTag`        | Filter by specific tag           |
| `:DroidLogcatFilter package=mine`     | Show only your app's logs        |
| `:DroidLogcatFilter grep=Exception`   | Filter by text pattern           |

**Combine filters:** `:DroidLogcatFilter tag=MyTag log_level=d`

### Quick Setup

```lua
-- Recommended keybindings
vim.keymap.set("n", "<leader>ar", ":DroidRun<CR>", { desc = "Run Android app" })
vim.keymap.set("n", "<leader>al", ":DroidLogcat<CR>", { desc = "Open logcat" })
vim.keymap.set("n", "<leader>ab", ":DroidBuildDebug<CR>", { desc = "Build debug APK" })
vim.keymap.set("n", "<leader>ae", ":DroidEmulator<CR>", { desc = "Launch emulator" })
```

### Typical Workflow

1. **`:DroidRun`** - Build, install, launch, and show logcat
2. **`:DroidLogcatFilter package=mine log_level=d`** - Focus on your app
3. **`:DroidLogcatFilter tag=MyActivity`** - Filter specific components
4. Make code changes and repeat

### Examples

```vim
" Build and test
:DroidRun                            " Full workflow
:DroidTask assembleRelease           " Build release
:DroidTask testDebugUnitTest         " Run tests

" Logcat filtering
:DroidLogcatFilter package=mine      " Show only your app
:DroidLogcatFilter log_level=e       " Errors only
:DroidLogcatFilter grep=Exception    " Find exceptions
```

## 🔧 Setup

### Android SDK

The plugin auto-detects your Android SDK from:
- `ANDROID_SDK_ROOT` or `ANDROID_HOME` environment variables
- `vim.g.android_sdk` (manual override)
- Platform defaults (`~/Library/Android/sdk`, `/opt/android-sdk`, etc.)

### Project Requirements

1. Executable `gradlew` in project root: `chmod +x gradlew`
2. Android SDK with `adb` in PATH
3. Connected device or running emulator

### Linux Users

Set Qt platform for emulator compatibility:

```lua
require("droid").setup({
  android = { qt_qpa_platform = "xcb" },
})
```

## 🛠️ Troubleshooting

| Issue                     | Solution                                 |
| ------------------------- | ---------------------------------------- |
| **"gradlew not found"**   | Run `chmod +x gradlew` in project root   |
| **"Android SDK not found"** | Set `ANDROID_SDK_ROOT` environment variable |
| **"No devices available"** | Connect device or start emulator        |
| **Emulator won't start (Linux)** | Set `qt_qpa_platform = "xcb"` in config |

### Debug Commands

```vim
:messages                    " Check for errors
:DroidTask tasks            " List Gradle tasks
:lua print(require("droid.android").get_adb_path())  " Check ADB path
```

---

**License:** MIT | **Contributions:** Welcome!
