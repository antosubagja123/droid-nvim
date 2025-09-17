local config = require "droid.config"
local android = require "droid.android"

local M = {}

M.job_id = nil
M.buf = nil
M.win = nil
M.auto_scroll = true
M.current_filters = nil
M.current_device_id = nil
M.current_adb = nil

local function create_logcat_buffer()
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        vim.api.nvim_buf_delete(M.buf, { force = true })
    end
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].filetype = "logcat"
    return M.buf
end

local function attach_cleanup()
    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = M.buf,
        callback = function()
            if M.job_id then
                vim.fn.jobstop(M.job_id)
                M.job_id = nil
                vim.notify("Logcat stopped (buffer closed)", vim.log.levels.INFO)
            end
        end,
    })
end

local function open_window(mode)
    local cfg = config.get()
    mode = mode or cfg.logcat_mode

    -- Open window according to mode
    if mode == "horizontal" then
        vim.cmd("botright split | resize " .. cfg.logcat_height)
        M.win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.win, M.buf)
    elseif mode == "vertical" then
        vim.cmd("vsplit | vertical resize " .. cfg.logcat_width)
        M.win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.win, M.buf)
    elseif mode == "float" then
        local opts = {
            relative = "editor",
            width = cfg.logcat_width,
            height = cfg.logcat_height,
            col = math.floor((vim.o.columns - cfg.logcat_width) / 2),
            row = math.floor((vim.o.lines - cfg.logcat_height) / 2),
            style = "minimal",
            border = "rounded",
            title = "Logcat",
            title_pos = "center",
        }
        M.win = vim.api.nvim_open_win(M.buf, true, opts)
    end
end

local function build_logcat_command(adb, device_id, filters, callback)
    local cmd = { adb, "-s", device_id, "logcat" }

    local function finalize_command()
        -- Apply tag and log level filtering (can be combined with PID)
        if filters.tag then
            table.insert(cmd, filters.tag .. ":" .. (filters.log_level or "v"))
            table.insert(cmd, "*:S") -- silence all other tags
        elseif filters.log_level and filters.log_level ~= "v" then
            -- Only apply global log level if no specific tag
            table.insert(cmd, "*:" .. string.upper(filters.log_level))
        end

        -- Build notification message
        local msg_parts = {}
        if filters.package then
            if filters.package == "mine" then
                local package_name = android.find_application_id()
                table.insert(msg_parts, "package: " .. (package_name or "unknown"))
            else
                table.insert(msg_parts, "package: " .. filters.package)
            end
        end
        if filters.tag then
            table.insert(msg_parts, "tag: " .. filters.tag)
        end
        if filters.log_level and filters.log_level ~= "v" then
            table.insert(msg_parts, "level: " .. filters.log_level .. "+")
        end

        if #msg_parts > 0 then
            vim.notify("Filtering logcat for " .. table.concat(msg_parts, ", "), vim.log.levels.INFO)
        end

        callback(cmd)
    end

    -- Apply package filtering (requires async PID lookup)
    if filters.package == "mine" then
        local package_name = android.find_application_id()
        if package_name then
            android.get_app_pid(adb, device_id, package_name, function(pid)
                if pid then
                    table.insert(cmd, "--pid=" .. pid)
                else
                    vim.notify("App not running, showing all logs", vim.log.levels.WARN)
                end
                finalize_command()
            end)
            return
        else
            vim.notify("Could not detect project package, showing all logs", vim.log.levels.WARN)
        end
    elseif filters.package and filters.package ~= "none" then
        android.get_app_pid(adb, device_id, filters.package, function(pid)
            if pid then
                table.insert(cmd, "--pid=" .. pid)
            else
                vim.notify("Package " .. filters.package .. " not running, showing all logs", vim.log.levels.WARN)
            end
            finalize_command()
        end)
        return
    end

    -- No package filtering, apply other filters directly
    finalize_command()
end

-- Compare two filter sets to determine if they would produce the same logcat command
local function filters_equivalent(current, new)
    if not current or not new then
        return false
    end

    -- Compare package filtering
    if current.package ~= new.package then
        return false
    end

    -- Compare effective log levels (treat nil and "v" as equivalent to no filtering)
    local function normalize_log_level(level)
        return (level == "v" or level == nil) and nil or level
    end

    local current_level = normalize_log_level(current.log_level)
    local new_level = normalize_log_level(new.log_level)
    if current_level ~= new_level then
        return false
    end

    -- Compare tag filtering
    if current.tag ~= new.tag then
        return false
    end

    -- Compare grep pattern filtering
    if current.grep_pattern ~= new.grep_pattern then
        return false
    end

    return true
end

function M.apply_filters(user_filters, adb, device_id)
    -- If device info is provided, use it directly (skip device selection)
    if adb and device_id then
        M.start(adb, device_id, nil, user_filters)
        return
    end

    -- If logcat is already running, apply filters to current session
    if M.job_id and M.current_adb and M.current_device_id then
        -- Calculate what the new filters would be (same logic as in M.start)
        local cfg = config.get()
        local base_filters = cfg.logcat_filters or {}
        local new_filters = {}

        -- Start with user's config as base
        for key, config_value in pairs(base_filters) do
            new_filters[key] = config_value
        end

        -- Apply override filters if provided
        if user_filters then
            for key, override_value in pairs(user_filters) do
                new_filters[key] = override_value
            end
        end

        -- Check if filters would actually change the logcat command
        if filters_equivalent(M.current_filters, new_filters) then
            vim.notify("Filters unchanged, logcat continues running", vim.log.levels.INFO)
            return
        end

        M.start(M.current_adb, M.current_device_id, nil, user_filters)
    else
        -- No existing logcat and no device provided, select from running devices only
        local actions = require "droid.actions"
        local tools = actions.get_required_tools()
        if not tools then
            return
        end

        android.get_running_devices(tools.adb, function(devices)
            if #devices == 0 then
                vim.notify("No devices or emulators available", vim.log.levels.ERROR)
                return
            end

            -- Auto-select if only one device and config allows it
            local cfg = config.get()
            if #devices == 1 and cfg.auto_select_single_target then
                M.start(tools.adb, devices[1].id, nil, user_filters)
                return
            end

            -- Multiple devices, show selection
            local formatted_devices = {}
            for _, device in ipairs(devices) do
                table.insert(formatted_devices, {
                    id = device.id,
                    name = "Device: " .. device.name,
                    display_name = device.name,
                })
            end

            vim.ui.select(formatted_devices, {
                prompt = "Select device for logcat",
                format_item = function(item)
                    return item.name
                end,
            }, function(choice)
                if choice then
                    M.start(tools.adb, choice.id, nil, user_filters)
                end
            end)
        end)
    end
end

-- Single source of truth for all logcat operations
-- Args:
--   adb: adb path
--   device_id: target device ID
--   mode: window mode (horizontal/vertical/float)
--   override_filters: optional filters to override config (temporary)
function M.start(adb, device_id, mode, override_filters)
    local cfg = config.get()
    local base_filters = cfg.logcat_filters or {}
    local active_filters = {}

    -- Start with user's config as base
    for key, config_value in pairs(base_filters) do
        active_filters[key] = config_value
    end

    -- Apply override filters if provided (temporary override)
    if override_filters then
        for key, override_value in pairs(override_filters) do
            active_filters[key] = override_value
        end
    end

    -- Smart reuse logic: check if we can reuse existing logcat session
    if M.job_id and M.current_adb == adb and M.current_device_id == device_id then
        -- Same device and logcat is running

        if not override_filters or (type(override_filters) == "table" and next(override_filters) == nil) then
            -- No filter override or empty table (DroidRun, DroidLogcat case) - always reuse
            vim.notify("Reusing existing logcat session", vim.log.levels.INFO)

            -- Reopen window if it was closed
            if not M.win or not vim.api.nvim_win_is_valid(M.win) then
                open_window(mode)
            end
            return
        else
            -- Filter override provided (DroidLogcatFilter case) - check equivalence
            if filters_equivalent(M.current_filters, active_filters) then
                vim.notify("Logcat filters unchanged, reusing session", vim.log.levels.INFO)

                -- Reopen window if it was closed
                if not M.win or not vim.api.nvim_win_is_valid(M.win) then
                    open_window(mode)
                end
                return
            else
                vim.notify("Filter changes detected, restarting logcat", vim.log.levels.INFO)
            end
        end
    end

    M.current_filters = active_filters
    M.current_device_id = device_id
    M.current_adb = adb

    -- Handle existing logcat session
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        M.job_id = nil

        -- If we're restarting with existing buffer, clear it but don't recreate
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
            vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, {})
            vim.notify("Applying filters...", vim.log.levels.INFO)
        end
    end

    -- Create buffer and window only if they don't exist
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
        create_logcat_buffer()
    end
    if not M.win or not vim.api.nvim_win_is_valid(M.win) then
        open_window(mode)
    end

    build_logcat_command(adb, device_id, active_filters, function(cmd)
        local job_opts = {
            stdout_buffered = false,
            on_stdout = function(_, data)
                if data then
                    local filtered_data = data

                    -- Apply grep pattern filtering
                    if active_filters.grep_pattern then
                        filtered_data = {}
                        for _, line in ipairs(data) do
                            if line:match(active_filters.grep_pattern) then
                                table.insert(filtered_data, line)
                            end
                        end
                    end

                    if #filtered_data > 0 then
                        vim.api.nvim_buf_set_lines(M.buf, -1, -1, false, filtered_data)
                        if M.auto_scroll and M.win and vim.api.nvim_win_is_valid(M.win) then
                            local line_count = vim.api.nvim_buf_line_count(M.buf)
                            vim.api.nvim_win_set_cursor(M.win, { line_count, 0 })
                        end
                    end
                end
            end,
            on_exit = function(_, _, _)
                M.job_id = nil
                M.current_device_id = nil
                M.current_adb = nil
                vim.notify("Logcat process exited", vim.log.levels.INFO)
            end,
        }

        M.job_id = vim.fn.jobstart(cmd, job_opts)
        attach_cleanup()
    end)
end

-- Legacy function for backward compatibility - now just calls unified start()
function M.open(adb, device_id, mode)
    M.start(adb, device_id, mode)
end

function M.stop()
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        M.job_id = nil
        M.current_device_id = nil
        M.current_adb = nil
        vim.notify("Logcat stopped", vim.log.levels.INFO)
        return true
    else
        vim.notify("No active logcat process", vim.log.levels.WARN)
        return false
    end
end

function M.is_running()
    return M.job_id ~= nil
end

function M.toggle_auto_scroll()
    M.auto_scroll = not M.auto_scroll
    local status = M.auto_scroll and "enabled" or "disabled"
    vim.notify("Logcat auto-scroll " .. status, vim.log.levels.INFO)
    return M.auto_scroll
end

function M.set_auto_scroll(enabled)
    M.auto_scroll = enabled
    local status = M.auto_scroll and "enabled" or "disabled"
    vim.notify("Logcat auto-scroll " .. status, vim.log.levels.INFO)
    return M.auto_scroll
end

function M.get_auto_scroll()
    return M.auto_scroll
end

function M.show_current_filters()
    local filters = M.current_filters
    if not filters then
        vim.notify("No filters currently active", vim.log.levels.INFO)
        return
    end

    local filter_info = {}
    if filters.package == "mine" then
        table.insert(filter_info, "Package: mine (project package)")
    elseif filters.package and filters.package ~= "none" then
        table.insert(filter_info, "Package: " .. filters.package)
    elseif filters.package == "none" then
        table.insert(filter_info, "Package: none (all packages)")
    end

    if filters.tag then
        table.insert(filter_info, "Tag: " .. filters.tag)
    end

    if filters.log_level and filters.log_level ~= "v" then
        table.insert(filter_info, "Log Level: " .. filters.log_level .. " and above")
    else
        table.insert(filter_info, "Log Level: v (all levels)")
    end

    if filters.grep_pattern then
        table.insert(filter_info, "Grep Pattern: " .. filters.grep_pattern)
    end

    if #filter_info > 0 then
        vim.notify("Active Logcat Filters:\n" .. table.concat(filter_info, "\n"), vim.log.levels.INFO)
    else
        vim.notify("No filters currently active", vim.log.levels.INFO)
    end
end

-- Clean up on Vim exit
vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
        if M.job_id then
            vim.fn.jobstop(M.job_id)
            M.job_id = nil
        end
    end,
})

return M
