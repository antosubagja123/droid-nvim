local config = require "droid.config"
local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local commands = require "droid.commands"

local M = {}

function M.setup(opts)
    config.setup(opts)
    commands.setup_commands()
end

-- Export public API functions
M.gradle_sync = gradle.sync
M.gradle_clean = gradle.clean
M.gradle_build_debug = gradle.build_debug
M.gradle_run = function()
    local adb = android.get_adb_path()
    local emulator = android.get_emulator_path()

    if not adb or not emulator then
        return
    end

    android.choose_target(adb, emulator, function(target)
        if target.type == "device" then
            vim.notify("Installing on " .. target.name, vim.log.levels.INFO)
            gradle.install_debug(function()
                logcat.open(adb, target.id)
            end)
        elseif target.type == "avd" then
            android.start_emulator(emulator, target.avd)

            -- Wait until device is ready and get its device ID
            android.wait_for_device_id(adb, function(device_id)
                gradle.install_debug(function()
                    logcat.open(adb, device_id)
                end)
            end)
        end
    end)
end
M.gradle_task = gradle.task
M.show_gradle_log = gradle.show_log
M.launch_emulator = android.launch_emulator
M.stop_emulator = android.stop_emulator
M.wipe_emulator_data = android.wipe_emulator_data

return M
