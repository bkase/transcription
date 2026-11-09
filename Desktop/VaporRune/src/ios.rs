use std::{
    ffi::{CStr, CString, c_char, c_void},
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};

use rune::{TouchPhase, embed::LayerHost};
use serde::Serialize;

use crate::{
    app_spec, design,
    state::{Page, State},
    ui,
};

struct Host {
    layer: LayerHost<State>,
    dirty: Arc<AtomicBool>,
    deadline: Option<f64>,
    animating: bool,
}

#[derive(Serialize)]
struct Node {
    key: Option<String>,
    role: &'static str,
    label: String,
    value: Option<String>,
    rect: [f32; 4],
    enabled: bool,
}

// The Swift host exclusively owns this Box and calls the bridge on the UIKit main thread.
unsafe fn host<'a>(ptr: *mut c_void) -> &'a mut Host {
    unsafe { &mut *ptr.cast() }
}

unsafe fn string<'a>(ptr: *const c_char) -> &'a str {
    unsafe { CStr::from_ptr(ptr) }.to_str().unwrap_or("")
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_create(
    layer: *mut c_void,
    w: f32,
    h: f32,
    scale: f32,
    folder: *const c_char,
    font: *const c_char,
) -> *mut c_void {
    let spec = app_spec(unsafe { string(font) });
    let state = State::in_folder(PathBuf::from(unsafe { string(folder) }));
    let dirty = Arc::new(AtomicBool::new(true));
    let flag = dirty.clone();
    let waker = Arc::new(move || flag.store(true, Ordering::Release));
    match unsafe {
        LayerHost::from_core_animation_layer(layer, &spec, state, (w, h), scale, false, waker)
    } {
        Ok(layer) => Box::into_raw(Box::new(Host {
            layer: layer.with_native_media(),
            dirty,
            deadline: None,
            animating: true,
        }))
        .cast(),
        Err(error) => {
            eprintln!("Vapor could not attach to its Metal layer: {error}");
            std::ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_destroy(ptr: *mut c_void) {
    drop(unsafe { Box::from_raw(ptr.cast::<Host>()) });
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_resize(ptr: *mut c_void, w: f32, h: f32, scale: f32) {
    let host = unsafe { host(ptr) };
    host.layer.resize((w, h), scale);
    host.dirty.store(true, Ordering::Release);
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_frame(ptr: *mut c_void, now: f64) -> bool {
    let host = unsafe { host(ptr) };
    let dirty = host.dirty.swap(false, Ordering::AcqRel);
    if !dirty && !host.animating && !host.deadline.is_some_and(|t| t <= now) {
        return false;
    }
    let frame = host.layer.frame();
    host.deadline = frame.wake_after_secs.map(|after| now + after);
    host.animating = frame.animating;
    frame.drew
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_touch(ptr: *mut c_void, phase: i32, x: f32, y: f32, now: f64) {
    let host = unsafe { host(ptr) };
    let phase = match phase {
        0 => TouchPhase::Started,
        1 => TouchPhase::Moved,
        2 => TouchPhase::Ended,
        _ => TouchPhase::Cancelled,
    };
    host.layer.runtime_mut().touch(0, phase, x, y, now);
    host.dirty.store(true, Ordering::Release);
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_preferences(ptr: *mut c_void, reduced_motion: bool) {
    let host = unsafe { host(ptr) };
    host.layer
        .runtime_mut()
        .set_system_reduced_motion(reduced_motion);
    host.dirty.store(true, Ordering::Release);
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_suspend(ptr: *mut c_void) {
    let host = unsafe { host(ptr) };
    let rt = host.layer.runtime_mut();
    rt.state.close();
    rt.invalidate();
    host.dirty.store(true, Ordering::Release);
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_activate(ptr: *mut c_void, key: *const c_char) -> bool {
    let host = unsafe { host(ptr) };
    let key = unsafe { string(key) };
    let accepted =
        host.layer
            .runtime_mut()
            .accessibility_action(key, accesskit::Action::Click, None);
    if accepted {
        host.dirty.store(true, Ordering::Release);
    }
    accepted
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_edit(
    ptr: *mut c_void,
    key: *const c_char,
    value: *const c_char,
    submit: bool,
) {
    let host = unsafe { host(ptr) };
    let rt = host.layer.runtime_mut();
    let key = unsafe { string(key) };
    let value = unsafe { string(value) };
    match (key, &mut rt.state.page) {
        ("search", Page::Timeline) => rt.state.search.replace_text(value),
        ("speakerName", Page::Recording(draft)) => {
            draft.name_edit.replace_text(value);
            if submit {
                ui::apply_name(&mut rt.state);
            }
        }
        _ => return,
    }
    rt.invalidate();
    host.dirty.store(true, Ordering::Release);
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_nodes(ptr: *mut c_void) -> *mut c_char {
    let rt = unsafe { host(ptr) }.layer.runtime();
    let elements = rt.elements();
    let nodes: Vec<_> = elements
        .iter()
        .filter_map(|element| {
            let key = element.key.as_deref();
            if element.exiting
                || element.inert
                || element.opacity < 0.05
                || element.visible[2] <= 0.0
                || element.visible[3] <= 0.0
            {
                return None;
            }
            let value = match (key, &rt.state.page) {
                (Some("search"), Page::Timeline) => Some(rt.state.search.text.clone()),
                (Some("speakerName"), Page::Recording(draft)) => Some(draft.name_edit.text.clone()),
                _ => None,
            };
            let role = if value.is_some() {
                "input"
            } else if element.role == "button" && key.is_some() {
                "button"
            } else if element.role == "text" {
                let mut parent = element.parent;
                while let Some(ancestor) = parent.and_then(|index| elements.get(index)) {
                    if ancestor.role == "button" {
                        return None;
                    }
                    parent = ancestor.parent;
                }
                "text"
            } else {
                return None;
            };
            Some(Node {
                key: element.key.clone(),
                role,
                label: element.label.clone().or_else(|| element.text.clone())?,
                value,
                rect: element.visible,
                enabled: role != "button" || element.focusable,
            })
        })
        .collect();
    serde_json::to_string(&nodes)
        .ok()
        .and_then(|json| CString::new(json).ok())
        .map_or(std::ptr::null_mut(), CString::into_raw)
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_free_nodes(nodes: *mut c_char) {
    drop(unsafe { CString::from_raw(nodes) });
}

#[unsafe(no_mangle)]
unsafe extern "C" fn vapor_color_rgb(name: *const c_char) -> u32 {
    let color = design::color(unsafe { string(name) });
    let channel = |linear| (rune::color::srgb_encode(linear) * 255.0).round() as u32;
    (channel(color.r) << 16) | (channel(color.g) << 8) | channel(color.b)
}
