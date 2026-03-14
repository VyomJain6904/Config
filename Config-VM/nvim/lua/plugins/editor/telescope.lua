local kind_filter = {
    default = {
        "Class",
        "Constructor",
        "Enum",
        "Field",
        "Function",
        "Interface",
        "Method",
        "Module",
        "Namespace",
        "Package",
        "Property",
        "Struct",
        "Trait",
    },
    markdown = false,
    help = false,
    lua = {
        "Class",
        "Constructor",
        "Enum",
        "Field",
        "Function",
        "Interface",
        "Method",
        "Module",
        "Namespace",
        "Property",
        "Struct",
        "Trait",
    },
}

local function get_kind_filter(buf)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
    local ft = vim.bo[buf].filetype

    if kind_filter[ft] == false then
        return nil
    end

    if type(kind_filter[ft]) == "table" then
        return kind_filter[ft]
    end

    return kind_filter.default
end

return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "echasnovski/mini.icons",
            {
                "nvim-telescope/telescope-fzf-native.nvim",
                build = "make",
            },
        },
        config = function()
            local telescope = require("telescope")
            local actions = require("telescope.actions")

            telescope.setup({
                defaults = {
                    layout_strategy = "horizontal",
                    layout_config = {
                        horizontal = {
                            preview_width = 0.65,
                        },
                    },
                    preview_cutoff = 1,
                    mappings = {
                        i = {
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                        },
                    },
                    file_ignore_patterns = { "node_modules", ".git/" },
                    vimgrep_arguments = {
                        "rg",
                        "--color=never",
                        "--no-heading",
                        "--with-filename",
                        "--line-number",
                        "--column",
                        "--smart-case",
                        "--hidden",
                    },
                    preview = {
                        treesitter = true,
                    },
                },
                pickers = {
                    find_files = {
                        hidden = true,
                        follow = true,
                    },
                    buffers = {
                        sort_mru = true,
                        sort_lastused = true,
                    },
                },
            })

            telescope.load_extension("fzf")
        end,
        keys = {
            { "<leader>,",       "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", desc = "Switch Buffer" },

            { "<leader>fb",      "<cmd>Telescope buffers<cr>",                                  desc = "Buffers" },
            { "<leader>ff",      "<cmd>Telescope find_files<cr>",                               desc = "Files" },
            { "<leader><space>", "<cmd>Telescope find_files<cr>",                               desc = "Find Files" },
            { "<leader>fg",      "<cmd>Telescope git_files<cr>",                                desc = "Git Files" },

            { "<leader>sg",      "<cmd>Telescope live_grep<cr>",                                desc = "Grep" },
            { "<leader>sh",      "<cmd>Telescope help_tags<cr>",                                desc = "Help Pages" },
            { "<leader>sk",      "<cmd>Telescope keymaps<cr>",                                  desc = "Keymaps" },
            { "<leader>sm",      "<cmd>Telescope marks<cr>",                                    desc = "Marks" },
            { "<leader>sq",      "<cmd>Telescope quickfix<cr>",                                 desc = "Quickfix" },
            { "<leader>sR",      "<cmd>Telescope resume<cr>",                                   desc = "Resume" },

            {
                "<leader>ss",
                function()
                    local filters = get_kind_filter()
                    if filters then
                        require("telescope.builtin").lsp_document_symbols({ symbols = filters })
                    else
                        require("telescope.builtin").lsp_document_symbols()
                    end
                end,
                desc = "Document Symbols",
            },
            {
                "<leader>sS",
                function()
                    local filters = get_kind_filter()
                    if filters then
                        require("telescope.builtin").lsp_workspace_symbols({ symbols = filters })
                    else
                        require("telescope.builtin").lsp_workspace_symbols()
                    end
                end,
                desc = "Workspace Symbols",
            },
        },
    },

    {
        "neovim/nvim-lspconfig",
        opts = function()
            local builtin = require("telescope.builtin")

            vim.keymap.set("n", "gd", function()
                builtin.lsp_definitions({ reuse_win = true })
            end, { desc = "Goto Definition" })

            vim.keymap.set("n", "gr", function()
                builtin.lsp_references({ include_current_line = false })
            end, { desc = "References" })

            vim.keymap.set("n", "gI", function()
                builtin.lsp_implementations({ reuse_win = true })
            end, { desc = "Goto Implementation" })

            vim.keymap.set("n", "gy", function()
                builtin.lsp_type_definitions({ reuse_win = true })
            end, { desc = "Goto Type Definition" })
        end,
    },
}
