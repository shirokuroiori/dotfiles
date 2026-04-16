-- リーダーの設定
-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ECSキーの明示的な設定（意図しない動作を防ぐ）
vim.keymap.set('n', '<Esc>', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('i', '<Esc>', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('v', '<Esc>', '<Esc>', { noremap = true, silent = true })


-- クリップボード
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])

-- 現在行のLSP診断メッセージをクリップボードにコピー
vim.keymap.set('n', '<leader>dy', function()
  local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line('.') - 1 })
  if #diagnostics > 0 then
    local messages = {}
    for _, d in ipairs(diagnostics) do
      table.insert(messages, d.message)
    end
    vim.fn.setreg('+', table.concat(messages, '\n'))
    vim.notify('Diagnostic copied!', vim.log.levels.INFO)
  else
    vim.notify('No diagnostics on this line', vim.log.levels.WARN)
  end
end, { desc = 'Copy line diagnostics to clipboard' })

-- VSCodeやCursor環境の検出
local is_vscode = vim.g.vscode ~= nil
local is_cursor = vim.env.CURSOR ~= nil

-- Telescope のキーマップは plugins/telescope.lua の lazy keys で定義


-- よくわからないのでプラグイン設定のほうに書く
-- ウィンドウ移動用キー
-- vim.keymap.set("n", "<C-h>", require("smart-splits").move_cursor_left, { desc = "Move window left" })
-- vim.keymap.set("n", "<C-j>", require("smart-splits").move_cursor_down, { desc = "Move window down" })
-- vim.keymap.set("n", "<C-k>", require("smart-splits").move_cursor_up, { desc = "Move window up" })
-- vim.keymap.set("n", "<C-l>", require("smart-splits").move_cursor_right, { desc = "Move window right" })
-- リサイズ用キー
-- vim.keymap.set("n", "<M-h>", require("smart-splits").resize_left, { desc = "Resize left" })
-- vim.keymap.set("n", "<M-j>", require("smart-splits").resize_down, { desc = "Resize down" })
-- vim.keymap.set("n", "<M-k>", require("smart-splits").resize_up, { desc = "Resize up" })
-- vim.keymap.set("n", "<M-l>", require("smart-splits").resize_right, { desc = "Resize right" })
