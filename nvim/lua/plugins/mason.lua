return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      for _, tool in ipairs({
        "hadolint",
        "stylua",
        "shellcheck",
        "shfmt",
        "prettier",
        "tofu-ls",
      }) do
        if not vim.tbl_contains(opts.ensure_installed, tool) then
          table.insert(opts.ensure_installed, tool)
        end
      end
    end,
  },
}
