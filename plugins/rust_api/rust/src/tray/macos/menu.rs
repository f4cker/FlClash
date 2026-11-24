//! The macOS tray menu: native rows drawn by custom views so a row can carry
//! a leading icon, a trailing badge and a detail next to the submenu arrow,
//! neighbouring checkboxes of one segment group become a segmented control,
//! and a menu that is open while new content arrives is updated in place
//! rather than replaced under the pointer.

use super::super::emit_signal;
use crate::api::tray::{
    TrayItem, TrayItemBadge, TrayItemIcon, TrayItemKind, TraySignal, TraySignalKind,
};
use block2::RcBlock;
use dispatch2::DispatchQueue;
use objc2::rc::{Retained, Weak};
use objc2::runtime::{AnyObject, Bool, ProtocolObject};
use objc2::{
    available, define_class, msg_send, sel, AllocAnyThread, DefinedClass, MainThreadMarker,
    MainThreadOnly, Message,
};
use objc2_app_kit::{
    NSAccessibility, NSAccessibilityButtonRole, NSAccessibilityGroupRole,
    NSAccessibilityMenuItemRole, NSAccessibilityPostNotification,
    NSAccessibilityTitleChangedNotification, NSAccessibilityValueChangedNotification, NSAlert,
    NSAlertStyle, NSAppearanceCustomization, NSAppearanceNameAqua, NSAppearanceNameDarkAqua,
    NSApplication, NSAutoresizingMaskOptions, NSBezierPath, NSBitmapImageRep, NSColor,
    NSCompositingOperation, NSControlStateValueOff, NSControlStateValueOn, NSEvent,
    NSEventMask, NSEventModifierFlags, NSEventType, NSFont, NSFontAttributeName, NSFontWeight,
    NSFontWeightMedium, NSFontWeightRegular, NSFontWeightSemibold,
    NSForegroundColorAttributeName, NSImage, NSImageSymbolConfiguration,
    NSLineBreakMode, NSMenu, NSMenuDelegate, NSMenuItem, NSMutableParagraphStyle,
    NSParagraphStyleAttributeName, NSRectFillUsingOperation, NSResponder, NSStringDrawing,
    NSStringDrawingOptions, NSStringNSExtendedStringDrawing, NSTextAlignment, NSTrackingArea,
    NSTrackingAreaOptions, NSView,
};
use objc2_foundation::{
    NSArray, NSAttributedStringKey, NSData, NSDictionary, NSNumber, NSObject, NSObjectProtocol,
    NSPoint, NSRect, NSSize, NSString,
};
use std::cell::{Cell, RefCell};
use std::ptr::{null_mut, NonNull};

const ROOT_MAXIMUM_WIDTH: f64 = 380.0;
const SUBMENU_MAXIMUM_WIDTH: f64 = 420.0;
const DETAIL_GAP: f64 = 12.0;
const ARROW_GAP: f64 = 8.0;
const BADGE_GAP: f64 = 8.0;
const BADGE_ARROW_GAP: f64 = 5.0;
const BADGE_PADDING: f64 = 3.0;
const BADGE_MINIMUM_WIDTH: f64 = 28.0;
const DETAIL_MAXIMUM_WIDTH: f64 = 110.0;
/// A group row's selection up to this wide is never cut, and a longer one is
/// cut no further: six CJK characters at 13pt. Beside a 3-digit delay a menu
/// of long selections is as wide as it was with the old 60pt badge.
const DETAIL_MINIMUM_WIDTH: f64 = 87.0;
const ICON_PNG_MAXIMUM_BYTES: usize = 2_100_000;
const ICON_MAXIMUM_PIXELS: isize = 4096;
const PNG_SIGNATURE: [u8; 8] = [137, 80, 78, 71, 13, 10, 26, 10];

// ---------------------------------------------------------------------------
// Entries: the menu model, kept beside the native items to reconcile against.
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum Kind {
    Action,
    Checkbox,
    Submenu,
    Separator,
    /// Neighbouring checkboxes of one segment group, drawn as one row.
    Segments,
}

#[derive(Debug, Clone, PartialEq)]
pub(super) struct Entry {
    pub kind: Kind,
    pub id: u32,
    pub label: String,
    pub detail: Option<String>,
    pub enabled: bool,
    pub checked: bool,
    pub status_key: Option<String>,
    pub segment_group: Option<String>,
    pub segment_error: Option<String>,
    pub icon: Option<TrayItemIcon>,
    pub badge: Option<TrayItemBadge>,
    pub accessibility_label: Option<String>,
    pub keeps_open: bool,
    pub items: Vec<Entry>,
}

impl Entry {
    pub fn of(item: &TrayItem) -> Self {
        Self {
            kind: match item.kind {
                TrayItemKind::Action => Kind::Action,
                TrayItemKind::Checkbox => Kind::Checkbox,
                TrayItemKind::Submenu => Kind::Submenu,
                TrayItemKind::Separator => Kind::Separator,
            },
            id: item.id,
            label: item.label.clone(),
            detail: item.detail.clone().filter(|detail| !detail.is_empty()),
            enabled: item.enabled,
            checked: item.checked,
            status_key: item.transient_status_key.clone(),
            segment_group: item.segment_group.clone(),
            segment_error: item.segment_error.clone(),
            icon: item.icon.clone(),
            badge: item.badge.clone(),
            accessibility_label: item.accessibility_label.clone(),
            keeps_open: item.keeps_menu_open && item.kind == TrayItemKind::Action,
            items: item.items.iter().map(Entry::of).collect(),
        }
    }

    pub fn list(items: &[TrayItem]) -> Vec<Self> {
        items.iter().map(Entry::of).collect()
    }

    fn segments(group: &str, first: Entry) -> Self {
        Self {
            kind: Kind::Segments,
            id: first.id,
            label: group.to_owned(),
            detail: None,
            enabled: true,
            checked: false,
            status_key: None,
            segment_group: None,
            segment_error: None,
            icon: None,
            badge: None,
            accessibility_label: None,
            keeps_open: false,
            items: vec![first],
        }
    }

    fn status_placeholder(id: u32, key: &str) -> Self {
        Self {
            kind: Kind::Action,
            id,
            label: String::new(),
            detail: None,
            enabled: false,
            checked: false,
            status_key: Some(key.to_owned()),
            segment_group: None,
            segment_error: None,
            icon: None,
            badge: None,
            accessibility_label: Some(String::new()),
            keeps_open: false,
            items: Vec::new(),
        }
    }
}

pub(super) mod topology {
    use super::{Entry, Kind};

    /// Folds runs of checkboxes that share a segment group into one entry.
    pub fn grouped(entries: Vec<Entry>) -> Vec<Entry> {
        let mut result: Vec<Entry> = Vec::new();
        for entry in entries {
            if let (Kind::Checkbox, Some(group)) = (entry.kind, entry.segment_group.clone()) {
                if let Some(last) = result.last_mut() {
                    if last.kind == Kind::Segments && last.label == group {
                        last.items.push(entry);
                        continue;
                    }
                }
                result.push(Entry::segments(&group, entry));
            } else {
                result.push(entry);
            }
        }
        result
    }

    fn same_identity(entry: &Entry, other: &Entry) -> bool {
        entry.kind == other.kind
            && entry.status_key == other.status_key
            && entry.label == other.label
    }

    /// Where [entry] lives in [desired], if both lists hold it exactly once.
    pub fn shared_index(entry: &Entry, current: &[Entry], desired: &[Entry]) -> Option<usize> {
        if current.iter().filter(|other| same_identity(entry, other)).count() != 1 {
            return None;
        }
        let matches: Vec<usize> = desired
            .iter()
            .enumerate()
            .filter(|(_, other)| same_identity(entry, other))
            .map(|(index, _)| index)
            .collect();
        match matches.as_slice() {
            [only] => Some(*only),
            _ => None,
        }
    }

    /// Whether [desired] has the same rows as [current], so the open menu
    /// can take it over in place.
    pub fn matches(current: &[Entry], desired: &[Entry]) -> bool {
        current.len() == desired.len()
            && current.iter().zip(desired).all(|(old, new)| {
                if old.kind != new.kind || old.id != new.id || old.status_key != new.status_key {
                    return false;
                }
                if old.kind == Kind::Separator {
                    return true;
                }
                old.label == new.label
                    && (!matches!(old.kind, Kind::Submenu | Kind::Segments)
                        || matches(&old.items, &new.items))
            })
    }

    /// A row that keeps the menu open was disabled only by its own running
    /// work, so it follows the new content back.
    pub fn retained_enabled(entry: &Entry, initially_enabled: bool) -> bool {
        entry.enabled && (entry.keeps_open || initially_enabled)
    }

    fn status_key(entry: &Entry) -> Option<&str> {
        match (&entry.kind, entry.enabled, entry.status_key.as_deref()) {
            (Kind::Action, false, Some(key)) if !key.is_empty() => Some(key),
            _ => None,
        }
    }

    /// A status row of an open menu keeps its place: it takes the text of
    /// the one row in [desired] with its key, or goes blank and silent.
    pub fn retained_status(entry: &Entry, current: &[Entry], desired: &[Entry]) -> Option<Entry> {
        let key = status_key(entry)?;
        let matches: Vec<&Entry> = desired
            .iter()
            .filter(|other| status_key(other) == Some(key))
            .collect();
        let held = current
            .iter()
            .filter(|other| status_key(other) == Some(key))
            .count();
        if let ([only], 1) = (matches.as_slice(), held) {
            let mut replacement = (*only).clone();
            replacement.id = entry.id;
            return Some(replacement);
        }
        Some(Entry::status_placeholder(entry.id, key))
    }
}

// ---------------------------------------------------------------------------
// The menu.
// ---------------------------------------------------------------------------

pub(super) struct MenuIvars {
    entries: RefCell<Vec<Entry>>,
    initially_enabled: RefCell<Vec<bool>>,
    contents: RefCell<Vec<Option<ItemContent>>>,
    generation: Cell<u32>,
    is_root: bool,
    maximum_width: f64,
}

define_class!(
    #[unsafe(super(NSMenu, NSObject))]
    #[thread_kind = MainThreadOnly]
    #[name = "FlashTrayMenu"]
    #[ivars = MenuIvars]
    pub(super) struct TrayMenu;

    unsafe impl NSObjectProtocol for TrayMenu {}

    unsafe impl NSMenuDelegate for TrayMenu {
        // AppKit does not support resizing custom row views during tracking,
        // so every row is measured once, before the menu shows.
        #[unsafe(method(menuNeedsUpdate:))]
        fn menu_needs_update(&self, _menu: &NSMenu) {
            self.install_views();
        }

        // AppKit does not redraw an item's view when its highlight changes.
        #[unsafe(method(menu:willHighlightItem:))]
        fn will_highlight_item(&self, menu: &NSMenu, item: Option<&NSMenuItem>) {
            if let Some(previous) = menu.highlightedItem() {
                set_highlight(&previous, false);
            }
            if let Some(item) = item {
                set_highlight(item, true);
            }
        }

        #[unsafe(method(menuDidClose:))]
        fn menu_did_close(&self, _menu: &NSMenu) {
            for item in self.itemArray().iter() {
                if let Some(view) = item.view() {
                    if let Some(segments) = view.downcast_ref::<SegmentsView>() {
                        segments.update_highlight(false);
                    } else if let Some(row) = view.downcast_ref::<ItemView>() {
                        row.menu_closed();
                    }
                }
            }
            if self.ivars().is_root {
                super::close_menu(self.ivars().generation.get());
            }
        }
    }

    impl TrayMenu {
        #[unsafe(method(selectItem:))]
        fn select_item(&self, sender: &NSMenuItem) {
            if !sender.isEnabled() {
                return;
            }
            if let Some(view) = sender.view() {
                if let Some(segments) = view.downcast_ref::<SegmentsView>() {
                    segments.activate_focused();
                    return;
                }
                if let Some(row) = view.downcast_ref::<ItemView>() {
                    if !row.ivars().content.borrow().enabled {
                        return;
                    }
                }
            }
            self.select(sender.tag() as u32);
        }
    }
);

fn set_highlight(item: &NSMenuItem, highlighted: bool) {
    let Some(view) = item.view() else {
        return;
    };
    if let Some(row) = view.downcast_ref::<ItemView>() {
        row.update_highlight(highlighted);
    } else if let Some(segments) = view.downcast_ref::<SegmentsView>() {
        segments.update_highlight(highlighted);
    }
}

impl TrayMenu {
    pub fn new(
        mtm: MainThreadMarker,
        items: Vec<Entry>,
        generation: u32,
        is_root: bool,
    ) -> Retained<Self> {
        let entries = topology::grouped(items);
        let this = Self::alloc(mtm).set_ivars(MenuIvars {
            entries: RefCell::new(Vec::new()),
            initially_enabled: RefCell::new(Vec::new()),
            contents: RefCell::new(Vec::new()),
            generation: Cell::new(generation),
            is_root,
            maximum_width: if is_root {
                ROOT_MAXIMUM_WIDTH
            } else {
                SUBMENU_MAXIMUM_WIDTH
            },
        });
        let menu: Retained<Self> =
            unsafe { msg_send![super(this), initWithTitle: &*NSString::from_str("")] };
        menu.setAutoenablesItems(false);
        menu.setDelegate(Some(ProtocolObject::from_ref(&*menu)));
        menu.setShowsStateColumn(false);
        unsafe { menu.setFont(Some(&STYLE.with(|style| style.font.clone()))) };
        let mut initially_enabled = Vec::with_capacity(entries.len());
        let mut contents = Vec::with_capacity(entries.len());
        for entry in &entries {
            let item = menu.make_item(mtm, entry);
            menu.addItem(&item);
            initially_enabled.push(item.isEnabled());
            contents.push(if item.isSeparatorItem() {
                None
            } else {
                Some(ItemContent::of(entry, &item))
            });
        }
        *menu.ivars().entries.borrow_mut() = entries;
        *menu.ivars().initially_enabled.borrow_mut() = initially_enabled;
        *menu.ivars().contents.borrow_mut() = contents;
        menu
    }

    pub fn generation(&self) -> u32 {
        self.ivars().generation.get()
    }

    /// Takes [items] over in place when they have the same rows; otherwise
    /// keeps the open rows where they are, updates those still in [items]
    /// and disables the rest, and returns false so a new menu is built.
    pub fn reconcile(&self, items: Vec<Entry>, generation: u32) -> bool {
        let items = topology::grouped(items);
        let same = topology::matches(&self.ivars().entries.borrow(), &items);
        if same {
            self.apply(items, generation);
        } else {
            self.reconcile_retained(items);
        }
        same
    }

    fn reconcile_retained(&self, desired: Vec<Entry>) {
        let desired = topology::grouped(desired);
        let original = self.ivars().entries.borrow().clone();
        let initially_enabled = self.ivars().initially_enabled.borrow().clone();
        for (index, item) in self.itemArray().iter().enumerate() {
            if item.isSeparatorItem() || index >= original.len() {
                continue;
            }
            let mut entry = original[index].clone();
            let submenu = item
                .submenu()
                .and_then(|menu| menu.downcast::<TrayMenu>().ok());
            if let Some(status) = topology::retained_status(&entry, &original, &desired) {
                entry = status;
                configure(&item, &entry);
            } else if let Some(found) = topology::shared_index(&entry, &original, &desired) {
                entry = desired[found].clone();
                entry.id = original[index].id;
                entry.enabled = topology::retained_enabled(
                    &entry,
                    initially_enabled.get(index).copied().unwrap_or(true),
                );
                if entry.kind == Kind::Segments {
                    let old_children = &original[index].items;
                    let new_children = &entry.items;
                    entry.items = old_children
                        .iter()
                        .map(|old| {
                            match topology::shared_index(old, old_children, new_children) {
                                Some(found) => {
                                    let mut child = new_children[found].clone();
                                    child.id = old.id;
                                    child
                                }
                                None => {
                                    let mut child = old.clone();
                                    child.enabled = false;
                                    child
                                }
                            }
                        })
                        .collect();
                }
                configure(&item, &entry);
                if let Some(submenu) = &submenu {
                    submenu.reconcile_retained(entry.items.clone());
                }
            } else {
                entry.enabled = false;
                item.setEnabled(item_enabled(&entry));
                if let Some(submenu) = &submenu {
                    submenu.reconcile_retained(Vec::new());
                }
            }
            if let Some(submenu) = &submenu {
                entry.items = submenu.ivars().entries.borrow().clone();
            }
            let content = ItemContent::of(&entry, &item);
            self.refresh_view(&item, &entry, &content);
            self.ivars().entries.borrow_mut()[index] = entry;
            self.ivars().contents.borrow_mut()[index] = Some(content);
        }
        self.refresh_badge_column();
    }

    fn apply(&self, entries: Vec<Entry>, generation: u32) {
        self.ivars().generation.set(generation);
        *self.ivars().initially_enabled.borrow_mut() =
            entries.iter().map(|entry| entry.enabled).collect();
        for (index, (item, entry)) in self.itemArray().iter().zip(&entries).enumerate() {
            if item.isSeparatorItem() {
                continue;
            }
            configure(&item, entry);
            if let Some(submenu) = item
                .submenu()
                .and_then(|menu| menu.downcast::<TrayMenu>().ok())
            {
                submenu.apply(topology::grouped(entry.items.clone()), generation);
            }
            let content = ItemContent::of(entry, &item);
            self.refresh_view(&item, entry, &content);
            if let Some(slot) = self.ivars().contents.borrow_mut().get_mut(index) {
                *slot = Some(content);
            }
        }
        *self.ivars().entries.borrow_mut() = entries;
        self.refresh_badge_column();
    }

    fn badge_column(&self) -> f64 {
        badge_column(self.ivars().contents.borrow().iter().flatten())
    }

    /// Gives every row the width of the widest badge now in the menu.
    fn refresh_badge_column(&self) {
        let column = self.badge_column();
        for item in self.itemArray().iter() {
            if let Some(row) = item
                .view()
                .and_then(|view| view.downcast::<ItemView>().ok())
            {
                row.set_badge_column(column);
            }
        }
    }

    fn refresh_view(&self, item: &NSMenuItem, entry: &Entry, content: &ItemContent) {
        let Some(view) = item.view() else {
            return;
        };
        if let Some(row) = view.downcast_ref::<ItemView>() {
            row.update(content.clone());
        } else if let Some(segments) = view.downcast_ref::<SegmentsView>() {
            segments.update(entry.items.clone(), item.isEnabled());
        }
    }

    /// Drops every row view so the next open measures the rows again.
    pub fn prepare_for_opening(&self) {
        for item in self.itemArray().iter() {
            item.setView(None);
            if let Some(submenu) = item
                .submenu()
                .and_then(|menu| menu.downcast::<TrayMenu>().ok())
            {
                submenu.prepare_for_opening();
            }
        }
    }

    fn select(&self, id: u32) {
        emit_signal(TraySignal {
            kind: TraySignalKind::ItemSelected,
            item_id: id,
            menu_generation: self.ivars().generation.get(),
            generations: Vec::new(),
            tracking_generation: None,
        });
    }

    fn make_item(&self, mtm: MainThreadMarker, entry: &Entry) -> Retained<NSMenuItem> {
        if entry.kind == Kind::Separator {
            return NSMenuItem::separatorItem(mtm);
        }
        let item = NSMenuItem::new(mtm);
        configure(&item, entry);
        if entry.kind == Kind::Submenu {
            let submenu = TrayMenu::new(mtm, entry.items.clone(), self.generation(), false);
            self.setSubmenu_forItem(Some(&submenu), &item);
        } else {
            unsafe {
                item.setTarget(Some(self));
                item.setAction(Some(sel!(selectItem:)));
            }
        }
        item
    }

    fn install_views(&self) {
        let items = self.itemArray();
        let missing = items
            .iter()
            .any(|item| !item.isSeparatorItem() && item.view().is_none());
        if !missing {
            return;
        }
        let entries = self.ivars().entries.borrow().clone();
        let contents = self.ivars().contents.borrow().clone();
        let mtm = self.mtm();
        let column = self.badge_column();
        let mut widest: f64 = 0.0;
        for (entry, content) in entries.iter().zip(&contents) {
            if entry.kind == Kind::Segments {
                for child in &entry.items {
                    let item = NSMenuItem::new(mtm);
                    configure(&item, child);
                    let content = ItemContent::of(child, &item);
                    widest = widest.max(ItemView::preferred_width(&content, 0.0));
                }
            } else if let Some(content) = content {
                widest = widest.max(ItemView::preferred_width(content, column));
            }
        }
        let width = widest.min(self.ivars().maximum_width);
        for (index, item) in items.iter().enumerate() {
            if item.isSeparatorItem() || item.view().is_some() {
                continue;
            }
            let Some(entry) = entries.get(index) else {
                continue;
            };
            if entry.kind == Kind::Segments {
                let view = SegmentsView::new(mtm, entry.items.clone(), width, self);
                view.update(entry.items.clone(), item.isEnabled());
                item.setView(Some(&view));
            } else if let Some(Some(content)) = contents.get(index) {
                item.setView(Some(&ItemView::new(mtm, content.clone(), width, column)));
            }
        }
    }
}

fn configure(item: &NSMenuItem, entry: &Entry) {
    let title = if entry.kind == Kind::Segments {
        entry
            .items
            .iter()
            .map(|child| child.label.as_str())
            .collect::<Vec<_>>()
            .join(", ")
    } else {
        entry.label.clone()
    };
    item.setTitle(&NSString::from_str(&title));
    item.setTag(entry.id as isize);
    item.setEnabled(item_enabled(entry));
    let tool_tip = entry.accessibility_label.clone().unwrap_or_else(|| {
        std::iter::once(title.as_str())
            .chain(entry.detail.as_deref())
            .collect::<Vec<_>>()
            .join(", ")
    });
    item.setToolTip(Some(&NSString::from_str(&tool_tip)));
    let checked = entry.kind == Kind::Checkbox && entry.checked;
    item.setState(if checked {
        NSControlStateValueOn
    } else {
        NSControlStateValueOff
    });
}

/// Disabling the highlighted item mid-tracking would move the highlight, so
/// a row that keeps the menu open stays enabled and its view draws and
/// refuses the disabled state instead.
fn item_enabled(entry: &Entry) -> bool {
    entry.enabled || entry.keeps_open
}

/// AppKit answers Return, Enter and Space on the highlighted item by sending
/// its action and closing the menu.
fn takes_key(
    keeps_open: bool,
    highlighted: bool,
    shown: bool,
    modifiers: NSEventModifierFlags,
    key_code: u16,
) -> bool {
    let commands = NSEventModifierFlags::Command
        | NSEventModifierFlags::Control
        | NSEventModifierFlags::Option;
    keeps_open
        && highlighted
        && shown
        && !modifiers.intersects(commands)
        && matches!(key_code, 36 | 49 | 76)
}

/// The menu a row belongs to, and the root that holds the tracking loop.
fn menus_of(item: &NSMenuItem) -> Option<(Retained<NSMenu>, Retained<NSMenu>)> {
    let menu = unsafe { item.menu() }?;
    let mut root = menu.clone();
    while let Some(parent) = unsafe { root.supermenu() } {
        root = parent;
    }
    Some((menu, root))
}

// ---------------------------------------------------------------------------
// Row content and style.
// ---------------------------------------------------------------------------

#[derive(Clone)]
pub(super) struct IconContent {
    monogram: String,
    background: u32,
    foreground: u32,
    image: Option<Retained<NSImage>>,
}

impl IconContent {
    fn of(icon: &TrayItemIcon) -> Self {
        Self {
            monogram: {
                let monogram: String = icon.monogram.chars().take(2).collect();
                if monogram.is_empty() {
                    "?".to_owned()
                } else {
                    monogram
                }
            },
            background: icon.background,
            foreground: icon.foreground,
            image: icon.png.as_deref().and_then(png_image),
        }
    }
}

fn png_image(png: &[u8]) -> Option<Retained<NSImage>> {
    if png.len() > ICON_PNG_MAXIMUM_BYTES || !png.starts_with(&PNG_SIGNATURE) {
        return None;
    }
    let bitmap = NSBitmapImageRep::imageRepWithData(&NSData::with_bytes(png))?;
    let (wide, high) = (bitmap.pixelsWide(), bitmap.pixelsHigh());
    if wide <= 0 || wide > ICON_MAXIMUM_PIXELS || high <= 0 || high > ICON_MAXIMUM_PIXELS {
        return None;
    }
    let size = NSSize::new(16.0, 16.0);
    let image = NSImage::initWithSize(NSImage::alloc(), size);
    bitmap.setSize(size);
    image.addRepresentation(&bitmap);
    image.setTemplate(false);
    Some(image)
}

#[derive(Clone, PartialEq)]
pub(super) struct BadgeContent {
    label: String,
    background: u32,
    foreground: u32,
}

#[derive(Clone)]
pub(super) struct ItemContent {
    label: String,
    detail: Option<String>,
    icon: Option<IconContent>,
    badge: Option<BadgeContent>,
    accessibility_label: Option<String>,
    is_checkbox: bool,
    checked: bool,
    enabled: bool,
    keeps_open: bool,
    has_submenu: bool,
}

impl ItemContent {
    fn of(entry: &Entry, item: &NSMenuItem) -> Self {
        Self {
            label: item.title().to_string(),
            detail: entry.detail.clone().filter(|detail| !detail.is_empty()),
            icon: entry.icon.as_ref().map(IconContent::of),
            badge: entry.badge.as_ref().map(|badge| BadgeContent {
                label: badge.label.clone(),
                background: badge.background,
                foreground: badge.foreground,
            }),
            accessibility_label: entry.accessibility_label.clone(),
            is_checkbox: entry.kind == Kind::Checkbox,
            checked: item.state() == NSControlStateValueOn,
            enabled: entry.enabled && item.isEnabled(),
            keeps_open: entry.keeps_open,
            has_submenu: item.hasSubmenu(),
        }
    }

    fn detail_width(&self, font: &NSFont) -> f64 {
        let width = self
            .detail
            .as_deref()
            .map_or(0.0, |detail| text_width(detail, font));
        if self.has_submenu {
            width.min(DETAIL_MAXIMUM_WIDTH)
        } else {
            width
        }
    }

    fn full_label(&self) -> String {
        if let Some(label) = &self.accessibility_label {
            return label.clone();
        }
        std::iter::once(self.label.as_str())
            .chain(self.detail.as_deref())
            .chain(self.badge.as_ref().map(|badge| badge.label.as_str()))
            .collect::<Vec<_>>()
            .join(", ")
    }
}

/// Row metrics, a little roomier than a native row so icons and badges fit.
struct Style {
    height: f64,
    leading_x: f64,
    leading_width: f64,
    title_x: f64,
    trailing: f64,
    highlight_inset: f64,
    highlight_radius: f64,
    font: Retained<NSFont>,
    detail_font: Retained<NSFont>,
    badge_font: Retained<NSFont>,
    monogram_font: Retained<NSFont>,
    checkmark: Retained<NSImage>,
    arrow: Retained<NSImage>,
}

impl Style {
    fn current() -> Self {
        let size = NSFont::menuFontOfSize(0.0).pointSize().max(13.0);
        let font = NSFont::menuFontOfSize(size);
        let size = font.pointSize();
        let height: f64 = if available!(macos = 26) { 28.0 } else { 26.0 };
        let leading_x = 12.0;
        let leading_width = 16.0;
        Self {
            height: height.max(size + 10.0),
            leading_x,
            leading_width,
            title_x: leading_x + leading_width + 8.0,
            trailing: 18.0,
            highlight_inset: 5.0,
            highlight_radius: 5.0,
            detail_font: NSFont::monospacedDigitSystemFontOfSize_weight(size, unsafe {
                NSFontWeightRegular
            }),
            badge_font: NSFont::monospacedDigitSystemFontOfSize_weight(
                (size - 3.0).max(10.0),
                unsafe { NSFontWeightMedium },
            ),
            monogram_font: NSFont::systemFontOfSize_weight(10.0, unsafe { NSFontWeightSemibold }),
            checkmark: symbol("checkmark", size, unsafe { NSFontWeightMedium }),
            arrow: symbol("chevron.right", size, unsafe { NSFontWeightSemibold }),
            font,
        }
    }

    fn badge_width(&self, label: &str) -> f64 {
        let measured = text_width(label, &self.badge_font) + 2.0 * BADGE_PADDING;
        if is_delay(label) {
            measured
        } else {
            measured.min(110.0)
        }
    }
}

/// `^\d+\s*ms$`
fn is_delay(label: &str) -> bool {
    let Some(number) = label.strip_suffix("ms") else {
        return false;
    };
    let digits = number.trim_end();
    !digits.is_empty() && digits.chars().all(|c| c.is_ascii_digit())
}

thread_local! {
    static STYLE: Style = Style::current();
}

fn symbol(name: &str, size: f64, weight: NSFontWeight) -> Retained<NSImage> {
    let configuration = NSImageSymbolConfiguration::configurationWithPointSize_weight(size, weight);
    NSImage::imageWithSystemSymbolName_accessibilityDescription(&NSString::from_str(name), None)
        .and_then(|image| image.imageWithSymbolConfiguration(&configuration))
        .unwrap_or_default()
}

fn argb(value: u32) -> Retained<NSColor> {
    let channel = |shift: u32| f64::from((value >> shift) & 0xFF) / 255.0;
    NSColor::colorWithSRGBRed_green_blue_alpha(channel(16), channel(8), channel(0), channel(24))
}

fn luminance(value: u32) -> f64 {
    let linear = |shift: u32| {
        let c = f64::from((value >> shift) & 0xFF) / 255.0;
        if c <= 0.04045 {
            c / 12.92
        } else {
            ((c + 0.055) / 1.055).powf(2.4)
        }
    };
    0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
}

/// [foreground] where it reads on [background], else black or white.
fn readable(foreground: u32, background: u32) -> Retained<NSColor> {
    let alpha = |value: u32| f64::from(value >> 24) / 255.0;
    if alpha(background) <= 0.5 {
        return NSColor::labelColor();
    }
    let (f, b) = (luminance(foreground), luminance(background));
    let contrast = (f.max(b) + 0.05) / (f.min(b) + 0.05);
    if alpha(foreground) > 0.5 && contrast >= 3.0 {
        argb(foreground)
    } else if b > 0.4 {
        NSColor::blackColor()
    } else {
        NSColor::whiteColor()
    }
}

fn is_dark(view: &NSView) -> bool {
    let names = unsafe { NSArray::from_slice(&[NSAppearanceNameDarkAqua, NSAppearanceNameAqua]) };
    view.effectiveAppearance()
        .bestMatchFromAppearancesWithNames(&names)
        .is_some_and(|name| unsafe { &*name == NSAppearanceNameDarkAqua })
}

fn post(element: &AnyObject, notification: &NSString) {
    unsafe { NSAccessibilityPostNotification(element, notification) };
}

// ---------------------------------------------------------------------------
// A row.
// ---------------------------------------------------------------------------

pub(super) struct ItemViewIvars {
    content: RefCell<ItemContent>,
    badge_column: Cell<f64>,
    highlighted: Cell<bool>,
    monitor: RefCell<KeyMonitor>,
}

define_class!(
    #[unsafe(super(NSView, NSResponder, NSObject))]
    #[thread_kind = MainThreadOnly]
    #[name = "FlashTrayMenuItemView"]
    #[ivars = ItemViewIvars]
    struct ItemView;

    impl ItemView {
        #[unsafe(method(isFlipped))]
        fn is_flipped(&self) -> bool {
            true
        }

        #[unsafe(method(drawRect:))]
        fn draw_rect(&self, _dirty: NSRect) {
            STYLE.with(|style| self.draw(style));
        }

        #[unsafe(method(viewDidMoveToWindow))]
        fn view_did_move_to_window(&self) {
            unsafe {
                let _: () = msg_send![super(self), viewDidMoveToWindow];
            }
            if let Some(submenu) = self.enclosingMenuItem().and_then(|item| item.submenu()) {
                let children = NSArray::from_retained_slice(&[Retained::into_super(
                    Retained::into_super(submenu),
                )]);
                unsafe { self.setAccessibilityChildren(Some(&children)) };
            }
            if self.window().is_none() {
                self.ivars().monitor.replace(KeyMonitor(None));
            }
        }

        #[unsafe(method(mouseUp:))]
        fn mouse_up(&self, _event: &NSEvent) {
            self.activate();
        }

        #[unsafe(method(accessibilityPerformPress))]
        fn accessibility_perform_press(&self) -> bool {
            if self.ivars().content.borrow().has_submenu {
                self.show_submenu()
            } else {
                self.activate()
            }
        }

        #[unsafe(method(accessibilityPerformShowMenu))]
        fn accessibility_perform_show_menu(&self) -> bool {
            self.show_submenu()
        }
    }
);

impl ItemView {
    fn preferred_width(content: &ItemContent, badge_column: f64) -> f64 {
        STYLE.with(|style| {
            row_width(
                style.title_x + style.trailing,
                text_width(&content.label, &style.font),
                content
                    .detail
                    .is_some()
                    .then(|| content.detail_width(&style.detail_font)),
                content
                    .badge
                    .as_ref()
                    .map(|badge| style.badge_width(&badge.label).max(badge_column)),
                content.has_submenu.then(|| style.arrow.size().width),
            )
        })
    }

    fn new(
        mtm: MainThreadMarker,
        content: ItemContent,
        width: f64,
        badge_column: f64,
    ) -> Retained<Self> {
        let height = STYLE.with(|style| style.height);
        let this = Self::alloc(mtm).set_ivars(ItemViewIvars {
            content: RefCell::new(content),
            badge_column: Cell::new(badge_column),
            highlighted: Cell::new(false),
            monitor: RefCell::new(KeyMonitor(None)),
        });
        let frame = NSRect::new(NSPoint::ZERO, NSSize::new(width, height));
        let view: Retained<Self> = unsafe { msg_send![super(this), initWithFrame: frame] };
        view.setAutoresizingMask(NSAutoresizingMaskOptions::ViewWidthSizable);
        view.update_accessibility();
        view
    }

    fn set_badge_column(&self, column: f64) {
        if self.ivars().badge_column.replace(column) != column {
            self.setNeedsDisplay(true);
        }
    }

    fn update(&self, content: ItemContent) {
        let previous = self.ivars().content.replace(content);
        let content = self.ivars().content.borrow().clone();
        self.update_accessibility();
        self.update_highlight(
            self.enclosingMenuItem()
                .is_some_and(|item| item.isHighlighted()),
        );
        if previous.full_label() != content.full_label() {
            post(self, unsafe { NSAccessibilityTitleChangedNotification });
        }
        if previous.checked != content.checked
            || previous.enabled != content.enabled
            || previous.badge.as_ref().map(|badge| &badge.label)
                != content.badge.as_ref().map(|badge| &badge.label)
        {
            post(self, unsafe { NSAccessibilityValueChangedNotification });
        }
    }

    fn update_accessibility(&self) {
        let content = self.ivars().content.borrow();
        let label = NSString::from_str(&content.full_label());
        self.setToolTip(Some(&label));
        self.setAccessibilityElement(true);
        unsafe { self.setAccessibilityRole(Some(NSAccessibilityMenuItemRole)) };
        self.setAccessibilityLabel(Some(&label));
        self.setAccessibilityEnabled(content.enabled);
        if content.is_checkbox {
            let value = NSNumber::new_i32(i32::from(content.checked));
            unsafe { self.setAccessibilityValue(Some(&value)) };
            self.setAccessibilitySelected(content.checked);
        }
        if content.has_submenu {
            self.setAccessibilityRoleDescription(Some(&NSString::from_str("submenu")));
        }
    }

    fn update_highlight(&self, highlighted: bool) {
        self.ivars().highlighted.set(highlighted);
        let listening = self.ivars().monitor.borrow().0.is_some();
        if highlighted
            && !listening
            && self.window().is_some()
            && self.ivars().content.borrow().keeps_open
        {
            self.ivars()
                .monitor
                .replace(KeyMonitor::key_down(self, Self::handle_key));
        }
        self.setNeedsDisplay(true);
    }

    fn menu_closed(&self) {
        self.ivars().highlighted.set(false);
        self.ivars().monitor.replace(KeyMonitor(None));
        self.setNeedsDisplay(true);
    }

    fn is_highlighted(&self) -> bool {
        let content = self.ivars().content.borrow();
        self.ivars().highlighted.get() && (content.enabled || content.keeps_open)
    }

    fn handle_key(&self, event: &NSEvent) -> bool {
        let shown = self.window().is_some_and(|window| window.isVisible());
        let keeps_open = self.ivars().content.borrow().keeps_open;
        if !takes_key(
            keeps_open,
            self.ivars().highlighted.get(),
            shown,
            event.modifierFlags(),
            event.keyCode(),
        ) {
            return false;
        }
        self.activate();
        true
    }

    fn activate(&self) -> bool {
        let (enabled, has_submenu, keeps_open) = {
            let content = self.ivars().content.borrow();
            (content.enabled, content.has_submenu, content.keeps_open)
        };
        if !enabled || has_submenu {
            return false;
        }
        let Some(item) = self.enclosingMenuItem() else {
            return false;
        };
        if !item.isEnabled() {
            return false;
        }
        let Some((menu, root)) = menus_of(&item) else {
            return false;
        };
        if !keeps_open {
            root.cancelTracking();
        }
        match menu.downcast::<TrayMenu>() {
            Ok(menu) => {
                menu.select(item.tag() as u32);
                true
            }
            Err(_) => false,
        }
    }

    fn show_submenu(&self) -> bool {
        if !self.ivars().content.borrow().enabled {
            return false;
        }
        let Some(item) = self.enclosingMenuItem() else {
            return false;
        };
        if !item.isEnabled() {
            return false;
        }
        let Some(submenu) = item.submenu() else {
            return false;
        };
        let point = NSPoint::new(self.bounds().size.width, 0.0);
        submenu.popUpMenuPositioningItem_atLocation_inView(None, point, Some(self))
    }

    fn draw(&self, style: &Style) {
        let content = self.ivars().content.borrow().clone();
        let bounds = self.bounds();
        let highlighted = self.is_highlighted();
        if highlighted {
            NSColor::selectedContentBackgroundColor().setFill();
            let inset = NSRect::new(
                NSPoint::new(bounds.origin.x + style.highlight_inset, bounds.origin.y),
                NSSize::new(
                    bounds.size.width - 2.0 * style.highlight_inset,
                    bounds.size.height,
                ),
            );
            NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(
                inset,
                style.highlight_radius,
                style.highlight_radius,
            )
            .fill();
        }
        let primary = if highlighted && !content.enabled {
            NSColor::selectedMenuItemTextColor().colorWithAlphaComponent(0.55)
        } else if highlighted {
            NSColor::selectedMenuItemTextColor()
        } else if content.enabled {
            NSColor::labelColor()
        } else {
            NSColor::disabledControlTextColor()
        };
        if content.checked {
            let width = style.checkmark.size().width.min(12.0);
            draw_symbol(
                &style.checkmark,
                style.leading_x + (style.leading_width - width) / 2.0,
                &primary,
                12.0,
                bounds,
            );
        } else if !content.is_checkbox {
            if let Some(icon) = &content.icon {
                let rect = NSRect::new(
                    NSPoint::new(
                        style.leading_x,
                        (bounds.size.height - style.leading_width) / 2.0,
                    ),
                    NSSize::new(style.leading_width, style.leading_width),
                );
                if let Some(image) = &icon.image {
                    unsafe {
                        image.drawInRect_fromRect_operation_fraction_respectFlipped_hints(
                            rect,
                            NSRect::ZERO,
                            NSCompositingOperation::SourceOver,
                            if content.enabled { 1.0 } else { 0.45 },
                            true,
                            None,
                        );
                    }
                } else {
                    let background = if highlighted {
                        NSColor::colorWithWhite_alpha(1.0, 0.12)
                    } else {
                        argb(icon.background)
                    };
                    background.setFill();
                    NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(rect, 4.0, 4.0).fill();
                    let color = if highlighted {
                        primary.clone()
                    } else if !content.enabled {
                        NSColor::disabledControlTextColor()
                    } else {
                        readable(icon.foreground, icon.background)
                    };
                    draw_text(
                        &icon.monogram,
                        rect.origin.x,
                        16.0,
                        &color,
                        &style.monogram_font,
                        bounds,
                        NSTextAlignment::Center,
                        NSLineBreakMode::ByTruncatingTail,
                    );
                }
            }
        }

        let mut trailing_x = bounds.size.width - style.trailing;
        if content.has_submenu {
            let arrow_width = style.arrow.size().width;
            draw_symbol(
                &style.arrow,
                trailing_x - arrow_width,
                &primary,
                f64::INFINITY,
                bounds,
            );
            trailing_x -= arrow_width + arrow_gap(content.badge.is_some());
        }
        let layout = trailing_layout(
            trailing_x - style.title_x,
            text_width(&content.label, &style.font),
            content
                .detail
                .is_some()
                .then(|| content.detail_width(&style.detail_font)),
            content.badge.as_ref().map(|badge| {
                style
                    .badge_width(&badge.label)
                    .max(self.ivars().badge_column.get())
            }),
            content.has_submenu,
        );
        if let Some(badge) = &content.badge {
            let width = layout.badge;
            let height = (style.badge_font.ascender() - style.badge_font.descender()).ceil() + 2.0;
            let rect = NSRect::new(
                NSPoint::new(trailing_x - width, (bounds.size.height - height) / 2.0),
                NSSize::new(width, height),
            );
            if highlighted {
                NSColor::windowBackgroundColor().setFill();
                NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(rect, 4.0, 4.0).fill();
            }
            argb(badge.background).setFill();
            NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(rect, 4.0, 4.0).fill();
            let color = if !content.enabled {
                NSColor::disabledControlTextColor()
            } else {
                readable(badge.foreground, badge.background)
            };
            draw_text(
                &badge.label,
                rect.origin.x + BADGE_PADDING,
                width - 2.0 * BADGE_PADDING,
                &color,
                &style.badge_font,
                bounds,
                NSTextAlignment::Right,
                NSLineBreakMode::ByTruncatingMiddle,
            );
            trailing_x -= width + BADGE_GAP;
        }
        if let Some(detail) = &content.detail {
            let color = if highlighted {
                primary.clone()
            } else if content.enabled {
                NSColor::secondaryLabelColor()
            } else {
                NSColor::disabledControlTextColor()
            };
            let width = layout.detail;
            draw_text(
                detail,
                trailing_x - width,
                width,
                &color,
                &style.detail_font,
                bounds,
                NSTextAlignment::Right,
                NSLineBreakMode::ByTruncatingTail,
            );
            trailing_x -= width + DETAIL_GAP;
        }
        draw_text(
            &content.label,
            style.title_x,
            trailing_x - style.title_x,
            &primary,
            &style.font,
            bounds,
            NSTextAlignment::Left,
            NSLineBreakMode::ByTruncatingTail,
        );
    }
}

/// Widths along a row's trailing edge, given [room] from the title's start to
/// the arrow or edge. On a group row the badge and title stay whole and the
/// selection truncates first, down to [DETAIL_MINIMUM_WIDTH].
#[derive(Debug, PartialEq)]
struct TrailingLayout {
    badge: f64,
    detail: f64,
    title: f64,
}

fn trailing_layout(
    mut room: f64,
    title: f64,
    detail: Option<f64>,
    badge: Option<f64>,
    has_submenu: bool,
) -> TrailingLayout {
    let badge_width = badge.map_or(0.0, |width| {
        let width = width.min(room.max(BADGE_MINIMUM_WIDTH));
        room -= width + BADGE_GAP;
        width
    });
    let detail_width = detail.map_or(0.0, |width| {
        let width = if has_submenu && badge.is_some() {
            width.min((room - title - DETAIL_GAP).max(DETAIL_MINIMUM_WIDTH))
        } else {
            width
        }
        .min(room.max(0.0));
        room -= width + DETAIL_GAP;
        width
    });
    TrailingLayout {
        badge: badge_width,
        detail: detail_width,
        title: room.max(0.0),
    }
}

/// The width every badge in a menu takes: its widest badge.
fn badge_column<'a>(contents: impl Iterator<Item = &'a ItemContent>) -> f64 {
    STYLE.with(|style| {
        contents
            .filter_map(|content| content.badge.as_ref())
            .map(|badge| style.badge_width(&badge.label))
            .fold(0.0, f64::max)
    })
}

fn arrow_gap(has_badge: bool) -> f64 {
    if has_badge {
        BADGE_ARROW_GAP
    } else {
        ARROW_GAP
    }
}

/// A group row always fits its badge, title and selection cut to the minimum.
fn row_width(
    edges: f64,
    title: f64,
    detail: Option<f64>,
    badge: Option<f64>,
    arrow: Option<f64>,
) -> f64 {
    let detail_room = detail.map_or(0.0, |width| width + DETAIL_GAP);
    let trailing = match (badge, arrow) {
        (Some(badge), Some(_)) => detail_room.max(
            badge
                + BADGE_GAP
                + detail.map_or(0.0, |width| width.min(DETAIL_MINIMUM_WIDTH) + DETAIL_GAP),
        ),
        (Some(badge), None) => detail_room + badge + BADGE_GAP,
        (None, _) => detail_room,
    };
    let arrow = arrow.map_or(0.0, |width| width + arrow_gap(badge.is_some()));
    (edges + title + trailing + arrow).ceil()
}

// ---------------------------------------------------------------------------
// A segmented control row.
// ---------------------------------------------------------------------------

struct KeyMonitor(Option<Retained<AnyObject>>);

impl KeyMonitor {
    fn key_down<V: Message + 'static>(view: &V, handle: fn(&V, &NSEvent) -> bool) -> Self {
        let this = Weak::from_retained(&view.retain());
        let handler = RcBlock::new(move |event: NonNull<NSEvent>| -> *mut NSEvent {
            let Some(this) = this.load() else {
                return event.as_ptr();
            };
            if handle(&this, unsafe { event.as_ref() }) {
                null_mut()
            } else {
                event.as_ptr()
            }
        });
        Self(unsafe {
            NSEvent::addLocalMonitorForEventsMatchingMask_handler(NSEventMask::KeyDown, &handler)
        })
    }
}

impl Drop for KeyMonitor {
    fn drop(&mut self) {
        if let Some(monitor) = self.0.take() {
            unsafe { NSEvent::removeMonitor(&monitor) };
        }
    }
}

pub(super) struct SegmentsIvars {
    entries: RefCell<Vec<Entry>>,
    segments: RefCell<Vec<Retained<SegmentView>>>,
    monitor: RefCell<KeyMonitor>,
    highlighted: Cell<bool>,
    keyboard_navigation: Cell<bool>,
    focused: Cell<usize>,
    enabled: Cell<bool>,
    menu: Weak<TrayMenu>,
}

define_class!(
    #[unsafe(super(NSView, NSResponder, NSObject))]
    #[thread_kind = MainThreadOnly]
    #[name = "FlashTrayMenuSegmentsView"]
    #[ivars = SegmentsIvars]
    struct SegmentsView;

    impl SegmentsView {
        #[unsafe(method(acceptsFirstResponder))]
        fn accepts_first_responder(&self) -> bool {
            true
        }

        #[unsafe(method(drawRect:))]
        fn draw_rect(&self, _dirty: NSRect) {
            let dark = is_dark(self);
            let color = if dark {
                NSColor::colorWithWhite_alpha(1.0, 0.07)
            } else {
                NSColor::colorWithWhite_alpha(0.0, 0.05)
            };
            color.setFill();
            NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(self.track(), 8.0, 8.0).fill();
        }

        #[unsafe(method(layout))]
        fn layout(&self) {
            unsafe {
                let _: () = msg_send![super(self), layout];
            }
            let track = self.track();
            let segments = self.ivars().segments.borrow();
            if segments.is_empty() {
                return;
            }
            let count = segments.len() as f64;
            let width = (track.size.width - 6.0 - (count - 1.0) * 2.0) / count;
            let height = track_height() - 6.0;
            for (index, segment) in segments.iter().enumerate() {
                segment.setFrame(NSRect::new(
                    NSPoint::new(
                        track.origin.x + 3.0 + index as f64 * (width + 2.0),
                        track.origin.y + 3.0,
                    ),
                    NSSize::new(width.max(0.0), height),
                ));
            }
        }

        #[unsafe(method(viewDidChangeEffectiveAppearance))]
        fn view_did_change_effective_appearance(&self) {
            unsafe {
                let _: () = msg_send![super(self), viewDidChangeEffectiveAppearance];
            }
            self.setNeedsDisplay(true);
            for segment in self.ivars().segments.borrow().iter() {
                segment.setNeedsDisplay(true);
            }
        }

        #[unsafe(method(viewDidMoveToWindow))]
        fn view_did_move_to_window(&self) {
            unsafe {
                let _: () = msg_send![super(self), viewDidMoveToWindow];
            }
            self.ivars().monitor.replace(KeyMonitor(None));
            if self.window().is_none() {
                return;
            }
            self.ivars().monitor.replace(KeyMonitor::key_down(self, Self::handle_key));
        }
    }
);

fn track_height() -> f64 {
    STYLE.with(|style| (style.font.ascender() - style.font.descender()).ceil() + 12.0)
        .max(30.0)
}

fn segment_track(bounds: NSRect, leading: f64, trailing: f64) -> NSRect {
    NSRect::new(
        NSPoint::new(bounds.origin.x + leading, bounds.origin.y + 4.0),
        NSSize::new(
            (bounds.size.width - leading - trailing).max(0.0),
            (bounds.size.height - 8.0).max(0.0),
        ),
    )
}

impl SegmentsView {
    fn new(
        mtm: MainThreadMarker,
        entries: Vec<Entry>,
        width: f64,
        menu: &TrayMenu,
    ) -> Retained<Self> {
        let focused = entries.iter().position(|entry| entry.checked).unwrap_or(0);
        let this = Self::alloc(mtm).set_ivars(SegmentsIvars {
            entries: RefCell::new(Vec::new()),
            segments: RefCell::new(Vec::new()),
            monitor: RefCell::new(KeyMonitor(None)),
            highlighted: Cell::new(false),
            keyboard_navigation: Cell::new(false),
            focused: Cell::new(focused),
            enabled: Cell::new(true),
            menu: Weak::from_retained(&menu.retain()),
        });
        let frame = NSRect::new(NSPoint::ZERO, NSSize::new(width, track_height() + 8.0));
        let view: Retained<Self> = unsafe { msg_send![super(this), initWithFrame: frame] };
        view.setAutoresizingMask(NSAutoresizingMaskOptions::ViewWidthSizable);
        view.setAccessibilityElement(true);
        unsafe { view.setAccessibilityRole(Some(NSAccessibilityGroupRole)) };
        view.update(entries, true);
        view
    }

    fn track(&self) -> NSRect {
        STYLE.with(|style| segment_track(self.bounds(), style.leading_x, style.trailing))
    }

    fn update(&self, entries: Vec<Entry>, enabled: bool) {
        let previous_error = self
            .ivars()
            .entries
            .borrow()
            .first()
            .and_then(|entry| entry.segment_error.clone());
        let error = entries.first().and_then(|entry| entry.segment_error.clone());
        self.ivars().enabled.set(enabled);
        let count = entries.len();
        *self.ivars().entries.borrow_mut() = entries.clone();
        if self.ivars().segments.borrow().len() != count {
            for segment in self.ivars().segments.borrow().iter() {
                segment.removeFromSuperview();
            }
            let segments: Vec<_> = (0..count)
                .map(|index| {
                    let segment = SegmentView::new(self.mtm(), index, self);
                    self.addSubview(&segment);
                    segment
                })
                .collect();
            let children: Vec<Retained<AnyObject>> = segments
                .iter()
                .map(|segment| Retained::into_super(Retained::into_super(Retained::into_super(Retained::into_super(segment.clone())))))
                .collect();
            unsafe { self.setAccessibilityChildren(Some(&NSArray::from_retained_slice(&children))) };
            *self.ivars().segments.borrow_mut() = segments;
        }
        for (segment, entry) in self.ivars().segments.borrow().iter().zip(&entries) {
            let ivars = segment.ivars();
            *ivars.label.borrow_mut() = entry.label.clone();
            ivars.selected.set(entry.checked);
            ivars.enabled.set(enabled && entry.enabled);
            let tool_tip = std::iter::once(entry.label.as_str())
                .chain(entry.detail.as_deref())
                .collect::<Vec<_>>()
                .join(", ");
            segment.setToolTip(Some(&NSString::from_str(&tool_tip)));
            segment.refresh();
        }
        let label = entries
            .iter()
            .map(|entry| entry.label.as_str())
            .collect::<Vec<_>>()
            .join(", ");
        self.setAccessibilityLabel(Some(&NSString::from_str(&label)));
        self.setNeedsLayout(true);
        self.setNeedsDisplay(true);
        let Some(error) = error.filter(|error| !error.is_empty()) else {
            return;
        };
        if Some(&error) == previous_error.as_ref() || self.window().is_none() {
            return;
        }
        if let Some((_, root)) = self.enclosingMenuItem().as_deref().and_then(menus_of) {
            root.cancelTracking();
        }
        DispatchQueue::main().exec_async(move || {
            let Some(mtm) = MainThreadMarker::new() else {
                return;
            };
            let alert = NSAlert::new(mtm);
            alert.setAlertStyle(NSAlertStyle::Warning);
            alert.setMessageText(&NSString::from_str(&error));
            alert.runModal();
        });
    }

    fn activate(&self, index: usize) {
        if !self.ivars().enabled.get() {
            return;
        }
        let id = {
            let entries = self.ivars().entries.borrow();
            match entries.get(index) {
                Some(entry) if entry.enabled && !entry.checked => entry.id,
                _ => return,
            }
        };
        self.ivars().focused.set(index);
        self.refresh_focus();
        if let Some(menu) = self.ivars().menu.load() {
            menu.select(id);
        }
    }

    fn activate_focused(&self) {
        self.activate(self.ivars().focused.get());
    }

    fn update_highlight(&self, highlighted: bool) {
        self.ivars().highlighted.set(highlighted);
        let from_keyboard = highlighted
            && NSApplication::sharedApplication(self.mtm())
                .currentEvent()
                .is_some_and(|event| event.r#type() == NSEventType::KeyDown);
        self.ivars().keyboard_navigation.set(from_keyboard);
        if highlighted {
            let checked = self
                .ivars()
                .entries
                .borrow()
                .iter()
                .position(|entry| entry.checked)
                .unwrap_or(0);
            self.ivars().focused.set(checked);
            if let Some(window) = self.window() {
                window.makeFirstResponder(Some(self));
            }
        }
        self.refresh_focus();
    }

    fn refresh_focus(&self) {
        let show = self.ivars().highlighted.get() && self.ivars().keyboard_navigation.get();
        let focused = self.ivars().focused.get();
        for (index, segment) in self.ivars().segments.borrow().iter().enumerate() {
            segment.ivars().focused.set(show && index == focused);
            segment.refresh();
        }
    }

    fn handle_key(&self, event: &NSEvent) -> bool {
        let count = self.ivars().entries.borrow().len();
        let modifiers = NSEventModifierFlags::Command
            | NSEventModifierFlags::Control
            | NSEventModifierFlags::Option;
        if !self.ivars().highlighted.get()
            || count == 0
            || event.modifierFlags().intersects(modifiers)
        {
            return false;
        }
        match event.keyCode() {
            123 | 124 => {
                self.ivars().keyboard_navigation.set(true);
                let focused = self.ivars().focused.get();
                let next = if event.keyCode() == 123 {
                    focused.saturating_sub(1)
                } else {
                    (focused + 1).min(count - 1)
                };
                self.ivars().focused.set(next);
                self.refresh_focus();
                true
            }
            36 | 49 | 76 => {
                self.activate_focused();
                true
            }
            _ => false,
        }
    }
}

pub(super) struct SegmentIvars {
    label: RefCell<String>,
    selected: Cell<bool>,
    enabled: Cell<bool>,
    focused: Cell<bool>,
    hovered: Cell<bool>,
    index: usize,
    parent: Weak<SegmentsView>,
}

define_class!(
    #[unsafe(super(NSView, NSResponder, NSObject))]
    #[thread_kind = MainThreadOnly]
    #[name = "FlashTrayMenuSegment"]
    #[ivars = SegmentIvars]
    struct SegmentView;

    impl SegmentView {
        #[unsafe(method(drawRect:))]
        fn draw_rect(&self, _dirty: NSRect) {
            self.draw();
        }

        #[unsafe(method(updateTrackingAreas))]
        fn update_tracking_areas(&self) {
            unsafe {
                let _: () = msg_send![super(self), updateTrackingAreas];
            }
            for area in self.trackingAreas().iter() {
                self.removeTrackingArea(&area);
            }
            let area = unsafe {
                NSTrackingArea::initWithRect_options_owner_userInfo(
                    NSTrackingArea::alloc(),
                    self.bounds(),
                    NSTrackingAreaOptions::MouseEnteredAndExited
                        | NSTrackingAreaOptions::ActiveAlways
                        | NSTrackingAreaOptions::InVisibleRect,
                    Some(self),
                    None,
                )
            };
            self.addTrackingArea(&area);
        }

        #[unsafe(method(mouseEntered:))]
        fn mouse_entered(&self, _event: &NSEvent) {
            self.ivars().hovered.set(true);
            self.refresh();
        }

        #[unsafe(method(mouseExited:))]
        fn mouse_exited(&self, _event: &NSEvent) {
            self.ivars().hovered.set(false);
            self.refresh();
        }

        #[unsafe(method(mouseUp:))]
        fn mouse_up(&self, _event: &NSEvent) {
            self.press();
        }

        #[unsafe(method(accessibilityPerformPress))]
        fn accessibility_perform_press(&self) -> bool {
            self.press()
        }
    }
);

impl SegmentView {
    fn new(mtm: MainThreadMarker, index: usize, parent: &SegmentsView) -> Retained<Self> {
        let this = Self::alloc(mtm).set_ivars(SegmentIvars {
            label: RefCell::new(String::new()),
            selected: Cell::new(false),
            enabled: Cell::new(true),
            focused: Cell::new(false),
            hovered: Cell::new(false),
            index,
            parent: Weak::from_retained(&parent.retain()),
        });
        let view: Retained<Self> = unsafe { msg_send![super(this), initWithFrame: NSRect::ZERO] };
        view.setAccessibilityElement(true);
        unsafe { view.setAccessibilityRole(Some(NSAccessibilityButtonRole)) };
        view
    }

    fn press(&self) -> bool {
        if !self.ivars().enabled.get() {
            return false;
        }
        if let Some(parent) = self.ivars().parent.load() {
            parent.activate(self.ivars().index);
        }
        true
    }

    fn refresh(&self) {
        let ivars = self.ivars();
        let selected = ivars.selected.get();
        self.setAccessibilityLabel(Some(&NSString::from_str(&ivars.label.borrow())));
        self.setAccessibilitySelected(selected);
        let value = NSNumber::new_i32(i32::from(selected));
        unsafe { self.setAccessibilityValue(Some(&value)) };
        self.setAccessibilityEnabled(ivars.enabled.get());
        post(self, unsafe { NSAccessibilityValueChangedNotification });
        self.setNeedsDisplay(true);
    }

    fn draw(&self) {
        let ivars = self.ivars();
        let bounds = self.bounds();
        let dark = is_dark(self);
        let fill = if ivars.selected.get() {
            Some(NSColor::colorWithWhite_alpha(1.0, if dark { 0.17 } else { 0.82 }))
        } else if ivars.hovered.get() && ivars.enabled.get() {
            Some(if dark {
                NSColor::colorWithWhite_alpha(1.0, 0.08)
            } else {
                NSColor::colorWithWhite_alpha(0.0, 0.04)
            })
        } else {
            None
        };
        if let Some(fill) = fill {
            fill.setFill();
            NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(bounds, 5.0, 5.0).fill();
        }
        if ivars.focused.get() {
            let ring = NSRect::new(
                NSPoint::new(bounds.origin.x + 1.0, bounds.origin.y + 1.0),
                NSSize::new(
                    (bounds.size.width - 2.0).max(0.0),
                    (bounds.size.height - 2.0).max(0.0),
                ),
            );
            NSColor::keyboardFocusIndicatorColor().setStroke();
            let path = NSBezierPath::bezierPathWithRoundedRect_xRadius_yRadius(ring, 4.0, 4.0);
            path.setLineWidth(2.0);
            path.stroke();
        }
        STYLE.with(|style| {
            draw_text(
                &ivars.label.borrow(),
                2.0,
                (bounds.size.width - 4.0).max(0.0),
                &NSColor::labelColor(),
                &style.font,
                bounds,
                NSTextAlignment::Center,
                NSLineBreakMode::ByTruncatingTail,
            );
        });
    }
}

// ---------------------------------------------------------------------------
// Drawing helpers.
// ---------------------------------------------------------------------------

fn attributes(
    font: &NSFont,
    color: &NSColor,
    paragraph: Option<&NSMutableParagraphStyle>,
) -> Retained<NSDictionary<NSAttributedStringKey, AnyObject>> {
    let mut keys: Vec<&NSAttributedStringKey> =
        unsafe { vec![NSFontAttributeName, NSForegroundColorAttributeName] };
    let mut values: Vec<&AnyObject> = vec![font, color];
    if let Some(paragraph) = paragraph {
        keys.push(unsafe { NSParagraphStyleAttributeName });
        values.push(paragraph);
    }
    NSDictionary::from_slices(&keys, &values)
}

fn text_width(text: &str, font: &NSFont) -> f64 {
    let attributes = attributes(font, &NSColor::labelColor(), None);
    let size = unsafe { NSString::from_str(text).sizeWithAttributes(Some(&attributes)) };
    size.width.ceil()
}

#[allow(clippy::too_many_arguments)]
fn draw_text(
    text: &str,
    x: f64,
    width: f64,
    color: &NSColor,
    font: &NSFont,
    bounds: NSRect,
    alignment: NSTextAlignment,
    line_break: NSLineBreakMode,
) {
    let paragraph = NSMutableParagraphStyle::new();
    paragraph.setLineBreakMode(line_break);
    paragraph.setAlignment(alignment);
    let height = (font.ascender() - font.descender()).ceil();
    let rect = NSRect::new(
        NSPoint::new(x, (bounds.size.height - height) / 2.0),
        NSSize::new(width.max(0.0), height),
    );
    let attributes = attributes(font, color, Some(&paragraph));
    unsafe {
        NSString::from_str(text).drawWithRect_options_attributes_context(
            rect,
            NSStringDrawingOptions::UsesLineFragmentOrigin,
            Some(&attributes),
            None,
        );
    }
}

fn draw_symbol(image: &NSImage, x: f64, color: &NSColor, max_width: f64, bounds: NSRect) {
    let natural = image.size();
    let scale = (max_width / natural.width.max(1.0)).min(1.0);
    let size = NSSize::new(natural.width * scale, natural.height * scale);
    let rect = NSRect::new(
        NSPoint::new(x, ((bounds.size.height - size.height) / 2.0).round()),
        size,
    );
    let image = image.retain();
    let color = color.retain();
    let tint = RcBlock::new(move |area: NSRect| -> Bool {
        image.drawInRect(area);
        color.setFill();
        NSRectFillUsingOperation(area, NSCompositingOperation::SourceAtop);
        Bool::YES
    });
    let tinted = NSImage::imageWithSize_flipped_drawingHandler(size, false, &tint);
    unsafe {
        tinted.drawInRect_fromRect_operation_fraction_respectFlipped_hints(
            rect,
            NSRect::ZERO,
            NSCompositingOperation::SourceOver,
            1.0,
            true,
            None,
        );
    }
}

#[cfg(test)]
mod tests {
    use super::topology::{grouped, matches, retained_enabled, retained_status, shared_index};
    use super::{
        badge_column, is_delay, item_enabled, row_width, segment_track, takes_key, text_width,
        trailing_layout, Entry, ItemContent, Kind, Style, TrailingLayout, ARROW_GAP,
        BADGE_ARROW_GAP, BADGE_GAP, BADGE_PADDING, DETAIL_GAP, DETAIL_MAXIMUM_WIDTH,
        DETAIL_MINIMUM_WIDTH,
    };
    use objc2_app_kit::NSEventModifierFlags;
    use objc2_app_kit::NSFont;
    use objc2_foundation::{NSPoint, NSRect, NSSize};

    #[test]
    fn segment_track_aligns_with_the_row_content_bounds() {
        for width in [180.0, 280.0, 380.0] {
            let bounds = NSRect::new(NSPoint::new(2.0, 3.0), NSSize::new(width, 40.0));
            let track = segment_track(bounds, 12.0, 18.0);
            assert_eq!(track.origin, NSPoint::new(14.0, 7.0));
            assert_eq!(track.size, NSSize::new(width - 30.0, 32.0));
            assert_eq!(
                track.origin.x + track.size.width,
                bounds.origin.x + width - 18.0
            );
        }
    }

    #[test]
    fn segment_track_clamps_small_bounds_without_changing_insets() {
        let track = segment_track(
            NSRect::new(NSPoint::ZERO, NSSize::new(20.0, 6.0)),
            12.0,
            18.0,
        );
        assert_eq!(track.origin, NSPoint::new(12.0, 4.0));
        assert_eq!(track.size, NSSize::ZERO);
    }

    #[test]
    fn action_details_keep_the_full_version_and_submenus_keep_their_cap() {
        let font = NSFont::systemFontOfSize(13.0);
        let mut content = ItemContent {
            label: "Update now".into(),
            detail: Some("NEW 1.0.0+2026111902".into()),
            icon: None,
            badge: None,
            accessibility_label: None,
            is_checkbox: false,
            checked: false,
            enabled: true,
            keeps_open: false,
            has_submenu: false,
        };
        let measured = text_width(content.detail.as_deref().unwrap(), &font);
        assert!(measured > DETAIL_MAXIMUM_WIDTH);
        assert_eq!(content.detail_width(&font), measured);
        content.has_submenu = true;
        assert_eq!(content.detail_width(&font), DETAIL_MAXIMUM_WIDTH);
        content.detail = Some("Short".into());
        assert_eq!(content.detail_width(&font), text_width("Short", &font));
        content.detail = None;
        assert_eq!(content.detail_width(&font), 0.0);
    }

    fn entry(kind: Kind, id: u32, label: &str) -> Entry {
        Entry {
            kind,
            id,
            label: label.into(),
            detail: None,
            enabled: true,
            checked: false,
            status_key: None,
            segment_group: None,
            segment_error: None,
            icon: None,
            badge: None,
            accessibility_label: None,
            keeps_open: false,
            items: Vec::new(),
        }
    }

    fn segment(id: u32, label: &str, group: &str) -> Entry {
        Entry {
            segment_group: Some(group.into()),
            ..entry(Kind::Checkbox, id, label)
        }
    }

    fn status(id: u32, key: &str, label: &str) -> Entry {
        Entry {
            enabled: false,
            status_key: Some(key.into()),
            ..entry(Kind::Action, id, label)
        }
    }

    #[test]
    fn folds_a_run_of_one_segment_group_into_one_row() {
        let rows = grouped(vec![
            entry(Kind::Action, 1, "Show"),
            segment(2, "Rule", "mode"),
            segment(3, "Global", "mode"),
            segment(4, "Direct", "mode"),
            entry(Kind::Separator, 5, ""),
            segment(6, "A", "other"),
        ]);
        let kinds: Vec<Kind> = rows.iter().map(|row| row.kind).collect();
        assert_eq!(
            kinds,
            [Kind::Action, Kind::Segments, Kind::Separator, Kind::Segments]
        );
        assert_eq!(rows[1].id, 2);
        assert_eq!(rows[1].label, "mode");
        assert_eq!(rows[1].items.len(), 3);
        assert_eq!(rows[3].items.len(), 1);
    }

    #[test]
    fn grouping_twice_changes_nothing() {
        let once = grouped(vec![segment(2, "Rule", "mode"), segment(3, "Global", "mode")]);
        assert_eq!(grouped(once.clone()), once);
    }

    #[test]
    fn matches_needs_the_same_ids_kinds_labels_and_status_keys() {
        let current = vec![entry(Kind::Action, 1, "Show"), status(2, "mode", "Switching")];
        assert!(matches(&current, &current.clone()));
        let mut relabelled = current.clone();
        relabelled[0].label = "Hide".into();
        assert!(!matches(&current, &relabelled));
        let mut renumbered = current.clone();
        renumbered[1].id = 3;
        assert!(!matches(&current, &renumbered));
        let mut detail_only = current.clone();
        detail_only[0].detail = Some("120 ms".into());
        assert!(matches(&current, &detail_only));
    }

    #[test]
    fn shared_index_needs_one_row_on_each_side() {
        let current = vec![entry(Kind::Action, 1, "A"), entry(Kind::Action, 2, "B")];
        let desired = vec![entry(Kind::Action, 7, "B"), entry(Kind::Action, 8, "A")];
        assert_eq!(shared_index(&current[0], &current, &desired), Some(1));
        let doubled = vec![entry(Kind::Action, 7, "A"), entry(Kind::Action, 8, "A")];
        assert_eq!(shared_index(&current[0], &current, &doubled), None);
    }

    #[test]
    fn a_status_row_takes_the_new_text_under_its_own_id() {
        let current = vec![status(4, "mode", "Switching…")];
        let desired = vec![status(9, "mode", "Switched to Global")];
        let kept = retained_status(&current[0], &current, &desired).unwrap();
        assert_eq!(kept.id, 4);
        assert_eq!(kept.label, "Switched to Global");
    }

    #[test]
    fn a_status_row_without_a_successor_goes_blank_and_silent() {
        let current = vec![status(4, "mode", "Switching…")];
        let kept = retained_status(&current[0], &current, &[]).unwrap();
        assert_eq!(kept.id, 4);
        assert_eq!(kept.label, "");
        assert_eq!(kept.accessibility_label.as_deref(), Some(""));
        assert!(!kept.enabled);
    }

    #[test]
    fn only_disabled_actions_with_a_key_are_status_rows() {
        let enabled = Entry {
            enabled: true,
            ..status(4, "mode", "x")
        };
        assert!(retained_status(&enabled, &[], &[]).is_none());
        assert!(retained_status(&entry(Kind::Action, 1, "x"), &[], &[]).is_none());
    }

    #[test]
    fn only_actions_keep_the_menu_open() {
        let mut item = crate::api::tray::TrayItem {
            id: 1,
            kind: crate::api::tray::TrayItemKind::Action,
            label: "Test latency".into(),
            detail: None,
            enabled: true,
            checked: false,
            items: Vec::new(),
            transient_status_key: None,
            segment_group: None,
            segment_error: None,
            icon: None,
            badge: None,
            accessibility_label: None,
            keeps_menu_open: true,
        };
        assert!(Entry::of(&item).keeps_open);
        item.kind = crate::api::tray::TrayItemKind::Checkbox;
        assert!(!Entry::of(&item).keeps_open);
        item.kind = crate::api::tray::TrayItemKind::Action;
        item.keeps_menu_open = false;
        assert!(!Entry::of(&item).keeps_open);
    }

    #[test]
    fn a_kept_row_that_keeps_the_menu_open_follows_its_new_enabled_state() {
        let row = Entry {
            keeps_open: true,
            ..entry(Kind::Action, 1, "Test latency")
        };
        assert!(retained_enabled(&row, false));
        assert!(!retained_enabled(&Entry { enabled: false, ..row.clone() }, true));
        let other = entry(Kind::Action, 2, "Show");
        assert!(!retained_enabled(&other, false));
        assert!(retained_enabled(&other, true));
    }

    #[test]
    fn a_row_that_keeps_the_menu_open_stays_an_enabled_item_while_disabled() {
        let busy = Entry {
            keeps_open: true,
            enabled: false,
            ..entry(Kind::Action, 1, "Test latency")
        };
        assert!(item_enabled(&busy));
        let disabled = Entry {
            enabled: false,
            ..entry(Kind::Action, 2, "Show")
        };
        assert!(!item_enabled(&disabled));
        assert!(item_enabled(&entry(Kind::Action, 3, "Exit")));
    }

    #[test]
    fn only_a_shown_highlighted_row_that_keeps_the_menu_open_takes_activation_keys() {
        let none = NSEventModifierFlags::empty();
        for key in [36, 49, 76] {
            assert!(takes_key(true, true, true, none, key));
            assert!(!takes_key(false, true, true, none, key));
            assert!(!takes_key(true, false, true, none, key));
            assert!(!takes_key(true, true, false, none, key));
        }
        for modifier in [
            NSEventModifierFlags::Command,
            NSEventModifierFlags::Control,
            NSEventModifierFlags::Option,
        ] {
            assert!(!takes_key(true, true, true, modifier, 36));
        }
        assert!(takes_key(true, true, true, NSEventModifierFlags::Shift, 36));
        for key in [53, 125, 126, 0] {
            assert!(!takes_key(true, true, true, none, key));
        }
    }

    #[test]
    fn keeping_the_menu_open_is_not_part_of_a_rows_identity() {
        let current = vec![entry(Kind::Action, 1, "Test latency")];
        let mut desired = current.clone();
        desired[0].keeps_open = true;
        desired[0].enabled = false;
        desired[0].detail = Some("Testing".into());
        assert!(matches(&current, &desired));
    }

    const EDGES: f64 = 54.0;
    const TITLE: f64 = 52.0;
    const ARROW: f64 = 10.0;
    const BADGE: f64 = 44.0;
    const BADGE_ROOM: f64 = BADGE + BADGE_GAP + BADGE_ARROW_GAP - ARROW_GAP;

    fn menu_width(details: &[f64], badge: Option<f64>) -> f64 {
        details
            .iter()
            .map(|&detail| row_width(EDGES, TITLE, Some(detail), badge, Some(ARROW)))
            .fold(0.0, f64::max)
    }

    fn layout_in(width: f64, detail: f64) -> TrailingLayout {
        let room = width - EDGES - ARROW - BADGE_ARROW_GAP;
        trailing_layout(room, TITLE, Some(detail), Some(BADGE), true)
    }

    #[test]
    fn short_selections_stay_whole_and_widen_the_menu_by_the_badge() {
        let details = [38.0, 46.0, 52.0];
        let before = menu_width(&details, None);
        let after = menu_width(&details, Some(BADGE));
        assert_eq!(after - before, BADGE_ROOM);
        for detail in details {
            let layout = layout_in(after, detail);
            assert_eq!(layout.detail, detail);
            assert_eq!(layout.badge, BADGE);
            assert!(layout.title >= TITLE);
        }
    }

    #[test]
    fn long_selections_are_cut_rather_than_widening_the_menu() {
        let at_minimum = menu_width(&[DETAIL_MINIMUM_WIDTH], Some(BADGE));
        let long = menu_width(&[DETAIL_MAXIMUM_WIDTH], Some(BADGE));
        assert_eq!(long, at_minimum);
        let before = menu_width(&[DETAIL_MAXIMUM_WIDTH], None);
        assert_eq!(
            long - before,
            BADGE_ROOM + DETAIL_MINIMUM_WIDTH - DETAIL_MAXIMUM_WIDTH
        );
        let layout = layout_in(long, DETAIL_MAXIMUM_WIDTH);
        assert_eq!(
            layout,
            TrailingLayout {
                badge: BADGE,
                detail: DETAIL_MINIMUM_WIDTH,
                title: TITLE
            }
        );
    }

    #[test]
    fn six_cjk_characters_stay_whole_beside_a_badge() {
        let style = Style::current();
        for name in ["香港节点 01", "新加坡节点组"] {
            assert!(text_width(name, &style.detail_font) <= DETAIL_MINIMUM_WIDTH);
        }
    }

    #[test]
    fn mixed_selections_keep_short_names_whole_and_badges_aligned() {
        let width = menu_width(&[38.0, DETAIL_MAXIMUM_WIDTH], Some(BADGE));
        let short = layout_in(width, 38.0);
        let long = layout_in(width, DETAIL_MAXIMUM_WIDTH);
        assert_eq!(short.detail, 38.0);
        assert_eq!(long.detail, DETAIL_MINIMUM_WIDTH);
        assert_eq!(short.badge, long.badge);
        let wider = layout_in(width + 20.0, DETAIL_MAXIMUM_WIDTH);
        assert_eq!(wider.detail, DETAIL_MINIMUM_WIDTH + 20.0);
    }

    #[test]
    fn badges_hug_their_own_text() {
        let style = Style::current();
        assert_eq!(style.badge_font.pointSize(), style.font.pointSize() - 3.0);
        for label in ["63 ms", "1234 ms", "未测速", "超时", "测试中"] {
            let text = text_width(label, &style.badge_font);
            assert_eq!(style.badge_width(label), text + 2.0 * BADGE_PADDING);
        }
        assert_eq!(style.badge_width("999 ms"), BADGE);
        assert!(style.badge_width("63 ms") < style.badge_width("1234 ms"));
    }

    fn badged(label: &str) -> ItemContent {
        ItemContent {
            label: "Group".into(),
            detail: None,
            icon: None,
            badge: Some(super::BadgeContent {
                label: label.into(),
                background: 0,
                foreground: 0,
            }),
            accessibility_label: None,
            is_checkbox: false,
            checked: false,
            enabled: true,
            keeps_open: false,
            has_submenu: true,
        }
    }

    #[test]
    fn a_menus_badges_take_the_width_of_its_widest_badge() {
        let style = Style::current();
        let column = |labels: &[&str]| {
            let contents: Vec<_> = labels.iter().map(|label| badged(label)).collect();
            badge_column(contents.iter())
        };
        assert_eq!(column(&["63 ms", "111 ms", "34 ms"]), BADGE);
        assert_eq!(column(&["63 ms", "1234 ms"]), style.badge_width("1234 ms"));
        assert_eq!(column(&["63 ms", "未测速"]), style.badge_width("63 ms"));
        assert_eq!(column(&["超时"]), style.badge_width("超时"));
        assert_eq!(badge_column(std::iter::empty()), 0.0);
    }

    #[test]
    fn a_narrower_badge_gives_its_room_to_the_selection() {
        let width = menu_width(&[DETAIL_MAXIMUM_WIDTH], Some(BADGE));
        let room = width - EDGES - ARROW - BADGE_ARROW_GAP;
        let narrow = trailing_layout(room, TITLE, Some(DETAIL_MAXIMUM_WIDTH), Some(40.0), true);
        assert_eq!(narrow.detail, DETAIL_MINIMUM_WIDTH + BADGE - 40.0);
        assert_eq!(
            narrow.badge + BADGE_GAP + narrow.detail,
            BADGE + BADGE_GAP + DETAIL_MINIMUM_WIDTH
        );
    }

    #[test]
    fn long_selections_keep_the_menu_width_of_the_old_badge() {
        let old = EDGES + TITLE + 60.0 + 12.0 + 64.0 + DETAIL_GAP + ARROW + ARROW_GAP;
        assert_eq!(menu_width(&[DETAIL_MAXIMUM_WIDTH], Some(BADGE)), old);
    }

    #[test]
    fn a_row_too_narrow_for_its_badge_gets_no_negative_widths() {
        for room in [-20.0, 0.0, 30.0] {
            let layout = trailing_layout(room, TITLE, Some(40.0), Some(BADGE), true);
            assert!(layout.badge >= 0.0 && layout.detail >= 0.0 && layout.title >= 0.0);
            assert_eq!(layout.detail, 0.0);
            assert_eq!(layout.title, 0.0);
            let plain = trailing_layout(room, TITLE, Some(40.0), None, false);
            assert!(plain.detail >= 0.0 && plain.title >= 0.0);
        }
    }

    #[test]
    fn rows_without_a_group_badge_keep_the_detail_first() {
        let layout = trailing_layout(150.0, 200.0, Some(100.0), None, true);
        assert_eq!(layout.detail, 100.0);
        assert_eq!(layout.title, 150.0 - 100.0 - DETAIL_GAP);
        let member = trailing_layout(150.0, 200.0, Some(100.0), Some(60.0), false);
        assert_eq!(member.badge, 60.0);
        assert_eq!(member.detail, 150.0 - 60.0 - BADGE_GAP);
    }

    #[test]
    fn recognises_delay_badges() {
        assert!(is_delay("120ms"));
        assert!(is_delay("120 ms"));
        assert!(!is_delay("ms"));
        assert!(!is_delay("Timeout"));
    }
}
