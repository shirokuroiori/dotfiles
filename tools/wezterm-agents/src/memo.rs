//! メモ（作業状況の保存）。仕様書 §5。
//!
//! 書き手は2つ。TUI（このモジュール）は「# メモ」節への表示と、人間が
//! エディタで編集するためのファイル用意だけを担当する。「## ログ」への
//! 追記は hook 側（.claude/hooks/wezterm-notify.sh 等）の仕事で、TUI は
//! そこを一切書かない（仕様書 §5.1 の役割分担）。
//!
//! 内部ロジックは全て `dir: &Path` を明示的に受け取る `_in` 関数として書き、
//! 公開関数はそこへ `memo_dir()` を渡すだけの薄いラッパーにしてある。
//! `HOME` を環境変数で差し替えてテストすると `cargo test` の並列実行で
//! プロセス全体の状態を取り合って壊れるため、テストは `_in` 関数へ
//! tempdir を渡す形で行う。

use std::fs;
use std::path::{Path, PathBuf};

pub fn memo_dir() -> PathBuf {
    // HOME が無い実行環境はまず無いが、無くてもクラッシュだけは避ける。
    match std::env::var("HOME") {
        Ok(h) if !h.is_empty() => PathBuf::from(h).join(".weztermemo"),
        _ => PathBuf::from("/tmp/.weztermemo"),
    }
}

fn archive_dir_in(dir: &Path) -> PathBuf {
    dir.join("archive")
}

fn path_in(dir: &Path, tab_id: u64) -> PathBuf {
    dir.join(format!("tab-{tab_id}.md"))
}

/// frontmatter の1フィールドだけを読む簡易パーサ。`---` で挟まれた領域の
/// 中から `<key>: <value>` 行を探す。YAML 全体は要らない用途なので、
/// クレートを増やさずここだけ自前で書く。
fn frontmatter_field(path: &Path, key: &str) -> Option<String> {
    let body = fs::read_to_string(path).ok()?;
    let mut in_fm = false;
    let prefix = format!("{key}:");
    for line in body.lines() {
        if line == "---" {
            if in_fm {
                break;
            }
            in_fm = true;
            continue;
        }
        if in_fm {
            if let Some(v) = line.strip_prefix(&prefix) {
                return Some(v.trim().to_string());
            }
        }
    }
    None
}

/// 「# メモ」節（人間の自由編集領域）だけを抜き出す。TUI はここだけを表示し、
/// 「## ログ」には触れない。
fn read_preview_in(dir: &Path, tab_id: u64) -> Option<String> {
    let body = fs::read_to_string(path_in(dir, tab_id)).ok()?;
    let start = body.find("# メモ")? + "# メモ".len();
    let rest = &body[start..];
    let end = rest.find("\n## ").unwrap_or(rest.len());
    let section = rest[..end].trim();
    if section.is_empty() {
        None
    } else {
        Some(section.to_string())
    }
}

pub fn read_preview(tab_id: u64) -> Option<String> {
    read_preview_in(&memo_dir(), tab_id)
}

/// タブのメモファイルを、無ければ frontmatter 付きの空メモとして作ってから
/// パスを返す。既存なら何もしない。
fn ensure_file_in(dir: &Path, tab_id: u64, cwd: &str) -> std::io::Result<PathBuf> {
    fs::create_dir_all(dir)?;
    let path = path_in(dir, tab_id);
    if !path.exists() {
        let created_at = now_rfc3339();
        let content = format!(
            "---\ntab_id: {tab_id}\ncwd: {cwd}\ncreated_at: {created_at}\n---\n\n# メモ\n\n## ログ\n\n"
        );
        fs::write(&path, content)?;
    }
    Ok(path)
}

pub fn ensure_file(tab_id: u64, cwd: &str) -> std::io::Result<PathBuf> {
    ensure_file_in(&memo_dir(), tab_id, cwd)
}

/// hook 側と同じ書式（RFC3339）。`.jsonl`/`.read` と時刻の見た目を揃える。
/// 外部コマンドの解決に PATH を当てにしない（wezterm.rs の wezterm_bin() と
/// 同じ理由。§9.6 で実際に PATH 解決に頼って壊れた経緯がある）。
fn now_rfc3339() -> String {
    for bin in ["/bin/date", "date"] {
        if let Ok(out) = std::process::Command::new(bin).arg("-Iseconds").output() {
            if let Ok(s) = String::from_utf8(out.stdout) {
                let s = s.trim();
                if !s.is_empty() {
                    return s.to_string();
                }
            }
        }
    }
    "1970-01-01T00:00:00+00:00".to_string()
}

/// エディタの解決順（仕様書 §5.3）: `$VISUAL` → `$EDITOR` → `nvim` → `vi`。
pub fn resolve_editor() -> String {
    for var in ["VISUAL", "EDITOR"] {
        if let Ok(v) = std::env::var(var) {
            if !v.trim().is_empty() {
                return v;
            }
        }
    }
    for candidate in ["nvim", "vi"] {
        if which(candidate) {
            return candidate.to_string();
        }
    }
    "vi".to_string()
}

fn which(bin: &str) -> bool {
    let Ok(path) = std::env::var("PATH") else {
        return false;
    };
    path.split(':').any(|dir| Path::new(dir).join(bin).is_file())
}

/// 起動時に1回だけ実行する stale GC（仕様書 §5.2）。
///
/// `tab_id` は WezTerm 再起動で 0 から振り直されるため、`~/.weztermemo` は
/// 永続なのに「昔の tab 3」のメモが「今の tab 3」に誤って紐づきうる。
/// frontmatter の `cwd` を現在のタブの cwd と突き合わせて判定する。
/// 一致しない・tab_id が現存しないメモは `archive/` へ退避する。
fn gc_stale_in(dir: &Path, live: &[(u64, String)]) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        let Some(id_str) = name.strip_prefix("tab-").and_then(|s| s.strip_suffix(".md")) else {
            continue;
        };
        let Ok(tab_id) = id_str.parse::<u64>() else {
            continue;
        };

        let current_cwd = live.iter().find(|(id, _)| *id == tab_id).map(|(_, c)| c.as_str());
        let stale = match current_cwd {
            None => true,
            Some(cwd) => frontmatter_field(&path, "cwd").as_deref() != Some(cwd),
        };
        if !stale {
            continue;
        }

        let archive = archive_dir_in(dir);
        if fs::create_dir_all(&archive).is_err() {
            continue;
        }
        let created_at = frontmatter_field(&path, "created_at").unwrap_or_else(|| "unknown".into());
        // ファイル名に使うのでコロン等は潰す。
        let safe_created_at: String = created_at
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() || c == '-' { c } else { '_' })
            .collect();
        let dest = archive.join(format!("tab-{tab_id}-{safe_created_at}.md"));
        let _ = fs::rename(&path, dest);
    }
}

pub fn gc_stale(live: &[(u64, String)]) {
    gc_stale_in(&memo_dir(), live)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// 各テストが自分専用の一時ディレクトリを使う。std::env::temp_dir() +
    /// プロセスID + テスト内カウンタで、並列実行しても衝突しない名前にする。
    fn tmp_dir(label: &str) -> PathBuf {
        let nanos = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
        let dir = std::env::temp_dir().join(format!(
            "wezterm-agents-memo-test-{}-{}-{}",
            std::process::id(),
            label,
            nanos
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn ensure_file_creates_frontmatter_and_sections() {
        let dir = tmp_dir("ensure");
        let path = ensure_file_in(&dir, 3, "/Users/io/dotfiles").unwrap();
        let body = fs::read_to_string(&path).unwrap();
        assert!(body.starts_with("---\ntab_id: 3\n"));
        assert!(body.contains("cwd: /Users/io/dotfiles\n"));
        assert!(body.contains("# メモ"));
        assert!(body.contains("## ログ"));

        // 既存なら上書きしない
        fs::write(&path, "changed").unwrap();
        ensure_file_in(&dir, 3, "/Users/io/dotfiles").unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "changed");
    }

    #[test]
    fn read_preview_extracts_only_memo_section() {
        let dir = tmp_dir("preview");
        fs::write(
            dir.join("tab-5.md"),
            "---\ntab_id: 5\ncwd: /x\ncreated_at: t\n---\n\n\
             # メモ\n\n- [x] a\n- [ ] b\n\n\
             ## ログ\n\n- 2026-08-16 10:00 claude: 何か\n",
        )
        .unwrap();
        let preview = read_preview_in(&dir, 5).unwrap();
        assert_eq!(preview, "- [x] a\n- [ ] b");
        assert!(!preview.contains("ログ"));
        assert!(!preview.contains("claude"));
    }

    #[test]
    fn read_preview_none_when_memo_section_empty_or_missing() {
        let dir = tmp_dir("preview-empty");
        assert_eq!(read_preview_in(&dir, 1), None); // ファイルが無い

        fs::write(dir.join("tab-2.md"), "---\ntab_id: 2\ncwd: /x\ncreated_at: t\n---\n\n# メモ\n\n## ログ\n\n- x\n").unwrap();
        assert_eq!(read_preview_in(&dir, 2), None); // 空
    }

    #[test]
    fn gc_stale_archives_missing_and_mismatched_cwd() {
        let dir = tmp_dir("gc");
        // tab 1: 現存し cwd も一致 → 残る
        fs::write(dir.join("tab-1.md"), "---\ntab_id: 1\ncwd: /a\ncreated_at: t1\n---\n\n# メモ\n").unwrap();
        // tab 2: 現存するが cwd が食い違う → archive行き
        fs::write(dir.join("tab-2.md"), "---\ntab_id: 2\ncwd: /old\ncreated_at: t2\n---\n\n# メモ\n").unwrap();
        // tab 3: もう存在しないタブ → archive行き
        fs::write(dir.join("tab-3.md"), "---\ntab_id: 3\ncwd: /c\ncreated_at: t3\n---\n\n# メモ\n").unwrap();

        let live = vec![(1u64, "/a".to_string()), (2u64, "/new".to_string())];
        gc_stale_in(&dir, &live);

        assert!(dir.join("tab-1.md").exists(), "一致するものは残るべき");
        assert!(!dir.join("tab-2.md").exists(), "cwd不一致は退避されるべき");
        assert!(!dir.join("tab-3.md").exists(), "存在しないtabは退避されるべき");

        let archived: Vec<_> = fs::read_dir(archive_dir_in(&dir))
            .unwrap()
            .filter_map(|e| e.ok())
            .map(|e| e.file_name().to_string_lossy().into_owned())
            .collect();
        assert_eq!(archived.len(), 2);
        assert!(archived.iter().any(|n| n.starts_with("tab-2-")));
        assert!(archived.iter().any(|n| n.starts_with("tab-3-")));
    }

    #[test]
    fn gc_stale_is_noop_on_missing_dir() {
        // 呼び出し自体が失敗しない（存在しないディレクトリでもパニックしない）
        let dir = std::env::temp_dir().join("wezterm-agents-memo-test-does-not-exist");
        gc_stale_in(&dir, &[]);
    }
}
