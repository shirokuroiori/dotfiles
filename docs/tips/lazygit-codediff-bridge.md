# LazyGit × CodeDiff 連携：ファイル操作はLazyGit、diffはCodeDiffで見る

## 課題

- LazyGit … ファイル管理・git add・push・branch操作はしやすいが、diffが行単位でしか見えない
- CodeDiff（`esmuellert/codediff.nvim`） … 文字単位diffは見やすいが、LazyGitから直接ファイルを開く手段がなかった
- LazyGitの浮動ウィンドウの中身を単純にファイルへ差し替えると、lazygitのジョブが裏で生き続けてしまい、閉じるのに2回操作が必要になる

## 仕組み

`kdheepak/lazygit.nvim` はlazygitを **Neovimの`:terminal`ジョブ** として浮動ウィンドウ内で起動している。
Neovimは`:terminal`ジョブに自動で `$NVIM`（自分自身のRPCソケットアドレス）を環境変数として渡すため、
lazygitのサブプロセス（＝lazygitのcustomCommand）から

```sh
nvim --server "$NVIM" --remote-send "..."
```

で親のNeovimインスタンスを直接操作できる。

ただし浮動ウィンドウの中身を`:edit`で差し替えるだけだとlazygitのジョブ自体は終了しないため、
`lazygit.lua`が公開している `vim.g.lazygit_on_exit_callback` フックを使い、

1. lazygit自身に `q`（正規の終了キー）を送る（`vim.fn.chansend`）
2. lazygitのジョブが実際に終了 → `lazygit.lua`側の`on_exit()`が発火 → 浮動ウィンドウを閉じ、元のウィンドウにフォーカスを戻す
3. `on_exit()`の最後で`lazygit_on_exit_callback`が呼ばれる → ここでファイル/CodeDiffを開く

という順で「LazyGitをちゃんと閉じてからファイルを開く」を実現している。

## 該当ファイル

- `.config/nvim/lua/plugins/git.lua`
  - `kdheepak/lazygit.nvim` の`init`：`_G.LazyGitQuitThen(after)` / `_G.LazyGitOpenFile(file)`
  - `esmuellert/codediff.nvim` の`init`：`_G.CodeDiffFile(file)`（`:CodeDiffFile`コマンドとしても使える） / `_G.LazyGitOpenCodeDiff(file)`
  - `esmuellert/codediff.nvim` の`opts.explorer.view_mode = "tree"`（ファイルツリー表示にする）
- `.config/lazygit/config.yml`
  - `customCommands` に `<c-v>` / `<c-o>` を追加

## 使い方

### LazyGitのFilesパネルから

| キー | 動作 |
|------|------|
| `<c-v>` | LazyGitを閉じて、選択中ファイルをCodeDiffのExplorer Mode（文字単位diff＋stage可）で開く |
| `<c-o>` | LazyGitを閉じて、選択中ファイルをそのままNeovimの通常バッファで開く（diffなし、原文を見る/編集する用） |

どちらもLazyGitのジョブごと終了するので、閉じる操作は1回で済む。

### CodeDiffのExplorer Mode（`<leader>do`）から

ファイルツリー上でカーソルを合わせて：

| キー | 動作 |
|------|------|
| `<CR>` | そのファイルの文字単位diffを開く |
| `-` | カーソル位置の**ファイル1つ**をstage/unstage切り替え（explorer・diffビュー共通） |
| `S` / `U` | 全ファイルをstage / unstage |
| `X` | working treeの変更を破棄（restore） |
| `gs` / `gu` | Staged / Changes グループの表示切り替え |

diffビューを開いた後（`<CR>`で入った状態）は：

| キー | 動作 |
|------|------|
| `-` | そのファイル全体をstage/unstage |
| `<leader>hs` | カーソル位置のhunkだけstage |
| `<leader>hu` | カーソル位置のhunkだけunstage |
| `<leader>hr` | カーソル位置のhunkを破棄（working treeのみ） |

差分を見てOKだったらその場で`-`を押すだけで完結する。lazygitに戻る必要はない。

## 注意点

- `<c-v>` / `<c-o>` はlazygitのデフォルトキーと衝突する可能性がある。競合があれば`.config/lazygit/config.yml`側のキーを変更する
- ファイル名にスペースが含まれると、lazygitのcustomCommandテンプレート展開（`{{.SelectedFile.Name}}`）がシェル的に壊れる可能性がある（lazygit側の既知の制約。通常のコード資産ではまず問題にならない）
- `_G.LAZYGIT_BUFFER` は `lazygit.lua` 側で `local` を付けずに宣言されている実装依存のグローバル変数。`kdheepak/lazygit.nvim` のアップデートで内部実装が変わると壊れる可能性がある
