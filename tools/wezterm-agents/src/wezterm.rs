//! `wezterm cli` との境界と、ペインジャンプ。

use std::collections::HashMap;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use crate::model::{derive_state, is_working_title, task_from_title, Group, Pane, Snapshot};
use crate::store::{git_branch, Store};

#[derive(Debug, Deserialize)]
struct CliPane {
    pane_id: u64,
    window_id: u64,
    tab_id: u64,
    workspace: String,
    cwd: String,
    title: String,
}

/// `wezterm` 実行ファイルの場所を解決する。
///
/// ここは2回間違えた箇所なので経緯を残す。
///
/// 1. PATH に頼ってはいけない。キーバインド（SpawnCommandInNewTab）から
///    起動されるとシェルを経由しないため .zshrc の PATH が効かず、
///    "No such file or directory" で落ちる。
/// 2. WEZTERM_EXECUTABLE をそのまま使ってもいけない。この値は起動経路で
///    中身が変わり、`wezterm cli spawn` 由来のペインでは .../wezterm だが、
///    キーバインド（GUI プロセス）由来だと .../wezterm-gui が入っている。
///    wezterm-gui に `cli` サブコマンドは無く
///    "unrecognized subcommand 'cli'" になる。
///
/// したがって「環境変数が指すディレクトリの中の `wezterm`」を探す。
/// wezterm と wezterm-gui は同じディレクトリに並んでいる。
fn wezterm_bin() -> String {
    let mut dirs: Vec<PathBuf> = Vec::new();
    if let Ok(dir) = std::env::var("WEZTERM_EXECUTABLE_DIR") {
        if !dir.is_empty() {
            dirs.push(PathBuf::from(dir));
        }
    }
    if let Ok(exe) = std::env::var("WEZTERM_EXECUTABLE") {
        if let Some(parent) = Path::new(&exe).parent() {
            dirs.push(parent.to_path_buf());
        }
    }
    dirs.push(PathBuf::from("/opt/homebrew/bin"));
    dirs.push(PathBuf::from("/usr/local/bin"));
    dirs.push(PathBuf::from("/Applications/WezTerm.app/Contents/MacOS"));

    for dir in dirs {
        let candidate = dir.join("wezterm");
        if candidate.is_file() {
            return candidate.to_string_lossy().into_owned();
        }
    }
    // 最後の望みとして PATH 解決に任せる
    "wezterm".to_string()
}

/// 1ティックに走るサブプロセスはこの1回だけ（仕様書 §4.4）。
pub fn list_panes() -> Result<Vec<CliPaneInfo>, String> {
    let out = Command::new(wezterm_bin())
        .args(["cli", "list", "--format", "json"])
        .output()
        .map_err(|e| format!("wezterm cli の起動に失敗: {e}"))?;
    if !out.status.success() {
        return Err(format!(
            "wezterm cli list が失敗: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        ));
    }
    let panes: Vec<CliPane> =
        serde_json::from_slice(&out.stdout).map_err(|e| format!("JSONの解析に失敗: {e}"))?;
    Ok(panes
        .into_iter()
        .map(|p| CliPaneInfo {
            pane_id: p.pane_id,
            window_id: p.window_id,
            tab_id: p.tab_id,
            workspace: p.workspace,
            cwd: decode_cwd(&p.cwd),
            title: p.title,
        })
        .collect())
}

pub struct CliPaneInfo {
    pub pane_id: u64,
    pub window_id: u64,
    pub tab_id: u64,
    pub workspace: String,
    pub cwd: String,
    pub title: String,
}

/// "file:///Users/example/my%20dir/" -> "/Users/example/my dir"
fn decode_cwd(uri: &str) -> String {
    let path = uri.strip_prefix("file://").unwrap_or(uri);
    let mut out = String::with_capacity(path.len());
    let bytes = path.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let Ok(b) = u8::from_str_radix(&path[i + 1..i + 3], 16) {
                out.push(b as char);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i] as char);
        i += 1;
    }
    // 末尾スラッシュは落とす（ルート "/" は残す）
    if out.len() > 1 && out.ends_with('/') {
        out.pop();
    }
    out
}

/// ペイン一覧からグルーピング済みのスナップショットを作る。
///
/// - グルーピングは cwd（プロジェクト）単位
/// - グループ内は window_id -> tab_id -> pane_id の昇順
/// - グループの並びは「未読ありを上」-> cwd の辞書順
/// - 自分自身のペイン（$WEZTERM_PANE）は隠す。ランチャーとして開いた
///   自分が一覧に並ぶのを防ぐため（仕様書 §4.2）
pub fn build_snapshot(panes: Vec<CliPaneInfo>, store: &mut Store, self_pane: Option<u64>) -> Snapshot {
    // 同じ cwd のペインが複数あるので、ティック内で git 解決をメモ化する。
    let mut branches: HashMap<String, Option<String>> = HashMap::new();
    let mut by_cwd: HashMap<String, Vec<Pane>> = HashMap::new();

    for info in panes {
        if Some(info.pane_id) == self_pane {
            continue;
        }
        let notifications = store.notifications(info.pane_id);
        let working = is_working_title(&info.title);
        let state = derive_state(working, &notifications);
        let unread = notifications.iter().filter(|n| n.unread).count();
        let branch = branches
            .entry(info.cwd.clone())
            .or_insert_with(|| git_branch(&info.cwd))
            .clone();
        // エージェント種別は通知ログに記録されている。無い場合は
        // タイトルのスピナーから Claude Code を推定する。
        let agent = notifications
            .first()
            .map(|n| n.agent.clone())
            .filter(|a| !a.is_empty())
            .or(if working { Some("claude".into()) } else { None });

        by_cwd.entry(info.cwd.clone()).or_default().push(Pane {
            pane_id: info.pane_id,
            window_id: info.window_id,
            tab_id: info.tab_id,
            workspace: info.workspace,
            cwd: info.cwd,
            branch,
            agent,
            state,
            unread,
            notifications,
            task: task_from_title(&info.title),
        });
    }

    let mut groups: Vec<Group> = by_cwd
        .into_iter()
        .map(|(cwd, mut panes)| {
            panes.sort_by_key(|p| (p.window_id, p.tab_id, p.pane_id));
            Group { cwd, panes }
        })
        .collect();

    groups.sort_by(|a, b| {
        let a_unread = a.unread() > 0;
        let b_unread = b.unread() > 0;
        b_unread.cmp(&a_unread).then_with(|| a.cwd.cmp(&b.cwd))
    });

    Snapshot { groups }
}

/// 選択したペインへフォーカスを移す。
///
/// 本命は OSC 1337 SetUserVar 経由で wezterm.lua の user-var-changed に
/// 処理させる経路（仕様書 §4.5）。`wezterm cli activate-pane` は別ネイティブ
/// ウィンドウを前面に出せない既知バグがあり、GUI プロセス内の
/// gui_window:focus() だけがそれを回避できることを実測で確認している（§9.1）。
///
/// WezTerm の外で起動された場合や /dev/tty を開けない場合は cli 経路に落とす。
pub fn jump(pane_id: u64) -> Result<(), String> {
    if std::env::var("WEZTERM_PANE").is_ok() {
        if let Ok(mut tty) = OpenOptions::new().write(true).open("/dev/tty") {
            // ratatui の描画バッファ経由ではなく /dev/tty へ直接書く。
            // バッファに混ぜると差分描画で落とされうる。
            let payload = b64(pane_id.to_string().as_bytes());
            let seq = format!("\x1b]1337;SetUserVar=wezterm_agents_jump={payload}\x07");
            if tty.write_all(seq.as_bytes()).is_ok() && tty.flush().is_ok() {
                return Ok(());
            }
        }
    }
    activate_pane_fallback(pane_id)
}

fn activate_pane_fallback(pane_id: u64) -> Result<(), String> {
    let out = Command::new(wezterm_bin())
        .args(["cli", "activate-pane", "--pane-id", &pane_id.to_string()])
        .output()
        .map_err(|e| format!("activate-pane の起動に失敗: {e}"))?;
    if out.status.success() {
        Ok(())
    } else {
        Err(format!(
            "activate-pane が失敗: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        ))
    }
}

/// SetUserVar の値は base64。この用途のためだけに依存を増やしたくないので
/// 標準的なエンコーダを直接書く（入力は数字だけなので実質固定長）。
fn b64(input: &[u8]) -> String {
    const TABLE: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::new();
    for chunk in input.chunks(3) {
        let b = [
            chunk[0],
            *chunk.get(1).unwrap_or(&0),
            *chunk.get(2).unwrap_or(&0),
        ];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        out.push(TABLE[(n >> 18 & 63) as usize] as char);
        out.push(TABLE[(n >> 12 & 63) as usize] as char);
        out.push(if chunk.len() > 1 {
            TABLE[(n >> 6 & 63) as usize] as char
        } else {
            '='
        });
        out.push(if chunk.len() > 2 {
            TABLE[(n & 63) as usize] as char
        } else {
            '='
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn base64_matches_reference() {
        assert_eq!(b64(b"14"), "MTQ=");
        assert_eq!(b64(b"7"), "Nw==");
        assert_eq!(b64(b"123"), "MTIz");
        assert_eq!(b64(b"1234"), "MTIzNA==");
    }

    #[test]
    fn cwd_is_decoded() {
        assert_eq!(decode_cwd("file:///Users/example/dotfiles/"), "/Users/example/dotfiles");
        assert_eq!(decode_cwd("file:///Users/example/my%20dir"), "/Users/example/my dir");
        assert_eq!(decode_cwd("file:///"), "/");
    }
}
