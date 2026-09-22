# Octo.nvimでPRレビュー：差分の読み方とコメント〜approveまでの流れ

## 課題

- `octo.nvim`のdiffは素のvim diff（行単位、char単位ハイライトなし）で、`codediff.nvim`のような細かい差分の見やすさが無い
- Files changedパネルは常に下固定のフラットリストで、位置やツリー表示を切り替える設定項目がそもそも存在しない
- レビュー開始→コメント→approveまでのキーマップが多く、しかも同じキー（`<localleader>vs`）が開いているバッファによって「開始」だったり「提出」だったりする

## 差分を「読む」だけならcodediffを使う

PRのコメント/approveをする気が無く、とにかく差分を丁寧に読みたいだけなら、octoの差分ビューは使わずcodediffに逃がした方が早い。

```sh
# PRブランチをローカルrefとして取得（checkoutしなくてよい）
git fetch origin pull/<PR番号>/head:pr-<PR番号>
```

```vim
:CodeDiff <base>...pr-<PR番号>
```

`...`（triple-dot）はmerge-base差分になるので、今いるブランチを離れずに`main`とPRのmerge-baseから見た正しい差分がexplorer形式（ファイルツリー＋char単位ハイライト）で開く。baseブランチ名が不明なら`gh pr view <番号> --json baseRefName -q .baseRefName`。

## コメント/approveをするならOcto review

### 開始・再開・破棄

| キー | コマンド | 動作 |
|---|---|---|
| `<leader>orv` | `Octo review start` | 新規レビュー開始（GitHub上にPENDING状態の下書きレビューを作成） |
| `<leader>orR` | `Octo review resume` | 自分がauthorのPENDINGレビューを復元して再開 |
| `<leader>orc` | `Octo review comments` | レビューを開始せず既存スレッドだけ閲覧 |
| `\vd`（diffペイン/ファイルパネル内） | `Octo review discard` | 下書きレビューを破棄（何も公開されない） |

下書きレビューはタブを閉じても消えない。GitHub側にPENDINGのまま残るので、後日`resume`で続きから再開できる。

### Files changedパネルの位置

octoにはパネル位置やツリー表示を切り替える設定項目が無い（`file_panel`設定は`size`と`icons`のみ、ソース上も`sp` + `wincmd J`で下固定にハードコードされている）。左の縦分割に固定する`BufWinEnter`オートコマンドを`git.lua`に追加済み（下記「該当ファイル」参照）。ツリー表示自体は上流に機能が無いため対応不可、フラットリストのまま運用する。

### diffペインでコメントを追加する（`review_diff`コンテキスト）

| キー | 動作 |
|---|---|
| `\ca` | 新規コメント（ビジュアル選択で複数行対応） |
| `\sa` | 「提案（suggestion）」として追加（相手がApply Suggestionできる） |
| `]c` / `[c` | 次/前のコメントへ |
| `]t` / `[t` | 次/前のスレッドへ |
| `]q` / `[q`、`[Q` / `]Q` | 次/前、最初/最後の変更ファイルへ |
| `]u` / `[u` | 次/前の未読ファイルへ |
| `\<Space>` | 現在ファイルの既読/未読トグル |
| `\e` / `\b` | ファイルパネルへフォーカス / 表示切替 |
| `gf` | ファイルへ移動 |

コメント入力バッファ（`octo://...`仮想バッファ）が開いたら、書いて**`:w`で送信**。`BufWriteCmd`が`octo.save_buffer()`にフックされているため、保存＝送信になる。この時点ではまだ非公開（PENDINGレビュー内のコメント）。送信せずキャンセルしたければ`:bd!`。

### 既存スレッドへの返信・解決（`review_thread`コンテキスト）

| キー | 動作 |
|---|---|
| `\cr` | スレッドに返信 |
| `\cd` / `\ce` | コメント削除 / 編集履歴表示 |
| `\rt` / `\rT` | スレッドをresolve / resolve解除 |
| `\rp` `\rh` `\re` `\r+` `\r-` `\rr` `\rl` `\rc` | リアクション |

### 提出（approve / comment / request changes）

| キー/コマンド | 動作 |
|---|---|
| `\vs`（diffペイン or ファイルパネル内） / `<leader>orx` | `Octo review submit` — 提出ウィンドウを開く |

提出ウィンドウで総評コメントを書いた後：

| キー | 動作 |
|---|---|
| `<C-a>` | Approve |
| `<C-m>` | Comment（承認/却下なし） |
| `<C-r>` | Request changes |
| `<C-c>` | キャンセル |

### 一発approveだけしたいとき

diffを見ずに「LGTM」だけ出すなら、PR概要バッファ（`Octo pr edit <n>`等で開く画面）で

```
<leader>qa
```

コメント無しのAPPROVEレビューが即提出される（`review_diff`とは別バッファのマッピングなので、diffペインでは効かない）。

## 該当ファイル

- `.config/nvim/lua/plugins/git.lua`
  - `pwntester/octo.nvim`の`keys`：`<leader>orv`（start）/ `<leader>orR`（resume）/ `<leader>orx`（submit）など
  - `pwntester/octo.nvim`の`init`：`BufWinEnter`（pattern `OctoChangedFiles-*`）でFiles changedパネルを`wincmd H`＋`vertical resize 40`し左固定にするオートコマンド

## 注意点

- `<localleader>vs`は文脈依存。PR概要バッファでは「レビュー開始」、diffペイン/ファイルパネルでは「レビュー提出」と意味が変わる。混乱するなら`<leader>o...`系（`git.lua`で自分が設定した方）を優先して使う
- ファイルツリー表示は上流に機能自体が無い（`file-panel.lua`にツリー描画ロジックが存在しない）ので、フラットリストのまま運用する前提
- コメントを大量に打つレビュー作業は、VSCodeのGitHub Pull Requests拡張の方が体感速いことが多い。差分を読む＝codediff/octo、コメントを大量に打つ＝VSCode、のハイブリッド運用でも構わない
