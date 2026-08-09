
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
