# 今後やりたい設定

- [ ] LazyGitで差分が見ずらい
  - [ ] LazyGitでの差分ツリー一覧をから本当のファイルに飛びたい
- [ ] ショートカットで選択行のパスをコンテキスト指定形式でクリップボードにコピーする
- [ ] WezTermが「エネルギーを著しく消費」になる件の切り分け
  - [ ] `window_background_opacity` / `macos_window_background_blur` / `max_fps` を下げてActivity Monitorのエネルギー欄で比較
  - [ ] copilot_status検知（画面最終行ポーリング）はredrawに相乗りしているだけで追加コストはほぼ無いはず、という仮説の裏取り
- [ ] Copilot CLIでskill内`runSubagent`のtodo完了ごとに`done`通知が誤発火する
  - 原因はCopilot CLI側の既知バグ: [`agentStop` triggering on subagent turns](https://github.com/github/copilot-cli/issues/3894)（本来`subagentStop`が担当すべきところに`agentStop`も発火する）
  - v1.0.79時点で未修正。上流が直すまでは保留、対応しない
  - もし将来手当てするなら: `.copilot/hooks/wezterm-notify.json`の`agentStop`を`done`から外す/matcherで絞る、など

