use std::{collections::BTreeMap, sync::LazyLock};

use rune::{Color, Easing, El, Family, TextStyle, el, text};
use serde::Deserialize;

#[derive(Deserialize)]
pub struct Tokens {
    colors: BTreeMap<String, BTreeMap<String, String>>,
    pub spacing: Spacing,
    pub radii: Radii,
    pub motion: Motion,
}

#[derive(Deserialize)]
pub struct Spacing {
    pub xs: f32,
    pub sm: f32,
    pub md: f32,
    pub lg: f32,
    pub xl: f32,
}

#[derive(Deserialize)]
pub struct Radii {
    pub md: f32,
}

#[derive(Deserialize)]
pub struct Motion {
    curves: BTreeMap<String, String>,
    durations: BTreeMap<String, f64>,
}

pub static VAPOR: LazyLock<Tokens> = LazyLock::new(|| {
    serde_json::from_str(include_str!("../tokens.json")).expect("Vapor design tokens")
});

impl Motion {
    pub fn seconds(&self, name: &str) -> f64 {
        self.durations[name] / 1000.0
    }

    pub fn easing(&self, name: &str) -> Easing {
        let points: Vec<f32> = self.curves[name]
            .trim_start_matches("cubic-bezier(")
            .trim_end_matches(')')
            .split(',')
            .map(|value| value.trim().parse().expect("Vapor bezier control point"))
            .collect();
        Easing::cubic(points[0], points[1], points[2], points[3])
    }
}

pub fn color(name: &str) -> Color {
    let hex = VAPOR
        .colors
        .values()
        .find_map(|group| group.get(name))
        .unwrap_or_else(|| panic!("Unknown Vapor color {name}"));
    rune::color::hex(hex).expect("Vapor color hex")
}

pub fn font(size: f32, weight: f32, tracking: f32) -> TextStyle {
    TextStyle::new(size, weight)
        .family(Family::Named(".SF NS"))
        .lh((size * 1.19).ceil())
        .tracking(tracking)
}

pub fn label(value: impl Into<String>, size: f32, weight: f32, tracking: f32, ink: &str) -> El {
    text(value.into())
        .font(font(size, weight, tracking))
        .color(color(ink))
}

pub fn circle(diameter: f32, fill: Color) -> El {
    el().size(diameter, diameter)
        .radius(diameter / 2.0)
        .fill(fill)
}

pub fn rule(ink: Color) -> El {
    el().w_full().h(1.0).fill(ink)
}

pub fn button(key: impl Into<String>, name: impl Into<String>, body: El) -> El {
    body.key(key).role("button").label(name).focusable(true)
}
