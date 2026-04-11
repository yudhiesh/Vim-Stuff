return {
  {
    "mrcjkb/rustaceanvim",
    opts = function(_, opts)
      opts = opts or {}
      opts.server = opts.server or {}
      opts.server.default_settings = opts.server.default_settings or {}

      opts.server.default_settings["rust-analyzer"] =
        vim.tbl_deep_extend("force", opts.server.default_settings["rust-analyzer"] or {}, {
          cargo = {
            allFeatures = true,
            loadOutDirsFromCheck = true,
            buildScripts = {
              enable = true,
            },
          },
          checkOnSave = true,
          check = {
            command = "clippy",
          },
          procMacro = {
            enable = true,
          },
          inlayHints = {
            bindingModeHints = {
              enable = false,
            },
            closingBraceHints = {
              enable = true,
              minLines = 10,
            },
            closureReturnTypeHints = {
              enable = "with_block",
            },
            discriminantHints = {
              enable = "fieldless",
            },
            lifetimeElisionHints = {
              enable = "skip_trivial",
              useParameterNames = true,
            },
            typeHints = {
              hideClosureInitialization = false,
              hideNamedConstructor = false,
            },
          },
        })
    end,
  },
}
