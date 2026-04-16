# Pyright × Poetry × Neovim：Import が解決しないとき

## 症状

- Python ファイルで `Import "XXX" could not be resolved`（Pyright の診断）
- `poetry shell` してから Neovim を起動すると直る
- 通常のシェルから Neovim だけだと直らない

## 原因（ざっくり）

Pyright は **起動時の環境**（`PATH` / `VIRTUAL_ENV`）や **プロジェクト設定** で「どの Python・どこを import ルートにするか」を決める。シェルで venv を有効にしていないと、システムの Python 側で解析され、Poetry の venv に入ったパッケージが見えない。

## 対処：`pyproject.toml` に `[tool.pyright]` を書く

**Poetry プロジェクトのルート**（例：`backend/pyproject.toml`）に、仮想環境と `src` レイアウトを明示する。

レイアウト例：

```text
project
  backend/
    .venv/          # Poetry（in-project venv など）
    pyproject.toml
    src/
      ...
```

`backend/pyproject.toml` に追記：

```toml
[tool.pyright]
venvPath = "."
venv = ".venv"
extraPaths = ["src"]
```

- `venvPath` / `venv` … そのディレクトリから見た仮想環境の場所（`.venv` が `backend` 直下の場合の例）
- `extraPaths` … `src` レイアウトでパッケージが `src/` 以下にあるときに必要

`pyrightconfig.json` で同じことを書いてもよい（どちらか一方でよい）。

## 確認のコツ

- 編集中のファイルが **`backend/` 配下**なら、Pyright はそこから上に辿って `pyproject.toml` / `pyrightconfig.json` を拾う
- venv の実際のパスが違う場合は `poetry env info -p` でパスを確認し、`venv` / `venvPath` を合わせる

## 参考（別手段）

- **direnv + Neovim 連携**：ディレクトリに入ったときに `VIRTUAL_ENV` をエディタに反映
- **venv-selector.nvim** など：プロジェクトごとに venv を選んで LSP に渡す

まずは **`[tool.pyright]` をプロジェクトに置く**のが、エディタ横断で覚えやすい。
