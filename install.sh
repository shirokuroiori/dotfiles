
# backup configs
backup_dir="$HOME/.backup/$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"

mv "$HOME/.config/nvim" "$backup_dir/nvim.bak"
mv "$HOME/.config/wezterm" "$backup_dir/wezterm.bak"
mv "$HOME/.config/starship.toml" "$backup_dir/starship.toml.bak"

rm -rf "$HOME/.config/nvim" && ln -s "$HOME/dotfiles/.config/nvim" "$HOME/.config/nvim"
rm -rf "$HOME/.config/wezterm" && ln -s "$HOME/dotfiles/.config/wezterm" "$HOME/.config/wezterm"
rm -rf "$HOME/.config/starship.toml" && ln -s "$HOME/dotfiles/.config/starship.toml" "$HOME/.config/starship.toml"
