local M = {}

local function get_palette()
    return {
        bg = '#141414',
        fg = '#c4c4c4',
        dim = '#606060',
        soft = '#909090',
        strong = '#e0e0e0',
        subtle = '#505050'
    }
end

function M.build_theme()
    return get_palette()
end

function M.apply_highlights()
    local c = get_palette()

    vim.api.nvim_set_hl(0, 'LualineNormalC', {
        fg = c.fg,
        bg = c.bg
    })
    vim.api.nvim_set_hl(0, 'LualineInactiveC', {
        fg = c.fg,
        bg = c.bg
    })
    vim.api.nvim_set_hl(0, 'LualineFilename', {
        fg = c.fg,
        bg = c.bg
    })

    vim.api.nvim_set_hl(0, 'LualineDiagnosticsError', {
        bg = c.bg,
        fg = c.dim
    })
    vim.api.nvim_set_hl(0, 'LualineDiagnosticsWarn', {
        bg = c.bg,
        fg = c.soft
    })
    vim.api.nvim_set_hl(0, 'LualineDiagnosticsInfo', {
        bg = c.bg,
        fg = c.fg
    })
    vim.api.nvim_set_hl(0, 'LualineLsp', {
        bg = c.bg,
        fg = c.fg
    })
    vim.api.nvim_set_hl(0, 'LualineBranch', {
        bg = c.bg,
        fg = c.strong,
        bold = true
    })
    vim.api.nvim_set_hl(0, 'LualineDiffAdded', {
        bg = c.bg,
        fg = c.fg,
        bold = true
    })
    vim.api.nvim_set_hl(0, 'LualineDiffModified', {
        bg = c.bg,
        fg = c.soft,
        bold = true
    })
    vim.api.nvim_set_hl(0, 'LualineDiffRemoved', {
        bg = c.bg,
        fg = c.dim,
        bold = true
    })

    -- add more as needed
end

return M
