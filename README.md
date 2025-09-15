<div align="center">

# 🤖 droid.nvim

**The ultimate Android development companion for Neovim**

_Build, run, and debug Android apps without leaving your editor_

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-blue.svg?style=flat-square&logo=lua)](https://lua.org)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

---

**droid.nvim** streamlines your Android development workflow with seamless Gradle, ADB, and emulator integration. Build, deploy, and monitor your apps directly from Neovim with real-time logcat output.

</div>

| NOTE: This plugin not yet finish

## ✨ Features

- 🔧 **Gradle Integration** - Run common tasks like `sync`, `clean`, `assembleDebug`, and custom tasks with flexible output modes
- 📱 **Device & Emulator Management** - Detect and select connected Android devices or emulators (AVDs) seamlessly
- 📋 **Logcat Support** - View `logcat` output in horizontal, vertical, or floating windows with filtering capabilities
- 🔍 **Automatic SDK Detection** - Smart detection using environment variables, global settings, or platform defaults
- ⚡ **Intuitive Commands** - Simple commands like `:DroidRun`, `:DroidBuildDebug`, `:DroidLogcat` for common tasks
- 🛡️ **Robust Error Handling** - Clear notifications for success, failure, and edge cases
- ⚙️ **Highly Configurable** - Flexible options for logcat display, device selection, and executable paths

## 📦 Installation

### Requirements

- Neovim 0.10.0 or later
- Android SDK with `adb` and `emulator` installed
- Gradle (with `gradlew` in your project)
- Optional: `vim.ui.select` support (e.g., via `telescope.nvim` for interactive selection)

#### lazy.nvim

```lua
{
  "rizukirr/droid-nvim",
  config = function()
      require("droid").setup({
          -- Optional configuration
          logcat_mode = "float",
          logcat_height = 15,
          logcat_width = 100,
          auto_select_single_target = true,
      })
  end,
}
```

#### packer.nvim

```lua
use {
  "rizukirr/droid-nvim",
  config = function()
      require("droid").setup({
          -- Optional configuration
          logcat_mode = "float",
          logcat_height = 15,
          logcat_width = 100,
          auto_select_single_target = true,
      })
  end,
}
```

## ⚙️ Configuration

The plugin can be configured by passing a table to `require("droid").setup()`. The default configuration is:

```lua
require("droid").setup({
  logcat_mode = "horizontal", -- "horizontal" | "vertical" | "float"
  logcat_height = 12,         -- Height for horizontal/float logcat
  logcat_width = 80,          -- Width for vertical/float logcat
  auto_select_single_target = true, -- Auto-select if only one device/emulator
  logcat_filters = {},        -- e.g., { tag = "MyApp", priority = "DEBUG" }
  adb_path = nil,             -- Custom path to adb executable
  emulator_path = nil,        -- Custom path to emulator executable
  device_wait_timeout_ms = 30000, -- Timeout for device/emulator readiness (ms)
})
```

### Example Configuration

```lua
 require("droid").setup({
  logcat_mode = "float",
  logcat_filters = { tag = "MyApp", priority = "DEBUG" },
  auto_select_single_target = false,
  adb_path = "/custom/path/to/adb",
})
```

## 🚀 Usage

### Commands

| Command                    | Description                                                       |
| -------------------------- | ----------------------------------------------------------------- |
| `:DroidRun`                | Build and install the debug variant with logcat output            |
| `:DroidBuildDebug`         | Run `assembleDebug` Gradle task to build debug APK                |
| `:DroidClean`              | Run `clean` Gradle task to clear build artifacts                  |
| `:DroidSync`               | Run `gradlew --refresh-dependencies` to sync dependencies         |
| `:DroidTask <task> [args]` | Run custom Gradle task (e.g., `:DroidTask assembleRelease`)       |
| `:DroidLogcat [mode]`      | Open logcat in specified mode (`horizontal`, `vertical`, `float`) |
| `:DroidLogcatStop`         | Stop active logcat process and close buffer                       |

### 🎯 Recommended Keybindings

```lua
vim.keymap.set("n", "<leader>ar", ":DroidRun<CR>", { desc = "Run Android app" })
vim.keymap.set("n", "<leader>ab", ":DroidBuildDebug<CR>", { desc = "Build debug APK" })
vim.keymap.set("n", "<leader>ac", ":DroidClean<CR>", { desc = "Clean project" })
vim.keymap.set("n", "<leader>as", ":DroidSync<CR>", { desc = "Sync dependencies" })
vim.keymap.set("n", "<leader>al", ":DroidLogcat<CR>", { desc = "Open logcat" })
vim.keymap.set("n", "<leader>ax", ":DroidLogcatStop<CR>", { desc = "Stop logcat" })
```

## 🔧 Environment Setup

- Ensure the Android SDK is installed and either `ANDROID_SDK_ROOT` or `ANDROID_HOME` is set, or set `vim.g.android_sdk` in Neovim:

```lua
 vim.g.android_sdk = "/path/to/android-sdk"
```

- Ensure `gradlew` is executable in your project directory.

## 📝 Notes

- The plugin automatically detects the Android SDK and Gradle wrapper (`gradlew`) in your project.
- If only one device/emulator is available, it can be auto-selected (configurable via `auto_select_single_target`).
- Logcat output is displayed in a scratch buffer with the `logcat` filetype, which can be customized with syntax highlighting (not included by default).
- The plugin ensures `logcat` processes are cleaned up when the buffer is closed or Neovim exits.

## 🔧 Troubleshooting

- **"gradlew not found"**: Ensure your project has an executable `gradlew` file. Run `chmod +x gradlew` if needed.
- **"Android SDK not found"**: Set `ANDROID_SDK_ROOT`, `ANDROID_HOME`, or `vim.g.android_sdk` to the SDK path.
- **"No devices or emulators available"**: Ensure `adb` is running and devices/emulators are connected (`adb devices`).
- **Logcat not showing**: Check if the selected device is online and supports `logcat`.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests to help improve droid.nvim.

## 📄 License

MIT License
