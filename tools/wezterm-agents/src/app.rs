//! アプリ状態と、一覧行の組み立て・カーソル操作。

use std::time::Duration;

use crate::model::{Pane, Snapshot};
use crate::store::Store;
use crate::wezterm;

/// ジャンプ後、FocusLost を待つ上限。実測のジャンプ所要は 50〜102ms なので
/// 十分な余裕を取りつつ、失敗しても体感で固まらない長さにする。
const JUMP_EXIT_TIMEOUT: Duration = Duration::from_millis(800);

/// 一覧の1行。カーソルが止まれるのは Pane 行だけ。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Row {
    Header { group: usize },
    Pane { group: usize, pane: usize },
}

pub struct App {
    pub snapshot: Snapshot,
    pub rows: Vec<Row>,
    pub cursor: usize,
    pub filter: String,
    pub filter_active: bool,
    pub message: Option<String>,
    pub show_detail_fullscreen: bool,
    pub should_quit: bool,
    /// ランチャーモードではジャンプしたら終了する。
    pub exit_on_jump: bool,
    /// ジャンプ送信後、フォーカスが実際に移るのを待っている間の締め切り。
    ///
    /// OSC を送った直後にプロセスを終わらせるとペインが閉じ、WezTerm が
    /// OSC を処理し終える前にフォーカスを別タブへ振り直してしまうことがある。
    /// 実測でこれは競合として不安定に再現した（成功したり失敗したりする）。
    /// ジャンプが成立すれば自分のペインは必ず FocusLost を受け取るので、
    /// それを終了の合図にする。届かない場合の保険として締め切りも持つ。
    pub pending_exit: Option<std::time::Instant>,
    /// `e` が押された次のティックで main.rs がエディタを起動するためのフラグ。
    /// app.rs は Terminal を持たないので、実際の起動処理は main.rs 側で行う。
    pub pending_edit: Option<(u64, String)>,
    store: Store,
    self_pane: Option<u64>,
}

impl App {
    pub fn new(exit_on_jump: bool) -> Self {
        let self_pane = std::env::var("WEZTERM_PANE")
            .ok()
            .and_then(|s| s.parse::<u64>().ok());
        Self {
            snapshot: Snapshot::default(),
            rows: Vec::new(),
            cursor: 0,
            filter: String::new(),
            filter_active: false,
            message: None,
            show_detail_fullscreen: false,
            should_quit: false,
            exit_on_jump,
            pending_exit: None,
            pending_edit: None,
            store: Store::new(),
            self_pane,
        }
    }

    /// `wezterm cli list` を1回呼んでスナップショットを作り直す。
    /// 失敗しても直前のスナップショットは保持し、フッターに理由を出す。
    pub fn refresh(&mut self) {
        match wezterm::list_panes() {
            Ok(panes) => {
                self.snapshot = wezterm::build_snapshot(panes, &mut self.store, self.self_pane);
                self.message = None;
            }
            Err(e) => {
                self.message = Some(e);
            }
        }
        self.rebuild_rows();
    }

    /// 起動時に1回だけ、死んだペインの状態ファイルを掃除する。
    pub fn gc_once(&self) {
        let live: Vec<u64> = self
            .snapshot
            .groups
            .iter()
            .flat_map(|g| g.panes.iter().map(|p| p.pane_id))
            .chain(self.self_pane)
            .collect();
        if !live.is_empty() {
            Store::gc(&live);
        }
    }

    fn matches_filter(&self, p: &Pane) -> bool {
        if self.filter.is_empty() {
            return true;
        }
        let needle = self.filter.to_lowercase();
        let hay = format!(
            "{} {} {} {}",
            p.cwd,
            p.branch.as_deref().unwrap_or(""),
            p.task,
            p.agent.as_deref().unwrap_or("")
        )
        .to_lowercase();
        hay.contains(&needle)
    }

    /// カーソルが指していたペインを覚えておき、再構築後も同じペインへ戻す。
    /// 1秒ごとに作り直すので、これが無いと並び替えで選択が飛ぶ。
    pub fn rebuild_rows(&mut self) {
        let anchor = self.selected_pane().map(|p| p.pane_id);
        let mut rows = Vec::new();
        for (gi, group) in self.snapshot.groups.iter().enumerate() {
            let visible: Vec<usize> = group
                .panes
                .iter()
                .enumerate()
                .filter(|(_, p)| self.matches_filter(p))
                .map(|(i, _)| i)
                .collect();
            if visible.is_empty() {
                continue;
            }
            rows.push(Row::Header { group: gi });
            for pi in visible {
                rows.push(Row::Pane { group: gi, pane: pi });
            }
        }
        self.rows = rows;

        self.cursor = anchor
            .and_then(|id| self.row_index_of_pane(id))
            .or_else(|| self.first_pane_row())
            .unwrap_or(0);
    }

    fn row_index_of_pane(&self, pane_id: u64) -> Option<usize> {
        self.rows.iter().position(|r| match r {
            Row::Pane { group, pane } => self.snapshot.groups[*group].panes[*pane].pane_id == pane_id,
            Row::Header { .. } => false,
        })
    }

    fn first_pane_row(&self) -> Option<usize> {
        self.rows
            .iter()
            .position(|r| matches!(r, Row::Pane { .. }))
    }

    pub fn selected_pane(&self) -> Option<&Pane> {
        match self.rows.get(self.cursor)? {
            Row::Pane { group, pane } => Some(&self.snapshot.groups[*group].panes[*pane]),
            Row::Header { .. } => None,
        }
    }

    /// ヘッダ行は飛ばして次の Pane 行へ。
    pub fn move_cursor(&mut self, delta: isize) {
        if self.rows.is_empty() {
            return;
        }
        let len = self.rows.len() as isize;
        let mut i = self.cursor as isize;
        for _ in 0..len {
            i += delta;
            if i < 0 {
                i = len - 1;
            } else if i >= len {
                i = 0;
            }
            if matches!(self.rows[i as usize], Row::Pane { .. }) {
                self.cursor = i as usize;
                return;
            }
        }
    }

    /// カーソルが見える位置までスクロールさせるためのオフセット。
    pub fn scroll_offset(&self, height: usize) -> usize {
        if height == 0 || self.cursor < height {
            return 0;
        }
        self.cursor + 1 - height
    }

    pub fn jump_to_selected(&mut self) {
        let Some(pane_id) = self.selected_pane().map(|p| p.pane_id) else {
            return;
        };
        match wezterm::jump(pane_id) {
            Ok(()) => {
                if self.exit_on_jump {
                    // すぐには終了しない。フォーカスが移った合図（FocusLost）を
                    // 待ってから抜ける。理由は pending_exit の説明を参照。
                    self.pending_exit =
                        Some(std::time::Instant::now() + JUMP_EXIT_TIMEOUT);
                    self.message = Some("ジャンプ中…".into());
                }
            }
            Err(e) => self.message = Some(e),
        }
    }

    /// FocusLost が来ないまま終了できなくなるのを防ぐ保険。
    pub fn tick_pending_exit(&mut self) {
        if let Some(deadline) = self.pending_exit {
            if std::time::Instant::now() >= deadline {
                self.should_quit = true;
            }
        }
    }

    /// フォーカスを失った ＝ ジャンプが成立した。
    pub fn on_focus_lost(&mut self) {
        if self.pending_exit.is_some() {
            self.should_quit = true;
        }
    }

    pub fn mark_selected_read(&mut self) {
        if let Some(p) = self.selected_pane() {
            Store::mark_read(p.pane_id);
            self.refresh();
        }
    }

    pub fn mark_all_read(&mut self) {
        let ids: Vec<u64> = self
            .snapshot
            .groups
            .iter()
            .flat_map(|g| g.panes.iter().map(|p| p.pane_id))
            .collect();
        for id in ids {
            Store::mark_read(id);
        }
        self.refresh();
    }

    /// `e` キー。実際のエディタ起動は main.rs 側（Terminal を持っている）に
    /// フラグで委譲する（仕様書 §5.3）。
    pub fn request_edit(&mut self) {
        if let Some(p) = self.selected_pane() {
            self.pending_edit = Some((p.tab_id, p.cwd.clone()));
        }
    }
}
