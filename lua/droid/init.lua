local config = require "droid.config"
local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local commands = require "droid.commands"
local actions = require "droid.actions"

local M = {}

function M.setup(opts)
    config.setup(opts)
    commands.setup_commands()
end

-- Export high-level workflow functions (recommended for users)
M.build_and_run = actions.build_and_run
M.install_only = actions.install_only
M.install_and_launch = actions.install_and_launch
M.logcat_only = actions.logcat_only
M.show_devices = actions.show_devices
M.start_emulator = actions.start_emulator

-- Export individual module functions (for advanced users)
M.gradle_sync = gradle.sync
M.gradle_clean = gradle.clean
M.gradle_build_debug = gradle.build_debug
M.gradle_install_debug = gradle.install_debug
M.gradle_task = gradle.task
M.toggle_gradle_window = gradle.toggle_gradle_window

M.launch_emulator = android.launch_emulator
M.stop_emulator = android.stop_emulator
M.wipe_emulator_data = android.wipe_emulator_data

M.logcat_stop = logcat.stop

-- Backward compatibility (deprecated - use actions instead)
M.gradle_run = actions.build_and_run
M.logcat_open = logcat.open

return M
