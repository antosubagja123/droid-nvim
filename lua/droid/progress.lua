-- Progress indicator utilities for droid.nvim
local M = {}

-- Spinner animation
M.spinner_chars = { "|", "/", "-", "\\" }
M.spinner_index = 1
M.spinner_timer = nil

-- Workflow progress
M.current_step = 0
M.total_steps = 0
M.current_message = ""

-- Global loading state management
M.is_loading = false
M.current_session = nil
M.loading_queue = {}

-- Priority levels (higher = more important)
M.PRIORITY = {
    LOW = 1, -- DroidEmulatorWipeData
    MEDIUM = 2, -- DroidClean, DroidSync, DroidEmulator
    HIGH = 3, -- DroidBuildDebug, DroidTask
    CRITICAL = 4, -- DroidRun, DroidInstall
}

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

-- Global loading management functions

-- Start loading with conflict management
function M.start_loading(options)
    local session = {
        id = vim.fn.localtime() .. math.random(1000),
        command = options.command or "Unknown",
        priority = options.priority or M.PRIORITY.MEDIUM,
        message = options.message or "Loading...",
        type = options.type or "spinner", -- "spinner" | "workflow"
        steps = options.steps,
    }

    -- Check for conflicts
    if M.is_loading then
        return M._handle_conflict(session)
    end

    -- Start loading
    M.is_loading = true
    M.current_session = session

    if session.type == "workflow" then
        M.start_workflow(session.steps)
    else
        M.start_spinner(session.message)
    end

    return session.id
end

-- Stop loading and process queue
function M.stop_loading(session_id, success, message)
    if not M.current_session or M.current_session.id ~= session_id then
        return false
    end

    -- Stop current loading
    if M.current_session.type == "workflow" then
        if success then
            M.complete_workflow(message)
        else
            M.error_workflow(message)
        end
    else
        M.stop_spinner()
        if message then
            local level = success and vim.log.levels.INFO or vim.log.levels.ERROR
            vim.notify(message, level)
        end
    end

    -- Reset state and process queue
    M.is_loading = false
    M.current_session = nil
    M._process_queue()

    return true
end

-- Check if loading is active
function M.is_active()
    return M.is_loading
end

-- Get current session info
function M.get_current_session()
    return M.current_session
end

-- Private functions

function M._handle_conflict(new_session)
    local current = M.current_session

    if new_session.priority > current.priority then
        -- Higher priority: interrupt current
        M._force_stop()
        M._queue_session(current)
        M.is_loading = false
        return M.start_loading(new_session)
    elseif new_session.priority == current.priority then
        -- Same priority: queue
        M._queue_session(new_session)
        vim.notify(
            string.format("%s queued (waiting for %s)", new_session.command, current.command),
            vim.log.levels.INFO
        )
        return nil
    else
        -- Lower priority: reject
        vim.notify(
            string.format("%s cancelled (%s is running)", new_session.command, current.command),
            vim.log.levels.WARN
        )
        return nil
    end
end

function M._queue_session(session)
    table.insert(M.loading_queue, session)
    table.sort(M.loading_queue, function(a, b)
        return a.priority > b.priority
    end)
end

function M._process_queue()
    if #M.loading_queue > 0 then
        local next_session = table.remove(M.loading_queue, 1)
        M.start_loading(next_session)
    end
end

function M._force_stop()
    M.stop_spinner()
    M.current_step = 0
    M.total_steps = 0
end

return M
