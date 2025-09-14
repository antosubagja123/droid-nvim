local M = {}

-- Config
M.config = {
    logcat_mode = "horizontal", -- "horizontal" | "vertical" | "float"
    logcat_height = 12,
    logcat_width = 80,
    auto_select_single_target = true, -- Auto-select if only one device/emulator
    logcat_filters = {}, -- e.g., { tag = "MyApp", priority = "DEBUG" }
    adb_path = nil, -- Custom ADB path override
    emulator_path = nil, -- Custom emulator path override
    device_wait_timeout_ms = 30000, -- Timeout for waiting for device (ms)
}

M.logcat_job_id = nil
M.logcat_buf = nil
M.logcat_win = nil

function M.setup(opts)
    opts = opts or {}
    -- Validate logcat_mode
    local valid_modes = { horizontal = true, vertical = true, float = true }
    if opts.logcat_mode and not valid_modes[opts.logcat_mode] then
        vim.notify("Invalid logcat_mode: " .. opts.logcat_mode .. ". Using default: horizontal", vim.log.levels.WARN)
        opts.logcat_mode = "horizontal"
    end
    -- Validate dimensions
    if opts.logcat_height and (type(opts.logcat_height) ~= "number" or opts.logcat_height <= 0) then
        vim.notify("Invalid logcat_height. Using default: 12", vim.log.levels.WARN)
        opts.logcat_height = 12
    end
    if opts.logcat_width and (type(opts.logcat_width) ~= "number" or opts.logcat_width <= 0) then
        vim.notify("Invalid logcat_width. Using default: 80", vim.log.levels.WARN)
        opts.logcat_width = 80
    end
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

-- Find gradlew in current project (search upward)
local function find_gradlew()
    local gradlew = vim.fs.find("gradlew", { upward = true })[1]
    if gradlew and vim.fn.executable(gradlew) == 1 then
        return { gradlew = gradlew, cwd = vim.fs.dirname(gradlew) }
    end
    vim.notify("gradlew not found in project", vim.log.levels.ERROR)
    return nil
end

-- Run gradle command, flexible output mode
local function run_gradle_task(cwd, gradlew, task, args, opts)
    opts = opts or {}
    local mode = opts.mode or "terminal" -- "terminal" | "scratch"
    local cmd = gradlew .. " " .. task .. (args and " " .. args or "")

    if mode == "terminal" then
        vim.cmd("botright split | resize 15 | terminal " .. cmd)
        vim.cmd "startinsert"
        return
    end

    -- Scratch buffer mode (non-interactive)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "Gradle: " .. task)
    vim.api.nvim_set_current_buf(bufnr)

    vim.fn.jobstart({ gradlew, task, unpack(args or {}) }, {
        cwd = cwd,
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
            end
        end,
        on_stderr = function(_, data)
            if data then
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
                for _, line in ipairs(data) do
                    if line:match "Build failed" then
                        vim.notify("Gradle build failed. Check output for details.", vim.log.levels.ERROR)
                        break
                    end
                end
            end
        end,
        on_exit = function(_, code)
            if code == 0 then
                vim.notify("✅ Gradle task '" .. task .. "' finished", vim.log.levels.INFO)
            else
                vim.notify("❌ Gradle task '" .. task .. "' failed", vim.log.levels.ERROR)
            end
        end,
    })
end

-- Detect Android SDK root
local function detect_android_sdk()
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

-- Get running devices
local function get_running_devices(adb)
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

-- Wait until device is ready with timeout
local function wait_for_device(adb, callback)
    local timer = vim.loop.new_timer()
    local start_time = vim.loop.now()
    timer:start(0, 2000, function()
        if vim.loop.now() - start_time > M.config.device_wait_timeout_ms then
            timer:stop()
            timer:close()
            vim.notify("Timed out waiting for device", vim.log.levels.ERROR)
            return
        end
        local state = vim.fn.system({ adb, "get-state" }):gsub("%s+", "")
        if state == "device" then
            timer:stop()
            timer:close()
            vim.schedule(callback)
        end
    end)
end

-- Get all targets (devices and AVDs)
local function get_all_targets(adb, emulator)
    local targets = {}
    local devices = get_running_devices(adb)

    for _, d in ipairs(devices) do
        table.insert(targets, { type = "device", id = d.id, name = "📱 " .. d.name })
    end

    if vim.fn.executable(emulator) == 1 then
        local avds = vim.fn.systemlist { emulator, "-list-avds" }
        for _, avd in ipairs(avds) do
            if #avd > 0 then
                table.insert(targets, { type = "avd", name = "🖥️ " .. avd, avd = avd })
            end
        end
    else
        vim.notify("Emulator executable not found at " .. emulator, vim.log.levels.WARN)
    end

    return targets
end

-- Choose target interactively
local function choose_target(adb, emulator, callback)
    local targets = get_all_targets(adb, emulator)
    if #targets == 0 then
        vim.notify("No devices or emulators available", vim.log.levels.ERROR)
        return
    end

    if #targets == 1 and M.config.auto_select_single_target then
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

-- Open logcat
local function open_logcat(adb, device_id, mode)
    mode = mode or M.config.logcat_mode

    -- Stop existing logcat if running
    if M.logcat_job_id then
        vim.fn.jobstop(M.logcat_job_id)
        M.logcat_job_id = nil
        vim.notify("Previous logcat stopped", vim.log.levels.INFO)
    end

    -- Reuse or create logcat buffer
    if M.logcat_buf and vim.api.nvim_buf_is_valid(M.logcat_buf) then
        vim.api.nvim_buf_delete(M.logcat_buf, { force = true })
    end
    M.logcat_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.logcat_buf].filetype = "logcat"

    local function attach_cleanup()
        vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = M.logcat_buf,
            callback = function()
                if M.logcat_job_id then
                    vim.fn.jobstop(M.logcat_job_id)
                    M.logcat_job_id = nil
                    vim.notify("Logcat stopped (buffer closed)", vim.log.levels.INFO)
                end
            end,
        })
    end

    local job_opts = {
        stdout_buffered = false,
        on_stdout = function(_, data)
            if data then
                vim.api.nvim_buf_set_lines(M.logcat_buf, -1, -1, false, data)
            end
        end,
        on_exit = function(_, _, _)
            M.logcat_job_id = nil
            vim.notify("Logcat process exited", vim.log.levels.INFO)
        end,
    }

    -- Open window according to mode
    if mode == "horizontal" then
        vim.cmd("botright split | resize " .. M.config.logcat_height)
        M.logcat_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.logcat_win, M.logcat_buf)
    elseif mode == "vertical" then
        vim.cmd("vsplit | vertical resize " .. M.config.logcat_width)
        M.logcat_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.logcat_win, M.logcat_buf)
    elseif mode == "float" then
        local opts = {
            relative = "editor",
            width = M.config.logcat_width,
            height = M.config.logcat_height,
            col = math.floor((vim.o.columns - M.config.logcat_width) / 2),
            row = math.floor((vim.o.lines - M.config.logcat_height) / 2),
            style = "minimal",
            border = "rounded",
            title = "Logcat",
            title_pos = "center",
        }
        M.logcat_win = vim.api.nvim_open_win(M.logcat_buf, true, opts)
    end

    -- Start logcat job with optional filters
    local cmd = { adb, "-s", device_id, "logcat" }
    if M.config.logcat_filters.tag then
        table.insert(cmd, M.config.logcat_filters.tag .. ":" .. (M.config.logcat_filters.priority or "V"))
    end
    M.logcat_job_id = vim.fn.jobstart(cmd, job_opts)
    attach_cleanup()
end

-- Build and run logic
local function build_and_run()
    local gradlew = find_gradlew()
    if not gradlew then
        return
    end

    local android_sdk = detect_android_sdk()
    if not android_sdk then
        return
    end

    local adb = M.config.adb_path
        or vim.fs.joinpath(
            android_sdk,
            "platform-tools",
            vim.uv.os_uname().sysname == "Windows_NT" and "adb.exe" or "adb"
        )
    local emulator = M.config.emulator_path
        or vim.fs.joinpath(
            android_sdk,
            "emulator",
            vim.uv.os_uname().sysname == "Windows_NT" and "emulator.exe" or "emulator"
        )

    choose_target(adb, emulator, function(target)
        if target.type == "device" then
            vim.notify("Installing on " .. target.name, vim.log.levels.INFO)
            run_gradle_task(gradlew.cwd, gradlew.gradlew, "installDebug")
            open_logcat(adb, target.id)
        elseif target.type == "avd" then
            vim.notify("Starting emulator " .. target.avd .. "...", vim.log.levels.INFO)
            vim.cmd "botright split | resize 15"
            vim.fn.jobstart { emulator, "-avd", target.avd }
            wait_for_device(adb, function()
                run_gradle_task(gradlew.cwd, gradlew.gradlew, "installDebug")
                open_logcat(adb, target.id)
            end)
        end
    end)
end

-- Clean up on Vim exit
vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
        if M.logcat_job_id then
            vim.fn.jobstop(M.logcat_job_id)
            M.logcat_job_id = nil
        end
    end,
})

-- Expose gradle commands
function M.gradle_sync()
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, "--refresh-dependencies")
    end
end

function M.gradle_clean()
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, "clean")
    end
end

function M.gradle_build_debug()
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, "assembleDebug")
    end
end

function M.gradle_run()
    build_and_run()
end

function M.gradle_task(task, args)
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, task, args)
    end
end

-- Commands
vim.api.nvim_create_user_command("DroidRun", M.gradle_run, {})
vim.api.nvim_create_user_command("DroidBuildDebug", M.gradle_build_debug, {})
vim.api.nvim_create_user_command("DroidClean", M.gradle_clean, {})
vim.api.nvim_create_user_command("DroidSync", M.gradle_sync, {})
vim.api.nvim_create_user_command("DroidTask", function(opts)
    M.gradle_task(opts.fargs[1], table.concat(vim.list_slice(opts.fargs, 2), " "))
end, { nargs = "+", complete = "shellcmd" })

vim.api.nvim_create_user_command("DroidLogcat", function(opts)
    local sdk = detect_android_sdk()
    if not sdk then
        return
    end
    local adb = M.config.adb_path or sdk .. "/platform-tools/adb"
    local emulator = M.config.emulator_path or sdk .. "/emulator/emulator"

    choose_target(adb, emulator, function(target)
        if target.type == "device" then
            local mode = opts.args ~= "" and opts.args or M.config.logcat_mode
            open_logcat(adb, target.id, mode)
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
    if M.logcat_job_id then
        vim.fn.jobstop(M.logcat_job_id)
        M.logcat_job_id = nil
        vim.notify("🛑 Logcat stopped", vim.log.levels.INFO)
    else
        vim.notify("No active logcat process", vim.log.levels.WARN)
    end
end, {})

return M
