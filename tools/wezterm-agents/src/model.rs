//! 表示に使うデータ構造と、状態の導出ロジック。
//!
//! 状態の定義は仕様書 §2.1 のとおり。
//!   working … エージェントが応答生成中（ペインタイトルのスピナーで検知）
//!   waiting … 承認・入力待ち（既読でも解除しない）
//!   done    … 応答完了かつ未読
//!   idle    … 上記以外（既読になった done を含む）

use ratatui::style::Color;

/// voltwave カラースキームに合わせる（.config/wezterm/colors/voltwave.toml）。
pub const COLOR_WAITING: Color = Color::Rgb(0xFE, 0x44, 0x50);
pub const COLOR_DONE: Color = Color::Rgb(0x50, 0xfa, 0x7b);
pub const COLOR_WORKING: Color = Color::Rgb(0xFF, 0xCC, 0x00);
pub const COLOR_ACCENT: Color = Color::Rgb(0x38, 0xda, 0xff);
pub const COLOR_DIM: Color = Color::Rgb(0x6B, 0x7A, 0x8F);
pub const COLOR_FG: Color = Color::Rgb(0x72, 0xF1, 0xB8);
/// 塗りつぶしバッジの文字色。voltwave の背景色と同じにして、
/// 明るいステータス色の上でも沈んで読めるようにする。
pub const COLOR_BADGE_FG: Color = Color::Rgb(0x20, 0x09, 0x33);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum State {
    Working,
    Waiting,
    Done,
    Idle,
}

impl State {
    /// 状態アイコン（Nerd Font）。コードポイントは nerd-fonts の
    /// glyphnames.json から引いた値で、`Bizin Gothic Discord NF` で
    /// 描画できることを実機確認済み。
    ///   waiting  nf-cod-stop_circle          U+EBA5
    ///   working  nf-cod-session_in_progress  U+EC77
    ///   done     nf-fa-ok_sign               U+F058
    ///   idle     nf-md-sleep                 U+F04B2
    ///
    /// いずれも私用領域なので `unicode-width` は幅1と数える。仮に端末が
    /// 2セルで描いても、全行がアイコンを1つ持つぶんズレは一律なので
    /// 行同士の桁揃えは崩れない。
    pub fn icon(self) -> &'static str {
        match self {
            State::Working => "\u{ec77}",
            State::Waiting => "\u{eba5}",
            State::Done => "\u{f058}",
            State::Idle => "\u{f04b2}",
        }
    }

    /// 背景を塗りつぶして表示するステータスバッジの文字列。
    /// 前後に空白を入れて塗りに余白を作り、幅を揃える（全て9カラム）。
    pub fn badge(self) -> &'static str {
        match self {
            State::Working => " WORKING ",
            State::Waiting => " WAITING ",
            State::Done => " DONE    ",
            State::Idle => " IDLE    ",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            State::Working => "応答生成中",
            State::Waiting => "承認/入力待ち",
            State::Done => "応答完了",
            State::Idle => "待機中",
        }
    }

    pub fn color(self) -> Color {
        match self {
            State::Working => COLOR_WORKING,
            State::Waiting => COLOR_WAITING,
            State::Done => COLOR_DONE,
            State::Idle => COLOR_DIM,
        }
    }
}

/// `.jsonl` の1行に対応する通知イベント。
#[derive(Debug, Clone)]
pub struct Notification {
    pub at: String,
    pub agent: String,
    pub kind: String,
    pub text: String,
    pub task: String,
    /// `.read` より新しいか。未読件数はこれを数えた導出値（仕様書 §1）。
    pub unread: bool,
}

impl Notification {
    /// "2026-08-16T21:40:03+09:00" -> "21:40"
    pub fn hhmm(&self) -> &str {
        self.at.get(11..16).unwrap_or("--:--")
    }
}

#[derive(Debug, Clone)]
pub struct Pane {
    pub pane_id: u64,
    pub window_id: u64,
    pub tab_id: u64,
    pub workspace: String,
    pub cwd: String,
    pub branch: Option<String>,
    pub agent: Option<String>,
    pub state: State,
    pub unread: usize,
    /// 新しい順、最大10件。
    pub notifications: Vec<Notification>,
    /// 直近のタスク内容（ペインタイトルから導出）。
    pub task: String,
}

impl Pane {
    pub fn project(&self) -> &str {
        self.cwd.rsplit('/').find(|s| !s.is_empty()).unwrap_or(&self.cwd)
    }
}

#[derive(Debug, Clone)]
pub struct Group {
    pub cwd: String,
    pub panes: Vec<Pane>,
}

impl Group {
    pub fn label(&self) -> &str {
        self.cwd.rsplit('/').find(|s| !s.is_empty()).unwrap_or(&self.cwd)
    }

    pub fn unread(&self) -> usize {
        self.panes.iter().map(|p| p.unread).sum()
    }
}

#[derive(Debug, Clone, Default)]
pub struct Snapshot {
    pub groups: Vec<Group>,
}

impl Snapshot {
    pub fn is_empty(&self) -> bool {
        self.groups.is_empty()
    }
}

/// ペインタイトル先頭のスピナー文字で「応答生成中」を判定する。
///
/// hook ではなくエージェント自身が画面に出す合図を見るので、Esc 中断のように
/// 終了系 hook が発火しないケースでも追従できる（wezterm.lua と同じ考え方）。
///
/// 2種類ある。Claude Code のバージョンでどちらを使うか変わる
/// （`bin/wezterm-agents` で 2.1.233 にて円形スピナーへの変更を確認済み）。
///   - 点字スピナー ⠀-⣿ (U+2800-U+28FF)（旧 Claude Code）
///   - 円形スピナー ◐◓◑◒ (U+25D0-U+25D3)（現行 Claude Code）
///

/// 既知の制限: Copilot CLI はタイトルにスピナーを出さず、画面最終行に
/// ステータス行を描く。それを読むにはペインごとに `wezterm cli get-text` を
/// 呼ぶ必要があり、1ティック1サブプロセスという方針（仕様書 §4.4）に反する。
/// そのため TUI 上では Copilot の working は検知しない（タブ色の方は
/// wezterm.lua が GUI プロセス内から安価に見ているので従来どおり動く）。
/// 置き換え対象の bash 版も同じ制限だったため、後退ではない。
pub fn is_working_title(title: &str) -> bool {
    matches!(title.chars().next(), Some(c) if
        ('\u{2800}'..='\u{28FF}').contains(&c) || ('\u{25D0}'..='\u{25D3}').contains(&c))
}

/// タイトルからタスク表示用のテキストを作る。
/// 先頭のスピナー文字と記号を落とし、プロセス名だけのものは "-" にする。
pub fn task_from_title(title: &str) -> String {
    let trimmed = title
        .trim_start_matches(|c: char| {
            ('\u{2800}'..='\u{28FF}').contains(&c)
                || ('\u{25D0}'..='\u{25D3}').contains(&c)
                || c == '✳'
                || c.is_whitespace()
        })
        .trim();
    match trimmed {
        "" | "zsh" | "bash" | "nvim" | "vim" | "node" | "claude" | "copilot" | "wezterm-gui" => {
            "-".to_string()
        }
        other => other.to_string(),
    }
}

/// 通知履歴と working 判定から状態を決める。
///
/// waiting は既読でも解除しない。実際に入力を求められている状態であり、
/// ユーザーが応答すればエージェントが動き出して working 検知に移るため、
/// 放っておいても自然に解消される（仕様書 §2.1）。
pub fn derive_state(working: bool, notifications: &[Notification]) -> State {
    if working {
        return State::Working;
    }
    match notifications.first() {
        Some(n) if n.kind == "waiting" => State::Waiting,
        Some(n) if n.kind == "done" => {
            if n.unread {
                State::Done
            } else {
                State::Idle
            }
        }
        _ => State::Idle,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_both_spinner_styles() {
        // 点字スピナー（旧 Claude Code）
        assert!(is_working_title("\u{28C0} 何かの要約"));
        // 円形スピナー（現行 Claude Code。実機の pane タイトルで確認: ◐）
        assert!(is_working_title("◐ Wezterm マルチエージェント計画の要件分析"));
        assert!(is_working_title("◓ x"));
        assert!(is_working_title("◑ x"));
        assert!(is_working_title("◒ x"));
        // 見た目が近い別記号(◎●○◉)は誤検知しない
        assert!(!is_working_title("◎ x"));
        assert!(!is_working_title("● x"));
        assert!(!is_working_title("nvim"));
        assert!(!is_working_title(""));
    }

    #[test]
    fn task_from_title_strips_both_spinner_styles() {
        assert_eq!(task_from_title("◐ Wezterm マルチエージェント計画の要件分析"), "Wezterm マルチエージェント計画の要件分析");
        assert_eq!(task_from_title("\u{28C0} タスクの要約"), "タスクの要約");
        assert_eq!(task_from_title("✳ 通常時のタイトル"), "通常時のタイトル");
    }
}
