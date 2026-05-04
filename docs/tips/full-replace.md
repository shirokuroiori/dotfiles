## Neovim の一括置換

### 基本的な置換

```vim
:%s/old/new/g
```
- `%` — ファイル全体
- `g` — 行内の全マッチ

### オプション

| フラグ | 説明 |
|--------|------|
| `g` | 行内全マッチ |
| `c` | 確認しながら置換 |
| `i` | 大文字小文字を無視 |
| `I` | 大文字小文字を区別 |

例: `:%s/old/new/gc` — 1つずつ確認

---

### 範囲指定

```vim
:10,20s/old/new/g     " 10〜20行目
:'<,'>s/old/new/g     " ビジュアル選択範囲（v で選択後）
```

---

### 複数ファイルへの一括置換

**quickfix リストを使う方法:**

```vim
:args **/*.lua          " 対象ファイルを指定
:argdo %s/old/new/g | update
```

または grep 結果から:

```vim
:grep old **/*.lua
:cfdo %s/old/new/g | update
```

---

### Telescope + telescope-live-grep-args (あなたの設定)

Telescope で検索後、`<C-q>` で quickfix に送って `:cfdo` で置換するのが実用的です。
