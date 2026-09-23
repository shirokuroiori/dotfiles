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

      -- カーソル行だけレンダリングを解除し、生の Markdown を編集できるようにする
      modes = { "n", "no", "c" },
      hybrid_modes = { "n" },
      linewise_hybrid_mode = true,
      edit_range = { 0, 0 },

      debounce = 25,
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

    -- markview は起動時の VimEnter/ColorScheme で見出しの色(MarkviewPaletteN)を
    -- @markup.heading.N.markdown から一度だけ計算してキャッシュする。だが計算する
    -- その瞬間はまだ nvim-treesitter 側でこのグループが各レベル別の色
    -- (@markup.heading.N) に解決されておらず、汎用の @markup.heading (pink) に
    -- フォールバックしてしまう。しかも markview は一度キャッシュした値を二度と
    -- 上書きしないため、見出しが全レベル pink に固定されたままになる。
    -- 一度キャッシュをクリアしてから再計算させることで正しい色に直す。
    local function refresh_heading_hl()
      for n = 1, 8 do
        for _, suffix in ipairs({ "", "Sign", "Fg", "Bg" }) do
          pcall(vim.api.nvim_set_hl, 0, "MarkviewPalette" .. n .. suffix, {})
        end
      end
      require("markview.highlights").setup()
    end

    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.schedule(refresh_heading_hl)
      end,
    })
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "voltwave",
      callback = function()
        vim.schedule(refresh_heading_hl)
      end,
    })
  end,
}
