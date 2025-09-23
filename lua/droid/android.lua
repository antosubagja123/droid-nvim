local config = require "droid.config"
local progress = require "droid.progress"

local M = {}

-- Simple function to find application ID from build.gradle (inspired by reference code)
function M.find_application_id()
    local gradle_candidates = { "app/build.gradle", "app/build.gradle.kts" }

    for _, candidate in ipairs(gradle_candidates) do
        local gradle_path = vim.fs.find(candidate, { upward = true })[1]
        if gradle_path and vim.fn.filereadable(gradle_path) == 1 then
            local file = io.open(gradle_path, "r")
            if file then
                local content = file:read "*all"
                file:close()

                for line in content:gmatch "[^\r\n]+" do
                    if line:find "applicationId" then
                        local app_id = line:match ".*[\"']([^\"']+)[\"']"
                        if app_id then
                            return app_id
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Find main activity using adb cmd (inspired by reference code)
function M.find_main_activity(adb, device_id, application_id)
    local obj = vim.system(
        { adb, "-s", device_id, "shell", "cmd", "package", "resolve-activity", "--brief", application_id },
        {}
    )
        :wait()
    if obj.code ~= 0 then
        return nil
    end

    local result = nil
    local output = obj.stdout or ""
    for line in output:gmatch "[^\r\n]+" do
        line = vim.trim(line)
        if line ~= "" then
            result = line
        end
    end

    return result
end

-- Launch app on device (standalone function)
-- Args: adb, device_id, callback (optional)
function M.launch_app_on_device(adb, device_id, callback)
    local application_id = M.find_application_id()

    if not application_id then
        vim.notify("Failed to find application ID from build.gradle", vim.log.levels.ERROR)
        if callback then
            vim.schedule(callback)
        end
        return
    end

    local main_activity = M.find_main_activity(adb, device_id, application_id)
    if not main_activity then
        vim.notify("Failed to find main activity, trying monkey command...", vim.log.levels.WARN)
        -- Fallback to monkey command
        local launch_obj = vim.system({
            adb,
            "-s",
            device_id,
            "shell",
            "monkey",
            "-p",
            application_id,
            "-c",
            "android.intent.category.LAUNCHER",
            "1",
        }, {}):wait()

        if launch_obj.code == 0 then
            vim.notify("App launched successfully!", vim.log.levels.INFO)
        else
            vim.notify("Failed to launch app: " .. (launch_obj.stderr or "unknown error"), vim.log.levels.ERROR)
        end

        if callback then
            vim.schedule(callback)
        end
        return
    end

    -- Launch with specific activity
    local launch_obj = vim.system({
        adb,
        "-s",
        device_id,
        "shell",
        "am",
        "start",
        "-a",
        "android.intent.action.MAIN",
        "-c",
        "android.intent.category.LAUNCHER",
        "-n",
        main_activity,
    }, {}):wait()

    if launch_obj.code == 0 then
        vim.notify("App launched successfully!", vim.log.levels.INFO)
    else
        vim.notify("Failed to launch app: " .. (launch_obj.stderr or "unknown error"), vim.log.levels.ERROR)
    end

    if callback then
        vim.schedule(callback)
    end
end

function M.get_app_pid(adb, device_id, package_name, callback)
    if not package_name or package_name == "" then
        callback(nil)
        return
    end

    local cmd = { adb, "-s", device_id, "shell", "pidof", package_name }
    local result = vim.system(cmd, {}):wait()

    if result.code == 0 and result.stdout then
        local pid = vim.trim(result.stdout)
        if pid ~= "" then
            callback(pid)
            return
        end
    end

    callback(nil)
end

function M.build_emulator_command(emulator, args)
    local cfg = config.get()
    local full_args = { emulator, "-netdelay", "none", "-netspeed", "full" }

    -- Add the provided arguments
    for _, arg in ipairs(args) do
        table.insert(full_args, arg)
    end

    -- If Qt platform is configured, use shell with environment variable
    if cfg.android.qt_qpa_platform then
        local cmd_str = "QT_QPA_PLATFORM=" .. cfg.android.qt_qpa_platform .. " " .. table.concat(full_args, " ")
        return { "sh", "-c", cmd_str }, cmd_str
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

    return cfg.android.adb_path
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

    return cfg.android.emulator_path
        or vim.fs.joinpath(
            android_sdk,
            "emulator",
            vim.uv.os_uname().sysname == "Windows_NT" and "emulator.exe" or "emulator"
        )
end

function M.get_running_devices(adb, callback)
    if vim.fn.executable(adb) ~= 1 then
        vim.notify("ADB executable not found at " .. adb, vim.log.levels.ERROR)
        callback {}
        return
    end

    vim.schedule(function()
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
        callback(devices)
    end)
end

function M.wait_for_device_id(adb, callback)
    local cfg = config.get()
    local timer = vim.loop.new_timer()
    local start_time = vim.loop.now()

    progress.update_spinner_message "Waiting for device to come online"

    timer:start(0, 2000, function()
        if vim.loop.now() - start_time > cfg.android.device_wait_timeout_ms then
            timer:stop()
            timer:close()
            vim.schedule(function()
                progress.stop_spinner()
                vim.notify("Timed out waiting for device", vim.log.levels.ERROR)
                callback(nil)
            end)
            return
        end
        M.get_running_devices(adb, function(devices)
            if #devices > 0 then
                timer:stop()
                timer:close()
                progress.update_spinner_message "Device ready"
                callback(devices[1].id)
            end
        end)
    end)
end

-- Check if device is fully booted and ready for app installation
local function is_device_boot_completed(adb, device_id, callback)
    vim.system({ adb, "-s", device_id, "shell", "getprop", "sys.boot_completed" }, {}, function(obj)
        local boot_completed = vim.trim(obj.stdout or "")
        local is_ready = boot_completed == "1"

        if is_ready then
            -- Additional check: ensure package manager is ready
            vim.system({ adb, "-s", device_id, "shell", "pm", "list", "packages" }, {}, function(pm_obj)
                local pm_ready = pm_obj.code == 0
                vim.schedule(function()
                    callback(pm_ready)
                end)
            end)
        else
            vim.schedule(function()
                callback(false)
            end)
        end
    end)
end

-- Enhanced device waiting that checks both device online status AND boot completion
function M.wait_for_device_ready(adb, callback)
    local cfg = config.get()
    local timer = vim.loop.new_timer()
    local start_time = vim.loop.now()
    local device_found = false
    local current_device_id = nil

    progress.update_spinner_message "Waiting for device to come online"

    timer:start(0, cfg.android.boot_check_interval_ms or 3000, function()
        local elapsed = vim.loop.now() - start_time
        local timeout = cfg.android.boot_complete_timeout_ms or 120000

        if elapsed > timeout then
            timer:stop()
            timer:close()
            vim.schedule(function()
                progress.stop_spinner()
                vim.notify("Timed out waiting for device to boot completely", vim.log.levels.ERROR)
                callback(nil)
            end)
            return
        end

        if not device_found then
            -- First phase: wait for device to appear in adb devices
            M.get_running_devices(adb, function(devices)
                if #devices > 0 then
                    device_found = true
                    current_device_id = devices[1].id
                    progress.update_spinner_message "Device found, waiting for boot completion"
                end
            end)
        else
            -- Second phase: wait for boot completion
            is_device_boot_completed(adb, current_device_id, function(is_ready)
                if is_ready then
                    timer:stop()
                    timer:close()
                    progress.update_spinner_message "Device ready for installation"
                    callback(current_device_id)
                end
            end)
        end
    end)
end

function M.get_all_targets(adb, emulator, callback)
    M.get_running_devices(adb, function(devices)
        local targets = {}

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

        callback(targets)
    end)
end

function M.choose_target(adb, emulator, callback)
    local cfg = config.get()
    M.get_all_targets(adb, emulator, function(targets)
        if #targets == 0 then
            vim.notify("No devices or emulators available", vim.log.levels.ERROR)
            return
        end

        if #targets == 1 and cfg.android.auto_select_single_target then
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
    end)
end

function M.start_emulator(emulator, avd)
    local cmd, _ = M.build_emulator_command(emulator, { "-avd", avd })
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
            vim.notify("Launching Emulator: " .. choice, vim.log.levels.INFO)

            local job_args, _ = M.build_emulator_command(emulator, { "-avd", choice })

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

    M.get_running_devices(adb, function(running_devices)
        local emulators = {}

        for _, device in ipairs(running_devices) do
            if device.id:match "^emulator%-" then
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
                vim.fn.jobstart({ adb, "-s", choice.id, "emu", "kill" }, {
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
            vim.ui.input({
                prompt = "Wipe data for '" .. choice .. "'? (y/N): ",
            }, function(input)
                if input and (input:lower() == "y" or input:lower() == "yes") then
                    local session_id = progress.start_loading {
                        command = "DroidEmulatorWipeData",
                        priority = progress.PRIORITY.LOW,
                        message = string.format("Wiping data for: %s", choice),
                    }
                    local cmd, _ = M.build_emulator_command(emulator, { "-avd", choice, "-wipe-data" })

                    vim.fn.jobstart(cmd, {
                        on_exit = vim.schedule_wrap(function(_, exit_code)
                            if exit_code == 0 then
                                progress.stop_loading(session_id, true, "Emulator data wiped successfully")
                            else
                                progress.stop_loading(session_id, false, "Failed to wipe Emulator data")
                            end
                        end),
                    })
                else
                    vim.notify("Wipe data cancelled", vim.log.levels.INFO)
                end
            end)
        else
            vim.notify("Wipe data cancelled", vim.log.levels.INFO)
        end
    end)
end

return M
