# markdown-oxide × Neovim：新規 `.md` がリンク補完・ジャンプに出てこないとき

## 症状

- 既存の Markdown ファイル間なら `[[wikilink]]` 補完や `gj`（goto_definition）が効く
- **さっき作ったばかりの `.md`** がリンク補完の候補に出てこない
- 一度 Neovim を再起動する（またはワークスペースを開き直す）と認識される

## 原因（ざっくり）

markdown-oxide は「ワークスペース内にどんな `.md` があるか」を
**`workspace/didChangeWatchedFiles`（ファイル監視通知）** で更新する。

この通知を受け取るには、LSP クライアント（Neovim）が
capabilities で **dynamic registration に対応している**と宣言する必要がある。
ところが blink.cmp の `get_lsp_capabilities()` が返す capabilities には
`workspace.didChangeWatchedFiles.dynamicRegistration` が含まれていないため、
markdown-oxide がファイル監視を登録できず、起動時にスキャンした
ファイル一覧のまま固まってしまう。

## 対処：capabilities に dynamicRegistration を足す

`.config/nvim/lua/plugins/lsp.lua` の `mason-lspconfig` の `config` 内、
`vim.lsp.config("*", ...)` の後に以下を追記する。

```lua
vim.lsp.config("markdown_oxide", {
  capabilities = {
    workspace = {
      didChangeWatchedFiles = { dynamicRegistration = true },
    },
  },
})
```

- `vim.lsp.config` は **サーバー名ごとの設定を既存の `"*"` 設定にマージ**するので、
  この差分だけ書けばよい（`capabilities` 全体を組み直す必要はない）
- 反映には Neovim の再起動、または `:LspRestart markdown_oxide` が必要

## 確認のコツ

- 追記後、新しく `foo.md` を作成 → 別の `.md` で `[[fo` と打って
  候補に `foo` が出れば OK
- 出ない場合は `:checkhealth vim.lsp` で markdown_oxide の
  registered capabilities に `didChangeWatchedFiles` があるか確認
- Obsidian vault で使うときは、その vault ディレクトリを Neovim の
  cwd にして開くと `.obsidian/` を読んでワークスペースを認識する

## 参考

- 無くても Neovim / ワークスペースを開き直せばファイルは認識される。
  「新規ファイルを作りながらリンクを張る」使い方をするなら入れる価値がある。
- Rust の `rust_analyzer` も同様にファイル監視で新規ファイルを拾うが、
  こちらは無くても実用上ほぼ困らない。
