local config = require "droid.config"

local M = {}

function M.build_emulator_command(emulator, args)
    local cfg = config.get()
    local full_args = { emulator, "-netdelay", "none", "-netspeed", "full" }

    -- Add the provided arguments
    for _, arg in ipairs(args) do
        table.insert(full_args, arg)
    end

    -- If Qt platform is configured, use shell with environment variable
    if cfg.qt_qpa_platform then
        local cmd_str = "QT_QPA_PLATFORM=" .. cfg.qt_qpa_platform .. " " .. table.concat(full_args, " ")
        return {"sh", "-c", cmd_str}, cmd_str
    else
        return full_args, table.concat(full_args, " ")
    end
end

function M.detect_android_sdk()
    -- Priority: global override > env vars > defaults
    if vim.g.android_sdk and vim.fn.isdirectory(vim.g.android_sdk) == 1 then
        return vim.g.android_sdk
    end

    local env = vim.env.ANDROID_SDK_ROOT or vim.env.ANDROID_HOME
    if env and vim.fn.isdirectory(env) == 1 then
        return env
    end

    local uv = vim.uv or vim.loop
    local sysname = uv.os_uname().sysname
    local home = vim.fn.expand "~"

    local candidates = {
        home .. "/Android/Sdk", -- Linux/macOS default (Android Studio)
        "/opt/android-sdk", -- Linux distros
    }

    if sysname == "Darwin" then
        table.insert(candidates, home .. "/Library/Android/sdk")
    elseif sysname == "Windows_NT" then
        table.insert(candidates, home .. "/AppData/Local/Android/Sdk")
    end

    for _, path in ipairs(candidates) do
        if vim.fn.isdirectory(path) == 1 then
            return path
        end
    end

    vim.notify("Android SDK not found. Set vim.g.android_sdk or ANDROID_HOME.", vim.log.levels.ERROR)
    return nil
end

function M.get_adb_path()
    local cfg = config.get()
    local android_sdk = M.detect_android_sdk()
    if not android_sdk then
        return nil
    end

    return cfg.adb_path
        or vim.fs.joinpath(
            android_sdk,
            "platform-tools",
            vim.uv.os_uname().sysname == "Windows_NT" and "adb.exe" or "adb"
        )
end

function M.get_emulator_path()
    local cfg = config.get()
    local android_sdk = M.detect_android_sdk()
    if not android_sdk then
        return nil
    end

    return cfg.emulator_path
        or vim.fs.joinpath(
            android_sdk,
            "emulator",
            vim.uv.os_uname().sysname == "Windows_NT" and "emulator.exe" or "emulator"
        )
end

function M.get_running_devices(adb)
    if vim.fn.executable(adb) ~= 1 then
        vim.notify("ADB executable not found at " .. adb, vim.log.levels.ERROR)
        return {}
    end
    local result = vim.fn.systemlist { adb, "devices", "-l" }
    local devices = {}
    for _, line in ipairs(result) do
        if not line:match "List of devices" and #line > 0 then
            local id, model = line:match "^(%S+)%s+device.*model:(%S+)"
            if id and model then
                table.insert(devices, { id = id, name = model })
            else
                local plain_id = line:match "^(%S+)%s+device"
                if plain_id then
                    table.insert(devices, { id = plain_id, name = "Unknown" })
                end
            end
        end
    end
    return devices
end

function M.wait_for_device_id(adb, callback)
    local cfg = config.get()
    local timer = vim.loop.new_timer()
    local start_time = vim.loop.now()
    timer:start(0, 2000, function()
        if vim.loop.now() - start_time > cfg.device_wait_timeout_ms then
            timer:stop()
            timer:close()
            vim.schedule(function()
                vim.notify("Timed out waiting for device", vim.log.levels.ERROR)
            end)
            return
        end
        local devices = M.get_running_devices(adb)
        if #devices > 0 then
            timer:stop()
            timer:close()
            vim.schedule(function()
                callback(devices[1].id)
            end)
        end
    end)
end

function M.get_all_targets(adb, emulator)
    local targets = {}
    local devices = M.get_running_devices(adb)

    for _, d in ipairs(devices) do
        table.insert(targets, { type = "device", id = d.id, name = "Device: " .. d.name })
    end

    if vim.fn.executable(emulator) == 1 then
        local avds = vim.fn.systemlist { emulator, "-list-avds" }
        for _, avd in ipairs(avds) do
            if #avd > 0 then
                table.insert(targets, { type = "avd", name = "Emulator: " .. avd, avd = avd })
            end
        end
    else
        vim.notify("Emulator executable not found at " .. emulator, vim.log.levels.WARN)
    end

    return targets
end

function M.choose_target(adb, emulator, callback)
    local cfg = config.get()
    local targets = M.get_all_targets(adb, emulator)
    if #targets == 0 then
        vim.notify("No devices or emulators available", vim.log.levels.ERROR)
        return
    end

    if #targets == 1 and cfg.auto_select_single_target then
        callback(targets[1])
        return
    end

    vim.ui.select(targets, {
        prompt = "Select device/emulator",
        format_item = function(item)
            return item.name
        end,
    }, function(choice)
        if choice then
            callback(choice)
        end
    end)
end

function M.start_emulator(emulator, avd)
    vim.notify("Starting emulator " .. avd, vim.log.levels.INFO)

    local cmd, cmd_str = M.build_emulator_command(emulator, {"-avd", avd})
    return vim.fn.jobstart(cmd)
end

function M.get_available_avds(emulator)
    if vim.fn.executable(emulator) ~= 1 then
        vim.notify("Emulator executable not found at " .. emulator, vim.log.levels.ERROR)
        return {}
    end

    local result = vim.fn.systemlist { emulator, "-list-avds" }
    local avds = {}

    for _, line in ipairs(result) do
        local trimmed = vim.trim(line)
        if #trimmed > 0 then
            table.insert(avds, trimmed)
        end
    end

    return avds
end

function M.launch_emulator()
    local emulator = M.get_emulator_path()
    if not emulator then
        return
    end

    local avds = M.get_available_avds(emulator)
    if #avds == 0 then
        vim.notify("No Emulators available", vim.log.levels.WARN)
        return
    end

    vim.ui.select(avds, {
        prompt = "Select Emulator to launch:",
        format_item = function(avd)
            return avd
        end,
    }, function(choice)
        if choice then
            local cfg = config.get()
            vim.notify("Launching Emulator: " .. choice, vim.log.levels.INFO)

            local job_args, cmd_str = M.build_emulator_command(emulator, {"-avd", choice})

            vim.fn.jobstart(job_args, {
                on_exit = vim.schedule_wrap(function(_, exit_code)
                    if exit_code ~= 0 then
                        vim.notify("Failed to launch Emulator: " .. choice, vim.log.levels.ERROR)
                    end
                end),
            })
        else
            vim.notify("Launch cancelled", vim.log.levels.INFO)
        end
    end)
end

function M.stop_emulator()
    local adb = M.get_adb_path()
    if not adb then
        return
    end

    local running_devices = M.get_running_devices(adb)
    local emulators = {}

    for _, device in ipairs(running_devices) do
        if device.id:match("^emulator%-") then
            table.insert(emulators, { id = device.id, name = device.name })
        end
    end

    if #emulators == 0 then
        vim.notify("No running emulators found", vim.log.levels.WARN)
        return
    end

    vim.ui.select(emulators, {
        prompt = "Select emulator to stop:",
        format_item = function(emu)
            return emu.id .. " (" .. emu.name .. ")"
        end,
    }, function(choice)
        if choice then
            vim.notify("Stopping emulator: " .. choice.id, vim.log.levels.INFO)
            vim.fn.jobstart({adb, "-s", choice.id, "emu", "kill"}, {
                on_exit = vim.schedule_wrap(function(_, exit_code)
                    if exit_code == 0 then
                        vim.notify("Emulator stopped successfully: " .. choice.id, vim.log.levels.INFO)
                    else
                        vim.notify("Failed to stop emulator: " .. choice.id, vim.log.levels.ERROR)
                    end
                end),
            })
        else
            vim.notify("Stop cancelled", vim.log.levels.INFO)
        end
    end)
end

function M.wipe_emulator_data()
    local emulator = M.get_emulator_path()
    if not emulator then
        return
    end

    local avds = M.get_available_avds(emulator)
    if #avds == 0 then
        vim.notify("No Emulators available", vim.log.levels.WARN)
        return
    end

    vim.ui.select(avds, {
        prompt = "Select Emulator to wipe data:",
        format_item = function(avd)
            return avd
        end,
    }, function(choice)
        if choice then
            -- Check if this emulator is currently running
            local adb = M.get_adb_path()
            local is_running = false
            local running_emulator_id = nil

            if adb then
                local running_devices = M.get_running_devices(adb)
                for _, device in ipairs(running_devices) do
                    if device.id:match("^emulator%-") then
                        -- Try to match by getting AVD name from running emulator
                        local result = vim.fn.system({adb, "-s", device.id, "shell", "getprop", "ro.kernel.qemu.avd_name"})
                        local avd_name = vim.trim(result)
                        if avd_name == choice then
                            is_running = true
                            running_emulator_id = device.id
                            break
                        end
                    end
                end
            end

            if is_running then
                -- Ask user if they want to stop the running emulator
                vim.ui.input({
                    prompt = "Emulator '" .. choice .. "' is running. Stop it and wipe data? (y/N): ",
                }, function(input)
                    if input and (input:lower() == "y" or input:lower() == "yes") then
                        vim.notify("Stopping emulator before wipe...", vim.log.levels.INFO)
                        vim.fn.jobstart({adb, "-s", running_emulator_id, "emu", "kill"}, {
                            on_exit = vim.schedule_wrap(function(_, exit_code)
                                if exit_code == 0 then
                                    vim.notify("Emulator stopped, wiping data...", vim.log.levels.INFO)
                                    -- Wait a moment then wipe data
                                    vim.defer_fn(function()
                                        M.start_wipe_data(emulator, choice)
                                    end, 2000)
                                else
                                    vim.notify("Failed to stop emulator, cannot wipe data", vim.log.levels.ERROR)
                                end
                            end),
                        })
                    else
                        vim.notify("Wipe data cancelled", vim.log.levels.INFO)
                    end
                end)
            else
                -- Emulator not running, ask for confirmation
                vim.ui.input({
                    prompt = "Wipe data for '" .. choice .. "'? (y/N): ",
                }, function(input)
                    if input and (input:lower() == "y" or input:lower() == "yes") then
                        M.start_wipe_data(emulator, choice)
                    else
                        vim.notify("Wipe data cancelled", vim.log.levels.INFO)
                    end
                end)
            end
        else
            vim.notify("Wipe data cancelled", vim.log.levels.INFO)
        end
    end)
end

function M.start_wipe_data(emulator, avd)
    vim.notify("Wiping data for Emulator: " .. avd, vim.log.levels.INFO)

    local cmd, cmd_str = M.build_emulator_command(emulator, {"-avd", avd, "-wipe-data"})

    vim.fn.jobstart(cmd, {
        on_exit = vim.schedule_wrap(function(_, exit_code)
            if exit_code == 0 then
                vim.notify("Emulator data wiped successfully: " .. avd, vim.log.levels.INFO)
            else
                vim.notify("Failed to wipe Emulator data: " .. avd, vim.log.levels.ERROR)
            end
        end),
    })
end

return M
