return {
  {
    "mrcjkb/rustaceanvim",
    opts = function(_, opts)
      opts.server = opts.server or {}
      opts.server.default_settings = vim.tbl_deep_extend("force", opts.server.default_settings or {}, {
        ["rust-analyzer"] = {
          check = {
            command = "clippy",
            allTargets = true,
            features = "all",
          },
        },
      })
    end,
  },
}
