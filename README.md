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

| NOTE: This plugin under heavy maintenance, please expect broken changes

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
          logcat = {
              window_type = "float",
              height = 15,
              width = 100,
              filters = { tag = "MyApp", priority = "DEBUG" }
          },
          android = {
              auto_select_single_target = true,
          }
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
          logcat = {
              window_type = "float",
              height = 15,
              width = 100,
              filters = { tag = "MyApp", priority = "DEBUG" }
          },
          android = {
              auto_select_single_target = true,
          }
      })
  end,
}
```

## ⚙️ Configuration

The plugin can be configured by passing a table to `require("droid").setup()`. Configuration is organized into logical sections for better maintainability.

### Default Configuration

```lua
require("droid").setup({
    logcat = {
        window_type = "horizontal", -- "horizontal" | "vertical" | "float"
        height = 12,                -- Height for horizontal/float logcat
        width = 80,                 -- Width for vertical/float logcat
        filters = {},               -- e.g., { tag = "MyApp", priority = "DEBUG" }
    },
    android = {
        auto_select_single_target = true,  -- Auto-select if only one device/emulator
        adb_path = nil,                    -- Custom path to adb executable
        emulator_path = nil,               -- Custom path to emulator executable
        qt_qpa_platform = nil,             -- Qt platform for emulator (e.g., "xcb" for Linux)
        device_wait_timeout_ms = 30000,    -- Timeout for device/emulator readiness (ms)
    },
})
```

### Configuration Examples

#### Basic Float Setup

```lua
require("droid").setup({
    logcat = {
        window_type = "float",
        height = 20,
        width = 120,
        filters = { tag = "MyApp", priority = "DEBUG" },
    }
})
```

#### Custom Paths and Qt Platform

```lua
require("droid").setup({
    android = {
        auto_select_single_target = false,
        adb_path = "/custom/path/to/adb",
        emulator_path = "/custom/path/to/emulator",
        -- For Linux users with Qt platform issues:
        qt_qpa_platform = "xcb",
        device_wait_timeout_ms = 45000,
    }
})
```

#### Backward Compatibility

The plugin still supports the legacy flat configuration for existing users:

```lua
require("droid").setup({
    logcat_mode = "float",          -- Still works
    logcat_height = 15,            -- Still works
    auto_select_single_target = false, -- Still works
    adb_path = "/custom/path/to/adb",  -- Still works
})
```

### Configuration Options

#### Logcat Section

| Option        | Type     | Default        | Description                                                   |
| ------------- | -------- | -------------- | ------------------------------------------------------------- |
| `window_type` | `string` | `"horizontal"` | Window layout: `"horizontal"`, `"vertical"`, or `"float"`     |
| `height`      | `number` | `12`           | Window height for horizontal and float modes                  |
| `width`       | `number` | `80`           | Window width for vertical and float modes                     |
| `filters`     | `table`  | `{}`           | Logcat filters, e.g., `{ tag = "MyApp", priority = "DEBUG" }` |

#### Android Section

| Option                      | Type      | Default | Description                                                    |
| --------------------------- | --------- | ------- | -------------------------------------------------------------- |
| `auto_select_single_target` | `boolean` | `true`  | Auto-select if only one device/emulator is available           |
| `adb_path`                  | `string`  | `nil`   | Custom path to adb executable (overrides auto-detection)       |
| `emulator_path`             | `string`  | `nil`   | Custom path to emulator executable (overrides auto-detection)  |
| `qt_qpa_platform`           | `string`  | `nil`   | Qt platform for emulator (e.g., "xcb" for Linux compatibility) |
| `device_wait_timeout_ms`    | `number`  | `30000` | Timeout when waiting for emulator to be ready (milliseconds)   |

#### Qt Platform Configuration

The `qt_qpa_platform` setting applies globally to all emulator operations (launch, stop, wipe data). This is useful for Linux systems that need specific Qt platform configurations (in case if you have issue with QT_QPA_PLATFORM when working with emulator like me).

**Default Emulator Behavior:**
By default, the plugin uses Android Studio's performance optimizations: `-netdelay none -netspeed full` for all emulator operations.

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
