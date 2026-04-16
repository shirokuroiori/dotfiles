vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

-- VSCodeやCursor環境の検出
local is_vscode          = vim.g.vscode ~= nil
local is_cursor          = vim.env.CURSOR ~= nil

-- VSCodeやCursor環境でない場合のみプラグインを読み込み
if not is_vscode and not is_cursor then
  require("config.lazy")
end

require("config.options")
require("config.keymaps")
