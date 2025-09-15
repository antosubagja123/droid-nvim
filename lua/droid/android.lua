local config = require "droid.config"

local M = {}

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
    vim.notify("Starting emulator " .. avd .. "...", vim.log.levels.INFO)
    return vim.fn.jobstart { emulator, "-avd", avd }
end

return M
