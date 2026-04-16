return {
  -- {
  --   "DaikyXendo/nvim-material-icon",
  --   lazy = false,
  --   config = function()
  --     require("nvim-web-devicons").setup({
  --       -- override や color_icons など
  --     })
  --   end,
  -- },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    -- README 推奨: lazy=true は内部遅延と二重になり初回オープンが空になることがある
    lazy = false,
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", mode = "n", desc = "Neotree toggle" }
    },
    opts = {
      -- options go here
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = true,
        }
      },
      default_component_configs = {
        -- VS Code に近づける: 追跡外/無視は「名前」だけ Git 色、アイコンは devicon の色を維持
        icon = {
          use_filtered_colors = false,
        },
        name = {
          use_git_status_colors = true,
        },
        git_status = {
          symbols = {
            -- Change type
            added = "", -- 新しく作ったファイルを git add した状態 = 新規ファイルがステージ済み
            -- added = " ", -- 新しく作ったファイルを git add した状態 = 新規ファイルがステージ済み
            -- added = "l", -- 新しく作ったファイルを git add した状態 = 新規ファイルがステージ済み
            modified = "", -- 既存のファイルを変更したけど、まだ git add していない状態 = 変更があるけど未ステージ
            -- modified = "󱇨 ", -- 既存のファイルを変更したけど、まだ git add していない状態 = 変更があるけど未ステージ
            deleted = "󰮘", -- ファイルを削除したことが検出された状態 this can only be used in the git_status source
            renamed = "󰁕", -- ファイル名を変更したときに Git がリネームを検出した状態 this can only be used in the git_status source

            -- Status type
            untracked = " ", -- Git 管理下にないファイル = git status で ?? filename と出るやつ（まだ一度も git add していない）
            ignored = "", -- .gitignore に書かれていて、Git が管理しないようにしているファイル
            unstaged = "󱇨 ", -- 変更はあるけど git add していない（ステージに載ってない）git status で 赤色で出る部分
            staged = "󱎯 ", -- git add 済みで、次のコミットに含まれる予定の変更 git status で 緑色で出る部分
            conflict = "⇕", -- 競合
          },
        },
      },
      -- function()
      --   vim.api.nvim_set_hl(0, "NeoTreeGitUntracked", { fg = "#00ffff" })
      -- end
    },
    config = function(_, opts)
      require('neo-tree').setup(opts)
      vim.api.nvim_set_hl(0, "NeoTreeGitUntracked", { fg = "#00fc65" })
      -- vim.api.nvim_set_hl(0, "NeoTreeGitUnstaged", { fg = "#00ffff" })
      -- vim.api.nvim_set_hl(0, "NeoTreeGitModified", { fg = "#00ffff" })
    end
  }
}
