local M = {}

function M.build_theme()
    return require('lualine.themes.dracula')
end

function M.apply_highlights()
    -- dracula-nvim handles lualine highlights automatically
end

return M
