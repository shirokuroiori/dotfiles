# Bizin Gothic に Nerd Font を合成する

Wezterm で使っている `Bizin Gothic Discord NF`（`.config/wezterm/wezterm.lua` で指定）の作り方。

## 結論：nerd-fonts の `font-patcher` は使わない

Nerd Fonts 公式の `font-patcher`（fontforge script）で後から合成する方法も試した形跡があるが、
最終的に使っているのは **bizin-gothic 本体（yuru7/bizin-gothic）が持つ `--nerd-font` ビルドオプション**。

- リポジトリの `git log` に `add support for Nerd Fonts` というコミットがあり、本家に Nerd Font 合成機能が入っている
- ビルド時にオプションを付けるだけで、Discord 版と同時に Nerd Font のグリフも合成できる

## 事前準備

リポジトリをクローン（既にあるなら不要）:

```bash
git clone git@github.com:yuru7/bizin-gothic.git ~/sources/bizin-gothic
cd ~/sources/bizin-gothic
```

`source_fonts/` に以下が揃っていることを確認する:

- `source_fonts/biz-ud-gothic/BIZUDGothic-{Regular,Bold}.ttf`
- `source_fonts/inconsolata/Inconsolata-{Medium,Bold}.ttf`
- `source_fonts/SymbolsNerdFont-Regular.ttf`（[nerd-fonts のリリース](https://github.com/ryanoasis/nerd-fonts/releases/latest) から Symbols 単体版 `NerdFontsSymbolsOnly.zip` を展開して配置）

Python 依存関係をインストール:

```bash
pip install -r requirements.txt
```

`fonttools_script.py` 実行時に setuptools 関連のエラーが出た場合:

```bash
pip install --upgrade setuptools
```

## Mac でのビルド時の注意

`build.ini` の `JP_FONT` / `ENG_FONT` は Windows パス区切り（`\`）になっているため、Mac では `/` に書き換える。

```ini
# 変更前
JP_FONT = biz-ud-gothic\BIZUDGothic-{style}.ttf
ENG_FONT = inconsolata\Inconsolata-{style}.ttf

# 変更後
JP_FONT = biz-ud-gothic/BIZUDGothic-{style}.ttf
ENG_FONT = inconsolata/Inconsolata-{style}.ttf
```

## ビルド実行

```bash
fontforge --script ./fontforge_script.py --nerd-font --discord && python fonttools_script.py
```

- `--discord` … Ricty インスパイアな判読性優先の字形調整（`07DZlrz|` など）を有効化
- `--nerd-font` … Nerd Font のグリフを合成

`build.ini` の `NERD_FONTS_STR = NF` / `DISCORD_STR = Discord` から、生成される family 名は
`Bizin Gothic Discord NF` になる（`wezterm.lua` の指定と一致させるために重要）。

## フォントのインストール

`build/` に出力された ttf を Fonts フォルダにコピーする。

```bash
cp build/*.ttf ~/Library/Fonts/
```

既存の同名ファイルを上書きする場合は、フォントキャッシュが古いまま残らないよう、
一度 Font Book などでインストール済みのものを削除してから入れ直すと確実。

## Wezterm 側の設定

```lua
-- .config/wezterm/wezterm.lua
config.font = wezterm.font("Bizin Gothic Discord NF", { weight = 600 })
```
