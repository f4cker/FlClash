use super::super::emit;
use crate::api::tray::{TrayDot, TrayIconPlacement, TrayImage, TraySignalKind};
use block2::RcBlock;
use objc2::rc::Retained;
use objc2::runtime::{AnyObject, Bool, ProtocolObject};
use objc2::{
    define_class, msg_send, AllocAnyThread, DefinedClass, MainThreadMarker, MainThreadOnly,
};
use objc2_app_kit::{
    NSAttributedStringNSExtendedStringDrawing, NSAttributedStringNSStringDrawing, NSBezierPath,
    NSBitmapImageRep, NSColor, NSCompositingOperation, NSEvent, NSFont, NSFontAttributeName,
    NSForegroundColorAttributeName, NSGraphicsContext, NSImage, NSImageScaling, NSImageView,
    NSLayoutConstraint, NSLayoutConstraintOrientation, NSLayoutPriorityRequired, NSResponder,
    NSStackView, NSStackViewDistribution, NSStatusBar, NSStatusBarButton, NSStatusItem,
    NSStringDrawingOptions, NSUserInterfaceLayoutOrientation, NSVariableStatusItemLength, NSView,
    NSViewNoIntrinsicMetric, NSWorkspace,
    NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification,
};
use objc2_foundation::{
    NSArray, NSAttributedString, NSAttributedStringKey, NSData, NSDictionary, NSNumber, NSObject,
    NSObjectProtocol, NSOperationQueue, NSPoint, NSRect, NSSize, NSString,
};
use objc2_quartz_core::{
    kCAMediaTimingFunctionEaseInEaseOut, CABasicAnimation, CAFrameRateRange, CAMediaTiming,
    CAMediaTimingFunction,
};
use std::cell::{Cell, RefCell};

const TITLE_MIN_WIDTH: f64 = 42.0;
const TITLE_FONT_SIZE: f64 = 8.75;
const TITLE_LINE_HEIGHT: f64 = 9.0;

// The dot mirrors the TUN dot drawn into the `*_tun.png` icons to the
// top-right corner, as measured from their pixels at every scale: on an
// 18pt icon, a 3pt dot centred 2pt in from the corner, in a cut 2.5pt in
// radius.
/// The icon size the geometry below is for; other sizes scale it.
const DOT_ICON_SIZE: f64 = 18.0;
/// The status dot's diameter, in points.
const DOT_DIAMETER: f64 = 3.0;
/// How far the dot's centre sits in from the icon's top and right edges.
const DOT_INSET: f64 = 2.0;
/// The gap cut out of the icon around the dot, through which the menu bar
/// shows.
const DOT_GAP: f64 = 1.0;
/// Breathing fades to this opacity and back.
const DOT_DIM_OPACITY: f32 = 0.4;
/// Half of the two-second breathing cycle; the animation autoreverses.
const DOT_HALF_CYCLE: f64 = 1.0;
/// The render server's frame budget for breathing; the app is not woken.
const DOT_FRAME_RATE: CAFrameRateRange = CAFrameRateRange {
    minimum: 4.0,
    maximum: 10.0,
    preferred: 10.0,
};
const BREATHING_KEY: &str = "flashBreathing";

/// The dot's rect in the unflipped coordinates of an icon `size` points
/// square, grown by `outset` on every side.
pub(super) fn dot_rect(size: f64, outset: f64) -> NSRect {
    let scale = size / DOT_ICON_SIZE;
    let centre = size - DOT_INSET * scale;
    let radius = (DOT_DIAMETER / 2.0 + outset) * scale;
    NSRect::new(
        NSPoint::new(centre - radius, centre - radius),
        NSSize::new(radius * 2.0, radius * 2.0),
    )
}

/// The red, green, blue and alpha components of an ARGB colour.
pub(super) fn argb_components(color: u32) -> [f64; 4] {
    let channel = |shift: u32| f64::from((color >> shift) & 0xff) / 255.0;
    [channel(16), channel(8), channel(0), channel(24)]
}

pub(super) fn image(spec: &TrayImage) -> Option<Retained<NSImage>> {
    let size = NSSize::new(f64::from(spec.size), f64::from(spec.size));
    let image = NSImage::initWithSize(NSImage::alloc(), size);
    for png in &spec.pngs {
        let Some(rep) = NSBitmapImageRep::imageRepWithData(&NSData::with_bytes(png)) else {
            continue;
        };
        rep.setSize(size);
        image.addRepresentation(&rep);
    }
    if image.representations().count() == 0 {
        return None;
    }
    image.setTemplate(spec.template);
    if spec.dot.is_none() {
        return Some(image);
    }
    Some(knock_out(image, size, spec.template))
}

/// Draws [base] with the ring around the dot cleared, so the dot reads as
/// stroked in whatever colour the menu bar has, and the icon stays template.
fn knock_out(base: Retained<NSImage>, size: NSSize, template: bool) -> Retained<NSImage> {
    let ring = dot_rect(size.width, DOT_GAP);
    let handler = RcBlock::new(move |rect: NSRect| -> Bool {
        base.drawInRect(rect);
        if let Some(context) = NSGraphicsContext::currentContext() {
            context.saveGraphicsState();
            context.setCompositingOperation(NSCompositingOperation::Clear);
            NSBezierPath::bezierPathWithOvalInRect(ring).fill();
            context.setCompositingOperation(NSCompositingOperation::SourceOver);
            context.restoreGraphicsState();
        }
        Bool::YES
    });
    let image = NSImage::imageWithSize_flipped_drawingHandler(size, false, &handler);
    image.setTemplate(template);
    image
}

pub(super) struct StatusItem {
    item: Retained<NSStatusItem>,
    content: Retained<ContentView>,
    motion_observer: Retained<ProtocolObject<dyn NSObjectProtocol>>,
}

impl StatusItem {
    pub fn new(mtm: MainThreadMarker) -> Option<Self> {
        let bar = NSStatusBar::systemStatusBar();
        let item = bar.statusItemWithLength(NSVariableStatusItemLength);
        let Some(button) = item.button(mtm) else {
            bar.removeStatusItem(&item);
            return None;
        };
        let content = ContentView::new(mtm);
        button.addSubview(&content);
        content.setTranslatesAutoresizingMaskIntoConstraints(false);
        activate(&[
            content
                .leadingAnchor()
                .constraintEqualToAnchor(&button.leadingAnchor()),
            content
                .trailingAnchor()
                .constraintEqualToAnchor(&button.trailingAnchor()),
            content
                .topAnchor()
                .constraintEqualToAnchor(&button.topAnchor()),
            content
                .bottomAnchor()
                .constraintEqualToAnchor(&button.bottomAnchor()),
            content
                .heightAnchor()
                .constraintEqualToConstant(bar.thickness()),
        ]);
        // Reduce Motion can change while the dot breathes.
        let dot = content.ivars().dot.clone();
        let observer = RcBlock::new(move |_| dot.apply_motion());
        let motion_observer = unsafe {
            NSWorkspace::sharedWorkspace()
                .notificationCenter()
                .addObserverForName_object_queue_usingBlock(
                    Some(NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification),
                    None,
                    Some(&NSOperationQueue::mainQueue()),
                    &observer,
                )
        };
        Some(Self {
            item,
            content,
            motion_observer,
        })
    }

    pub fn item(&self) -> &Retained<NSStatusItem> {
        &self.item
    }

    pub fn set_image(&self, image: &NSImage, placement: TrayIconPlacement) {
        if self.content.set_image(image, placement) {
            self.refit();
        }
    }

    pub fn set_dot(&self, dot: Option<TrayDot>, size: u32) {
        self.content.set_dot(dot, f64::from(size));
    }

    pub fn set_title(&self, title: &str) {
        if self.content.ivars().title.set_title(title) {
            self.refit();
        }
    }

    pub fn remove(self) {
        unsafe {
            NSWorkspace::sharedWorkspace()
                .notificationCenter()
                .removeObserver(self.motion_observer.as_ref());
        }
        self.content.set_dot(None, 0.0);
        self.item.setMenu(None);
        NSStatusBar::systemStatusBar().removeStatusItem(&self.item);
    }

    fn refit(&self) {
        if let Some(button) = self.button() {
            button.sizeToFit();
        }
    }

    fn button(&self) -> Option<Retained<NSStatusBarButton>> {
        self.item.button(self.content.mtm())
    }
}

fn activate(constraints: &[Retained<NSLayoutConstraint>]) {
    NSLayoutConstraint::activateConstraints(&NSArray::from_retained_slice(constraints));
}

pub(super) struct ContentIvars {
    image: Retained<NSImageView>,
    title: Retained<TitleView>,
    stack: Retained<NSStackView>,
    dot: Retained<DotView>,
    dot_x: Retained<NSLayoutConstraint>,
    dot_y: Retained<NSLayoutConstraint>,
    dot_size: Retained<NSLayoutConstraint>,
}

define_class!(
    #[unsafe(super(NSView, NSResponder, NSObject))]
    #[thread_kind = MainThreadOnly]
    #[name = "FlClashTrayContentView"]
    #[ivars = ContentIvars]
    pub(super) struct ContentView;

    impl ContentView {
        #[unsafe(method(mouseDown:))]
        fn mouse_down(&self, _event: &NSEvent) {
            emit(TraySignalKind::MenuRequested, 0);
        }

        #[unsafe(method(rightMouseDown:))]
        fn right_mouse_down(&self, _event: &NSEvent) {
            emit(TraySignalKind::MenuRequested, 0);
        }
    }
);

impl ContentView {
    fn new(mtm: MainThreadMarker) -> Retained<Self> {
        let image = NSImageView::new(mtm);
        image.setImageScaling(NSImageScaling::ScaleProportionallyDown);
        image.setHidden(true);
        image.setContentHuggingPriority_forOrientation(
            NSLayoutPriorityRequired,
            NSLayoutConstraintOrientation::Horizontal,
        );
        let title = TitleView::new(mtm);
        title.setHidden(true);
        let stack = NSStackView::new(mtm);
        stack.setOrientation(NSUserInterfaceLayoutOrientation::Horizontal);
        stack.setSpacing(6.0);
        stack.setDistribution(NSStackViewDistribution::EqualSpacing);
        let dot = DotView::new(mtm);
        dot.setHidden(true);
        dot.setTranslatesAutoresizingMaskIntoConstraints(false);
        let dot_x = dot
            .centerXAnchor()
            .constraintEqualToAnchor(&image.centerXAnchor());
        let dot_y = dot
            .centerYAnchor()
            .constraintEqualToAnchor(&image.centerYAnchor());
        let dot_size = dot.widthAnchor().constraintEqualToConstant(DOT_DIAMETER);

        let this = Self::alloc(mtm).set_ivars(ContentIvars {
            image,
            title,
            stack,
            dot,
            dot_x,
            dot_y,
            dot_size,
        });
        let view: Retained<Self> = unsafe { msg_send![super(this), initWithFrame: NSRect::ZERO] };
        let ivars = view.ivars();
        view.addSubview(&ivars.stack);
        ivars
            .stack
            .setTranslatesAutoresizingMaskIntoConstraints(false);
        activate(&[
            ivars
                .stack
                .leadingAnchor()
                .constraintEqualToAnchor_constant(&view.leadingAnchor(), 8.0),
            ivars
                .stack
                .trailingAnchor()
                .constraintEqualToAnchor_constant(&view.trailingAnchor(), -8.0),
            ivars
                .stack
                .topAnchor()
                .constraintEqualToAnchor_constant(&view.topAnchor(), 2.0),
            ivars
                .stack
                .bottomAnchor()
                .constraintEqualToAnchor_constant(&view.bottomAnchor(), -2.0),
        ]);
        view.apply_placement(TrayIconPlacement::Leading);
        // Above the stack, and outside it so it never takes part in layout.
        view.addSubview(&ivars.dot);
        activate(&[
            ivars.dot_x.clone(),
            ivars.dot_y.clone(),
            ivars.dot_size.clone(),
            ivars
                .dot
                .heightAnchor()
                .constraintEqualToAnchor(&ivars.dot.widthAnchor()),
        ]);
        ivars
            .title
            .setTranslatesAutoresizingMaskIntoConstraints(false);
        ivars.title.setContentHuggingPriority_forOrientation(
            NSLayoutPriorityRequired,
            NSLayoutConstraintOrientation::Horizontal,
        );
        ivars
            .title
            .setContentCompressionResistancePriority_forOrientation(
                NSLayoutPriorityRequired,
                NSLayoutConstraintOrientation::Horizontal,
            );
        activate(&[ivars
            .title
            .widthAnchor()
            .constraintGreaterThanOrEqualToConstant(TITLE_MIN_WIDTH)]);
        view
    }

    fn set_image(&self, image: &NSImage, placement: TrayIconPlacement) -> bool {
        let view = &self.ivars().image;
        let was_hidden = view.isHidden();
        let previous = view.image().map_or(NSSize::ZERO, |image| image.size());
        view.setImage(Some(image));
        view.setHidden(false);
        self.apply_placement(placement);
        was_hidden || previous != image.size()
    }

    /// Places the dot on the top-right corner of the icon, which the image
    /// view centres.
    fn set_dot(&self, dot: Option<TrayDot>, size: f64) {
        let ivars = self.ivars();
        let Some(dot) = dot else {
            ivars.dot.set_breathing(false);
            ivars.dot.setHidden(true);
            return;
        };
        let rect = dot_rect(size, 0.0);
        let offset = rect.origin.x + rect.size.width / 2.0 - size / 2.0;
        ivars.dot_size.setConstant(rect.size.width);
        ivars.dot_x.setConstant(offset);
        // Layout anchors grow downwards.
        ivars.dot_y.setConstant(-offset);
        ivars.dot.set_color(dot.color);
        ivars.dot.setHidden(false);
        ivars.dot.set_breathing(dot.breathing);
    }

    fn apply_placement(&self, placement: TrayIconPlacement) {
        let ivars = self.ivars();
        let image: &NSView = &ivars.image;
        let title: &NSView = &ivars.title;
        let wanted = match placement {
            TrayIconPlacement::Leading => [image, title],
            TrayIconPlacement::Trailing => [title, image],
        };
        let current = ivars.stack.arrangedSubviews().to_vec();
        let in_place = current.len() == wanted.len()
            && current
                .iter()
                .zip(wanted)
                .all(|(view, wanted)| std::ptr::eq(&**view, wanted));
        if in_place {
            return;
        }
        for view in &current {
            ivars.stack.removeArrangedSubview(view);
        }
        for (index, view) in wanted.into_iter().enumerate() {
            ivars
                .stack
                .insertArrangedSubview_atIndex(view, index as isize);
        }
    }
}

pub(super) struct DotIvars {
    color: Cell<u32>,
    breathing: Cell<bool>,
}

define_class!(
    #[unsafe(super(NSView, NSResponder, NSObject))]
    #[thread_kind = MainThreadOnly]
    #[name = "FlClashTrayDotView"]
    #[ivars = DotIvars]
    pub(super) struct DotView;

    impl DotView {
        #[unsafe(method(drawRect:))]
        fn draw_rect(&self, _dirty: NSRect) {
            let [red, green, blue, alpha] = argb_components(self.ivars().color.get());
            NSColor::colorWithSRGBRed_green_blue_alpha(red, green, blue, alpha).set();
            NSBezierPath::bezierPathWithOvalInRect(self.bounds()).fill();
        }
    }
);

impl DotView {
    fn new(mtm: MainThreadMarker) -> Retained<Self> {
        let this = Self::alloc(mtm).set_ivars(DotIvars {
            color: Cell::new(0),
            breathing: Cell::new(false),
        });
        let view: Retained<Self> = unsafe { msg_send![super(this), initWithFrame: NSRect::ZERO] };
        // Breathing animates the layer's opacity in the render server.
        view.setWantsLayer(true);
        view
    }

    fn set_color(&self, color: u32) {
        if self.ivars().color.replace(color) != color {
            self.setNeedsDisplay(true);
        }
    }

    fn set_breathing(&self, breathing: bool) {
        self.ivars().breathing.set(breathing);
        self.apply_motion();
    }

    /// Breathes when asked to and the system allows motion; otherwise holds
    /// full opacity.
    fn apply_motion(&self) {
        let Some(layer) = self.layer() else {
            return;
        };
        let key = NSString::from_str(BREATHING_KEY);
        let wanted = self.ivars().breathing.get()
            && !NSWorkspace::sharedWorkspace().accessibilityDisplayShouldReduceMotion();
        let running = unsafe { layer.animationForKey(&key) }.is_some();
        if wanted == running {
            return;
        }
        if !wanted {
            layer.removeAnimationForKey(&key);
            return;
        }
        let animation =
            CABasicAnimation::animationWithKeyPath(Some(&NSString::from_str("opacity")));
        let from: &AnyObject = &NSNumber::new_f32(1.0);
        let to: &AnyObject = &NSNumber::new_f32(DOT_DIM_OPACITY);
        unsafe {
            animation.setFromValue(Some(from));
            animation.setToValue(Some(to));
        }
        animation.setDuration(DOT_HALF_CYCLE);
        animation.setAutoreverses(true);
        animation.setRepeatCount(f32::INFINITY);
        animation.setTimingFunction(Some(&CAMediaTimingFunction::functionWithName(unsafe {
            kCAMediaTimingFunctionEaseInEaseOut
        })));
        animation.setPreferredFrameRateRange(DOT_FRAME_RATE);
        animation.setRemovedOnCompletion(false);
        layer.addAnimation_forKey(&animation, Some(&key));
    }
}

pub(super) struct TitleIvars {
    lines: RefCell<Vec<Retained<NSAttributedString>>>,
    width: Cell<f64>,
}

define_class!(
    #[unsafe(super(NSView, NSResponder, NSObject))]
    #[thread_kind = MainThreadOnly]
    #[name = "FlClashTrayTitleView"]
    #[ivars = TitleIvars]
    pub(super) struct TitleView;

    impl TitleView {
        #[unsafe(method(isFlipped))]
        fn is_flipped(&self) -> bool {
            true
        }

        #[unsafe(method(intrinsicContentSize))]
        fn intrinsic_content_size(&self) -> NSSize {
            NSSize::new(self.ivars().width.get(), unsafe { NSViewNoIntrinsicMetric })
        }

        // Line boxes carry descender space, so centring them leaves the digits high.
        #[unsafe(method(drawRect:))]
        fn draw_rect(&self, _dirty: NSRect) {
            let Ok(lines) = self.ivars().lines.try_borrow() else {
                return;
            };
            if lines.is_empty() {
                return;
            }
            let bounds = self.bounds();
            let cap_height = title_font().capHeight();
            let block_height = cap_height + TITLE_LINE_HEIGHT * (lines.len() - 1) as f64;
            let scale = self.window().map_or(2.0, |window| window.backingScaleFactor());
            let mut baseline =
                (((bounds.size.height - block_height) / 2.0 + cap_height) * scale).round() / scale;
            for line in lines.iter() {
                let width = line.size().width;
                line.drawWithRect_options_context(
                    NSRect::new(
                        NSPoint::new(bounds.size.width - width, baseline),
                        NSSize::new(width, 0.0),
                    ),
                    NSStringDrawingOptions::empty(),
                    None,
                );
                baseline += TITLE_LINE_HEIGHT;
            }
        }
    }
);

impl TitleView {
    fn new(mtm: MainThreadMarker) -> Retained<Self> {
        let this = Self::alloc(mtm).set_ivars(TitleIvars {
            lines: RefCell::new(Vec::new()),
            width: Cell::new(TITLE_MIN_WIDTH),
        });
        unsafe { msg_send![super(this), initWithFrame: NSRect::ZERO] }
    }

    fn set_title(&self, title: &str) -> bool {
        let was_hidden = self.isHidden();
        let previous_width = self.ivars().width.get();
        let lines: Vec<_> = if title.is_empty() {
            Vec::new()
        } else {
            let attributes = title_attributes();
            title
                .split('\n')
                .map(|line| unsafe {
                    NSAttributedString::initWithString_attributes(
                        NSAttributedString::alloc(),
                        &NSString::from_str(line),
                        Some(&attributes),
                    )
                })
                .collect()
        };
        let text_width = lines
            .iter()
            .map(|line| line.size().width.ceil())
            .fold(0.0, f64::max);
        let width = TITLE_MIN_WIDTH.max(text_width);
        if let Ok(mut current) = self.ivars().lines.try_borrow_mut() {
            *current = lines;
        }
        self.setNeedsDisplay(true);
        self.ivars().width.set(width);
        self.setHidden(title.is_empty());
        let width_changed = width != previous_width;
        if width_changed {
            self.invalidateIntrinsicContentSize();
        }
        was_hidden != self.isHidden() || width_changed
    }
}

fn title_font() -> Retained<NSFont> {
    NSFont::systemFontOfSize(TITLE_FONT_SIZE)
}

fn title_attributes() -> Retained<NSDictionary<NSAttributedStringKey, AnyObject>> {
    let font = title_font();
    let color = NSColor::labelColor();
    let keys: [&NSAttributedStringKey; 2] =
        unsafe { [NSFontAttributeName, NSForegroundColorAttributeName] };
    let values: [&AnyObject; 2] = [&font, &color];
    NSDictionary::from_slices(&keys, &values)
}

#[cfg(test)]
mod tests {
    use super::*;

    // The TUN icons' dot: centre (16, 16) from the top left of 18pt, 3pt
    // across, in a 5pt cut. Mirrored to the top it sits at (16, 2), which is
    // (16, 16) in unflipped coordinates.
    #[test]
    fn dot_mirrors_the_tun_dot_to_the_top_right_corner() {
        let rect = dot_rect(18.0, 0.0);
        assert_eq!(rect.size, NSSize::new(3.0, 3.0));
        assert_eq!(rect.origin.x + rect.size.width / 2.0, 16.0);
        assert_eq!(rect.origin.y + rect.size.height / 2.0, 16.0);
    }

    #[test]
    fn the_gap_matches_the_tun_dot() {
        let dot = dot_rect(18.0, 0.0);
        let cut = dot_rect(18.0, DOT_GAP);
        assert_eq!(cut.size, NSSize::new(5.0, 5.0));
        assert_eq!(cut.origin.x, dot.origin.x - 1.0);
        assert_eq!(cut.origin.y, dot.origin.y - 1.0);
    }

    #[test]
    fn other_icon_sizes_scale_the_geometry() {
        let rect = dot_rect(36.0, 0.0);
        assert_eq!(rect.size, NSSize::new(6.0, 6.0));
        assert_eq!(rect.origin.x + rect.size.width / 2.0, 32.0);
    }

    #[test]
    fn argb_colours_split_into_components() {
        assert_eq!(
            argb_components(0xFFFF3B30),
            [1.0, 59.0 / 255.0, 48.0 / 255.0, 1.0]
        );
        assert_eq!(argb_components(0x80FF9F0A)[3], 128.0 / 255.0);
    }

    #[test]
    fn breathing_stays_within_ten_frames_a_second() {
        assert!(DOT_FRAME_RATE.maximum <= 10.0);
        assert!(DOT_FRAME_RATE.minimum <= DOT_FRAME_RATE.preferred);
        assert!(DOT_FRAME_RATE.preferred <= DOT_FRAME_RATE.maximum);
        assert_eq!(DOT_HALF_CYCLE * 2.0, 2.0);
    }
}
