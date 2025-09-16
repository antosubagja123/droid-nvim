local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
local config = require "droid.config"
local actions = require "droid.actions"

local M = {}

function M.setup_commands()
    -- Composite command (does everything)
    vim.api.nvim_create_user_command("DroidRun", function()
        actions.build_and_run()
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
        actions.show_devices()
    end, {})

    vim.api.nvim_create_user_command("DroidStartEmulator", function()
        actions.start_emulator()
    end, {})

    vim.api.nvim_create_user_command("DroidInstall", function()
        actions.install_only()
    end, {})

    vim.api.nvim_create_user_command("DroidLogcat", function(opts)
        local mode = opts.args ~= "" and opts.args or config.get().logcat_mode
        actions.logcat_only(mode)
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
