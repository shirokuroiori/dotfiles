return {
  -- $ brew tap daipeihust/tap && brew install im-select
  -- im-select
  "keaising/im-select.nvim",
  config = function()
    require("im_select").setup({
      default_im_select = "com.apple.keylayout.US",
      default_command = "im-select",
      set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave" },
    })
  end,
}
