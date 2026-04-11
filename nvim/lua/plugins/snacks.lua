return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          files = {
            hidden = true,
            ignored = true,
            exclude = { ".git", "target" },
          },
          grep = {
            hidden = true,
            ignored = true,
            exclude = { ".git", "target" },
          },
          explorer = {
            hidden = true,
            ignored = true,
            exclude = { ".git", "target" },
          },
        },
      },
    },
  },
}
