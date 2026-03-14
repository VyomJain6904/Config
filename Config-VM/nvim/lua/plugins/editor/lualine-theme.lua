local M = {}

local function get_palette()
    -- Official Dracula palette
    return {
        bg = "#282a36",
        fg = "#f8f8f2",

        comment = "#6272a4",
        cyan = "#8be9fd",
        green = "#50fa7b",
        orange = "#ffb86c",
        pink = "#ff79c6",
        purple = "#bd93f9",
        red = "#ff5555",
        yellow = "#f1fa8c",
    }
end

function M.build_theme()
    return get_palette()
end

function M.apply_highlights()
    local c = get_palette()

    -- Center section
    vim.api.nvim_set_hl(0, "LualineNormalC", {
        fg = c.fg,
        bg = c.bg,
    })

    vim.api.nvim_set_hl(0, "LualineInactiveC", {
        fg = c.comment,
        bg = c.bg,
    })

    vim.api.nvim_set_hl(0, "LualineFilename", {
        fg = c.fg,
        bg = c.bg,
        bold = true,
    })

    -- Diagnostics
    vim.api.nvim_set_hl(0, "LualineDiagnosticsError", {
        fg = c.red,
        bg = c.bg,
    })

    vim.api.nvim_set_hl(0, "LualineDiagnosticsWarn", {
        fg = c.yellow,
        bg = c.bg,
    })

    vim.api.nvim_set_hl(0, "LualineDiagnosticsInfo", {
        fg = c.cyan,
        bg = c.bg,
    })

    -- LSP
    vim.api.nvim_set_hl(0, "LualineLsp", {
        fg = c.pink,
        bg = c.bg,
    })

    -- Git
    vim.api.nvim_set_hl(0, "LualineBranch", {
        fg = c.purple,
        bg = c.bg,
        bold = true,
    })

    vim.api.nvim_set_hl(0, "LualineDiffAdded", {
        fg = c.green,
        bg = c.bg,
        bold = true,
    })

    vim.api.nvim_set_hl(0, "LualineDiffModified", {
        fg = c.orange,
        bg = c.bg,
        bold = true,
    })

    vim.api.nvim_set_hl(0, "LualineDiffRemoved", {
        fg = c.red,
        bg = c.bg,
        bold = true,
    })
end

return M
