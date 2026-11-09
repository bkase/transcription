mod design;
mod state;
mod symbols;
mod ui;

use rune::{AppSpec, Key};
use state::{Page, State};
use std::sync::OnceLock;

#[cfg(target_os = "ios")]
mod ios;

fn app_spec(font_path: &str) -> AppSpec<State> {
    static FONTS: OnceLock<&'static [&'static [u8]]> = OnceLock::new();
    let fonts = FONTS.get_or_init(|| {
        std::fs::read(font_path)
            .ok()
            .map(|bytes| {
                let face: &'static [u8] = bytes.leak();
                &*vec![face].leak()
            })
            .unwrap_or(&[])
    });
    AppSpec {
        min_size: Some((350.0, 700.0)),
        fonts,
        families: (".SF NS, .SF UI, Inter", "ui-monospace"),
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
    }
}

#[cfg(not(target_os = "ios"))]
pub fn desktop_main() {
    rune::App::new(app_spec("/System/Library/Fonts/SFNS.ttf"))
        .standard_menus()
        .on_close(|s, _| s.close())
        .run();
}
