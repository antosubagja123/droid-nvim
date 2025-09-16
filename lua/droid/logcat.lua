local config = require "droid.config"

local M = {}

M.job_id = nil
M.buf = nil
M.win = nil

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

function M.open(adb, device_id, mode)
    local cfg = config.get()

    -- Stop existing logcat if running (silently)
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        M.job_id = nil
        vim.notify("Logcat stopped", vim.log.levels.INFO)
    end

    -- Create new buffer and window
    create_logcat_buffer()
    open_window(mode)

    local job_opts = {
        stdout_buffered = false,
        on_stdout = function(_, data)
            if data then
                vim.api.nvim_buf_set_lines(M.buf, -1, -1, false, data)
            end
        end,
        on_exit = function(_, _, _)
            M.job_id = nil
            vim.notify("Logcat process exited", vim.log.levels.INFO)
        end,
    }

    -- Start logcat job with optional filters
    local cmd = { adb, "-s", device_id, "logcat" }
    if cfg.logcat_filters.tag then
        table.insert(cmd, cfg.logcat_filters.tag .. ":" .. (cfg.logcat_filters.priority or "V"))
    end

    M.job_id = vim.fn.jobstart(cmd, job_opts)
    attach_cleanup()

    vim.notify("Logcat started for device: " .. device_id, vim.log.levels.INFO)
end

function M.stop()
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        M.job_id = nil
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
