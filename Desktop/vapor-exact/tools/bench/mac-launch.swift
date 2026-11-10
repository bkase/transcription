import CoreGraphics
import Darwin
import Foundation

struct Trial: Encodable {
    let framework: String
    let windowMs: Double
    let idleRSSMiB: Double
    let idleCPUPct: Double
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func hasWindow(_ pid: pid_t) -> Bool {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    return windows.contains { window in
        guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
              window[kCGWindowLayer as String] as? Int == 0,
              let size = window[kCGWindowBounds as String] as? [String: Double] else { return false }
        return (size["Width"] ?? 0) >= 300 && (size["Height"] ?? 0) >= 300
    }
}

func usage(_ pid: pid_t) -> (resident: Double, cpu: Double) {
    var info = rusage_info_v0()
    let status = withUnsafeMutablePointer(to: &info) { buffer in
        buffer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
            proc_pid_rusage(pid, RUSAGE_INFO_V0, $0)
        }
    }
    guard status == 0 else { fail("Could not read process \(pid) usage") }
    return (Double(info.ri_resident_size) / 1_048_576, Double(info.ri_user_time + info.ri_system_time) / 1e9)
}

func trial(_ name: String, bundle path: String, archive: String) throws -> Trial {
    let bundle = Bundle(url: URL(fileURLWithPath: path))
    guard let executable = bundle?.executableURL else { fail("No executable in \(path)") }
    let app = Process()
    app.executableURL = executable
    app.environment = ProcessInfo.processInfo.environment.filter { key, _ in
        !key.hasPrefix("EXACT_") && !key.hasPrefix("RUNE_")
    }
    if name == "Rune" { app.environment?["VAPOR_RUNE_DATA_DIR"] = archive }
    app.standardOutput = FileHandle.nullDevice
    app.standardError = FileHandle.nullDevice
    let clock = ProcessInfo.processInfo
    let start = clock.systemUptime
    try app.run()
    defer { if app.isRunning { app.terminate(); app.waitUntilExit() } }
    let deadline = start + 10
    while !hasWindow(app.processIdentifier) {
        guard app.isRunning, clock.systemUptime < deadline else {
            throw CocoaError(.executableLoad, userInfo: [NSLocalizedDescriptionKey: "\(name) showed no app window within 10 s"])
        }
        usleep(5_000)
    }
    let startup = (clock.systemUptime - start) * 1000
    Thread.sleep(forTimeInterval: 1)
    let begin = clock.systemUptime
    let first = usage(app.processIdentifier)
    var resident = [first.resident]
    for _ in 0..<10 {
        Thread.sleep(forTimeInterval: 0.20)
        resident.append(usage(app.processIdentifier).resident)
    }
    let last = usage(app.processIdentifier)
    let cpu = (last.cpu - first.cpu) / (clock.systemUptime - begin) * 100
    return Trial(framework: name, windowMs: startup, idleRSSMiB: resident.sorted()[5], idleCPUPct: cpu)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 2 else { fail("Usage: mac-launch <Exact.app> <Rune.app>") }
let apps = [("Exact", args[0]), ("Rune", args[1])]
let archive = FileManager.default.temporaryDirectory.appendingPathComponent("vapor-bench-" + UUID().uuidString)
try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: false)
defer { try? FileManager.default.removeItem(at: archive) }
var trials: [Trial] = []
for pass in 0...7 {
    for (name, path) in (pass.isMultiple(of: 2) ? apps : Array(apps.reversed())) {
        let measurement = try trial(name, bundle: path, archive: archive.path)
        if pass > 0 { trials.append(measurement) }
        Thread.sleep(forTimeInterval: 0.25)
    }
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(trials), as: UTF8.self))
