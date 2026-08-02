vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Use Pyrefly for Python type checking; Ruff remains enabled by LazyVim.
vim.g.lazyvim_python_lsp = "pyrefly"

require("config.options")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
