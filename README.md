<div align="center">

# 🤖 droid.nvim

**Bring Android Studio experience to Neovim**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-blue.svg?style=flat-square&logo=lua)](https://lua.org)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Complete Android development workflow in Neovim - build, install, launch, and debug your apps with the same seamless experience as Android Studio.

</div>

> **⚠️ Development Status**
> This project is under heavy maintenance. Expect breaking changes and frequent updates as we improve the codebase.

## ✨ Features

- 🔧 **Gradle Integration** - Build, clean, sync, and run custom Gradle tasks
- 📱 **Device Management** - Automatic device/emulator detection and selection
- 📋 **Logcat Support** - Real-time logcat output in multiple window modes
- 🚀 **Auto Launch** - Automatically launches apps after installation (like Android Studio)
- ⚡ **Simple Commands** - Intuitive commands for common Android development tasks
- ⚙️ **Configurable** - Flexible configuration for different development setups

## 📦 Installation

### Requirements

- Neovim 0.10.0+
- Android SDK with `adb` and `emulator`
- Android project with `gradlew`

### lazy.nvim

```lua
{
  "rizukirr/droid-nvim",
  config = function()
      require("droid").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "rizukirr/droid-nvim",
  config = function()
      require("droid").setup()
  end,
}
```

## ⚙️ Configuration

Optional configuration can be passed to `setup()`:

```lua
require("droid").setup({
    logcat = {
        window_type = "horizontal", -- "horizontal" | "vertical" | "float"
        height = 12,
        width = 80,
    },
    android = {
        auto_select_single_target = true,
        auto_launch_app = true,     -- Launch app after install
    },
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
| `:DroidEmulator`           | Launch an emulator (standalone AVD picker)                        |
| `:DroidEmulatorStop`       | Stop a running emulator                                           |
| `:DroidEmulatorWipeData`   | Wipe emulator data (handles running emulators automatically)      |

### 🎯 Recommended Keybindings

```lua
vim.keymap.set("n", "<leader>ar", ":DroidRun<CR>", { desc = "Run Android app" })
vim.keymap.set("n", "<leader>ab", ":DroidBuildDebug<CR>", { desc = "Build debug APK" })
vim.keymap.set("n", "<leader>ac", ":DroidClean<CR>", { desc = "Clean project" })
vim.keymap.set("n", "<leader>as", ":DroidSync<CR>", { desc = "Sync dependencies" })
vim.keymap.set("n", "<leader>al", ":DroidLogcat<CR>", { desc = "Open logcat" })
vim.keymap.set("n", "<leader>ax", ":DroidLogcatStop<CR>", { desc = "Stop logcat" })
vim.keymap.set("n", "<leader>ae", ":DroidEmulator<CR>", { desc = "Launch emulator" })
vim.keymap.set("n", "<leader>aE", ":DroidEmulatorStop<CR>", { desc = "Stop emulator" })
vim.keymap.set("n", "<leader>aw", ":DroidEmulatorWipeData<CR>", { desc = "Wipe emulator data" })
```

### 📋 Common Workflows

#### Development Cycle

1. `:DroidSync` - Sync dependencies when `build.gradle` changes
2. `:DroidBuildDebug` - Build your app to check for compilation errors
3. `:DroidRun` - Deploy and run with live logcat output
4. `:DroidLogcat vertical` - Switch logcat to vertical mode if needed
5. `:DroidLogcatStop` - Stop logcat when done

#### Testing on Multiple Devices

1. `:DroidEmulator` - Launch additional emulators
2. `:DroidRun` - Select different targets for each run
3. Use multiple Neovim instances for parallel logcat monitoring

#### Emulator Management

1. `:DroidEmulator` - Launch a new emulator instance
2. `:DroidEmulatorStop` - Stop running emulators when done
3. `:DroidEmulatorWipeData` - Reset emulator to clean state (handles running emulators automatically)

#### Custom Gradle Tasks

```lua
:DroidTask assembleRelease           -- Build release APK
:DroidTask testDebugUnitTest        -- Run unit tests
:DroidTask connectedDebugAndroidTest -- Run instrumented tests
:DroidTask bundleRelease            -- Build app bundle
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
- **Emulator won't start on Linux**: Try setting the Qt platform:
  ```lua
  android = {
      qt_qpa_platform = "xcb"
  }
  ```
  **Common Qt Platform Values:**
  - `"xcb"` - For Linux X11 systems (most common)
  - `"wayland"` - For Linux Wayland systems
  - `"offscreen"` - For headless/server environments
  - `nil` - Use system default (default)
- **Emulator starts but app doesn't install**: Wait for the emulator to fully boot before running `:DroidRun`.
- **Permission denied errors**: Ensure `gradlew` has execute permissions and emulator tools are accessible.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests to help improve droid.nvim.

## 📄 License

MIT License

---

<div align="center">
<sub>If this plugin helps your workflow, consider <a href="https://ko-fi.com/rizukirr">buying me a coffee</a> ☕</sub>
</div>
