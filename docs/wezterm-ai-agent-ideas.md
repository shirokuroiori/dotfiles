# WezTerm × AIエージェント連携アイデア（未実装分）

WezTerm上でClaude Code / GitHub Copilot CLIのようなAIエージェントを使いこなすための
ハック案のうち、まだ手を付けていないものをメモしておく。

実装済みのもの（状態のタブ色表示・通知・選択中タブの指マーク）は
`.config/wezterm/wezterm.lua` の `format-tab-title` / `bell` イベント、
`.claude/hooks/wezterm-notify.sh`、`.copilot/hooks/wezterm-notify.sh` を参照。

`bin/wezterm-agents` も実装済み。全ペインをプロジェクト(cwd)ごとにグルーピングし、
gitブランチ名・エージェント状態(working/waiting/done)・直近のタスク内容
（Claude Code / Copilot CLIが自分でペインタイトルに書く会話サマリを流用）を
一覧表示するCLI。状態のwaiting/doneは上記hookが `/tmp/wezterm-agent-status/<pane_id>`
にも書き出したものを読んでいる（`pane.user_vars` は `wezterm cli list` の
JSON出力に含まれないため）。`install.sh` で `~/.local/bin/wezterm-agents` に
シンボリックリンクされる。

## 3. ファイルパスをクリック可能に

Claude Code / Copilot CLIは出力に `file.py:123` のようなパスをよく出す。
`config.hyperlink_rules` に正規表現を追加すると、Cmd+クリックでジャンプできる
ようになる。

```lua
table.insert(config.hyperlink_rules, {
  regex = [[\b([\w./-]+\.\w+):(\d+)\b]],
  format = 'file://$1#$2',
})
```

飛び先をエディタで直接開きたい場合は、`nvim --server`のリモート機能などと
組み合わせる必要がある（ブラウザではなくエディタで開く部分は要検討）。

## 4. セッション永続化（mux server / detach-reattach）

`wezterm-mux-server` を裏で常駐させ、`wezterm connect unix` で接続する運用に
すると、SSH切断やmacOSスリープを跨いでエージェントのセッションを維持できる
（tmuxのdetach/attachに相当）。

リモートホストでエージェントを動かす場合は `config.ssh_domains` にホストを
登録しておくと、接続のたびに設定し直さず1コマンドで復帰できる。

```lua
config.ssh_domains = {
  {
    name = 'work-server',
    remote_address = 'example.com',
    username = 'io',
  },
}
```

`wezterm connect work-server` で接続し直せば、切断前のペイン構成ごと復元
される。

## 5. git worktreeによるマルチエージェント隔離

同じリポジトリで複数のエージェント（Claude Code / Copilot CLI）を並行して
動かすと、作業ディレクトリとブランチを共有してしまい、片方の未コミット差分
ともう片方の変更がぶつかったり、同じファイルを同時に触ってしまったりする。
`git worktree`で「1エージェント = 1worktree = 1ブランチ」に分離すれば、
作業ディレクトリレベルで完全に独立させられる（cmuxが複数エージェントを
安全に並行動作させるために採っているのと同じ発想）。

ブランチ名を渡すとworktreeを作り、そのディレクトリで新しいWezTermウィンドウ
を開いてエージェントまで起動する、をシェル関数で1コマンド化する:

```zsh
# ~/.zshrc など
agent-worktree() {
  local branch="$1"
  if [ -z "$branch" ]; then
    echo "usage: agent-worktree <branch>" >&2
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel) || return 1
  local repo_name
  repo_name=$(basename "$repo_root")
  local worktree_dir="${repo_root}/../${repo_name}-worktrees/${branch}"

  if [ ! -d "$worktree_dir" ]; then
    # 既存ブランチなら -b を外して `git worktree add "$worktree_dir" "$branch"` にする
    git -C "$repo_root" worktree add -b "$branch" "$worktree_dir" || return 1
  fi

  wezterm cli spawn --cwd "$worktree_dir" -- zsh -lc 'claude'
}
```

後片付け用の対のコマンドも用意しておくと、worktreeが溜まりっぱなしになる
のを防げる（未コミット差分が残っていると`git worktree remove`は失敗するので、
その場合は先にコミット/stashするか`--force`で捨てるかを都度判断する）:

```zsh
agent-worktree-rm() {
  local branch="$1"
  local repo_root
  repo_root=$(git rev-parse --show-toplevel) || return 1
  local repo_name
  repo_name=$(basename "$repo_root")
  local worktree_dir="${repo_root}/../${repo_name}-worktrees/${branch}"

  git -C "$repo_root" worktree remove "$worktree_dir"
}
```

運用上の注意点:

- worktreeディレクトリ名をブランチ名にしておけば、タブタイトルの末尾
  ディレクトリ名表示（既存の`format-tab-title`実装）がそのまま「どのタブが
  どのブランチのエージェントか」の目印になる。
- `node_modules`のような依存物はworktree間で共有されない。JS系プロジェクト
  だとworktreeを作るたびに`npm install`し直しになり、ディスクも時間も食う点は
  トレードオフとして把握しておく（pnpmのcontent-addressable storeなど、
  worktree間で実体を共有できるパッケージマネージャだと影響は小さい）。
- `git worktree list`で棚卸しし、使われなくなったworktreeを定期的に
  `agent-worktree-rm`で消す運用にしないと、ブランチとディレクトリが際限なく
  増える。

## 6. workspaceによるプロジェクト単位のウィンドウ切り替え

普段は「nvimウィンドウ」と「AIエージェントウィンドウ」を分けて使っている
（ペイン分割はしない）ため、プロジェクトを切り替えるたびにこの2枚を
セットで持ってきたい。WezTermの**workspace**（Windowに付けられる名前タグ。
tmuxのセッションに相当）を使うと、これが実現できる。

workspaceを切り替えると、そのworkspaceに属さないWindowは画面から隠れ、
切り替え先のworkspaceに属するWindowだけが表示される。つまり「プロジェクト
Aのnvim+エージェントの2枚」と「プロジェクトBのnvim+エージェントの2枚」を
workspace名で分けておけば、workspace切り替え＝プロジェクト切り替えになる。

プロジェクトを開く（nvimウィンドウとエージェントウィンドウを同じworkspace名で
2枚立てる）シェル関数:

```zsh
# ~/.zshrc など
project-open() {
  local name="$1"   # workspace名。プロジェクト名をそのまま使うと分かりやすい
  local path="$2"   # プロジェクトのルートディレクトリ

  wezterm cli spawn --new-window --workspace "$name" --cwd "$path" -- zsh -lc 'nvim'
  wezterm cli spawn --new-window --workspace "$name" --cwd "$path" -- zsh -lc 'claude'
}
```

```
project-open gaia-con ~/sources/gaia-con
```

`--new-window`が必須。これがないと「今いるウィンドウに新しいタブを足す」
動作になり、独立した2ウィンドウにならない。

workspace間を移動するキーバインド（`keys.lua`に追加）:

```lua
{
  key = 'p',
  mods = 'CMD|SHIFT',
  action = wezterm.action.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' },
},
```

ファジー検索付きのworkspace一覧が出て、選ぶとそのworkspaceのWindow群だけが
手前に表示される。`wezterm.action.SwitchWorkspaceRelative{offset=1}`を
別キーに割り当てれば、隣のworkspaceへ循環移動もできる。

運用上の注意点:

- workspace名はcwdから自動で決まらないので、`project-open`を呼ぶ側が
  常に同じ名前（プロジェクトのbasenameなど）を渡す規約にしておく。
- `wezterm cli list`で見えるWindowは今のところ全部`default`workspace。
  導入するなら「プロジェクト作業は必ずworkspace付きで開く」ルールにしないと
  `default`と名前付きworkspaceが混在して分かりにくくなる。
- 「5. git worktreeによるマルチエージェント隔離」と組み合わせ、
  `project-open`にブランチ引数も足せば「プロジェクト×ブランチ」単位で
  workspaceを切る拡張もできる。
