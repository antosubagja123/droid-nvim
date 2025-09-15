local config = require "droid.config"

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


local function run_gradle_task(cwd, gradlew, task, args)
    local cmd_args = vim.iter({ task, args or {} }):flatten():totable()
    local cmd = gradlew .. " " .. table.concat(cmd_args, " ")

    -- Reuse existing terminal buffer if valid
    if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
        -- Check if window still exists and is showing our buffer
        if M.term_win and vim.api.nvim_win_is_valid(M.term_win) then
            -- Focus existing window and clear it
            vim.api.nvim_set_current_win(M.term_win)
        else
            -- Window closed, create new one with existing buffer
            vim.cmd("botright split | resize 15")
            M.term_win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(M.term_win, M.term_buf)
        end

        -- Start new terminal job in existing buffer
        vim.fn.termopen(cmd, { cwd = cwd })
    else
        -- Create new terminal buffer
        vim.cmd("botright split | resize 15 | terminal " .. cmd)
        M.term_buf = vim.api.nvim_get_current_buf()
        M.term_win = vim.api.nvim_get_current_win()

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

    -- Auto-exit insert mode when terminal job ends
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = M.term_buf,
        once = true,
        callback = function()
            vim.cmd("stopinsert")
            vim.notify("Gradle task completed - you can now scroll the output", vim.log.levels.INFO)
        end,
    })

    vim.cmd "startinsert"
end

function M.show_log()
    if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
        if M.term_win and vim.api.nvim_win_is_valid(M.term_win) then
            -- Focus existing window
            vim.api.nvim_set_current_win(M.term_win)
        else
            -- Window was closed, reopen it
            vim.cmd("botright split | resize 15")
            M.term_win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(M.term_win, M.term_buf)
        end
        vim.cmd("normal! G")
    else
        vim.notify("No gradle terminal buffer available. Run a gradle command first.", vim.log.levels.WARN)
    end
end

function M.sync()
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, "--refresh-dependencies")
    end
end

function M.clean()
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, "clean")
    end
end

function M.build_debug()
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, "assembleDebug")
    end
end

function M.task(task, args)
    local g = find_gradlew()
    if g then
        run_gradle_task(g.cwd, g.gradlew, task, args)
    end
end

function M.install_debug(callback)
    local g = find_gradlew()
    if not g then
        return
    end

    vim.notify("Installing debug APK...", vim.log.levels.INFO)

    -- Use silent terminal for install (no window, just job control)
    M.job_id = vim.fn.jobstart({ g.gradlew, "installDebug" }, {
        cwd = g.cwd,
        on_exit = function(_, code)
            M.job_id = nil

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
