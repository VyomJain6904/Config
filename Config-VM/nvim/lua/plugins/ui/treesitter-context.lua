return {
    "nvim-treesitter/nvim-treesitter-context",
    event = {"BufReadPost", "BufWritePost", "BufNewFile"},

    opts = {
        mode = "cursor",
        max_lines = 3
    },

    config = function(_, opts)
        local ctx = require("treesitter-context")
        ctx.setup(opts)

        vim.keymap.set("n", "<leader>ut", function()
            ctx.toggle()
        end, {
            noremap = true,
            silent = true,
            desc = "Toggle Treesitter Context"
        })
    end
}
