---@diagnostic disable: undefined-global
return {
  "tetsuya28/memo.nvim",
  keys = {
    { "<leader>mn", mode = "n", desc = "Open new memo" },
  },
  config = function()
    require("memo").setup({
      save_dir = vim.fn.expand("$HOME/memos"),
      width = 100,
      height = 40,
    })
  end,
}
