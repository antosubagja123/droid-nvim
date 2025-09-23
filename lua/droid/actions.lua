-- High-level workflow actions for droid.nvim
-- Simplified, reusable functions for common Android development tasks

local config = require "droid.config"
local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local progress = require "droid.progress"

local M = {}

-- Helper function to handle common post-install workflow
local function handle_post_install(tools, device_id, session_id, launch_app)
    local cfg = config.get()

    local function start_logcat()
        local delay_ms = cfg.android.logcat_startup_delay_ms or 2000
        vim.defer_fn(function()
            logcat.refresh_logcat(tools.adb, device_id, nil, {})
            local message = launch_app and "Build, install, and launch completed" or "Build and install completed"
            progress.stop_loading(session_id, true, message)
        end, delay_ms)
    end

    if launch_app and cfg.android.auto_launch_app then
        android.launch_app_on_device(tools.adb, device_id, start_logcat)
    else
        start_logcat()
    end
end

-- Helper function to execute build and install workflow
local function execute_build_install(tools, device_id, session_id, launch_app)
    gradle.build_and_install_debug(function(success, exit_code, message, step)
        if not success then
            local error_msg = string.format("Workflow failed at %s step: %s", step, message)
            progress.stop_loading(session_id, false, error_msg)
            return
        end

        handle_post_install(tools, device_id, session_id, launch_app)
    end)
end

-- Get required Android tools or show error
function M.get_required_tools()
    local adb = android.get_adb_path()
    local emulator = android.get_emulator_path()

    if not adb or not emulator then
        vim.notify("Android SDK tools not found. Check ANDROID_SDK_ROOT.", vim.log.levels.ERROR)
        return nil
    end

    return { adb = adb, emulator = emulator }
end

-- Select target device or emulator
function M.select_target(tools, callback)
    if not tools then
        return
    end
    android.choose_target(tools.adb, tools.emulator, callback)
end

-- Complete build and run workflow (core DroidRun functionality)
function M.build_and_run()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if not target then
            return
        end

        local session_id = progress.start_loading {
            command = "DroidRun",
            priority = progress.PRIORITY.CRITICAL,
            message = "Building and installing application",
        }

        if not session_id then
            return
        end

        if target.type == "device" then
            execute_build_install(tools, target.id, session_id, true)
        elseif target.type == "avd" then
            android.start_emulator(tools.emulator, target.avd)
            android.wait_for_device_id(tools.adb, function(device_id)
                if not device_id then
                    progress.stop_loading(session_id, false, "Failed to start emulator")
                    return
                end
                execute_build_install(tools, device_id, session_id, true)
            end)
        end
    end)
end

-- Install-only workflow (no launch)
function M.install_only()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    local session_id = progress.start_loading {
        command = "DroidInstall",
        priority = progress.PRIORITY.CRITICAL,
        message = "Installing application",
    }

    if not session_id then
        return
    end

    M.select_target(tools, function(target)
        if not target then
            progress.stop_loading(session_id, false, "No target selected")
            return
        end

        if target.type == "device" then
            execute_build_install(tools, target.id, session_id, false)
        elseif target.type == "avd" then
            android.start_emulator(tools.emulator, target.avd)
            android.wait_for_device_id(tools.adb, function(device_id)
                if not device_id then
                    progress.stop_loading(session_id, false, "Failed to start emulator")
                    return
                end
                execute_build_install(tools, device_id, session_id, false)
            end)
        end
    end)
end

-- Install and launch workflow (for backward compatibility)
function M.install_and_launch()
    M.build_and_run()
end

-- Show logcat for selected device
function M.logcat_only()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    logcat.apply_filters {}
end

-- Show device selection dialog
function M.show_devices()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if not target then
            return
        end

        local msg = target.type == "device" and string.format("Selected device: %s (%s)", target.name, target.id)
            or string.format("Selected AVD: %s (%s)", target.name, target.avd)

        vim.notify(msg, vim.log.levels.INFO)
    end)
end

-- Start emulator from AVD list
function M.start_emulator()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if not target then
            return
        end

        if target.type == "avd" then
            android.start_emulator(tools.emulator, target.avd)
        else
            vim.notify("Selected target is not an AVD", vim.log.levels.WARN)
        end
    end)
end

return M
