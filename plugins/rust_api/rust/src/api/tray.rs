use crate::frb_generated::StreamSink;
use crate::tray;
use flutter_rust_bridge::for_generated::SseCodec;
use flutter_rust_bridge::frb;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrayItemKind {
    Action,
    Checkbox,
    Submenu,
    Separator,
}

/// A small leading glyph: a PNG when one is given, otherwise up to two
/// letters on a rounded square. Colors are ARGB.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayItemIcon {
    pub monogram: String,
    pub background: u32,
    pub foreground: u32,
    pub png: Option<Vec<u8>>,
}

/// A trailing pill, such as a delay. Colors are ARGB.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayItemBadge {
    pub label: String,
    pub background: u32,
    pub foreground: u32,
}

#[frb]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayItem {
    pub id: u32,
    pub kind: TrayItemKind,
    pub label: String,
    pub detail: Option<String>,
    pub enabled: bool,
    pub checked: bool,
    pub items: Vec<TrayItem>,
    /// A disabled action that only reports a state; an open menu keeps its
    /// row in place and swaps the text when the state changes.
    pub transient_status_key: Option<String>,
    /// Neighbouring checkboxes with the same group are drawn as one
    /// segmented control on macOS.
    pub segment_group: Option<String>,
    /// Shown as an alert once when a segment group reports an error.
    pub segment_error: Option<String>,
    pub icon: Option<TrayItemIcon>,
    pub badge: Option<TrayItemBadge>,
    pub accessibility_label: Option<String>,
    /// An action whose selection leaves the macOS menu open, so the rows
    /// it updates can be watched; its row stays highlightable while
    /// disabled. Ignored elsewhere.
    #[frb(default = false)]
    pub keeps_menu_open: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrayIconPlacement {
    Leading,
    Trailing,
}

/// A status dot on the icon's top-right corner that keeps its colour while
/// the icon follows the menu bar; macOS only. The color is ARGB.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TrayDot {
    pub color: u32,
    /// Fades between full and 40% opacity every two seconds, unless the
    /// system asks to reduce motion.
    pub breathing: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayImage {
    pub path: String,
    pub pngs: Vec<Vec<u8>>,
    pub template: bool,
    pub size: u32,
    pub placement: TrayIconPlacement,
    pub dot: Option<TrayDot>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayContent {
    pub id: String,
    pub image: TrayImage,
    pub tool_tip: String,
    pub title: String,
    pub menu: Vec<TrayItem>,
    /// Names this menu in later selections on macOS, where an open menu may
    /// outlive the content that built it. Zero where unused.
    pub menu_generation: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TraySignalKind {
    IconActivated,
    MenuRequested,
    ItemSelected,
    /// The menu generations the native side still holds, and the one being
    /// tracked, if a menu is open.
    MenuGenerations,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TraySignal {
    pub kind: TraySignalKind,
    pub item_id: u32,
    pub menu_generation: u32,
    pub generations: Vec<u32>,
    pub tracking_generation: Option<u32>,
}

#[frb]
pub fn tray_signals(sink: StreamSink<TraySignal, SseCodec>) {
    tray::listen(sink);
}

#[frb(sync)]
pub fn show_tray(content: TrayContent) -> bool {
    tray::show(content)
}

#[frb(sync)]
pub fn set_tray_title(title: String) -> bool {
    tray::set_title(title)
}

#[frb(sync)]
pub fn hide_tray() {
    tray::hide();
}

#[frb(sync)]
pub fn open_tray_menu() -> bool {
    tray::open_menu()
}
