return {
  "rmagatti/auto-session",
  lazy = false,

  ---enables autocomplete for opts
  ---@module "auto-session"
  ---@type AutoSession.Config
  opts = {
    auto_save_enabled = true,
    auto_restore_enabled = true,
    -- true にすると「cwd用のセッションが無い時に、無関係な別プロジェクトの最後のセッション」を
    -- 復元してしまい、意図しないバッファが開いて「バグった」ように見える原因になりやすいので false
    auto_session_enable_last_session = false,
    session_lens = {
      picker = nil, -- Telescope が自動検出される
    },
  },
}
