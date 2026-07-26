-- lua/plugins/comment-context.lua
return {
  "JoosepAlviste/nvim-ts-context-commentstring",
  event = "VeryLazy",
  config = function()
    require("ts_context_commentstring").setup({
      enable_autocmd = false,
    })
  end,
}
