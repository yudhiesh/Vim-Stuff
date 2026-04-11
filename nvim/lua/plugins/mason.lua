return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "hadolint",
        "gofumpt",
        "pyright",
        "prettier",
        "ruff",
        "rust-analyzer",
        "shellcheck",
        "shfmt",
        "stylua",
        "taplo",
        "tflint",
        "goimports",
      },
    },
  },
}
