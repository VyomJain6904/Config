return {
    "glepnir/dashboard-nvim",
    event = "VimEnter",
    config = function()
        local db = require("dashboard")

        local date_str = os.date("  %A, %d %B %Y")

        db.setup({
            theme = "doom",
            config = {
                header = {"",
                          "⣿⢹⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⣿⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⢠⣿⣿⣿⣿⣿⣿⣿⢸⣿",
                          "⣿⢸⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⣿⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡈⣿⣿⣿⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿⡇⣼⣿",
                          "⣿⡄⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⢃⣾⣿⣿⣿⣿⣿⣿⣿⣿⠿⠿⠿⠿⠿⠿⠿⠿⢿⣿⣿⣿⣿⣷⡌⢿⣿⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿⢡⣿⣿",
                          "⣿⡇⢻⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⢃⣾⣿⣿⣿⠿⠛⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠙⠻⢿⣿⣿⣥⢸⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⡏⣸⣿⣿",
                          "⣿⣷⢸⣿⣿⣿⣿⣿⡇⢿⣿⣿⢋⣾⡿⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣤⣤⣈⠀⠹⣿⣦⠸⣿⣿⢸⣿⣿⣿⣿⣿⢁⣿⣿⣿",
                          "⣿⣿⡄⣿⣿⣿⣿⣿⣇⢸⣿⠏⠼⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⣿⣿⣿⣿⣿⣿⣿⣦⣌⠻⣆⢻⡏⢸⣿⣿⣿⣿⠇⣸⣿⣿⣿",
                          "⣿⣿⣧⢸⣿⣿⣿⣿⣿⢸⡿⠀⠀⠀⢀⣠⣤⣴⣶⣶⣶⣶⣤⣄⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⢿⡇⣼⣿⣿⣿⡿⢰⣿⣿⣿⣿",
                          "⣿⣿⣿⡄⢿⣿⣿⣿⣿⢸⠇⠀⣠⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡌⢰⣿⣿⣿⣿⠇⣾⣿⣿⣿⣿",
                          "⣿⣿⣿⣧⠸⣿⣿⣿⣿⡆⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢁⣿⣿⣿⣿⡿⢸⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣇⢻⣿⣿⣿⣷⡘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⢸⣿⣿⣿⣿⠇⣾⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⡈⣿⣿⣿⣿⣧⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⣛⣛⣛⣩⣴⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⣧⢹⣿⣿⣿⣿⣇⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿⣿⣿⠟⢁⣌⣙⣛⠛⣛⣋⣭⣽⣿⣿⡇⣼⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⣿⡈⣿⣿⣿⣿⣿⡄⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⣿⣿⣿⣿⣿⣿⣿⣯⡀⠒⠲⠮⣭⣙⣋⣩⡭⢴⣿⠟⣰⣿⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⣿⠃⢻⣿⣿⢣⡙⣿⣄⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⣿⣿⣿⣿⡿⠛⣿⣿⣿⣿⣦⣄⡀⠭⠭⠥⠖⣋⡅⣾⣿⣿⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⡏⣸⠈⣿⣧⡘⢷⣌⠻⣷⣌⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢃⣧⡘⠿⢛⣉⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⣇⣀⠠⠹⣌⠻⣦⡙⢷⣄⠙⢷⣦⠙⣿⣿⣿⣿⣿⣿⡿⢃⣾⠏⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠅⣿⣿⣿⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⣿⣿⡇⣧⡙⣷⡈⠻⣦⡙⠷⣄⠨⣡⣼⣿⣿⡿⠟⣋⣴⡄⠏⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⣿⣿⡇⢻⣿⣌⢻⣄⢠⡙⠷⣌⠻⢦⢹⣿⣿⣿⣿⣿⣿⣷⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿",
                          "⣿⣿⣿⣿⣿⣿⣿⣿⠸⣿⣿⣧⡙⣦⠹⣷⣬⡑⠆⢸⣿⣿⣿⣿⣿⣿⣿⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿",
                          "", date_str, ""},
                center = {{
                    icon = " ",
                    icon_hl = "Title",
                    desc = "Find File",
                    desc_hl = "String",
                    key = "f",
                    keymap = "SPC f f",
                    key_hl = "Number",
                    action = function()
                        require("telescope.builtin").find_files()
                    end
                }, {
                    icon = " ",
                    desc = "Recent Files",
                    key = "r",
                    keymap = "SPC f r",
                    key_hl = "Number",
                    action = function()
                        require("telescope.builtin").oldfiles()
                    end
                }, {
                    icon = " ",
                    desc = "Edit Config",
                    key = "c",
                    keymap = "SPC f c",
                    key_hl = "Number",
                    action = "edit " .. vim.fn.expand("~/.config/nvim/init.lua")
                }, {
                    icon = " ",
                    desc = "Find Dotfiles",
                    key = "d",
                    keymap = "SPC f d",
                    key_hl = "Number",
                    action = function()
                        require("telescope.builtin").find_files({
                            cwd = vim.fn.expand("~/.dotfiles")
                        })
                    end
                }, {
                    icon = "󰩈 ",
                    desc = "Quit Neovim",
                    key = "q",
                    keymap = "SPC q",
                    key_hl = "Number",
                    action = "qa"
                }},
                footer = {""}
            }
        })
    end
}
