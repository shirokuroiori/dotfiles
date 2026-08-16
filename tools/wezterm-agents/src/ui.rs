//! ratatui による描画（仕様書 §4.2 のレイアウト）。

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph, Wrap};
use ratatui::Frame;
use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

use crate::app::{App, Row};
use crate::memo;
use crate::model::*;

/// 詳細ペインを畳む幅の閾値（仕様書 §4.2）。
pub const NARROW_COLS: u16 = 100;

/// LIST の列幅。ヘッダーと各行が同じ定数を使うことで、ズレようがない
/// 構造にする（ヘッダーだけ調整して行が追随しない、という事故を防ぐ）。
/// STATUS 列 = アイコン(1) + スペース(1) + バッジ(9) = 11。
const COL_STATUS: usize = 11;
const COL_UNREAD: usize = 3;
const COL_WS: usize = 9;
const COL_WIN: usize = 4;
const COL_TAB: usize = 4;
const COL_PANE: usize = 5;
const COL_AGENT: usize = 8;

/// 表示幅ちょうどに切り詰めてから右を空白で埋める。
///
/// 文字数（`{:<n}`）で padding してはいけない。workspace 名やブランチ名に
/// CJK が入ると1文字が2カラムを占めるため列が崩れる。bash 版で実際に
/// 崩れていた問題で、docs/wezterm-ai-agent-ideas.md にも経緯が残っている。
pub fn fit(s: &str, width: usize) -> String {
    if width == 0 {
        return String::new();
    }
    let total = s.width();
    let mut out = String::new();
    let mut w = 0;
    if total > width {
        // 末尾に … を置くぶん1カラム空けて詰める
        for c in s.chars() {
            let cw = UnicodeWidthChar::width(c).unwrap_or(0);
            if w + cw > width - 1 {
                break;
            }
            out.push(c);
            w += cw;
        }
        out.push('…');
        w += 1;
    } else {
        out.push_str(s);
        w = total;
    }
    out.push_str(&" ".repeat(width - w));
    out
}

pub fn draw(f: &mut Frame, app: &App) {
    let area = f.area();
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(1)])
        .split(area);

    let narrow = area.width < NARROW_COLS;
    if narrow {
        if app.show_detail_fullscreen {
            draw_detail(f, chunks[0], app);
        } else {
            draw_list(f, chunks[0], app);
        }
    } else {
        let cols = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(45), Constraint::Percentage(55)])
            .split(chunks[0]);
        draw_list(f, cols[0], app);
        draw_detail(f, cols[1], app);
    }
    draw_footer(f, chunks[1], app, narrow);
}

fn draw_list(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .title(Span::styled(" LIST ", Style::default().fg(COLOR_ACCENT)));
    let inner = block.inner(area);
    f.render_widget(block, area);

    if app.rows.is_empty() {
        let msg = if app.snapshot.is_empty() {
            "対象のペインがありません"
        } else {
            "絞り込みに一致するペインがありません"
        };
        f.render_widget(Paragraph::new(msg).style(Style::default().fg(COLOR_DIM)), inner);
        return;
    }

    // ヘッダー行。列幅は上の COL_* 定数を行の描画と共有しているので、
    // ここだけ調整して行が追随しない、という事故は起きない。
    let header = format!(
        " {} {} {} {} {} {} {} {}",
        fit("", COL_STATUS),
        fit("", COL_UNREAD),
        fit("WS", COL_WS),
        fit("WIN", COL_WIN),
        fit("TAB", COL_TAB),
        fit("PANE", COL_PANE),
        fit("AGENT", COL_AGENT),
        "BRANCH",
    );
    let header_line = Line::from(Span::styled(
        header,
        Style::default().fg(COLOR_DIM).add_modifier(Modifier::BOLD),
    ));
    f.render_widget(Paragraph::new(vec![header_line]), Rect { height: 1, ..inner });
    let inner = Rect {
        y: inner.y + 1,
        height: inner.height.saturating_sub(1),
        ..inner
    };

    let height = inner.height as usize;
    let offset = app.scroll_offset(height);
    let mut lines: Vec<Line> = Vec::new();

    for (idx, row) in app.rows.iter().enumerate().skip(offset).take(height) {
        match row {
            Row::Header { group } => {
                let g = &app.snapshot.groups[*group];
                let unread = g.unread();
                let mut spans = vec![Span::styled(
                    g.label().to_string(),
                    Style::default().fg(COLOR_FG).add_modifier(Modifier::BOLD),
                )];
                if unread > 0 {
                    spans.push(Span::styled(
                        format!("  ●{unread}"),
                        Style::default().fg(COLOR_ACCENT).add_modifier(Modifier::BOLD),
                    ));
                }
                lines.push(Line::from(spans));
            }
            Row::Pane { group, pane } => {
                let p = &app.snapshot.groups[*group].panes[*pane];
                let selected = idx == app.cursor;
                // 未読の行は左端にアクセント色のバーを立てる（仕様書 §4.2）
                let bar = if selected {
                    Span::styled("▌", Style::default().fg(COLOR_ACCENT))
                } else if p.unread > 0 {
                    Span::styled("▎", Style::default().fg(COLOR_ACCENT))
                } else {
                    Span::raw(" ")
                };
                let unread = if p.unread > 0 {
                    format!("●{:<2}", p.unread)
                } else {
                    "   ".to_string()
                };
                let mut rest = Style::default();
                if p.unread > 0 || selected {
                    rest = rest.add_modifier(Modifier::BOLD);
                }
                // workspace / window / tab / pane は独立した列にする。
                // 桁揃えは文字数ではなく表示幅で行う（fit を参照）。
                lines.push(Line::from(vec![
                    bar,
                    Span::styled(
                        format!("{} ", p.state.icon()),
                        Style::default().fg(p.state.color()),
                    ),
                    // ステータスは背景塗りつぶしで出す。色だけだと
                    // waiting/done/working の区別が付きにくいため。
                    Span::styled(
                        p.state.badge(),
                        Style::default()
                            .bg(p.state.color())
                            .fg(COLOR_BADGE_FG)
                            .add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        format!(
                            " {} {} {} {} {} {} {}",
                            fit(&unread, COL_UNREAD),
                            fit(&p.workspace, COL_WS),
                            fit(&p.window_id.to_string(), COL_WIN),
                            fit(&p.tab_id.to_string(), COL_TAB),
                            fit(&p.pane_id.to_string(), COL_PANE),
                            fit(p.agent.as_deref().unwrap_or("-"), COL_AGENT),
                            p.branch.as_deref().unwrap_or("-"),
                        ),
                        rest,
                    ),
                ]));
            }
        }
    }
    f.render_widget(Paragraph::new(lines), inner);
}

fn draw_detail(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .title(Span::styled(" DETAIL ", Style::default().fg(COLOR_ACCENT)));
    let inner = block.inner(area);
    f.render_widget(block, area);

    let Some(p) = app.selected_pane() else {
        f.render_widget(
            Paragraph::new("選択中のペインがありません").style(Style::default().fg(COLOR_DIM)),
            inner,
        );
        return;
    };

    let label = |k: &str| Span::styled(format!("{k:<9}: "), Style::default().fg(COLOR_DIM));
    let mut lines = vec![
        Line::from(Span::styled(
            p.project().to_string(),
            Style::default().fg(COLOR_FG).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(vec![
            label("status"),
            Span::styled(
                format!("{} ", p.state.icon()),
                Style::default().fg(p.state.color()),
            ),
            Span::styled(
                p.state.badge(),
                Style::default()
                    .bg(p.state.color())
                    .fg(COLOR_BADGE_FG)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {}", p.state.label()),
                Style::default().fg(COLOR_DIM),
            ),
        ]),
        Line::from(vec![
            label("agent"),
            Span::raw(p.agent.clone().unwrap_or_else(|| "-".into())),
        ]),
        Line::from(vec![label("cwd"), Span::raw(shorten_home(&p.cwd))]),
        Line::from(vec![
            label("branch"),
            Span::raw(p.branch.clone().unwrap_or_else(|| "-".into())),
        ]),
        Line::from(vec![label("task"), Span::raw(p.task.clone())]),
        Line::from(""),
        section("位置", inner.width),
        // workspace/window/tab/pane は他のフィールドと粒度が違う
        // （同じ「ペインの所在」を表す4つの値）ので、独立したセクションに
        // 分けて他フィールドと同じ label() 書式で1つずつ出す。
        Line::from(vec![label("workspace"), Span::raw(p.workspace.clone())]),
        Line::from(vec![label("window"), Span::raw(p.window_id.to_string())]),
        Line::from(vec![label("tab"), Span::raw(p.tab_id.to_string())]),
        Line::from(vec![label("pane"), Span::raw(p.pane_id.to_string())]),
        Line::from(""),
        section("通知", inner.width),
    ];

    if p.notifications.is_empty() {
        lines.push(Line::from(Span::styled(
            "  （まだありません）",
            Style::default().fg(COLOR_DIM),
        )));
    } else {
        for n in &p.notifications {
            let marker = if n.unread { "●" } else { " " };
            let style = if n.unread {
                Style::default().fg(COLOR_ACCENT).add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(COLOR_DIM)
            };
            lines.push(Line::from(vec![
                Span::styled(format!("{marker} {} ", n.hhmm()), style),
                Span::raw(n.text.clone()),
            ]));
            // 通知の text は状態ごとの固定文言なので、それだけだと情報量がない。
            // 発火時点のタスク内容（ペインタイトル）を添えて「何をしていたか」を
            // 追えるようにする（仕様書 §2.2 の task フィールドの目的）。
            let task = crate::model::task_from_title(&n.task);
            if task != "-" {
                lines.push(Line::from(Span::styled(
                    format!("    └ {task}"),
                    Style::default().fg(COLOR_DIM),
                )));
            }
        }
    }

    lines.push(Line::from(""));
    lines.push(section("メモ", inner.width));
    // 「# メモ」節（人間の自由編集領域）だけを見せる。「## ログ」は
    // hook が書く場所で、ここには出さない（仕様書 §5.1 の役割分担）。
    // ファイル I/O はここで発生するが、draw() は入力かティックのたびに
    // 高々1回しか呼ばれないので、format-tab-title の話（毎フレーム・
    // GUIレンダースレッド）とは事情が違う（§3.2.1 の制約はここには適用外）。
    match memo::read_preview(p.tab_id) {
        Some(body) => {
            const MAX_LINES: usize = 8;
            let body_lines: Vec<&str> = body.lines().collect();
            for line in body_lines.iter().take(MAX_LINES) {
                lines.push(Line::from(Span::raw(format!("  {line}"))));
            }
            if body_lines.len() > MAX_LINES {
                lines.push(Line::from(Span::styled(
                    format!("  … 他 {} 行（`e` で全文編集）", body_lines.len() - MAX_LINES),
                    Style::default().fg(COLOR_DIM),
                )));
            }
        }
        None => {
            lines.push(Line::from(Span::styled(
                "  （まだメモはありません。`e` で編集）",
                Style::default().fg(COLOR_DIM),
            )));
        }
    }

    f.render_widget(Paragraph::new(lines).wrap(Wrap { trim: false }), inner);
}

fn section(title: &str, width: u16) -> Line<'static> {
    let dashes = (width as usize).saturating_sub(title.width() + 4);
    Line::from(Span::styled(
        format!("── {title} {}", "─".repeat(dashes)),
        Style::default().fg(COLOR_DIM),
    ))
}

fn draw_footer(f: &mut Frame, area: Rect, app: &App, narrow: bool) {
    if let Some(msg) = &app.message {
        f.render_widget(
            Paragraph::new(Span::styled(
                format!(" {msg}"),
                Style::default().fg(COLOR_WAITING),
            )),
            area,
        );
        return;
    }
    if app.filter_active {
        f.render_widget(
            Paragraph::new(Span::styled(
                format!(" /{}", app.filter),
                Style::default().fg(COLOR_ACCENT),
            )),
            area,
        );
        return;
    }

    let mut hints = vec![
        "↑/↓ 移動",
        "⏎ ジャンプ",
        "e メモ",
        "r 既読",
        "R 全既読",
        "/ 絞込",
        "g 更新",
        "q 終了",
    ];
    if narrow {
        hints.insert(1, "Tab 詳細");
    }
    f.render_widget(
        Paragraph::new(Span::styled(
            format!(" {}", hints.join("  ")),
            Style::default().fg(COLOR_DIM),
        )),
        area,
    );
}

fn shorten_home(path: &str) -> String {
    match std::env::var("HOME") {
        Ok(home) if !home.is_empty() && path.starts_with(&home) => {
            format!("~{}", &path[home.len()..])
        }
        _ => path.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// fit は列揃えの要なので、幅がちょうど合うことを保証する。
    #[test]
    fn fit_pads_and_truncates_by_display_width() {
        assert_eq!(fit("abc", 6).width(), 6);
        assert_eq!(fit("abc", 6), "abc   ");
        // CJK は1文字2カラム。文字数で数えると崩れる
        assert_eq!(fit("あい", 6).width(), 6);
        assert_eq!(fit("あい", 6), "あい  ");
        // ちょうど収まるときは切り詰めない
        assert_eq!(fit("あいう", 6), "あいう");
        // はみ出すときは … を付けて幅ちょうどに収める
        assert_eq!(fit("あいうえ", 6).width(), 6);
        assert_eq!(fit("abcdefgh", 4).width(), 4);
        assert_eq!(fit("abcdefgh", 4), "abc…");
        // 2カラム文字が境界にかかるケースでも幅を超えない
        assert_eq!(fit("あいう", 4).width(), 4);
        assert_eq!(fit("", 3), "   ");
        assert_eq!(fit("abc", 0), "");
    }
}
