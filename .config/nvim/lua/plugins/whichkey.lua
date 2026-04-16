return {
  {
    "folke/which-key.nvim",
    config = function()
      require("which-key").setup({
        win = {
          border = "rounded",
        },
      })
    end,
  }
}
