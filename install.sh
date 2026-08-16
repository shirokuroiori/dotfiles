
# backup configs
backup_dir="$HOME/.backup/$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"

[ -e "$HOME/.config/nvim" ] && { mv "$HOME/.config/nvim" "$backup_dir/nvim.bak" || exit 1; }
[ -e "$HOME/.config/wezterm" ] && { mv "$HOME/.config/wezterm" "$backup_dir/wezterm.bak" || exit 1; }
[ -e "$HOME/.config/starship.toml" ] && { mv "$HOME/.config/starship.toml" "$backup_dir/starship.toml.bak" || exit 1; }
mkdir -p "$backup_dir/lazygit"
[ -e "$HOME/Library/Application Support/lazygit/config.yml" ] && { mv "$HOME/Library/Application Support/lazygit/config.yml" "$backup_dir/lazygit/config.yml.bak" || exit 1; }
[ -e "$HOME/.claude/commands/shortcuts.md" ] && { mv "$HOME/.claude/commands/shortcuts.md" "$backup_dir/shortcuts.md.bak" || exit 1; }
[ -e "$HOME/.claude/hooks/wezterm-notify.sh" ] && { mv "$HOME/.claude/hooks/wezterm-notify.sh" "$backup_dir/wezterm-notify.sh.bak" || exit 1; }
[ -e "$HOME/.copilot/hooks/wezterm-notify.sh" ] && { mv "$HOME/.copilot/hooks/wezterm-notify.sh" "$backup_dir/copilot-wezterm-notify.sh.bak" || exit 1; }
[ -e "$HOME/.copilot/hooks/wezterm-notify.json" ] && { mv "$HOME/.copilot/hooks/wezterm-notify.json" "$backup_dir/copilot-wezterm-notify.json.bak" || exit 1; }
[ -e "$HOME/.local/bin/wezterm-agents" ] && { mv "$HOME/.local/bin/wezterm-agents" "$backup_dir/wezterm-agents.bak" || exit 1; }
# 旧名（Phase 2〜3の一時名）。移行期の残骸を掃除する。
[ -e "$HOME/.local/bin/wezterm-agents-tui" ] && { mv "$HOME/.local/bin/wezterm-agents-tui" "$backup_dir/wezterm-agents-tui.bak" || exit 1; }

rm -rf "$HOME/.config/nvim" && ln -s "$HOME/dotfiles/.config/nvim" "$HOME/.config/nvim"
rm -rf "$HOME/.config/wezterm" && ln -s "$HOME/dotfiles/.config/wezterm" "$HOME/.config/wezterm"
rm -rf "$HOME/.config/starship.toml" && ln -s "$HOME/dotfiles/.config/starship.toml" "$HOME/.config/starship.toml"
mkdir -p "$HOME/Library/Application Support/lazygit"
rm -rf "$HOME/Library/Application Support/lazygit/config.yml" && ln -s "$HOME/dotfiles/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
mkdir -p "$HOME/.claude/commands"
rm -rf "$HOME/.claude/commands/shortcuts.md" && ln -s "$HOME/dotfiles/.claude/commands/shortcuts.md" "$HOME/.claude/commands/shortcuts.md"
mkdir -p "$HOME/.claude/hooks"
rm -rf "$HOME/.claude/hooks/wezterm-notify.sh" && ln -s "$HOME/dotfiles/.claude/hooks/wezterm-notify.sh" "$HOME/.claude/hooks/wezterm-notify.sh"
mkdir -p "$HOME/.copilot/hooks"
rm -rf "$HOME/.copilot/hooks/wezterm-notify.sh" && ln -s "$HOME/dotfiles/.copilot/hooks/wezterm-notify.sh" "$HOME/.copilot/hooks/wezterm-notify.sh"
rm -rf "$HOME/.copilot/hooks/wezterm-notify.json" && ln -s "$HOME/dotfiles/.copilot/hooks/wezterm-notify.json" "$HOME/.copilot/hooks/wezterm-notify.json"
mkdir -p "$HOME/.local/bin"

# wezterm-agents (Rust製のエージェント一覧TUI)
# docs/plans/wezterm-multi-agent-spec.md §4.1
# 旧bash版(bin/wezterm-agents)はPhase 4で廃止し、この名前をRust版が引き継いだ。
# バイナリはリポジトリに置かず、ここでビルドしてシンボリックリンクする。
# コールドビルドは実測20秒。ソースが変わっていなければスキップする。
agents_tui_src="$HOME/dotfiles/tools/wezterm-agents"
agents_tui_bin="$agents_tui_src/target/release/wezterm-agents"
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
fi
