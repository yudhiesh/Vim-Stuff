return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "hadolint",
        "stylua",
        "shellcheck",
        "shfmt",
        "prettier",
        "tflint",
        "ruff",
        "rust-analyzer",
        "goimports",
        "gofumpt",
        "ruff",
        "pyright",
      },
    },
  },
}
