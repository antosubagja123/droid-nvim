-- High-level workflow actions for droid.nvim
-- This module provides reusable, independent functions for common Android development tasks

local config = require "droid.config"
local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local progress = require "droid.progress"

local M = {}

-- Validates and gets required tools (adb, emulator)
-- Returns: { adb = path, emulator = path } or nil if validation fails
function M.get_required_tools()
    local adb = android.get_adb_path()
    local emulator = android.get_emulator_path()

    if not adb or not emulator then
        return nil
    end

    return { adb = adb, emulator = emulator }
end

-- Executes target selection workflow
-- Args: tools (from get_required_tools), callback(target)
-- Target: { type = "device"|"avd", id = device_id, name = display_name, avd = avd_name }
function M.select_target(tools, callback)
    if not tools then
        vim.notify("Android tools not available", vim.log.levels.ERROR)
        return
    end

    android.choose_target(tools.adb, tools.emulator, callback)
end

-- Builds debug APK only
-- Args: callback() - called after build completes
function M.build_debug(callback)
    gradle.build_debug()
    if callback then
        vim.schedule(callback)
    end
end

-- Installs debug APK only (no launch)
-- Args: adb, device_id, callback() - called after install completes
function M.install_debug(adb, device_id, callback)
    gradle.install_debug(callback)
end

-- Installs and launches debug APK
-- Args: adb, device_id, callback() - called after launch completes
function M.install_and_launch(adb, device_id, callback)
    gradle.install_debug_and_launch(adb, device_id, callback)
end

-- Launches app on device (without install)
-- Args: adb, device_id, callback() - called after launch completes
function M.launch_app(adb, device_id, callback)
    android.launch_app_on_device(adb, device_id, callback)
end

-- Complete build and run workflow (the core DroidRun functionality)
-- This is the main workflow: select target -> install+launch -> logcat
function M.build_and_run()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if not target then
            return
        end

        -- Start loading after device selection
        local session_id = progress.start_loading {
            command = "DroidRun",
            priority = progress.PRIORITY.CRITICAL,
            message = "Running build and install workflow",
        }

        if not session_id then
            return -- Loading was queued or cancelled
        end

        if target.type == "device" then
            M.install_and_launch(tools.adb, target.id, function()
                -- Add delay before starting logcat to let app fully start
                local config = require "droid.config"
                local cfg = config.get()
                local delay_ms = cfg.logcat_startup_delay_ms or 2000

                vim.defer_fn(function()
                    logcat.apply_filters({}, tools.adb, target.id)
                    progress.stop_loading(session_id, true, "Run application successful")
                end, delay_ms)
            end)
        elseif target.type == "avd" then
            android.start_emulator(tools.emulator, target.avd)
            android.wait_for_device_id(tools.adb, function(device_id)
                if device_id then
                    M.install_and_launch(tools.adb, device_id, function()
                        -- Add delay before starting logcat to let app fully start
                        local config = require "droid.config"
                        local cfg = config.get()
                        local delay_ms = cfg.logcat_startup_delay_ms or 2000

                        vim.defer_fn(function()
                            logcat.apply_filters({}, tools.adb, device_id)
                            progress.stop_loading(session_id, true, "Run application successful")
                        end, delay_ms)
                    end)
                else
                    progress.stop_loading(session_id, false, "Failed to start emulator or device not ready")
                end
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

    -- Start loading with global management
    local session_id = progress.start_loading {
        command = "DroidInstall",
        priority = progress.PRIORITY.CRITICAL,
        message = "Selecting target device",
    }

    if not session_id then
        return -- Loading was queued or cancelled
    end

    M.select_target(tools, function(target)
        if not target then
            progress.stop_loading(session_id, false, "No target selected")
            return
        end

        if target.type == "device" then
            progress.update_spinner_message("Installing on " .. target.name)
            M.install_debug(tools.adb, target.id, function()
                progress.stop_loading(session_id, true, "Installation completed")
            end)
        elseif target.type == "avd" then
            progress.update_spinner_message "Starting emulator"
            android.start_emulator(tools.emulator, target.avd)
            android.wait_for_device_id(tools.adb, function(device_id)
                if device_id then
                    progress.update_spinner_message "Installing on emulator"
                    M.install_debug(tools.adb, device_id, function()
                        progress.stop_loading(session_id, true, "Installation completed")
                    end)
                else
                    progress.stop_loading(session_id, false, "Failed to start emulator or device not ready")
                end
            end)
        end
    end)
end

-- Logcat-only workflow
function M.logcat_only(mode)
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if target.type == "device" then
            logcat.apply_filters {}
        elseif target.type == "avd" then
            vim.notify("AVD must be started first before attaching logcat", vim.log.levels.WARN)
        end
    end)
end

-- Device selection workflow (just shows selected device)
function M.show_devices()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if target.type == "device" then
            vim.notify("Selected device: " .. target.name .. " (" .. target.id .. ")", vim.log.levels.INFO)
        elseif target.type == "avd" then
            vim.notify("Selected AVD: " .. target.name .. " (" .. target.avd .. ")", vim.log.levels.INFO)
        end
    end)
end

-- Start emulator workflow
function M.start_emulator()
    local tools = M.get_required_tools()
    if not tools then
        return
    end

    M.select_target(tools, function(target)
        if target.type == "avd" then
            android.start_emulator(tools.emulator, target.avd)
        else
            vim.notify("Selected target is not an AVD", vim.log.levels.WARN)
        end
    end)
end

return M
