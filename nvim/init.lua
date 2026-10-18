vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Make Mason-managed LSPs, formatters, linters, debuggers, and the
-- Treesitter CLI available to every Neovim subprocess from startup.
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if not vim.env.PATH:find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
end

-- Use Pyrefly for Python type checking; Ruff remains enabled by LazyVim.
vim.g.lazyvim_python_lsp = "pyrefly"

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
