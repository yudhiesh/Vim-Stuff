return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        terraformls = { enabled = false },
        tofu_ls = {},
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        terraform = { "tofu_fmt" },
        tf = { "tofu_fmt" },
        opentofu = { "tofu_fmt" },
        ["terraform-vars"] = { "tofu_fmt" },
        ["opentofu-vars"] = { "tofu_fmt" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        terraform = { "tofu" },
        tf = { "tofu" },
        opentofu = { "tofu" },
      },
    },
  },
}
