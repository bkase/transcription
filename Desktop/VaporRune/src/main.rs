#[cfg(not(target_os = "ios"))]
fn main() {
    vapor_rune::desktop_main();
}

#[cfg(target_os = "ios")]
fn main() {
    // The iOS application links the library from Xcode and enters through UIApplication.
}
