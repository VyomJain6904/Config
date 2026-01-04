return { ---------------------------------------------------------------------------
-- TREESITTER: Rust
---------------------------------------------------------------------------
{
    "nvim-treesitter/nvim-treesitter",
    opts = {
        ensure_installed = {"rust", "toml"}
    }
}, ---------------------------------------------------------------------------
-- LSP: rust-analyzer
---------------------------------------------------------------------------
{
    "neovim/nvim-lspconfig",
    opts = {
        servers = {
            rust_analyzer = {
                settings = {
                    ["rust-analyzer"] = {
                        cargo = {
                            allFeatures = true,
                            loadOutDirsFromCheck = true,
                            buildScripts = {
                                enable = true
                            }
                        },
                        checkOnSave = {
                            command = "clippy"
                        },
                        procMacro = {
                            enable = true
                        },
                        diagnostics = {
                            enable = true,
                            experimental = true
                        },
                        inlayHints = {
                            bindingModeHints = {
                                enable = true
                            },
                            chainingHints = {
                                enable = true
                            },
                            closingBraceHints = {
                                minLines = 1
                            },
                            closureReturnTypeHints = {
                                enable = "with_block"
                            },
                            lifetimeElisionHints = {
                                enable = "always"
                            },
                            expressionAdjustmentHints = {
                                enable = true
                            },
                            parameterHints = {
                                enable = true
                            },
                            reborrowHints = {
                                enable = "always"
                            }
                        }
                    }
                }
            }
        },

        -----------------------------------------------------------------------
        -- rust-analyzer
        -----------------------------------------------------------------------
        setup = {
            rust_analyzer = function(_, opts)
                Utils.lsp.on_attach(function(client, _)
                    if not client.server_capabilities.semanticTokensProvider then
                        local semantic = client.config.capabilities.textDocument.semanticTokens
                        client.server_capabilities.semanticTokensProvider = {
                            full = true,
                            legend = {
                                tokenTypes = semantic.tokenTypes,
                                tokenModifiers = semantic.tokenModifiers
                            },
                            range = true
                        }
                    end
                end, "rust_analyzer")
            end
        }
    }
}, ---------------------------------------------------------------------------
-- NEOTEST: Rust
---------------------------------------------------------------------------
{"rouge8/neotest-rust"}}
