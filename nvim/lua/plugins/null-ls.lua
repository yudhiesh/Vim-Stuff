return {
  {
    "jose-elias-alvarez/null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason.nvim" },
    opts = function()
      local nls = require("null-ls")
      return {
        sources = {
          nls.builtins.diagnostics.hadolint,
          nls.builtins.diagnostics.markdownlint,
          nls.builtins.diagnostics.shellcheck,
          nls.builtins.formatting.gofmt,
          nls.builtins.formatting.prettier,
          nls.builtins.formatting.shfmt,
          nls.builtins.formatting.stylua,
          nls.builtins.formatting.terraform_fmt,
          nls.builtins.formatting.black,
          nls.builtins.formatting.isort,
          nls.builtins.diagnostics.flake8,
        },
      }
    end,
  },
}
