---@param config {type?:string, args?:string[]|fun():string[]?}
local function get_args(config)
    local args = type(config.args) == "function" and (config.args() or {}) or config.args or {} ---@as string[] | string

    local args_str = type(args) == "table" and table.concat(args, " ") or args ---@as string

    config = vim.deepcopy(config)
    ---@cast args string[]

    config.args = function()
        local new_args = vim.fn.expand(vim.fn.input("Run with args: ", args_str)) ---@as string
        if config.type and config.type == "java" then
            ---@diagnostic disable-next-line: return-type-mismatch
            return new_args
        end
        return require("dap.utils").splitstr(new_args)
    end

    return config
end

return { ---------------------------------------------------------------------------
-- CORE DAP
---------------------------------------------------------------------------
{
    "mfussenegger/nvim-dap",
    recommended = true,
    desc = "Debugging support. Requires language-specific adapters (see lang extras)",

    dependencies = {"rcarriga/nvim-dap-ui", {
        "theHamsta/nvim-dap-virtual-text",
        opts = {
            virt_text_win_col = 80
        }
    }},

    keys = {{
        "<leader>da",
        function()
            require("dap").continue({
                before = get_args
            })
        end,
        desc = "Run with Args"
    }, {
        "<leader>db",
        function()
            require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint"
    }, {
        "<leader>dB",
        function()
            require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end,
        desc = "Conditional Breakpoint"
    }, {
        "<leader>dC",
        function()
            require("dap").run_to_cursor()
        end,
        desc = "Run to Cursor"
    }, {
        "<leader>dc",
        function()
            require("dap").continue()
        end,
        desc = "Continue"
    }, {
        "<leader>de",
        function()
            require("dapui").eval()
        end,
        desc = "Evaluate"
    }, {
        "<leader>dg",
        function()
            require("dap").goto_()
        end,
        desc = "Go to Line (No Execute)"
    }, {
        "<leader>di",
        function()
            require("dap").step_into()
        end,
        desc = "Step Into"
    }, {
        "<leader>dj",
        function()
            require("dap").down()
        end,
        desc = "Down Stack"
    }, {
        "<leader>dk",
        function()
            require("dap").up()
        end,
        desc = "Up Stack"
    }, {
        "<leader>dl",
        function()
            require("dap").run_last()
        end,
        desc = "Run Last"
    }, {
        "<leader>do",
        function()
            require("dap").step_over()
        end,
        desc = "Step Over"
    }, {
        "<leader>dO",
        function()
            require("dap").step_out()
        end,
        desc = "Step Out"
    }, {
        "<leader>dP",
        function()
            require("dap").pause()
        end,
        desc = "Pause"
    }, {
        "<leader>dr",
        function()
            require("dap").repl.toggle()
        end,
        desc = "Toggle REPL"
    }, {
        "<leader>ds",
        function()
            require("dap").session()
        end,
        desc = "Session"
    }, {
        "<leader>dt",
        function()
            require("dap").terminate()
        end,
        desc = "Terminate"
    }, {
        "<leader>du",
        function()
            require("dapui").toggle()
        end,
        desc = "DAP UI"
    }, {
        "<leader>dw",
        function()
            require("dap.ui.widgets").hover()
        end,
        desc = "DAP Widgets"
    }},

    config = function()
        -- Load mason adapters AFTER DAP config
        local mason_dap = require("lazy.core.config").spec.plugins["mason-nvim-dap.nvim"]
        local Plugin = require("lazy.core.plugin")
        local opts = Plugin.values(mason_dap, "opts", false)
        require("mason-nvim-dap").setup(opts)

        -- Highlight current line when stopped
        vim.api.nvim_set_hl(0, "DapStoppedLine", {
            default = true,
            link = "Visual"
        })

        -- Custom DAP signs
        local signs = {
            Stopped = {"󰁕 ", "DiagnosticWarn", "DapStoppedLine"},
            Breakpoint = " ",
            BreakpointCondition = " ",
            BreakpointRejected = {" ", "DiagnosticError"},
            LogPoint = ".>"
        }

        for name, sign in pairs(signs) do
            sign = type(sign) == "table" and sign or {sign}
            vim.fn.sign_define("Dap" .. name, {
                text = sign[1],
                texthl = sign[2] or "DiagnosticInfo",
                linehl = sign[3],
                numhl = sign[3]
            })
        end

        -- VSCode launch.json support
        local vscode = require("dap.ext.vscode")
        local json = require("plenary.json")

        vscode.json_decode = function(str)
            return vim.json.decode(json.json_strip_comments(str))
        end

        -- Overseer integration
        require("overseer").enable_dap()
    end
}, ---------------------------------------------------------------------------
-- DAP UI
---------------------------------------------------------------------------
{
    "rcarriga/nvim-dap-ui",
    dependencies = {"nvim-neotest/nvim-nio"},

    keys = {{
        "<leader>du",
        function()
            require("dapui").toggle()
        end,
        desc = "DAP UI"
    }, {
        "<leader>de",
        function()
            require("dapui").eval()
        end,
        mode = {"n", "v"},
        desc = "Evaluate Expression"
    }},

    opts = {
        controls = {
            enabled = false
        }
    },

    config = function(_, opts)
        local dap = require("dap")
        local dapui = require("dapui")
        dapui.setup(opts)

        dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close()
        end
    end
}, ---------------------------------------------------------------------------
-- Mason DAP Integration
---------------------------------------------------------------------------
{
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = "mason.nvim",
    cmd = {"DapInstall", "DapUninstall"},

    opts = {
        automatic_installation = true,
        handlers = {},
        ensure_installed = {}
    }
}}
