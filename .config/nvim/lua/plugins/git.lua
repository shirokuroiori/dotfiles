-- lua/plugins/git.lua
return {
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "┃" }, -- 実線（追加）
          change = { text = "┋" }, -- 点線（修正）
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
        -- word_diff = true,
        sign_priority = 20,
        -- signcolumn = true,
        -- numhl = false,
        -- linehl = false,
        -- word_diff = false,
        -- watch_gitdir = {
        --   interval = 1000,
        --   follow_files = true,
        -- },
        -- attach_to_untracked = true,
        -- current_line_blame = false,
        -- current_line_blame_opts = {
        --   virt_text = true,
        --   virt_text_pos = 'eol',
        --   delay = 1000,
        -- },
        -- update_debounce = 100,
        -- status_formatter = nil,
        -- preview_config = {
        --   border = 'single',
        --   style = 'minimal',
        --   relative = 'cursor',
        --   row = 0,
        --   col = 1,
        -- },
      })

      -- gitsignsの色設定
      -- vim.cmd [[
      --   " 追加された行のサイン
      --   highlight GitSignsAdd    guibg=NONE guifg=#5eff6c
      --   " 変更された行のサイン
      --   highlight GitSignsChange guibg=NONE guifg=#5ea1ff
      --   " 削除された行のサイン
      --   highlight GitSignsDelete guibg=NONE guifg=#dc3545
      -- ]]
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "Lazygit",
      "LazygitConfig",
      "LazygitCurrentFile",
      "LazygitFilter",
      "LazygitFilterCurrentFile",
    },
    keys = {
      { "<leader>G", "<cmd>LazyGit<cr>", desc = "LazyGit" }
    }
  },
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>dv", "<cmd>DiffviewOpen<cr>",  desc = "Diffview: Open" },
      { "<leader>dc", "<cmd>DiffviewClose<cr>", desc = "Diffview: Close" },
    },
    opts = {
      -- enhanced_diff_hl = true,
    },
    config = function(_, opts)
      vim.opt.fillchars:append({ diff = " " })
      require("diffview").setup(opts)
    end,
  },
}
