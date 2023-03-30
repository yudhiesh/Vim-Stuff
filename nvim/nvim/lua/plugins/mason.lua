return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "hadolint",
        "stylua",
        "shellcheck",
        "shfmt",
        "flake8",
        "prettier",
        "tflint",
        "black",
        "isort",
      },
    },
  },
}
