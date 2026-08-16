//! `/tmp/wezterm-agent-status/` の読み取りと、git ブランチの解決。
//!
//! 書き込みは原則しない。例外は「既読にする」操作（`r` / `R`）で `.read` を
//! 上書きする場合だけで、これは wezterm.lua と同じ「現在時刻で上書き」なので
//! 後勝ちで問題にならない（仕様書 §4.3）。

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

use crate::model::Notification;

pub const STATUS_DIR: &str = "/tmp/wezterm-agent-status";

/// `.jsonl` は mtime が変わったものだけ読み直す（仕様書 §4.4）。
#[derive(Default)]
pub struct Store {
    cache: HashMap<u64, (SystemTime, Vec<Notification>)>,
}

impl Store {
    pub fn new() -> Self {
        Self::default()
    }

    /// 通知履歴を新しい順で返す。`.read` より新しいものに unread を立てる。
    pub fn notifications(&mut self, pane_id: u64) -> Vec<Notification> {
        let path = PathBuf::from(format!("{STATUS_DIR}/{pane_id}.jsonl"));
        let mtime = fs::metadata(&path).and_then(|m| m.modified()).ok();

        let parsed: Vec<Notification> = match mtime {
            None => {
                self.cache.remove(&pane_id);
                Vec::new()
            }
            Some(mtime) => {
                let hit = matches!(self.cache.get(&pane_id), Some((cached, _)) if *cached == mtime);
                if !hit {
                    let events = parse_jsonl(&path);
                    self.cache.insert(pane_id, (mtime, events));
                }
                self.cache
                    .get(&pane_id)
                    .map(|(_, v)| v.clone())
                    .unwrap_or_default()
            }
        };

        // 未読判定は毎回やり直す。`.read` は wezterm.lua が随時書き換えるので、
        // `.jsonl` の mtime が変わっていなくても未読件数は変わりうる。
        let read_at = read_cursor(pane_id);
        let mut out: Vec<Notification> = parsed
            .into_iter()
            .map(|mut n| {
                n.unread = match &read_at {
                    Some(r) => n.at.as_str() > r.as_str(),
                    None => true,
                };
                n
            })
            .collect();
        out.reverse(); // ファイルは古い順。表示は新しい順
        out.truncate(10);
        out
    }

    /// `r` / `R` で明示的に既読にする。
    pub fn mark_read(pane_id: u64) {
        let _ = fs::create_dir_all(STATUS_DIR);
        let _ = fs::write(format!("{STATUS_DIR}/{pane_id}.read"), now_rfc3339());
    }

    /// 起動時に1回だけ、存在しないペインの残骸を掃除する（仕様書 §2.2）。
    pub fn gc(live_pane_ids: &[u64]) {
        let Ok(entries) = fs::read_dir(STATUS_DIR) else {
            return;
        };
        for entry in entries.flatten() {
            let name = entry.file_name();
            let Some(name) = name.to_str() else { continue };
            // "<id>" / "<id>.jsonl" / "<id>.read" のいずれか
            let stem = name.split('.').next().unwrap_or("");
            let Ok(id) = stem.parse::<u64>() else { continue };
            if !live_pane_ids.contains(&id) {
                let _ = fs::remove_file(entry.path());
            }
        }
    }
}

fn read_cursor(pane_id: u64) -> Option<String> {
    let raw = fs::read_to_string(format!("{STATUS_DIR}/{pane_id}.read")).ok()?;
    let trimmed = raw.trim().to_string();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed)
    }
}

/// serde_json で1行ずつパースする。壊れた行は黙って捨てる
/// （hook 側が追記中の半端な行を読む可能性は O_APPEND のためほぼ無いが、
///  ここで落ちると一覧全体が出なくなるので握りつぶす方を選ぶ）。
fn parse_jsonl(path: &Path) -> Vec<Notification> {
    let Ok(body) = fs::read_to_string(path) else {
        return Vec::new();
    };
    body.lines()
        .filter_map(|line| {
            let v: serde_json::Value = serde_json::from_str(line).ok()?;
            Some(Notification {
                at: v.get("at")?.as_str()?.to_string(),
                agent: v.get("agent").and_then(|x| x.as_str()).unwrap_or("").to_string(),
                kind: v.get("kind").and_then(|x| x.as_str()).unwrap_or("").to_string(),
                text: v.get("text").and_then(|x| x.as_str()).unwrap_or("").to_string(),
                task: v.get("task").and_then(|x| x.as_str()).unwrap_or("").to_string(),
                unread: false,
            })
        })
        .collect()
}

/// hook 側の `date -Iseconds` と同じ書式。
/// chrono を入れるほどの用途ではないので、UNIX時刻から自前で組み立てる。
/// ローカルオフセットは `date +%z` ではなく、標準ライブラリだけで求まる
/// 「localtime と gmtime の差」を使う……のは std だけでは取れないため、
/// 環境変数 TZ に依存しない方法として `date` を1回だけ呼ぶ。
/// 既読は稀にしか打たれないので、ここでのサブプロセス起動は毎ティックの
/// コスト計算（仕様書 §4.4）には入らない。
/// なお `date` も PATH 解決に頼らない。キーバインドから起動されると PATH が
/// 最小構成のことがあるため（wezterm.rs の wezterm_bin() と同じ理由）。
fn now_rfc3339() -> String {
    for bin in ["/bin/date", "date"] {
        let out = std::process::Command::new(bin)
            .arg("-Iseconds")
            .output()
            .ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
        if let Some(s) = out {
            return s;
        }
    }
    // ここに来ると既読判定が壊れる（全部未読になる）が、落とすよりはまし。
    "1970-01-01T00:00:00+00:00".to_string()
}

/// cwd から git ブランチ名を求める。`git` は起動しない（仕様書 §4.4）。
///
/// 実測で `git branch --show-current` が約5,300µs、`.git/HEAD` の直読みが
/// 約12µs と440倍差があるため、TTLキャッシュ自体が不要になる。
/// リポジトリのサブディレクトリで開いている場合もあるので親を辿る。
pub fn git_branch(cwd: &str) -> Option<String> {
    let mut dir = PathBuf::from(cwd);
    for _ in 0..40 {
        let dot_git = dir.join(".git");
        match fs::metadata(&dot_git) {
            Ok(meta) if meta.is_dir() => return head_to_branch(&dot_git.join("HEAD")),
            Ok(_) => {
                // worktree では .git がファイルで、中身は
                // "gitdir: /path/to/repo/.git/worktrees/<name>"
                let body = fs::read_to_string(&dot_git).ok()?;
                let gitdir = body.trim().strip_prefix("gitdir:")?.trim();
                return head_to_branch(&PathBuf::from(gitdir).join("HEAD"));
            }
            Err(_) => {
                if !dir.pop() {
                    return None;
                }
            }
        }
    }
    None
}

fn head_to_branch(head: &Path) -> Option<String> {
    let body = fs::read_to_string(head).ok()?;
    let body = body.trim();
    match body.strip_prefix("ref:") {
        Some(r) => Some(
            r.trim()
                .strip_prefix("refs/heads/")
                .unwrap_or(r.trim())
                .to_string(),
        ),
        // detached HEAD。SHA を短縮して返す
        None if !body.is_empty() => Some(body.chars().take(7).collect()),
        None => None,
    }
}
