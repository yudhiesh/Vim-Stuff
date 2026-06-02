return {
  "stevearc/conform.nvim",
  opts = {
    notify_on_error = false,
    formatters_by_ft = {
      cuda = { "clang_format" },
      lua = { "stylua" },
      python = { "ruff" },
      rust = { "rustfmt", lsp_format = "fallback" },
      javascript = { "prettierd", "prettier", stop_after_first = true },
      go = { "goimports", "gofumpt" },
    },
  },
}
