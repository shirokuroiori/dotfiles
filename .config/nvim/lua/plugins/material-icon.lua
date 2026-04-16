-- nvim-web-devicons と同じモジュール名を提供。stock devicons より先に RTP に載せないと
-- neo-tree / lualine などでアイコンが時々空になる。
return {
  "DaikyXendo/nvim-material-icon",
  lazy = false,
  priority = 10000,
  config = function()
    local function setup_devicons()
      require("nvim-web-devicons").setup({
        default = true,
        color_icons = true,
      })
    end
    setup_devicons()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("material-icon-hl", { clear = true }),
      callback = setup_devicons,
    })
  end,
}
