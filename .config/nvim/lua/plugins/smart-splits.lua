return {
  "mrjones2014/smart-splits.nvim",
  event = "VeryLazy", -- 遅延読み込みのタイミング
  opts = {
    ignored_filetypes = { "nofile", "quickfix", "qf", "prompt" },
    ignored_buftypes = { "nofile" },
    default_amount = 2,
    -- at_edge = "wrap", -- 端から反対側に移動
    -- weztermとの互換性向上
    resize_mode = {
      silent = true,
      hooks = {
        on_enter = function()
          vim.notify("Entering resize mode", vim.log.levels.INFO)
        end,
        on_leave = function()
          vim.notify("Exiting resize mode", vim.log.levels.INFO)
        end,
      },
    },
    -- マルチプレクサ統合設定
    multiplexer_integration = "wezterm", -- weztermを使用
    at_edge = "stop",                    -- 端に到達したら停止（マルチプレクサに移動しない）
  },
  config = function(_, opts)
    local smart_splits = require("smart-splits")
    smart_splits.setup(opts)

    -- ウィンドウ間移動（Ctrl + hjkl）
    vim.keymap.set("n", "<C-h>", function()
      smart_splits.move_cursor_left()
    end, { desc = "Move to left window" })
    vim.keymap.set("n", "<C-j>", function()
      smart_splits.move_cursor_down()
    end, { desc = "Move to down window" })
    vim.keymap.set("n", "<C-k>", function()
      smart_splits.move_cursor_up()
    end, { desc = "Move to up window" })
    vim.keymap.set("n", "<C-l>", function()
      smart_splits.move_cursor_right()
    end, { desc = "Move to right window" })

    -- リサイズ（Alt/Meta + hjkl）
    vim.keymap.set("n", "<M-h>", function()
      smart_splits.resize_left()
    end, { desc = "Resize split left" })
    vim.keymap.set("n", "<M-j>", function()
      smart_splits.resize_down()
    end, { desc = "Resize split down" })
    vim.keymap.set("n", "<M-k>", function()
      smart_splits.resize_up()
    end, { desc = "Resize split up" })
    vim.keymap.set("n", "<M-l>", function()
      smart_splits.resize_right()
    end, { desc = "Resize split right" })

    -- リサイズモード（標準の <C-w> は潰さない）
    vim.keymap.set("n", "<leader>wr", function()
      smart_splits.start_resize_mode()
    end, { desc = "Start resize mode" })

    -- マルチプレクサ統合キーバインド（Shift + hjkl）
    -- vim.keymap.set("n", "<S-h>", function()
    --   smart_splits.move_cursor_left()
    -- end, { desc = "Move to left (including multiplexer)" })
    -- vim.keymap.set("n", "<S-j>", function()
    --   smart_splits.move_cursor_down()
    -- end, { desc = "Move to down (including multiplexer)" })
    -- vim.keymap.set("n", "<S-k>", function()
    --   smart_splits.move_cursor_up()
    -- end, { desc = "Move to up (including multiplexer)" })
    -- vim.keymap.set("n", "<S-l>", function()
    --   smart_splits.move_cursor_right()
    -- end, { desc = "Move to right (including multiplexer)" })
  end,
}
