import AVFoundation
import CoreText
import UIKit

@main
final class VaporApp: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = VaporScene.self
        return configuration
    }
}

final class VaporScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var surface: VaporSurface?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        } catch {
            NSLog("Vapor audio session setup failed: %@", error.localizedDescription)
        }

        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--ui-testing")
        let archive = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(testing ? "Vapor Rune UI Tests" : "Vapor Rune", isDirectory: true)
        #if DEBUG
        if testing && arguments.contains("--reset-test-archive") {
            try? FileManager.default.removeItem(at: archive)
        }
        #endif

        let surface = VaporSurface(archive: archive)
        let controller = UIViewController()
        controller.view.backgroundColor = surface.backgroundColor
        controller.view.addSubview(surface)
        surface.translatesAutoresizingMaskIntoConstraints = false
        let safeArea = controller.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            surface.topAnchor.constraint(equalTo: safeArea.topAnchor),
            surface.bottomAnchor.constraint(equalTo: controller.view.keyboardLayoutGuide.topAnchor),
        ])
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = controller
        self.window = window
        self.surface = surface
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        surface?.setActive(true)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        surface?.setActive(false)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        surface?.setActive(false)
        surface = nil
        window = nil
    }
}

@_cdecl("vapor_symbol")
func vaporSymbol(
    _ name: UnsafePointer<CChar>, _ pointSize: Float, _ weight: Int32,
    _ red: Float, _ green: Float, _ blue: Float,
    _ width: UnsafeMutablePointer<Float>, _ height: UnsafeMutablePointer<Float>
) -> UnsafeMutableRawPointer? {
    let weights: [UIImage.SymbolWeight] = [.light, .regular, .medium]
    let configuration = UIImage.SymbolConfiguration(pointSize: CGFloat(pointSize), weight: weights[Int(weight)])
    let tint = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    guard let symbol = UIImage(systemName: String(cString: name), withConfiguration: configuration)?
        .withTintColor(tint, renderingMode: .alwaysOriginal) else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3
    let bitmap = UIGraphicsImageRenderer(size: symbol.size, format: format).pngData { _ in
        symbol.draw(at: .zero)
    }
    width.pointee = Float(symbol.size.width)
    height.pointee = Float(symbol.size.height)
    return Unmanaged.passRetained(bitmap as NSData).toOpaque()
}
