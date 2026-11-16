mod menu;
mod status;

use super::emit_signal;
use crate::api::tray::{TrayContent, TraySignal, TraySignalKind};
use block2::RcBlock;
use menu::{Entry, TrayMenu};
use objc2::rc::Retained;
use objc2::MainThreadMarker;
use objc2_app_kit::NSStatusItem;
use objc2_foundation::NSRunLoop;
use status::StatusItem;
use std::cell::RefCell;

thread_local! {
    static TRAY: RefCell<Option<Tray>> = const { RefCell::new(None) };
}

struct Tray {
    status: StatusItem,
    /// The menu the next open shows.
    menu: Option<Retained<TrayMenu>>,
    /// The menu being tracked, which may be older than [menu].
    tracking: Option<Retained<TrayMenu>>,
    /// The last menu that closed; a selection made in it is still delivered
    /// after it closes.
    closed: Option<Retained<TrayMenu>>,
    open_scheduled: bool,
}

impl Tray {
    fn generations(&self) -> TraySignal {
        let mut generations: Vec<u32> = [&self.menu, &self.tracking, &self.closed]
            .into_iter()
            .flatten()
            .map(|menu| menu.generation())
            .collect();
        generations.sort_unstable();
        generations.dedup();
        TraySignal {
            kind: TraySignalKind::MenuGenerations,
            item_id: 0,
            menu_generation: 0,
            generations,
            tracking_generation: self.tracking.as_ref().map(|menu| menu.generation()),
        }
    }
}

fn publish(signal: Option<TraySignal>) {
    if let Some(signal) = signal {
        emit_signal(signal);
    }
}

// Every entry point is a synchronous bridge call, which Flutter runs on the
// platform thread; one that is not is refused rather than sent across.
pub fn show(content: TrayContent) -> bool {
    let Some(mtm) = MainThreadMarker::new() else {
        return false;
    };
    let Some(image) = status::image(&content.image) else {
        return false;
    };
    let mut signal = None;
    let shown = TRAY.with(|cell| {
        let Ok(mut slot) = cell.try_borrow_mut() else {
            return false;
        };
        if slot.is_none() {
            *slot = StatusItem::new(mtm).map(|status| Tray {
                status,
                menu: None,
                tracking: None,
                closed: None,
                open_scheduled: false,
            });
        }
        let Some(tray) = slot.as_mut() else {
            return false;
        };
        tray.status.set_image(&image, content.image.placement);
        tray.status.set_title(&content.title);
        let entries = Entry::list(&content.menu);
        let generation = content.menu_generation;
        // An open menu takes new content in place when its rows are the
        // same; otherwise it keeps its rows and the next open builds anew.
        let reused = tray
            .tracking
            .as_ref()
            .filter(|active| active.reconcile(entries.clone(), generation))
            .cloned();
        tray.menu = Some(match reused {
            Some(active) => active,
            None => TrayMenu::new(mtm, entries, generation, true),
        });
        signal = Some(tray.generations());
        true
    });
    // Emitted outside the borrow: a sink never calls back in, but the menu
    // delegate may, and must find the cell free.
    publish(signal);
    shown
}

pub fn set_title(title: String) -> bool {
    if MainThreadMarker::new().is_none() {
        return false;
    }
    TRAY.with(|cell| match cell.try_borrow().as_deref() {
        Ok(Some(tray)) => {
            tray.status.set_title(&title);
            true
        }
        _ => false,
    })
}

pub fn hide() {
    if MainThreadMarker::new().is_none() {
        return;
    }
    let tray = TRAY.with(|cell| cell.try_borrow_mut().ok().and_then(|mut slot| slot.take()));
    if let Some(tray) = tray {
        if let Some(active) = &tray.tracking {
            active.cancelTracking();
        }
        tray.status.remove();
        publish(Some(TraySignal {
            kind: TraySignalKind::MenuGenerations,
            item_id: 0,
            menu_generation: 0,
            generations: Vec::new(),
            tracking_generation: None,
        }));
    }
}

pub fn open_menu() -> bool {
    if MainThreadMarker::new().is_none() {
        return false;
    }
    let (has_menu, schedule) = TRAY.with(|cell| {
        let Ok(mut slot) = cell.try_borrow_mut() else {
            return (false, false);
        };
        let Some(tray) = slot.as_mut() else {
            return (false, false);
        };
        if tray.menu.is_none() {
            return (false, false);
        }
        if tray.tracking.is_some() || tray.open_scheduled {
            return (true, false);
        }
        tray.open_scheduled = true;
        (true, true)
    });
    // Tracking a menu runs a nested event loop, which inside this call would
    // hold the Dart isolate until the menu closes.
    if schedule {
        unsafe { NSRunLoop::mainRunLoop().performBlock(&RcBlock::new(track_menu)) };
    }
    has_menu
}

fn track_menu() {
    let Some(mtm) = MainThreadMarker::new() else {
        return;
    };
    let mut signal = None;
    let target = TRAY.with(|cell| {
        let mut slot = cell.try_borrow_mut().ok()?;
        let tray = slot.as_mut()?;
        if !tray.open_scheduled {
            return None;
        }
        tray.open_scheduled = false;
        let menu = tray.menu.clone()?;
        menu.prepare_for_opening();
        tray.tracking = Some(menu.clone());
        signal = Some(tray.generations());
        Some((tray.status.item().clone(), menu))
    });
    publish(signal);
    let Some((item, menu)) = target else {
        return;
    };
    item.setMenu(Some(&menu));
    if let Some(button) = item.button(mtm) {
        unsafe { button.performClick(None) };
    }
}

/// Called by the root menu's delegate once it closes.
fn close_menu(generation: u32) {
    let mut signal = None;
    let item: Option<Retained<NSStatusItem>> = TRAY.with(|cell| {
        let mut slot = cell.try_borrow_mut().ok()?;
        let tray = slot.as_mut()?;
        if tray.tracking.as_ref()?.generation() != generation {
            return None;
        }
        tray.closed = tray.tracking.take();
        signal = Some(tray.generations());
        Some(tray.status.item().clone())
    });
    if let Some(item) = item {
        item.setMenu(None);
    }
    publish(signal);
}
