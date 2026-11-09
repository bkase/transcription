mod design;
mod state;
mod symbols;
mod ui;

use rune::{App, AppSpec, Key};
use state::{Page, State};

fn main() {
    let fonts = std::fs::read("/System/Library/Fonts/SFNS.ttf")
        .ok()
        .map(|bytes| {
            let face: &'static [u8] = bytes.leak();
            &*vec![face].leak()
        })
        .unwrap_or(&[]);
    let spec: AppSpec<State> = AppSpec {
        min_size: Some((350.0, 700.0)),
        fonts,
        families: (".SF NS, Inter", "ui-monospace"),
        setup: Some(|s, waker| s.waker = Some(waker)),
        poll: Some(|s, _, tx| s.poll(tx)),
        on_key: Some(|s, event, tx| {
            if event.key != Key::Escape || matches!(s.page, Page::Timeline) {
                return false;
            }
            if matches!(&s.page, Page::Recording(draft) if draft.modal.is_some()) {
                ui::close_modal(s);
                tx.blur();
            } else {
                s.back();
            }
            true
        }),
        ..AppSpec::new("Vapor", (390.0, 844.0), State::new, ui::view)
    };
    App::new(spec)
        .standard_menus()
        .on_close(|s, _| s.close())
        .run();
}
