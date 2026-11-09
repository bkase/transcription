#[cfg(not(target_os = "ios"))]
fn main() {
    vapor_rune::desktop_main();
}

#[cfg(all(target_os = "ios", not(all(target_abi = "sim", feature = "ios-hot"))))]
fn main() {
    // The iOS application links the library from Xcode and enters through UIApplication.
}

#[cfg(all(target_os = "ios", target_abi = "sim", feature = "ios-hot"))]
include!("lib.rs");

#[cfg(all(target_os = "ios", target_abi = "sim", feature = "ios-hot"))]
fn main() {
    unsafe extern "C" {
        fn vapor_launch() -> i32;
    }
    // This binary's main thread owns UIKit. The shell was linked by build.rs.
    std::process::exit(unsafe { vapor_launch() });
}
