-- lua/config/bigfile.lua
-- 大きいファイルを開いたときに重いプラグイン機能を無効化し、フリーズを防ぐ
local M = {}

M.size_limit = 1024 * 1024 -- 1MB

local function get_size(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return 0
  end
  local stats = (vim.uv or vim.loop).fs_stat(name)
  return stats and stats.size or 0
end

function M.is_bigfile(buf)
  buf = buf or 0
  return get_size(buf) > M.size_limit
end

vim.api.nvim_create_autocmd("BufReadPre", {
  group = vim.api.nvim_create_augroup("BigFileDetect", { clear = true }),
  callback = function(args)
    if not M.is_bigfile(args.buf) then
      return
    end
    vim.b[args.buf].bigfile = true

    vim.opt_local.swapfile = false
    vim.opt_local.foldmethod = "manual"
    vim.opt_local.undolevels = -1
    vim.opt_local.spell = false

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(args.buf) then
        return
      end
      pcall(function() require("colorizer").detach_from_buffer(args.buf) end)
      pcall(function() require("ibl").setup_buffer(args.buf, { enabled = false }) end)
      pcall(function() require("gitsigns").detach(args.buf) end)
    end)
  end,
})

return M
