return {
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "python", "lua", "vim", "query", "javascript", "typescript", "vue", "tsx" },
        ignore_install = {},
        modules = {},
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            node_decremental = "<bs>",
            scope_incremental = false,
          },
        },
        textobjects = {
          select = {
            enable = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner"
            },
          },
          move = {
            enable = true,
            goto_next_start = {
              ["]f"] = "@function.outer",
              ["]c"] = "@class.outer"
            },
            goto_previous_start = {
              ["[f"] = "@function.outer",
              ["[c"] = "@class.outer"
            },
          },
        },
      })

      -- Neovim 0.12 + markdown インジェクション: 一部キャプチャで get_node_text が落ちる（range nil）。
      -- Lspsaga hover は vim.treesitter.start + conceal に依存するため、nofile の highlight 切りではなく
      -- nvim-treesitter の directive を pcall 付きで上書きする。
      do
        local ts_query = require("vim.treesitter.query")
        local info_string_aliases = {
          ex = "elixir",
          pl = "perl",
          sh = "bash",
          uxn = "uxntal",
          ts = "typescript",
        }
        local function lang_from_markdown_info_string(s)
          local m = vim.filetype.match({ filename = "a." .. s })
          return m or info_string_aliases[s] or s
        end
        local reg_opts = { force = true, all = false }
        ts_query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
          local cap = pred[2]
          local node = match[cap]
          if not node then
            return
          end
          local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
          if not ok or type(text) ~= "string" or text == "" then
            return
          end
          metadata["injection.language"] = lang_from_markdown_info_string(text:lower())
        end, reg_opts)
      end
    end,
  },
}
