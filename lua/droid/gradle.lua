local config = require "droid.config"
local progress = require "droid.progress"
local buffer = require "droid.buffer"

local M = {}

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

    -- Get or create centralized buffer for gradle output with ownership
    local buf, win = buffer.get_or_create("gradle", "horizontal", "gradle")

    if not buf then
        -- Buffer is busy, callback with error
        if callback then
            vim.schedule(function()
                callback(false, -1)
            end)
        end
        return
    end

    -- Set the terminal job to run in the buffer
    vim.api.nvim_buf_call(buf, function()
        local job_id = vim.fn.jobstart(cmd, {
            term = true,
            cwd = cwd,
            on_exit = function(_, exit_code)
                buffer.set_current_job_with_owner(nil, "gradle")

                -- Show terminal window on completion, auto-focus on failure
                vim.schedule(function()
                    -- Ensure window is visible
                    if not buffer.is_valid() then
                        buffer.get_or_create("gradle", "horizontal", "gradle")
                    end

                    -- Focus window on failure for easier debugging
                    if exit_code ~= 0 then
                        buffer.focus()
                        buffer.scroll_to_bottom()
                    end

                    -- Release buffer lock after job completion
                    buffer.release_lock "gradle"

                    -- Run callback
                    if callback then
                        callback(exit_code == 0, exit_code)
                    end
                end)
            end,
        })
        buffer.set_current_job_with_owner(job_id, "gradle")
    end)
end

function M.open_gradle_window()
    local buf_info = buffer.get_buffer_info()
    if not buf_info.buffer_id or buf_info.type ~= "gradle" then
        return false
    end

    if buffer.is_valid() then
        -- Focus existing window
        buffer.focus()
    else
        -- Create new window
        buffer.get_or_create("gradle", "horizontal")
    end

    -- Scroll to bottom
    buffer.scroll_to_bottom()
    vim.cmd "stopinsert"
    return true
end

function M.is_gradle_window_visible()
    local buf_info = buffer.get_buffer_info()
    return buf_info.type == "gradle" and buffer.is_valid()
end

function M.show_log()
    if M.open_gradle_window() then
        return
    else
        vim.notify("No gradle terminal buffer available. Run a gradle command first.", vim.log.levels.WARN)
    end
end

function M.hide_gradle_window()
    local buf_info = buffer.get_buffer_info()
    if buf_info.type == "gradle" and buffer.is_valid() then
        -- Close window but keep buffer for later reuse
        local win_id = buf_info.window_id
        if win_id and vim.api.nvim_win_is_valid(win_id) then
            vim.api.nvim_win_close(win_id, true)
            return true
        end
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
        if callback then
            vim.schedule(function()
                callback(false, -1, "gradlew not found")
            end)
        end
        return
    end

    progress.start_spinner "Installing debug APK"

    -- Try to get buffer for background operation (no window display)
    local buf, win = buffer.get_or_create("gradle", nil, "gradle")

    if not buf then
        -- Buffer is busy, show message and queue operation
        progress.stop_spinner()
        vim.notify("Buffer is busy, install operation queued", vim.log.levels.WARN)
        if callback then
            vim.schedule(function()
                callback(false, -1, "Buffer busy")
            end)
        end
        return
    end

    -- Use centralized job management
    local job_id = vim.fn.jobstart({ g.gradlew, "installDebug" }, {
        cwd = g.cwd,
        on_exit = function(_, code)
            buffer.set_current_job_with_owner(nil, "gradle")
            progress.stop_spinner()

            local success = code == 0
            local message

            if success then
                message = "Debug APK installed successfully"
                vim.notify(message, vim.log.levels.INFO)
            else
                message = "Debug APK installation failed (exit code: " .. code .. ")"
                vim.notify(message, vim.log.levels.ERROR)
            end

            -- Release buffer lock
            buffer.release_lock "gradle"

            if callback then
                vim.schedule(function()
                    callback(success, code, message)
                end)
            end
        end,
    })

    buffer.set_current_job_with_owner(job_id, "gradle")
end

-- Sequential build and install function for enhanced DroidRun workflow
-- Args: callback(success, exit_code, message, step) - step indicates which phase failed
function M.build_and_install_debug(callback)
    local g = find_gradlew()
    if not g then
        if callback then
            vim.schedule(function()
                callback(false, -1, "gradlew not found", "build")
            end)
        end
        return
    end

    progress.start_spinner "Building debug APK"

    -- First: Build debug APK using centralized buffer
    run_gradle_task(g.cwd, g.gradlew, "assembleDebug", nil, function(build_success, build_code)
        if not build_success then
            progress.stop_spinner()
            local message = "Build failed (exit code: " .. build_code .. ")"
            vim.notify(message, vim.log.levels.ERROR)

            if callback then
                vim.schedule(function()
                    callback(false, build_code, message, "build")
                end)
            end
            return
        end

        -- Build succeeded, now install
        progress.update_spinner_message "Installing debug APK"

        -- Get buffer for install operation (reuse if gradle buffer is available)
        local buf, win = buffer.get_or_create("gradle", nil, "gradle")

        if not buf then
            progress.stop_spinner()
            local message = "Buffer busy, install cancelled"
            vim.notify(message, vim.log.levels.ERROR)
            if callback then
                vim.schedule(function()
                    callback(false, -1, message, "install")
                end)
            end
            return
        end

        local job_id = vim.fn.jobstart({ g.gradlew, "installDebug" }, {
            cwd = g.cwd,
            on_exit = function(_, install_code)
                buffer.set_current_job_with_owner(nil, "gradle")
                progress.stop_spinner()

                local install_success = install_code == 0
                local message

                if install_success then
                    message = "Build and install completed successfully"
                    vim.notify(message, vim.log.levels.INFO)
                else
                    message = "Install failed (exit code: " .. install_code .. ")"
                    vim.notify(message, vim.log.levels.ERROR)
                end

                -- Release buffer lock
                buffer.release_lock "gradle"

                if callback then
                    vim.schedule(function()
                        callback(install_success, install_code, message, "install")
                    end)
                end
            end,
        })

        buffer.set_current_job_with_owner(job_id, "gradle")
    end)
end

-- Composite function: install + launch (moved to keep compatibility)
function M.install_debug_and_launch(adb, device_id, callback)
    local config = require "droid.config"
    local cfg = config.get()

    M.install_debug(function(success, exit_code, message)
        if not success then
            -- Install failed, don't launch
            if callback then
                vim.schedule(callback)
            end
            return
        end

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
    local buf_info = buffer.get_buffer_info()
    if buf_info.job_id and (buf_info.job_owner == "gradle" or buf_info.type == "gradle") then
        buffer.stop_current_job_with_owner "gradle"
        buffer.release_lock "gradle"
        vim.notify("Gradle task stopped", vim.log.levels.INFO)
    else
        vim.notify("No active Gradle task", vim.log.levels.WARN)
    end
end

-- Clean up on Vim exit - now handled by centralized buffer management
vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
        -- Force stop any gradle jobs and release ownership
        local buf_info = buffer.get_buffer_info()
        if buf_info.job_owner == "gradle" then
            buffer.stop_current_job_with_owner "gradle"
            buffer.release_lock "gradle"
        end
    end,
})

return M
