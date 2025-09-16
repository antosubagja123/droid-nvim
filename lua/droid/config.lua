local M = {}

M.defaults = {
    logcat = {
        window_type = "horizontal", -- "horizontal" | "vertical" | "float"
        height = 12,
        width = 80,
        filters = {
            package = "mine", -- "mine" (auto-detect project package), specific package, or "none"
            log_level = "v", -- v, d, i, w, e, f (lowercase)
            tag = nil, -- specific tag to filter, or nil for no tag filtering
            grep_pattern = nil, -- regex pattern for content filtering, or nil
        },
    },
    android = {
        auto_select_single_target = true, -- Auto-select if only one device/emulator
        auto_launch_app = true, -- Auto-launch app after successful installation
        adb_path = nil, -- Custom ADB path override
        emulator_path = nil, -- Custom emulator path override
        qt_qpa_platform = nil, -- Qt platform for emulator (e.g., "xcb" for Linux)
        device_wait_timeout_ms = 30000, -- Timeout for waiting for device (ms)
        logcat_startup_delay_ms = 2000, -- Delay after app launch before starting logcat (ms)
    },
}

M.config = vim.deepcopy(M.defaults)

function M.setup(opts)
    opts = opts or {}

    -- Handle legacy flat config for backward compatibility
    local config_to_merge = {}
    if opts.logcat_mode or opts.logcat_height or opts.logcat_width or opts.logcat_filters then
        -- Handle legacy logcat_filters migration
        local filters = {}
        if opts.logcat_filters then
            if opts.logcat_filters.tag then
                filters.tag = opts.logcat_filters.tag
            end
            if opts.logcat_filters.priority then
                filters.log_level = string.lower(opts.logcat_filters.priority)
            end
        end

        config_to_merge.logcat = {
            window_type = opts.logcat_mode,
            height = opts.logcat_height,
            width = opts.logcat_width,
            filters = filters,
        }
    end
    if
        opts.auto_select_single_target
        or opts.auto_launch_app
        or opts.adb_path
        or opts.emulator_path
        or opts.qt_qpa_platform
        or opts.device_wait_timeout_ms
        or opts.logcat_startup_delay_ms
    then
        config_to_merge.android = {
            auto_select_single_target = opts.auto_select_single_target,
            auto_launch_app = opts.auto_launch_app,
            adb_path = opts.adb_path,
            emulator_path = opts.emulator_path,
            qt_qpa_platform = opts.qt_qpa_platform,
            device_wait_timeout_ms = opts.device_wait_timeout_ms,
            logcat_startup_delay_ms = opts.logcat_startup_delay_ms,
        }
    end

    -- Merge nested config
    if opts.logcat then
        config_to_merge.logcat = vim.tbl_extend("force", config_to_merge.logcat or {}, opts.logcat)
    end
    if opts.android then
        config_to_merge.android = vim.tbl_extend("force", config_to_merge.android or {}, opts.android)
    end

    -- Validate logcat window_type
    local valid_modes = { horizontal = true, vertical = true, float = true }
    if
        config_to_merge.logcat
        and config_to_merge.logcat.window_type
        and not valid_modes[config_to_merge.logcat.window_type]
    then
        vim.notify(
            "Invalid logcat window_type: " .. config_to_merge.logcat.window_type .. ". Using default: horizontal",
            vim.log.levels.WARN
        )
        config_to_merge.logcat.window_type = "horizontal"
    end

    -- Validate dimensions
    if config_to_merge.logcat then
        if
            config_to_merge.logcat.height
            and (type(config_to_merge.logcat.height) ~= "number" or config_to_merge.logcat.height <= 0)
        then
            vim.notify("Invalid logcat height. Using default: 12", vim.log.levels.WARN)
            config_to_merge.logcat.height = 12
        end
        if
            config_to_merge.logcat.width
            and (type(config_to_merge.logcat.width) ~= "number" or config_to_merge.logcat.width <= 0)
        then
            vim.notify("Invalid logcat width. Using default: 80", vim.log.levels.WARN)
            config_to_merge.logcat.width = 80
        end
    end

    M.config = vim.tbl_deep_extend("force", M.config, config_to_merge)
end

function M.get()
    -- Return config with backward compatibility flat structure
    local flat_config = vim.tbl_deep_extend("force", {}, M.config)

    -- Add flat aliases for backward compatibility
    if M.config.logcat then
        flat_config.logcat_mode = M.config.logcat.window_type
        flat_config.logcat_height = M.config.logcat.height
        flat_config.logcat_width = M.config.logcat.width
        flat_config.logcat_filters = M.config.logcat.filters
    end

    if M.config.android then
        flat_config.auto_select_single_target = M.config.android.auto_select_single_target
        flat_config.auto_launch_app = M.config.android.auto_launch_app
        flat_config.adb_path = M.config.android.adb_path
        flat_config.emulator_path = M.config.android.emulator_path
        flat_config.qt_qpa_platform = M.config.android.qt_qpa_platform
        flat_config.device_wait_timeout_ms = M.config.android.device_wait_timeout_ms
        flat_config.logcat_startup_delay_ms = M.config.android.logcat_startup_delay_ms
    end

    return flat_config
end

return M
