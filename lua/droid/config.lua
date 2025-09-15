local M = {}

M.defaults = {
    logcat_mode = "horizontal", -- "horizontal" | "vertical" | "float"
    logcat_height = 12,
    logcat_width = 80,
    auto_select_single_target = true, -- Auto-select if only one device/emulator
    logcat_filters = {}, -- e.g., { tag = "MyApp", priority = "DEBUG" }
    adb_path = nil, -- Custom ADB path override
    emulator_path = nil, -- Custom emulator path override
    device_wait_timeout_ms = 30000, -- Timeout for waiting for device (ms)
}

M.config = vim.deepcopy(M.defaults)

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

function M.get()
    return M.config
end

return M
