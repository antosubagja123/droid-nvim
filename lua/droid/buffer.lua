-- Simple buffer management for droid.nvim
-- Manages a single reusable buffer for both logcat and gradle output

local config = require "droid.config"

local M = {}

-- Simple state tracking
M.buffer_id = nil
M.window_id = nil
M.buffer_type = nil -- "logcat" | "gradle"
M.current_job_id = nil

-- Check if buffer is busy with a different type
local function is_buffer_busy(new_type)
    return M.buffer_id and vim.api.nvim_buf_is_valid(M.buffer_id) and M.buffer_type ~= new_type
end

-- Get or create buffer for specified type and mode
local function get_or_create_buffer(buffer_type, mode)
    -- Check if buffer was deleted externally
    if M.buffer_id and not vim.api.nvim_buf_is_valid(M.buffer_id) then
        M.reset_state()
    end

    -- Create new buffer if needed
    if not M.buffer_id then
        M.buffer_id = vim.api.nvim_create_buf(false, true)
        M.buffer_type = buffer_type
        M.setup_buffer(buffer_type)
        M.open_window(mode)
        M.attach_cleanup()
    else
        -- Reuse existing buffer
        if M.buffer_type ~= buffer_type then
            M.stop_current_job()
            M.buffer_type = buffer_type
            M.setup_buffer(buffer_type)
        end

        M.clear_content()

        -- Ensure window is visible
        if not M.window_id or not vim.api.nvim_win_is_valid(M.window_id) then
            M.open_window(mode)
        end
    end

    return M.buffer_id, M.window_id
end

-- Get or create buffer for specified type and mode
-- Args: type ("logcat" | "gradle"), mode (window display mode)
-- Returns: buffer_id, window_id
function M.get_or_create(buffer_type, mode)
    -- Warn if switching buffer types while in use
    if is_buffer_busy(buffer_type) then
        vim.notify(string.format("Switching buffer from %s to %s", M.buffer_type, buffer_type), vim.log.levels.INFO)
    end

    return get_or_create_buffer(buffer_type, mode)
end

-- Clear buffer content and prepare for new output
function M.clear_content()
    if M.buffer_id and vim.api.nvim_buf_is_valid(M.buffer_id) then
        -- Make buffer modifiable temporarily
        local was_modifiable = vim.bo[M.buffer_id].modifiable
        vim.bo[M.buffer_id].modifiable = true

        -- Clear all content
        vim.api.nvim_buf_set_lines(M.buffer_id, 0, -1, false, {})

        -- Reset modified flag
        vim.bo[M.buffer_id].modified = false

        -- Restore modifiable state
        vim.bo[M.buffer_id].modifiable = was_modifiable
    end
end

-- Switch buffer content type (logcat ↔ gradle)
function M.switch_content(new_type)
    if M.buffer_id and vim.api.nvim_buf_is_valid(M.buffer_id) then
        M.stop_current_job()
        M.buffer_type = new_type
        M.setup_buffer(new_type)
        M.clear_content()
    end
end

-- Reset buffer state (for when buffer becomes invalid)
function M.reset_state()
    M.buffer_id = nil
    M.window_id = nil
    M.buffer_type = nil
    M.current_job_id = nil
end

-- Setup buffer properties based on type
function M.setup_buffer(type)
    if not M.buffer_id or not vim.api.nvim_buf_is_valid(M.buffer_id) then
        return
    end

    if type == "logcat" then
        vim.bo[M.buffer_id].filetype = "logcat"
        vim.bo[M.buffer_id].modifiable = false
        vim.bo[M.buffer_id].readonly = true
    elseif type == "gradle" then
        vim.bo[M.buffer_id].filetype = "terminal"
        vim.bo[M.buffer_id].modifiable = true
        vim.bo[M.buffer_id].readonly = false
    end

    -- Common buffer settings
    vim.bo[M.buffer_id].buflisted = false
    vim.bo[M.buffer_id].bufhidden = "wipe"
end

-- Open window according to display mode
function M.open_window(mode)
    if not M.buffer_id or not vim.api.nvim_buf_is_valid(M.buffer_id) then
        return false
    end

    local cfg = config.get()
    mode = mode or cfg.logcat.mode

    -- Close existing window if open
    if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
        vim.api.nvim_win_close(M.window_id, true)
    end

    -- Open window according to mode
    if mode == "horizontal" then
        local height = cfg.logcat.height or 15
        vim.cmd("botright split | resize " .. height)
        M.window_id = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.window_id, M.buffer_id)
    elseif mode == "vertical" then
        local width = cfg.logcat.width or 80
        vim.cmd("vsplit | vertical resize " .. width)
        M.window_id = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.window_id, M.buffer_id)
    elseif mode == "float" then
        local win_opts = {
            relative = "editor",
            width = cfg.logcat.float_width or 120,
            height = cfg.logcat.float_height or 30,
            row = (vim.o.lines - (cfg.logcat.float_height or 30)) / 2,
            col = (vim.o.columns - (cfg.logcat.float_width or 120)) / 2,
            style = "minimal",
            border = "rounded",
        }
        M.window_id = vim.api.nvim_open_win(M.buffer_id, true, win_opts)
    end

    return M.window_id ~= nil
end

-- Attach cleanup handlers
function M.attach_cleanup()
    if not M.buffer_id then
        return
    end

    -- Handle buffer deletion
    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = M.buffer_id,
        once = true,
        callback = function()
            M.close()
        end,
    })

    -- Handle Neovim exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            M.close()
        end,
        once = true,
    })
end

-- Stop current running job
function M.stop_current_job()
    if M.current_job_id then
        vim.fn.jobstop(M.current_job_id)
        M.current_job_id = nil
    end
end

-- Close buffer and reset state
function M.close()
    -- Stop any running job
    M.stop_current_job()

    -- Close window
    if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
        vim.api.nvim_win_close(M.window_id, true)
    end

    -- Delete buffer (with error handling for terminal buffers)
    if M.buffer_id and vim.api.nvim_buf_is_valid(M.buffer_id) then
        -- For terminal buffers, give a moment for processes to clean up
        local bufname = vim.api.nvim_buf_get_name(M.buffer_id)
        if bufname:match "^term://" then
            local buffer_to_delete = M.buffer_id -- Capture buffer ID before defer_fn
            vim.defer_fn(function()
                if buffer_to_delete and vim.api.nvim_buf_is_valid(buffer_to_delete) then
                    local success, err = pcall(vim.api.nvim_buf_delete, buffer_to_delete, { force = true })
                    if not success then
                        -- If force delete still fails, hide the buffer
                        pcall(function()
                            vim.bo[buffer_to_delete].buflisted = false
                            vim.bo[buffer_to_delete].bufhidden = "wipe"
                        end)
                    end
                end
            end, 100) -- 100ms delay
        else
            local success, err = pcall(vim.api.nvim_buf_delete, M.buffer_id, { force = true })
            if not success then
                -- If force delete fails, try to hide it instead
                pcall(function()
                    vim.bo[M.buffer_id].buflisted = false
                    vim.bo[M.buffer_id].bufhidden = "wipe"
                end)
            end
        end
    end

    -- Reset all state
    M.reset_state()
end

-- Get current buffer info
function M.get_buffer_info()
    return {
        buffer_id = M.buffer_id,
        window_id = M.window_id,
        type = M.buffer_type,
        job_id = M.current_job_id,
    }
end

-- Set current job ID (for tracking by logcat/gradle modules)
function M.set_current_job(job_id)
    M.current_job_id = job_id
end

-- Check if buffer and window are valid
function M.is_valid()
    return M.buffer_id
        and vim.api.nvim_buf_is_valid(M.buffer_id)
        and M.window_id
        and vim.api.nvim_win_is_valid(M.window_id)
end

-- Focus the buffer window
function M.focus()
    if M.window_id and vim.api.nvim_win_is_valid(M.window_id) then
        vim.api.nvim_set_current_win(M.window_id)
        return true
    end
    return false
end

-- Scroll to bottom of buffer
function M.scroll_to_bottom()
    if M.is_valid() then
        vim.api.nvim_win_call(M.window_id, function()
            vim.cmd "normal! G"
        end)
    end
end

return M
