return {
    "mikavilpas/yazi.nvim",
    dependencies = {"akinsho/toggleterm.nvim"},
    lazy = false,

    keys = {{
        "<leader>yy",
        "<cmd>Yazi<cr>",
        desc = "Yazi (cwd)"
    }, {
        "<leader>yf",
        function()
            require("yazi").yazi(nil, vim.fn.expand("%:p"))
        end,
        desc = "Yazi (file dir)"
    }},

    config = function()
        require("yazi").setup({
            floating_window = true,
            floating_window_opts = {
                border = "rounded",
                width = 0.90,
                height = 0.85,
                row = 0.5,
                col = 0.5
            },
            backdrop = 70
        })
        vim.keymap.set("t", "<Esc>", [[<C-\><C-n>:close<CR>]], {
            silent = true
        })
    end
}
