use rune::{El, el};

#[derive(Clone, Copy)]
pub struct Symbol {
    pub name: &'static str,
    pub size: u8,
    pub weight: Weight,
}

#[derive(Clone, Copy, Eq, Hash, PartialEq)]
pub enum Weight {
    Light,
    Regular,
    Medium,
}

impl Symbol {
    pub const fn new(name: &'static str, size: u8, weight: Weight) -> Self {
        Self { name, size, weight }
    }
}

#[cfg(any(target_os = "macos", target_os = "ios"))]
pub fn symbol(spec: Symbol, ink: &'static str) -> El {
    use std::{cell::RefCell, collections::HashMap};

    type Key = (&'static str, u8, Weight, &'static str);
    type Icon = (rune::Image, f32, f32);

    thread_local! {
        static SYMBOLS: RefCell<HashMap<Key, Option<Icon>>> = RefCell::default();
    }

    SYMBOLS.with_borrow_mut(|cache| {
        let key = (spec.name, spec.size, spec.weight, ink);
        match cache.entry(key).or_insert_with(|| load(spec, ink)) {
            Some((image, width, height)) => el().size(*width, *height).pixels(image.pixels()),
            None => el().size(f32::from(spec.size), f32::from(spec.size)),
        }
    })
}

#[cfg(target_os = "macos")]
fn load(spec: Symbol, ink: &str) -> Option<(rune::Image, f32, f32)> {
    use objc2::rc::autoreleasepool;
    use objc2_app_kit::{
        NSBitmapImageFileType, NSBitmapImageRep, NSColor, NSImage, NSImageSymbolConfiguration,
    };
    use objc2_foundation::{NSArray, NSDictionary, NSString};
    use rune::color::srgb_encode;
    use std::sync::{Arc, LazyLock};

    static IMAGES: LazyLock<rune::ImageCache> =
        LazyLock::new(|| rune::ImageCache::new(Arc::new(|| {})));
    autoreleasepool(|_| {
        let color = crate::design::color(ink);
        let tint = NSColor::colorWithSRGBRed_green_blue_alpha(
            srgb_encode(color.r) as f64,
            srgb_encode(color.g) as f64,
            srgb_encode(color.b) as f64,
            color.a as f64,
        );
        let palette =
            NSImageSymbolConfiguration::configurationWithPaletteColors(&NSArray::from_slice(&[
                &*tint,
            ]));
        let size = f64::from(spec.size);
        let weight = match spec.weight {
            Weight::Light => -0.4,
            Weight::Regular => 0.0,
            Weight::Medium => 0.23,
        };
        let image = NSImage::imageWithSystemSymbolName_accessibilityDescription(
            &NSString::from_str(spec.name),
            None,
        )?;
        let nominal = NSImageSymbolConfiguration::configurationWithPointSize_weight(size, weight);
        let bounds = image.imageWithSymbolConfiguration(&nominal)?.size();
        let retina =
            NSImageSymbolConfiguration::configurationWithPointSize_weight(size * 3.0, weight)
                .configurationByApplyingConfiguration(&palette);
        let image = image.imageWithSymbolConfiguration(&retina)?;
        let tiff = image.TIFFRepresentation()?;
        let bitmap = NSBitmapImageRep::imageRepWithData(&tiff)?;
        // An empty dictionary supplies AppKit's default PNG encoder options.
        let png = unsafe {
            bitmap.representationUsingType_properties(
                NSBitmapImageFileType::PNG,
                &NSDictionary::new(),
            )
        }?;
        let image = IMAGES.load(png.to_vec());
        image.wait().ok()?;
        Some((image, bounds.width as f32, bounds.height as f32))
    })
}

#[cfg(not(any(target_os = "macos", target_os = "ios")))]
pub fn symbol(spec: Symbol, ink: &'static str) -> El {
    let glyph = match spec.name {
        "chevron.left" => "‹",
        "chevron.right" => "›",
        "chevron.up" => "⌃",
        "chevron.down" => "⌄",
        "play.fill" => "▶",
        "pause" => "Ⅱ",
        "person.2" => "♙♙",
        "mic" => "♩",
        "magnifyingglass" => "⌕",
        _ => "",
    };
    let weight = match spec.weight {
        Weight::Light => 300.0,
        Weight::Regular => 400.0,
        Weight::Medium => 500.0,
    };
    crate::design::label(glyph, f32::from(spec.size), weight, 0.0, ink)
}

#[cfg(target_os = "ios")]
fn load(spec: Symbol, ink: &str) -> Option<(rune::Image, f32, f32)> {
    use objc2::rc::Retained;
    use objc2_foundation::NSData;
    use rune::color::srgb_encode;
    use std::{
        ffi::{CString, c_char},
        sync::{Arc, LazyLock},
    };

    unsafe extern "C" {
        fn vapor_symbol(
            name: *const c_char,
            point_size: f32,
            weight: i32,
            red: f32,
            green: f32,
            blue: f32,
            width: *mut f32,
            height: *mut f32,
        ) -> *mut NSData;
    }

    static IMAGES: LazyLock<rune::ImageCache> =
        LazyLock::new(|| rune::ImageCache::new(Arc::new(|| {})));
    let name = CString::new(spec.name).ok()?;
    let color = crate::design::color(ink);
    let weight = match spec.weight {
        Weight::Light => 0,
        Weight::Regular => 1,
        Weight::Medium => 2,
    };
    let (mut width, mut height) = (0.0, 0.0);
    // The UIKit host calls the view on the main thread. The callback copies the name
    // immediately and gives Rust one retained NSData containing the symbol's PNG.
    let png = unsafe {
        Retained::from_raw(vapor_symbol(
            name.as_ptr(),
            f32::from(spec.size),
            weight,
            srgb_encode(color.r),
            srgb_encode(color.g),
            srgb_encode(color.b),
            &mut width,
            &mut height,
        ))
    }?;
    let image = IMAGES.load(png.to_vec());
    image.wait().ok()?;
    Some((image, width, height))
}
