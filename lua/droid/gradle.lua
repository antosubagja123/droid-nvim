local config = require "droid.config"
local progress = require "droid.progress"

local M = {}

M.job_id = nil
M.term_buf = nil
M.term_win = nil

local function find_gradlew()
    local gradlew = vim.fs.find("gradlew", { upward = true })[1]
    if gradlew and vim.fn.executable(gradlew) == 1 then
        return { gradlew = gradlew, cwd = vim.fs.dirname(gradlew) }
    end

    -- Check if gradlew exists but is not executable
    if gradlew and vim.fn.filereadable(gradlew) == 1 then
        vim.notify(
            "gradlew found but not executable: " .. gradlew .. " - attempting to fix permissions...",
            vim.log.levels.WARN
        )

        -- Try to make it executable
        vim.fn.system { "chmod", "+x", gradlew }
        if vim.v.shell_error == 0 then
            vim.notify("Made gradlew executable: " .. gradlew, vim.log.levels.INFO)
            return { gradlew = gradlew, cwd = vim.fs.dirname(gradlew) }
        else
            vim.notify("Could not make gradlew executable (will use shell execution): " .. gradlew, vim.log.levels.WARN)
            return { gradlew = gradlew, cwd = vim.fs.dirname(gradlew) }
        end
    end

    vim.notify("gradlew not found in project", vim.log.levels.ERROR)
    return nil
end

local function run_gradle_task(cwd, gradlew, task, args, callback)
    local cmd_args = vim.iter({ task, args or {} }):flatten():totable()
    local cmd = gradlew .. " " .. table.concat(cmd_args, " ")

    -- Create or reuse terminal buffer (clear and mark unmodified for reuse)
    if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
        -- Make buffer modifiable, clear content, and mark as unmodified
        vim.bo[M.term_buf].modifiable = true
        vim.api.nvim_buf_set_lines(M.term_buf, 0, -1, false, {})
        vim.bo[M.term_buf].modified = false
    else
        -- Create new terminal buffer
        M.term_buf = vim.api.nvim_create_buf(false, true)

        -- Handle buffer deletion
        vim.api.nvim_create_autocmd("BufDelete", {
            buffer = M.term_buf,
            once = true,
            callback = function()
                M.term_buf = nil
                M.term_win = nil
            end,
        })
    end

    -- Set the terminal job to run in the buffer (in background)
    vim.api.nvim_buf_call(M.term_buf, function()
        M.job_id = vim.fn.jobstart(cmd, {
            term = true,
            cwd = cwd,
            on_exit = function(_, exit_code)
                M.job_id = nil

                -- Show terminal window only on completion
                vim.schedule(function()
                    M.open_gradle_window()

                    -- Run callback
                    if callback then
                        callback(exit_code == 0, exit_code)
                    end
                end)
            end,
        })
    end)
end

function M.open_gradle_window()
    if not M.term_buf or not vim.api.nvim_buf_is_valid(M.term_buf) then
        return false
    end

    if M.term_win and vim.api.nvim_win_is_valid(M.term_win) then
        -- Focus existing window
        vim.api.nvim_set_current_win(M.term_win)
    else
        -- Create new window
        vim.cmd "botright split | resize 15"
        M.term_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(M.term_win, M.term_buf)

        -- Configure window appearance
        vim.wo[M.term_win].number = false
        vim.wo[M.term_win].relativenumber = false
        vim.wo[M.term_win].signcolumn = "no"
    end

    -- Scroll to bottom
    vim.cmd "normal! G"
    vim.cmd "stopinsert"
    return true
end

function M.is_gradle_window_visible()
    return M.term_win and vim.api.nvim_win_is_valid(M.term_win)
end

function M.show_log()
    if M.open_gradle_window() then
        return
    else
        vim.notify("No gradle terminal buffer available. Run a gradle command first.", vim.log.levels.WARN)
    end
end

function M.hide_gradle_window()
    if M.term_win and vim.api.nvim_win_is_valid(M.term_win) then
        vim.api.nvim_win_close(M.term_win, false)
        M.term_win = nil
        return true
    end
    return false
end

function M.toggle_gradle_window()
    if M.is_gradle_window_visible() then
        -- Window is visible, hide it
        M.hide_gradle_window()
        vim.notify("Gradle window hidden", vim.log.levels.INFO)
    else
        -- Window is hidden, show it
        if M.open_gradle_window() then
            vim.notify("Gradle window shown", vim.log.levels.INFO)
        else
            vim.notify("No gradle terminal buffer available. Run a gradle command first.", vim.log.levels.WARN)
        end
    end
end

function M.sync()
    local g = find_gradlew()
    if not g then
        return
    end

    -- Start loading with global management
    local session_id = progress.start_loading {
        command = "DroidSync",
        priority = progress.PRIORITY.MEDIUM,
        message = "Syncing dependencies",
    }

    if not session_id then
        return -- Loading was queued or cancelled
    end

    run_gradle_task(g.cwd, g.gradlew, "--refresh-dependencies", nil, function(success, exit_code)
        local message
        if success then
            message = "Dependencies synced successfully"
        else
            message = string.format("Sync failed (exit code: %d)", exit_code)
        end
        progress.stop_loading(session_id, success, message)
    end)
end

function M.clean()
    local g = find_gradlew()
    if not g then
        return
    end

    -- Start loading with global management
    local session_id = progress.start_loading {
        command = "DroidClean",
        priority = progress.PRIORITY.MEDIUM,
        message = "Cleaning project",
    }

    if not session_id then
        return -- Loading was queued or cancelled
    end

    run_gradle_task(g.cwd, g.gradlew, "clean", nil, function(success, exit_code)
        local message
        if success then
            message = "Project cleaned successfully"
        else
            message = string.format("Clean failed (exit code: %d)", exit_code)
        end
        progress.stop_loading(session_id, success, message)
    end)
end

function M.build_debug()
    local g = find_gradlew()
    if not g then
        return
    end

    -- Start loading with global management
    local session_id = progress.start_loading {
        command = "DroidBuildDebug",
        priority = progress.PRIORITY.HIGH,
        message = "Building debug APK",
    }

    if not session_id then
        return -- Loading was queued or cancelled
    end

    run_gradle_task(g.cwd, g.gradlew, "assembleDebug", nil, function(success, exit_code)
        local message
        if success then
            message = "Debug APK built successfully"
        else
            message = string.format("Build failed (exit code: %d)", exit_code)
        end
        progress.stop_loading(session_id, success, message)
    end)
end

function M.task(task, args)
    local g = find_gradlew()
    if not g then
        return
    end

    -- Start loading with global management
    local session_id = progress.start_loading {
        command = "DroidTask",
        priority = progress.PRIORITY.HIGH,
        message = "Running task: " .. task,
    }

    if not session_id then
        return -- Loading was queued or cancelled
    end

    run_gradle_task(g.cwd, g.gradlew, task, args, function(success, exit_code)
        local message
        if success then
            message = string.format("Task '%s' completed successfully", task)
        else
            message = string.format("Task '%s' failed (exit code: %d)", task, exit_code)
        end
        progress.stop_loading(session_id, success, message)
    end)
end

-- Pure install function (no launching)
function M.install_debug(callback)
    local g = find_gradlew()
    if not g then
        return
    end

    progress.start_spinner "Installing debug APK"

    -- Use silent terminal for install (no window, just job control)
    M.job_id = vim.fn.jobstart({ g.gradlew, "installDebug" }, {
        cwd = g.cwd,
        on_exit = function(_, code)
            M.job_id = nil
            progress.stop_spinner()

            if code == 0 then
                vim.notify("Debug APK installed successfully", vim.log.levels.INFO)
            else
                vim.notify("Debug APK installation failed (exit code: " .. code .. ")", vim.log.levels.ERROR)
            end

            if callback then
                vim.schedule(callback)
            end
        end,
    })
end

-- Composite function: install + launch (moved to keep compatibility)
function M.install_debug_and_launch(adb, device_id, callback)
    local config = require "droid.config"
    local cfg = config.get()

    M.install_debug(function()
        -- Launch app if auto_launch_app is enabled
        if cfg.auto_launch_app then
            local android = require "droid.android"
            android.launch_app_on_device(adb, device_id, callback)
        else
            if callback then
                vim.schedule(callback)
            end
        end
    end)
end

function M.stop()
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        M.job_id = nil
        vim.notify("Gradle task stopped", vim.log.levels.INFO)
    else
        vim.notify("No active Gradle task", vim.log.levels.WARN)
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
