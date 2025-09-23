local M = {}

-- Default configuration
local defaults = {
    logcat = {
        mode = "horizontal", -- "horizontal" | "vertical" | "float"
        height = 15,
        width = 80,
        float_width = 120,
        float_height = 30,
        filters = {
            package = "mine", -- "mine" (auto-detect), specific package, or "none"
            log_level = "v", -- v, d, i, w, e, f
            tag = nil,
            grep_pattern = nil,
        },
    },
    android = {
        auto_select_single_target = true,
        auto_launch_app = true,
        adb_path = nil,
        emulator_path = nil,
        qt_qpa_platform = nil,
        device_wait_timeout_ms = 120000,
        logcat_startup_delay_ms = 2000,
    },
}

M.config = vim.deepcopy(defaults)

-- Validate configuration values
local function validate_config(config)
    local valid_modes = { horizontal = true, vertical = true, float = true }
    if config.logcat and config.logcat.mode and not valid_modes[config.logcat.mode] then
        vim.notify("Invalid logcat mode. Using 'horizontal'", vim.log.levels.WARN)
        config.logcat.mode = "horizontal"
    end

    if config.logcat then
        if config.logcat.height and (type(config.logcat.height) ~= "number" or config.logcat.height <= 0) then
            config.logcat.height = 15
        end
        if config.logcat.width and (type(config.logcat.width) ~= "number" or config.logcat.width <= 0) then
            config.logcat.width = 80
        end
    end
end

-- Handle legacy flat configuration format
local function migrate_legacy_config(opts)
    local migrated = {}

    -- Migrate logcat options
    if opts.logcat_mode or opts.logcat_height or opts.logcat_width or opts.logcat_filters then
        migrated.logcat = {
            mode = opts.logcat_mode,
            height = opts.logcat_height,
            width = opts.logcat_width,
            filters = {},
        }

        if opts.logcat_filters then
            migrated.logcat.filters.tag = opts.logcat_filters.tag
            if opts.logcat_filters.priority then
                migrated.logcat.filters.log_level = string.lower(opts.logcat_filters.priority)
            end
        end
    end

    -- Migrate android options
    local android_keys = {
        "auto_select_single_target",
        "auto_launch_app",
        "adb_path",
        "emulator_path",
        "qt_qpa_platform",
        "device_wait_timeout_ms",
        "logcat_startup_delay_ms",
    }

    local has_android_config = false
    for _, key in ipairs(android_keys) do
        if opts[key] ~= nil then
            has_android_config = true
            break
        end
    end

    if has_android_config then
        migrated.android = {}
        for _, key in ipairs(android_keys) do
            migrated.android[key] = opts[key]
        end
    end

    return migrated
end

function M.setup(opts)
    opts = opts or {}

    -- Start with legacy migration
    local config_to_merge = migrate_legacy_config(opts)

    -- Merge modern nested config
    if opts.logcat then
        config_to_merge.logcat = vim.tbl_extend("force", config_to_merge.logcat or {}, opts.logcat)
    end
    if opts.android then
        config_to_merge.android = vim.tbl_extend("force", config_to_merge.android or {}, opts.android)
    end

    -- Validate and merge final config
    validate_config(config_to_merge)
    M.config = vim.tbl_deep_extend("force", M.config, config_to_merge)
end

function M.get()
    return M.config
end

return M
