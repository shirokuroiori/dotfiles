local options = {
  number = true, -- 行番号を表示
  relativenumber = true,
  wrap = false,  -- 画面の右端で改行しない
  expandtab = true,
  shiftwidth = 2,
  tabstop = 2,
  termguicolors = true,
  winblend = 0,
  pumblend = 0,
  cursorline = true,
  cursorlineopt = "number",
  signcolumn = "yes",
  --  clipboard = "unnamedplus",
  -- sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions",
}

for k, v in pairs(options) do
  vim.opt[k] = v
end


vim.diagnostic.config({
  signs = {
    -- 表示する診断サインを設定
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "󰋼",
      [vim.diagnostic.severity.HINT] = "󰌵",
    },
    linehl = nil, -- 行のハイライト
    numhl = nil,  -- 行番号のハイライト
  },
})


local filetype_tabstop = {
  lua = 2,
  markdown = 2,
  python = 4
} -- filetype毎のインデント幅
local usrftcfg = vim.api.nvim_create_augroup("UserFileTypeConfig", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = usrftcfg,
  callback = function(args)
    local ftts = filetype_tabstop[args.match]
    if ftts then
      vim.bo.expandtab = true
      vim.bo.tabstop = ftts
      vim.bo.shiftwidth = ftts
    end
  end
})
