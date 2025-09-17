local gradle = require "droid.gradle"
local android = require "droid.android"
local logcat = require "droid.logcat"
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

    vim.api.nvim_create_user_command("DroidLogcat", function()
        actions.logcat_only()
    end, {
        nargs = "?",
        complete = function()
            return { "horizontal", "vertical", "float" }
        end,
    })

    vim.api.nvim_create_user_command("DroidLogcatStop", function()
        logcat.stop()
    end, {})

    vim.api.nvim_create_user_command("DroidLogcatToggleAutoScroll", function()
        logcat.toggle_auto_scroll()
    end, {})

    vim.api.nvim_create_user_command("DroidLogcatFilter", function(opts)
        local filters = {}

        -- Parse key=value pairs from opts.fargs
        for _, arg in ipairs(opts.fargs) do
            local key, value = arg:match "([^=]+)=([^=]+)"
            if key and value then
                filters[key] = value
            end
        end

        -- Apply filters
        logcat.apply_filters(filters)
    end, {
        nargs = "*",
        complete = function(arg_lead, _, _)
            local completions = {
                "package=",
                "package=mine",
                "package=none",
                "log_level=v",
                "log_level=d",
                "log_level=i",
                "log_level=w",
                "log_level=e",
                "log_level=f",
                "tag=",
                "grep=",
            }

            -- Filter completions based on what user has typed
            local filtered = {}
            for _, comp in ipairs(completions) do
                if comp:find(arg_lead, 1, true) == 1 then
                    table.insert(filtered, comp)
                end
            end
            return filtered
        end,
    })

    vim.api.nvim_create_user_command("DroidLogcatFilterShow", function()
        logcat.show_current_filters()
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
