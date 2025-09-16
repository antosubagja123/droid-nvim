-- Progress indicator utilities for droid.nvim
local M = {}

M.spinner_chars = { "|", "/", "-", "\\" }
M.spinner_index = 1
M.spinner_timer = nil
M.current_step = 0
M.total_steps = 0
M.current_message = ""

-- Start a spinner with optional message
function M.start_spinner(message)
    M.current_message = message or ""
    M.spinner_index = 1

    if M.spinner_timer then
        M.spinner_timer:stop()
    end

    M.spinner_timer = vim.loop.new_timer()
    M.spinner_timer:start(
        0,
        100,
        vim.schedule_wrap(function()
            local spinner_char = M.spinner_chars[M.spinner_index]
            M.spinner_index = (M.spinner_index % #M.spinner_chars) + 1

            local progress_text = ""
            if M.total_steps > 0 then
                progress_text = string.format("[%d/%d] ", M.current_step, M.total_steps)
            end

            local full_message = progress_text .. M.current_message .. " " .. spinner_char
            vim.api.nvim_echo({ { full_message, "MoreMsg" } }, false, {})
        end)
    )
end

-- Stop the spinner
function M.stop_spinner()
    if M.spinner_timer then
        M.spinner_timer:stop()
        M.spinner_timer = nil
    end
    vim.api.nvim_echo({ { "", "" } }, false, {}) -- Clear command line
end

-- Update spinner message without restarting
function M.update_spinner_message(message)
    M.current_message = message
end

-- Initialize progress tracking for a workflow
function M.start_workflow(total_steps)
    M.total_steps = total_steps
    M.current_step = 0
end

-- Advance to next step with message and optional spinner
function M.next_step(message, use_spinner)
    M.current_step = M.current_step + 1

    if use_spinner then
        M.start_spinner(message)
    else
        M.stop_spinner()
        local progress_text = string.format("[%d/%d] %s", M.current_step, M.total_steps, message)
        vim.notify(progress_text, vim.log.levels.INFO)
    end
end

-- Complete the workflow
function M.complete_workflow(message)
    M.stop_spinner()
    if message then
        vim.notify(message, vim.log.levels.INFO)
    end
    M.current_step = 0
    M.total_steps = 0
end

-- Error in workflow
function M.error_workflow(message)
    M.stop_spinner()
    if message then
        vim.notify(message, vim.log.levels.ERROR)
    end
    M.current_step = 0
    M.total_steps = 0
end

return M
