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

    if filters.package == "mine" then
        local package_name = android.find_application_id()
        if package_name then
            android.get_app_pid(adb, device_id, package_name, function(pid)
                if pid then
                    table.insert(cmd, "--pid=" .. pid)
                    vim.notify(
                        "Filtering logcat for package: " .. package_name .. " (PID: " .. pid .. ")",
                        vim.log.levels.INFO
                    )
                else
                    vim.notify("App not running, showing all logs", vim.log.levels.WARN)
                end
                callback(cmd)
            end)
            return
        else
            vim.notify("Could not detect project package, showing all logs", vim.log.levels.WARN)
        end
    elseif filters.package and filters.package ~= "none" then
        android.get_app_pid(adb, device_id, filters.package, function(pid)
            if pid then
                table.insert(cmd, "--pid=" .. pid)
                vim.notify(
                    "Filtering logcat for package: " .. filters.package .. " (PID: " .. pid .. ")",
                    vim.log.levels.INFO
                )
            else
                vim.notify("Package " .. filters.package .. " not running, showing all logs", vim.log.levels.WARN)
            end
            callback(cmd)
        end)
        return
    elseif filters.tag then
        table.insert(cmd, filters.tag .. ":" .. (filters.log_level or "v"))
        table.insert(cmd, "*:S")
        vim.notify(
            "Filtering logcat for tag: " .. filters.tag .. " (level: " .. (filters.log_level or "v") .. ")",
            vim.log.levels.INFO
        )
    elseif filters.log_level and filters.log_level ~= "v" then
        table.insert(cmd, "*:" .. string.upper(filters.log_level))
        vim.notify("Filtering logcat for log level: " .. filters.log_level .. " and above", vim.log.levels.INFO)
    end

    callback(cmd)
end

function M.apply_filters(user_filters, adb, device_id)
    -- If device info is provided, use it directly (skip device selection)
    if adb and device_id then
        M.start(adb, device_id, nil, user_filters)
        return
    end

    -- If logcat is already running, apply filters to current session
    if M.job_id and M.current_adb and M.current_device_id then
        M.start(M.current_adb, M.current_device_id, nil, user_filters)
    else
        -- No existing logcat and no device provided, start fresh with device selection
        local actions = require "droid.actions"
        local tools = actions.get_required_tools()
        if not tools then
            return
        end

        actions.select_target(tools, function(target)
            if target.type == "device" then
                M.start(tools.adb, target.id, nil, user_filters)
            elseif target.type == "avd" then
                vim.notify("AVD must be started first before attaching logcat", vim.log.levels.WARN)
            end
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
            vim.notify("Applying filters to existing logcat...", vim.log.levels.INFO)
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

        local filter_desc = "default filters"
        if active_filters.package == "mine" then
            filter_desc = "project package"
        elseif active_filters.package and active_filters.package ~= "none" then
            filter_desc = "package: " .. active_filters.package
        elseif active_filters.tag then
            filter_desc = "tag: " .. active_filters.tag
        end
        vim.notify("Logcat started for device: " .. device_id .. " (" .. filter_desc .. ")", vim.log.levels.INFO)
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
