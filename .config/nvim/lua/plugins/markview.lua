-- render-markdown.nvim からの乗り換え。table/checkbox/callout に加えて
-- HTML やLaTeXのレンダリングにも対応し、より高機能。
return {
  "OXY2DEV/markview.nvim",
  lazy = false, -- 内部で遅延読み込みを最適化しているため lazy 指定はしない
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-mini/mini.icons",
  },
  opts = {
    preview = {
      filetypes = { "markdown", "quarto", "rmd", "codecompanion" },
      icon_provider = "mini",
    },
    markdown_inline = {
      checkboxes = {
        -- render-markdown.nvim で使っていたアイコンに合わせる
        -- scope_hl はタスク本文の文字色を変える設定なので false で無効化する
        checked = { text = "󰱒", hl = "MarkviewCheckboxIconChecked", scope_hl = false },
        unchecked = { text = "󰄱", hl = "MarkviewCheckboxIconUnchecked", scope_hl = false },
      },
    },
    markdown = {
      list_items = {
        -- add_padding が第一階層にも shift_width 分の余白を一律で入れてしまうため無効化
        -- (ネスト自体はソースのインデント量でそのまま表現される)
        marker_minus = { add_padding = false },
        marker_plus = { add_padding = false },
        marker_star = { add_padding = false },
        marker_dot = { add_padding = false },
        marker_parenthesis = { add_padding = false },
      },
    },
  },
  config = function(_, opts)
    -- voltwave のパレット上の Markview*Fg リンクはテーマ側で意味が入れ替わっているため、
    -- アイコン専用のハイライトを voltwave のパレット色から直接定義する
    local function set_checkbox_hl()
      local palette = require("voltwave.palette")
      vim.api.nvim_set_hl(0, "MarkviewCheckboxIconChecked", { fg = palette.green })
      vim.api.nvim_set_hl(0, "MarkviewCheckboxIconUnchecked", { fg = palette.fg_dim })
    end
    set_checkbox_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "voltwave",
      callback = set_checkbox_hl,
    })

    require("markview").setup(opts)
  end,
}
