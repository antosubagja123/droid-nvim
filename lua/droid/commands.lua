local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local config = require "droid.config"

local M = {}

local function build_and_run()
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

function M.setup_commands()
    -- Composite command (does everything)
    vim.api.nvim_create_user_command("DroidRun", function()
        build_and_run()
    end, {})

    -- Individual gradle commands
    vim.api.nvim_create_user_command("DroidBuildDebug", function()
        gradle.build_debug()
    end, {})

    vim.api.nvim_create_user_command("DroidClean", function()
        gradle.clean()
    end, {})

    vim.api.nvim_create_user_command("DroidSync", function()
        gradle.sync()
    end, {})

    vim.api.nvim_create_user_command("DroidTask", function(opts)
        gradle.task(opts.fargs[1], table.concat(vim.list_slice(opts.fargs, 2), " "))
    end, { nargs = "+", complete = "shellcmd" })

    -- Individual device management commands
    vim.api.nvim_create_user_command("DroidDevices", function()
        local adb = android.get_adb_path()
        local emulator = android.get_emulator_path()

        if not adb or not emulator then
            return
        end

        android.choose_target(adb, emulator, function(target)
            if target.type == "device" then
                vim.notify("Selected device: " .. target.name .. " (" .. target.id .. ")", vim.log.levels.INFO)
            elseif target.type == "avd" then
                vim.notify("Selected AVD: " .. target.name .. " (" .. target.avd .. ")", vim.log.levels.INFO)
            end
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidStartEmulator", function()
        local adb = android.get_adb_path()
        local emulator = android.get_emulator_path()

        if not adb or not emulator then
            return
        end

        android.choose_target(adb, emulator, function(target)
            if target.type == "avd" then
                android.start_emulator(emulator, target.avd)
            else
                vim.notify("Selected target is not an AVD", vim.log.levels.WARN)
            end
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidInstall", function()
        local adb = android.get_adb_path()
        local emulator = android.get_emulator_path()

        if not adb or not emulator then
            return
        end

        android.choose_target(adb, emulator, function(target)
            if target.type == "device" then
                vim.notify("Installing on " .. target.name, vim.log.levels.INFO)
                gradle.install_debug()
            elseif target.type == "avd" then
                vim.notify("Starting emulator", vim.log.levels.INFO)
                android.start_emulator(emulator, target.avd)
                android.wait_for_device_id(adb, function(device_id)
                    vim.notify("Installing on emulator", vim.log.levels.INFO)
                    gradle.install_debug()
                end)
            end
        end)
    end, {})

    vim.api.nvim_create_user_command("DroidLogcat", function(opts)
        local adb = android.get_adb_path()
        local emulator = android.get_emulator_path()

        if not adb or not emulator then
            return
        end

        android.choose_target(adb, emulator, function(target)
            if target.type == "device" then
                local mode = opts.args ~= "" and opts.args or config.get().logcat_mode
                logcat.open(adb, target.id, mode)
            elseif target.type == "avd" then
                vim.notify("AVD must be started first before attaching logcat", vim.log.levels.WARN)
            end
        end)
    end, {
        nargs = "?",
        complete = function()
            return { "horizontal", "vertical", "float" }
        end,
    })

    vim.api.nvim_create_user_command("DroidLogcatStop", function()
        logcat.stop()
    end, {})

    vim.api.nvim_create_user_command("DroidGradleLog", function()
        gradle.show_log()
    end, {})

    vim.api.nvim_create_user_command("DroidGradleStop", function()
        gradle.stop()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulator", function()
        android.launch_emulator()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulatorStop", function()
        android.stop_emulator()
    end, {})

    vim.api.nvim_create_user_command("DroidEmulatorWipeData", function()
        android.wipe_emulator_data()
    end, {})
end

return M
