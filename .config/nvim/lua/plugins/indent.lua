-- lua/plugins/indent.lua
local excluded_filetypes = {
  "help",
  "alpha",
  "dashboard",
  "neo-tree",
  "Trouble",
  "lazy",
  "mason",
  "notify",
  "toggleterm",
  "lazyterm",
}

return {
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local rainbow = require("rainbow-delimiters")

      ---@param bufnr integer
      ---@return rainbow_delimiters.strategy | nil
      local function safe_strategy(bufnr)
        if vim.b[bufnr].bigfile then
          return nil
        end
        local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
        if not ok or not parser then
          return nil
        end
        return rainbow.strategy["global"]
      end

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = safe_strategy,
        },
        query = {
          [""] = "rainbow-delimiters",
          ["tsx"] = "rainbow-parens",            -- JSXタグを除外し括弧のみ
          ["javascript"] = "rainbow-delimiters", -- Reactタグなし（デフォルト維持）
          ["vue"] = "rainbow-delimiters-parens", -- HTMLタグを除外し{{ }}のみ
        },
        blacklist = excluded_filetypes,
      }
    end,
  },
  {
    {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      event = { "BufReadPost", "BufNewFile" },
      dependencies = { "HiPhish/rainbow-delimiters.nvim" },
      config = function()
        require("ibl").setup({
          indent = {
            char = "▏",
            tab_char = "│",
          },
          scope = {
            enabled = true,
            show_start = true,
            show_end = true,        -- スコープの最後の閉じ括弧位置にライン表示するか
            highlight = 'IblScope', -- 既存の設定を維持
          },
          exclude = {
            filetypes = excluded_filetypes,
          },
        })
      end,
    },
  }
}
