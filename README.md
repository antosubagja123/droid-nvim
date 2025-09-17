<div align="center">

# 🤖 droid.nvim

**Complete Android development workflow for Neovim**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-blue.svg?style=flat-square&logo=lua)](https://lua.org)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Build, run, and debug Android apps directly from Neovim with real-time logcat filtering.

</div>

## ✨ Features

- 🔧 **Gradle Integration** - Build, clean, sync, and run custom tasks
- 📱 **Emulator Integration** - Run, Stop, Device/emulator List and Selection
- 📋 **Advanced Logcat** - Real-time filtering by package, tag, log level, and text patterns
- 🚀 **Rich-Command Workflow** - Build → Install → Launch → Logcat in one step
- ⚙️ **Flexible Windows** - Horizontal, vertical, or floating logcat display

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
  },
  android = {
    auto_select_single_target = true,
    auto_launch_app = true,
  },
})
```

## 🚀 Usage

### Core Commands

| Command            | Description                                           |
| ------------------ | ----------------------------------------------------- |
| `:DroidRun`        | Build → Install → Launch → Logcat (complete workflow) |
| `:DroidBuildDebug` | Build debug APK only                                  |
| `:DroidLogcat`     | Open logcat viewer                                    |
| `:DroidLogcatStop` | Stop logcat                                           |

### Logcat Filtering

| Command                                | Example                                             |
| -------------------------------------- | --------------------------------------------------- |
| `:DroidLogcatFilter log_level=<level>` | `log_level=d` (debug+), `log_level=e` (errors only) |
| `:DroidLogcatFilter tag=<name>`        | `tag=MyTag`                                         |
| `:DroidLogcatFilter package=<name>`    | `package=com.example.app`                           |
| `:DroidLogcatFilter grep=<pattern>`    | `grep=Network`                                      |

**Combine filters:** `:DroidLogcatFilter tag=MyTag log_level=d`

### Other Commands

| Command             | Description            |
| ------------------- | ---------------------- |
| `:DroidTask <task>` | Run custom Gradle task |
| `:DroidEmulator`    | Launch emulator        |
| `:DroidSync`        | Sync dependencies      |
| `:DroidClean`       | Clean project          |

### Quick Setup

```lua
-- Recommended keybindings
vim.keymap.set("n", "<leader>ar", ":DroidRun<CR>", { desc = "Run Android app" })
vim.keymap.set("n", "<leader>ab", ":DroidBuildDebug<CR>", { desc = "Build debug APK" })
vim.keymap.set("n", "<leader>al", ":DroidLogcat<CR>", { desc = "Open logcat" })
vim.keymap.set("n", "<leader>ax", ":DroidLogcatStop<CR>", { desc = "Stop logcat" })
```

### Typical Workflow

1. **`:DroidRun`** - Build, install, and launch your app with logcat
2. **`:DroidLogcatFilter log_level=e`** - Filter to show only errors
3. **`:DroidLogcatFilter tag=MyTag`** - Focus on specific component
4. **`:DroidLogcatStop`** - Stop when done

### Examples

```vim
:DroidTask assembleRelease           " Build release APK
:DroidTask testDebugUnitTest         " Run unit tests
:DroidLogcatFilter package=mine log_level=d  " Your app, debug level+
```

## Environment Setup

Set your Android SDK path:

```lua
vim.g.android_sdk = "/path/to/android-sdk"  -- Optional if ANDROID_SDK_ROOT is set
```

Make sure `gradlew` is executable: `chmod +x gradlew`

## Troubleshooting

**Common Issues:**

- **"gradlew not found"**: Run `chmod +x gradlew` in your project
- **"Android SDK not found"**: Set `ANDROID_SDK_ROOT` or `ANDROID_HOME`
- **"No devices available"**: Check `adb devices`
- **Emulator won't start because QT Platform issue (Linux)**: Set `qt_qpa_platform = "xcb"` in config

---

**License:** MIT | **Contributions:** Welcome!
