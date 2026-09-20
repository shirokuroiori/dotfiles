
# backup configs
backup_dir="$HOME/.backup/$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"

[ -e "$HOME/.config/nvim" ] && { mv "$HOME/.config/nvim" "$backup_dir/nvim.bak" || exit 1; }
[ -e "$HOME/.config/wezterm" ] && { mv "$HOME/.config/wezterm" "$backup_dir/wezterm.bak" || exit 1; }
[ -e "$HOME/.config/starship.toml" ] && { mv "$HOME/.config/starship.toml" "$backup_dir/starship.toml.bak" || exit 1; }
mkdir -p "$backup_dir/lazygit"
[ -e "$HOME/Library/Application Support/lazygit/config.yml" ] && { mv "$HOME/Library/Application Support/lazygit/config.yml" "$backup_dir/lazygit/config.yml.bak" || exit 1; }
[ -e "$HOME/.claude/settings.json" ] && { mv "$HOME/.claude/settings.json" "$backup_dir/claude-settings.json.bak" || exit 1; }
[ -e "$HOME/.claude/statusline-command.sh" ] && { mv "$HOME/.claude/statusline-command.sh" "$backup_dir/claude-statusline-command.sh.bak" || exit 1; }
[ -e "$HOME/.claude/deny-push-hook.sh" ] && { mv "$HOME/.claude/deny-push-hook.sh" "$backup_dir/claude-deny-push-hook.sh.bak" || exit 1; }
[ -e "$HOME/.claude/commands/shortcuts.md" ] && { mv "$HOME/.claude/commands/shortcuts.md" "$backup_dir/shortcuts.md.bak" || exit 1; }
[ -e "$HOME/.copilot/hooks/wezterm-notify.json" ] && { mv "$HOME/.copilot/hooks/wezterm-notify.json" "$backup_dir/copilot-wezterm-notify.json.bak" || exit 1; }
[ -e "$HOME/.local/bin/wezterm-agents" ] && { mv "$HOME/.local/bin/wezterm-agents" "$backup_dir/wezterm-agents.bak" || exit 1; }
# 旧 bash 版の hook。Rust 側の `wezterm-agents hook` サブコマンドに移したので
# 張り直さない（退避だけして掃除する）。
[ -e "$HOME/.claude/hooks/wezterm-notify.sh" ] && { mv "$HOME/.claude/hooks/wezterm-notify.sh" "$backup_dir/wezterm-notify.sh.bak" || exit 1; }
[ -e "$HOME/.copilot/hooks/wezterm-notify.sh" ] && { mv "$HOME/.copilot/hooks/wezterm-notify.sh" "$backup_dir/copilot-wezterm-notify.sh.bak" || exit 1; }
# 旧名（Phase 2〜3の一時名）。移行期の残骸を掃除する。
[ -e "$HOME/.local/bin/wezterm-agents-tui" ] && { mv "$HOME/.local/bin/wezterm-agents-tui" "$backup_dir/wezterm-agents-tui.bak" || exit 1; }

rm -rf "$HOME/.config/nvim" && ln -s "$HOME/dotfiles/.config/nvim" "$HOME/.config/nvim"
rm -rf "$HOME/.config/wezterm" && ln -s "$HOME/dotfiles/.config/wezterm" "$HOME/.config/wezterm"
rm -rf "$HOME/.config/starship.toml" && ln -s "$HOME/dotfiles/.config/starship.toml" "$HOME/.config/starship.toml"
mkdir -p "$HOME/Library/Application Support/lazygit"
rm -rf "$HOME/Library/Application Support/lazygit/config.yml" && ln -s "$HOME/dotfiles/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

# wezterm-agents (Rust製のエージェント一覧TUI + 各エージェントのhook本体 +
# wezterm プラグイン)
#
# 2026-09-13 に dotfiles モノレポから独立リポジトリへ分離した
# （https://github.com/shirokuroiori/wezterm-agents 、履歴は git-filter-repo
# で移植済み）。dotfiles 側は clone 先の場所だけを知っていればよい。
#
# 【必ずエージェント設定より先に置くこと】claude-settings.json と
# .copilot/hooks/wezterm-notify.json はこのバイナリを hook として呼ぶ。
# 設定を先に張ると、バイナリが古い／無い状態で hook が走る瞬間ができる。
# 実際にそれをやって、hook が終了コード2を返し Claude Code の全ツール
# 呼び出しがブロックされた（2026-09-13）。順序はこのための制約。
#
# clone 先は ~/sources/wezterm-agents 固定（.config/wezterm/wezterm.lua の
# dofile もここを見るので、動かすなら両方直すこと）。既にあれば pull だけ、
# 無ければ clone する。バイナリはリポジトリに置かず、ここでビルドして
# シンボリックリンクする。コールドビルドは実測20秒。ソースが変わっていなければ
# スキップする。
#
# 【GitHub Releases 対応は未実装】将来ビルド済みバイナリを配れるようになったら、
# cargo が無い環境でもここでダウンロードするフォールバックを足す。今は cargo
# が無いと hook が丸ごと無効になる。
mkdir -p "$HOME/.local/bin" "$HOME/sources"
agents_tui_src="$HOME/sources/wezterm-agents"
agents_tui_bin="$agents_tui_src/target/release/wezterm-agents"
if [ -e "$agents_tui_src/.git" ]; then
  git -C "$agents_tui_src" pull --ff-only \
    || echo "warning: wezterm-agents の更新に失敗しました（ローカルの変更が残っているかも）" >&2
elif command -v git >/dev/null 2>&1; then
  git clone https://github.com/shirokuroiori/wezterm-agents "$agents_tui_src" \
    || echo "warning: wezterm-agents の clone に失敗しました" >&2
else
  echo "warning: git が無いので wezterm-agents の取得をスキップします" >&2
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "warning: cargo が無いので wezterm-agents のビルドをスキップします" >&2
  echo "         brew install rustup で導入できます" >&2
elif [ "${WEZTERM_AGENTS_FORCE_BUILD:-}" != "1" ] && [ -x "$agents_tui_bin" ] \
     && [ -z "$(find "$agents_tui_src/src" "$agents_tui_src/Cargo.toml" "$agents_tui_src/Cargo.lock" -newer "$agents_tui_bin" 2>/dev/null)" ]; then
  echo "wezterm-agents: 変更が無いのでビルドをスキップします"
else
  (cd "$agents_tui_src" && cargo build --release) \
    || echo "warning: wezterm-agents のビルドに失敗しました" >&2
fi
if [ -x "$agents_tui_bin" ]; then
  rm -rf "$HOME/.local/bin/wezterm-agents" \
    && ln -s "$agents_tui_bin" "$HOME/.local/bin/wezterm-agents"
else
  echo "warning: wezterm-agents のバイナリが見つからないためリンクをスキップします" >&2
  echo "         エージェントの hook は無効のまま（何も通知されない）になります" >&2
fi

mkdir -p "$HOME/.claude/commands"
# settings.json はユーザーグローバル設定。実体は claude-settings.json という別名で置く。
# dotfiles リポジトリ内で Claude Code を開いたときに .claude/settings.json が
# プロジェクト設定として二重ロードされ hook が二重発火するのを避けるため
# （自動ロードされるのは settings.json / settings.local.json という正確な名前のみ）。
rm -rf "$HOME/.claude/settings.json" && ln -s "$HOME/dotfiles/.claude/claude-settings.json" "$HOME/.claude/settings.json"
rm -rf "$HOME/.claude/statusline-command.sh" && ln -s "$HOME/dotfiles/.claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
rm -rf "$HOME/.claude/deny-push-hook.sh" && ln -s "$HOME/dotfiles/.claude/deny-push-hook.sh" "$HOME/.claude/deny-push-hook.sh"
rm -rf "$HOME/.claude/commands/shortcuts.md" && ln -s "$HOME/dotfiles/.claude/commands/shortcuts.md" "$HOME/.claude/commands/shortcuts.md"
mkdir -p "$HOME/.copilot/hooks"
rm -rf "$HOME/.copilot/hooks/wezterm-notify.json" && ln -s "$HOME/dotfiles/.copilot/hooks/wezterm-notify.json" "$HOME/.copilot/hooks/wezterm-notify.json"
