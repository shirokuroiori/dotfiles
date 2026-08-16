//! WezTerm 上のAIエージェントを一覧・監視し、選んだペインへジャンプするTUI。
//! 設計は docs/plans/wezterm-multi-agent-spec.md §4。
//!
//! 使い方:
//!   wezterm-agents                 ランチャー。選んでジャンプしたら終了
//!   wezterm-agents --watch         常駐ダッシュボード。ジャンプしても残る
//!   wezterm-agents --print         対話なしで一覧を1回出して終了
//!   wezterm-agents --interval 3    ティック間隔(秒)を明示指定

mod app;
mod memo;
mod model;
mod store;
mod ui;
mod wezterm;

use std::io::{self, Stdout};
use std::process::Command;
use std::time::{Duration, Instant};

use ratatui::crossterm::event::{
    self, DisableFocusChange, EnableFocusChange, Event, KeyCode, KeyEvent, KeyEventKind,
    KeyModifiers,
};
use ratatui::crossterm::execute;
use ratatui::crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::prelude::CrosstermBackend;
use ratatui::Terminal;

use app::App;
use model::State;

/// ティック間隔（仕様書 §4.4）。
/// ランチャーは数秒で消えるので 1Hz でよい。--watch は常駐するため落とす。
/// 非フォーカス時にさらに落とすのは、見えていない画面のために CPU を
/// 起こしてノートPCの深いアイドルを妨げないため。
const TICK_LAUNCHER: Duration = Duration::from_secs(1);
const TICK_WATCH_FOCUSED: Duration = Duration::from_secs(2);
const TICK_WATCH_BLURRED: Duration = Duration::from_secs(5);

struct Options {
    watch: bool,
    print: bool,
    interval: Option<Duration>,
}

fn parse_args() -> Result<Options, String> {
    let mut opts = Options {
        watch: false,
        print: false,
        interval: None,
    };
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--watch" | "-w" => opts.watch = true,
            "--print" | "-p" => opts.print = true,
            "--interval" | "-i" => {
                let v = args.next().ok_or("--interval には秒数が要ります")?;
                let secs: u64 = v.parse().map_err(|_| format!("秒数が不正です: {v}"))?;
                if secs == 0 {
                    return Err("--interval は1以上にしてください".into());
                }
                opts.interval = Some(Duration::from_secs(secs));
            }
            "--help" | "-h" => {
                print_help();
                std::process::exit(0);
            }
            other => return Err(format!("不明なオプション: {other}")),
        }
    }
    Ok(opts)
}

fn print_help() {
    println!(
        "\
WezTerm 上のAIエージェント一覧

  wezterm-agents                 ランチャー（ジャンプで終了）
  wezterm-agents --watch         常駐ダッシュボード
  wezterm-agents --print         対話なしで1回表示して終了
  wezterm-agents --interval <秒> ティック間隔を明示指定

キー:
  ↑/↓ k/j  移動      ⏎  ジャンプ    e  メモ編集
  r 既読    R 全既読   /  絞り込み    g  即時更新
  Tab 詳細(幅が狭いとき)             q/Esc 終了"
    );
}

fn main() {
    let opts = match parse_args() {
        Ok(o) => o,
        Err(e) => {
            eprintln!("{e}");
            eprintln!("`--help` で使い方を表示します");
            std::process::exit(2);
        }
    };

    if opts.print {
        print_once();
        return;
    }

    if let Err(e) = run(opts) {
        eprintln!("{e}");
        std::process::exit(1);
    }
}

/// `--print` 用のステータスバッジ。ratatui を通さないので ANSI を直接組む。
/// TUI 側（ui.rs）と同じ配色・同じ文字列にして見た目を揃える。
fn ansi_badge(state: State) -> String {
    let (r, g, b) = match state {
        State::Working => (0xFF, 0xCC, 0x00),
        State::Waiting => (0xFE, 0x44, 0x50),
        State::Done => (0x50, 0xfa, 0x7b),
        State::Idle => (0x6B, 0x7A, 0x8F),
    };
    format!(
        "\x1b[48;2;{r};{g};{b}m\x1b[38;2;32;9;51m\x1b[1m{}\x1b[0m",
        state.badge()
    )
}

/// 対話なしの静的表示。/dev/tty が無い環境やデバッグ用。
fn print_once() {
    let mut app = App::new(false);
    app.refresh();
    if let Some(msg) = &app.message {
        eprintln!("{msg}");
    }
    for group in &app.snapshot.groups {
        let unread = group.unread();
        let badge = if unread > 0 {
            format!("  ●{unread}")
        } else {
            String::new()
        };
        println!("\n{} ({}){}", group.label(), group.cwd, badge);
        // 行のフォーマット文字列をそのまま使い回してヘッダーを組む。
        // 幅の数字を2箇所に別々に書くと、片方だけ直して列がズレる
        // 事故になるので、row() 1つに寄せて header/body の両方から呼ぶ。
        fn row(icon: &str, unread: &str, ws: &str, win: &str, tab: &str, pane: &str, agent: &str, branch: &str) -> String {
            format!(
                "  {icon} {} {} {} {} {} {} {branch}",
                ui::fit(unread, 3),
                ui::fit(ws, 9),
                ui::fit(win, 4),
                ui::fit(tab, 4),
                ui::fit(pane, 5),
                ui::fit(agent, 8),
            )
        }
        // icon 列は本体側で icon(1) + space(1) + badge(9) = 11 カラムを
        // 占めるので、ヘッダーもそれと同じ幅の空白を渡して揃える。
        println!(
            "{}",
            row(&" ".repeat(11), "", "WS", "WIN", "TAB", "PANE", "AGENT", "BRANCH")
        );
        for p in &group.panes {
            let unread = if p.unread > 0 {
                format!("●{}", p.unread)
            } else {
                String::new()
            };
            println!(
                "{}",
                row(
                    &format!("{} {}", p.state.icon(), ansi_badge(p.state)),
                    &unread,
                    &p.workspace,
                    &p.window_id.to_string(),
                    &p.tab_id.to_string(),
                    &p.pane_id.to_string(),
                    p.agent.as_deref().unwrap_or("-"),
                    p.branch.as_deref().unwrap_or("-"),
                )
            );
            println!("       task: {}", p.task);
        }
    }
    if app.snapshot.is_empty() {
        println!("対象のペインがありません");
    }
}

fn run(opts: Options) -> Result<(), String> {
    let mut app = App::new(!opts.watch);
    app.refresh();
    app.gc_once();
    // メモの stale GC（仕様書 §5.2）。ペインの GC（app.gc_once）と同じく
    // 起動時に1回だけ。tab_id は同じタブに複数ペインがあると重複するが、
    // gc_stale 側は最初に見つかった cwd で判定するだけなので実害はない。
    let live_tabs: Vec<(u64, String)> = app
        .snapshot
        .groups
        .iter()
        .flat_map(|g| g.panes.iter().map(|p| (p.tab_id, p.cwd.clone())))
        .collect();
    memo::gc_stale(&live_tabs);

    let mut terminal = setup_terminal().map_err(|e| format!("端末の初期化に失敗: {e}"))?;
    let result = event_loop(&mut terminal, &mut app, &opts);
    restore_terminal(&mut terminal).map_err(|e| format!("端末の復元に失敗: {e}"))?;
    result
}

fn setup_terminal() -> io::Result<Terminal<CrosstermBackend<Stdout>>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    // EnableFocusChange = DECSET 1004。タブ裏／非フォーカス時にティックを
    // 落とすための唯一の信頼できる信号（仕様書 §4.4、実測は §9.2）。
    execute!(stdout, EnterAlternateScreen, EnableFocusChange)?;
    Terminal::new(CrosstermBackend::new(stdout))
}

fn restore_terminal(terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> io::Result<()> {
    // DisableFocusChange を忘れると端末にモードが残る。
    execute!(
        terminal.backend_mut(),
        DisableFocusChange,
        LeaveAlternateScreen
    )?;
    disable_raw_mode()?;
    terminal.show_cursor()
}

fn event_loop(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    app: &mut App,
    opts: &Options,
) -> Result<(), String> {
    // 端末は 1004 を有効にした時点の状態を送ってこないため、起動直後は
    // 自分がフォーカスされているか分からない。ランチャーはユーザーが今まさに
    // 起動したものなので、フォーカス済みとみなして高速ティックから始める
    // （仕様書 §4.4）。
    let mut focused = true;
    let mut last_tick = Instant::now();

    loop {
        terminal
            .draw(|f| ui::draw(f, app))
            .map_err(|e| format!("描画に失敗: {e}"))?;

        let tick = current_tick(opts, focused);
        let mut timeout = tick.saturating_sub(last_tick.elapsed());
        // ジャンプ待ちの間は、FocusLost に素早く反応できるよう細かく回す。
        if app.pending_exit.is_some() {
            timeout = timeout.min(Duration::from_millis(20));
        }

        if event::poll(timeout).map_err(|e| format!("入力待ちに失敗: {e}"))? {
            match event::read().map_err(|e| format!("入力の読み取りに失敗: {e}"))? {
                Event::Key(key) if key.kind == KeyEventKind::Press => handle_key(app, key),
                Event::FocusGained => focused = true,
                Event::FocusLost => {
                    focused = false;
                    // ジャンプ送信後にフォーカスを失った＝移動が成立した合図。
                    app.on_focus_lost();
                }
                Event::Resize(_, _) => {}
                _ => {}
            }
        }

        // エディタは Terminal を握るので、Terminal を持たない handle_key では
        // 起動できない。ここでフラグを見て、代替スクリーンを一時的に抜けて
        // 起動する（仕様書 §5.3）。
        if let Some((tab_id, cwd)) = app.pending_edit.take() {
            if let Err(e) = open_editor(terminal, tab_id, &cwd) {
                app.message = Some(e);
            }
        }

        app.tick_pending_exit();
        if app.should_quit {
            return Ok(());
        }
        // ジャンプ待ちの最中に一覧を作り直すと、選択が動いて紛らわしいので止める。
        if app.pending_exit.is_none() && last_tick.elapsed() >= tick {
            app.refresh();
            last_tick = Instant::now();
        }
    }
}

/// メモを `$VISUAL`/`$EDITOR`/`nvim`/`vi` で編集する（仕様書 §5.3）。
/// 代替スクリーンを抜けてエディタに端末を明け渡し、終了後に再描画する。
fn open_editor(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    tab_id: u64,
    cwd: &str,
) -> Result<(), String> {
    let path = memo::ensure_file(tab_id, cwd).map_err(|e| format!("メモの作成に失敗: {e}"))?;

    disable_raw_mode().map_err(|e| format!("raw mode 解除に失敗: {e}"))?;
    execute!(
        terminal.backend_mut(),
        DisableFocusChange,
        LeaveAlternateScreen
    )
    .map_err(|e| format!("代替スクリーンの解除に失敗: {e}"))?;

    let editor = memo::resolve_editor();
    let status = Command::new(&editor).arg(&path).status();

    // エディタが失敗しても、端末は必ずTUI用の状態に戻す。
    let resume = (|| -> io::Result<()> {
        execute!(terminal.backend_mut(), EnterAlternateScreen, EnableFocusChange)?;
        enable_raw_mode()?;
        terminal.clear()
    })();

    resume.map_err(|e| format!("端末の復帰に失敗: {e}"))?;

    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("{editor} が異常終了しました ({s})")),
        Err(e) => Err(format!("{editor} の起動に失敗: {e}")),
    }
}

fn current_tick(opts: &Options, focused: bool) -> Duration {
    if let Some(d) = opts.interval {
        return d;
    }
    if !opts.watch {
        return TICK_LAUNCHER;
    }
    if focused {
        TICK_WATCH_FOCUSED
    } else {
        TICK_WATCH_BLURRED
    }
}

fn handle_key(app: &mut App, key: KeyEvent) {
    if app.filter_active {
        match key.code {
            KeyCode::Esc => {
                app.filter.clear();
                app.filter_active = false;
                app.rebuild_rows();
            }
            KeyCode::Enter => app.filter_active = false,
            KeyCode::Backspace => {
                app.filter.pop();
                app.rebuild_rows();
            }
            KeyCode::Char(c) => {
                app.filter.push(c);
                app.rebuild_rows();
            }
            _ => {}
        }
        return;
    }

    if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
        app.should_quit = true;
        return;
    }

    match key.code {
        KeyCode::Char('q') | KeyCode::Esc => app.should_quit = true,
        KeyCode::Up | KeyCode::Char('k') => app.move_cursor(-1),
        KeyCode::Down | KeyCode::Char('j') => app.move_cursor(1),
        KeyCode::Enter => app.jump_to_selected(),
        KeyCode::Char('r') => app.mark_selected_read(),
        KeyCode::Char('R') => app.mark_all_read(),
        KeyCode::Char('g') => app.refresh(),
        KeyCode::Char('/') => {
            app.filter_active = true;
            app.message = None;
        }
        KeyCode::Tab => app.show_detail_fullscreen = !app.show_detail_fullscreen,
        KeyCode::Char('e') => app.request_edit(),
        _ => {}
    }
}
