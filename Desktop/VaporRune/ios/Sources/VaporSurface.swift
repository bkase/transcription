import CoreText
import QuartzCore
import UIKit

final class VaporSurface: UIView, UITextFieldDelegate {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    private let archive: URL
    private var host: UnsafeMutableRawPointer?
    private var displayLink: CADisplayLink?
    private var lastSize: CGSize = .zero
    private var lastScale: CGFloat = 0
    private var lastSemantics: CFTimeInterval = -.infinity
    private var controls: [String: UIAccessibilityElement] = [:]
    private var input: UITextField?
    private var active = false
    private var finger: UITouch?

    init(archive: URL) {
        self.archive = archive
        super.init(frame: .zero)
        backgroundColor = vaporColor("mist")
        isAccessibilityElement = false
        isMultipleTouchEnabled = false
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        displayLink?.invalidate()
        if let host { vapor_destroy(host) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let window, bounds.width > 0, bounds.height > 0 else { return }
        let scale = window.traitCollection.displayScale
        if lastSize == bounds.size && lastScale == scale { return }
        lastSize = bounds.size
        lastScale = scale
        contentScaleFactor = scale
        if let host {
            vapor_resize(host, Float(bounds.width), Float(bounds.height), Float(scale))
        } else {
            let font = CTFontCreateUIFontForLanguage(.system, 14, nil)
            let url = font.flatMap { CTFontCopyAttribute($0, kCTFontURLAttribute) as? URL }
            let metalLayer = Unmanaged.passUnretained(layer).toOpaque()
            host = archive.path.withCString { folder in
                (url?.path ?? "").withCString { path in
                    vapor_create(metalLayer, Float(bounds.width), Float(bounds.height), Float(scale), folder, path)
                }
            }
            if host == nil {
                let error = UILabel(frame: bounds)
                error.text = "Vapor couldn’t start its Metal renderer."
                error.textAlignment = .center
                error.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(error)
                return
            }
        }
        lastSemantics = -.infinity
        if active { drawFrame() }
    }

    func setActive(_ active: Bool) {
        self.active = active
        if active {
            guard displayLink == nil else { return }
            let driver = DisplayDriver(surface: self)
            let link = CADisplayLink(target: driver, selector: #selector(DisplayDriver.tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastSemantics = -.infinity
            drawFrame()
        } else {
            displayLink?.invalidate()
            displayLink = nil
            if let finger { touchEvent(finger, phase: 3) }
            finger = nil
            if let host { vapor_suspend(host) }
        }
    }

    fileprivate func drawFrame() {
        guard let host, active else { return }
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        if appliedReduceMotion != reduceMotion {
            appliedReduceMotion = reduceMotion
            vapor_preferences(host, reduceMotion)
        }
        let now = CACurrentMediaTime()
        if vapor_frame(host, now) {
            semanticsPending = true
        }
        if semanticsPending && now - lastSemantics >= 1.0 / 30.0 {
            lastSemantics = now
            semanticsPending = false
            updateSemantics(host)
        }
    }

    private var semanticsPending = false
    private var appliedReduceMotion: Bool?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard finger == nil, let touch = touches.first else { return }
        endEditing(true)
        finger = touch
        touchEvent(touch, phase: 0)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let finger, touches.contains(finger) { touchEvent(finger, phase: 1) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(touches, phase: 2)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(touches, phase: 3)
    }

    private func finishTouch(_ touches: Set<UITouch>, phase: Int32) {
        guard let finger, touches.contains(finger) else { return }
        touchEvent(finger, phase: phase)
        self.finger = nil
    }

    private func touchEvent(_ touch: UITouch, phase: Int32) {
        guard let host else { return }
        let point = touch.location(in: self)
        vapor_touch(host, phase, Float(point.x), Float(point.y), touch.timestamp)
    }

    private func updateSemantics(_ host: UnsafeMutableRawPointer) {
        guard let bytes = vapor_nodes(host) else { return }
        defer { vapor_free_nodes(bytes) }
        let data = Data(bytes: bytes, count: strlen(bytes))
        guard let nodes = try? JSONDecoder().decode([SemanticNode].self, from: data) else { return }
        let inputNode = nodes.first { $0.role == "input" }
        updateInput(inputNode)

        var ordered: [Any] = []
        var next: [String: UIAccessibilityElement] = [:]
        for (index, node) in nodes.enumerated() {
            if node.role == "input" {
                if let input { ordered.append(input) }
                continue
            }
            let identifier = node.key ?? "text-\(index)-\(node.label)"
            let element = controls[identifier] ?? RuneAccessibilityElement(accessibilityContainer: self)
            if let element = element as? RuneAccessibilityElement {
                element.activate = { [weak self] in
                    guard let host = self?.host, let key = node.key, node.enabled else { return false }
                    return key.withCString { vapor_activate(host, $0) }
                }
            }
            element.accessibilityIdentifier = node.key
            element.accessibilityLabel = node.label
            element.accessibilityFrameInContainerSpace = node.frame
            element.accessibilityTraits = node.role == "button" ? .button : .staticText
            if !node.enabled { element.accessibilityTraits.insert(.notEnabled) }
            next[identifier] = element
            ordered.append(element)
        }
        controls = next
        accessibilityElements = ordered
    }

    private func updateInput(_ node: SemanticNode?) {
        guard let node, let key = node.key else {
            input?.removeFromSuperview()
            input = nil
            return
        }
        if input?.accessibilityIdentifier != key {
            input?.removeFromSuperview()
            let field = UITextField()
            let search = key == "search"
            field.accessibilityIdentifier = key
            field.accessibilityLabel = node.label
            field.font = .systemFont(ofSize: 14, weight: search ? .light : .regular)
            field.textColor = vaporColor("textPrimary")
            field.attributedPlaceholder = NSAttributedString(
                string: search ? "Search recordings..." : "Speaker name",
                attributes: [.foregroundColor: vaporColor("textTertiary")]
            )
            field.autocorrectionType = search ? .no : .default
            field.autocapitalizationType = search ? .none : .words
            field.returnKeyType = search ? .search : .done
            field.delegate = self
            field.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
            addSubview(field)
            input = field
            field.text = node.value
            if !search { field.becomeFirstResponder() }
        }
        if input?.isFirstResponder == false {
            input?.text = node.value
        }
        input?.frame = key == "search" ? node.frame : node.frame.insetBy(dx: 8, dy: 0)
    }

    @objc private func editingChanged(_ field: UITextField) {
        guard field.markedTextRange == nil else { return }
        edit(field, submit: false)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        edit(textField, submit: true)
        textField.resignFirstResponder()
        return true
    }

    private func edit(_ field: UITextField, submit: Bool) {
        guard let host, let key = field.accessibilityIdentifier else { return }
        key.withCString { identifier in
            (field.text ?? "").withCString { value in
                vapor_edit(host, identifier, value, submit)
            }
        }
    }
}

private final class DisplayDriver: NSObject {
    weak var surface: VaporSurface?
    init(surface: VaporSurface) { self.surface = surface }
    @objc func tick() { surface?.drawFrame() }
}

private final class RuneAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activate?() ?? false }
}

private struct SemanticNode: Decodable {
    let key: String?
    let role: String
    let label: String
    let value: String?
    let rect: [CGFloat]
    let enabled: Bool

    var frame: CGRect { CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3]) }
}


private func vaporColor(_ name: String) -> UIColor {
    let rgb = name.withCString { vapor_color_rgb($0) }
    return UIColor(
        red: CGFloat((rgb >> 16) & 255) / 255,
        green: CGFloat((rgb >> 8) & 255) / 255,
        blue: CGFloat(rgb & 255) / 255,
        alpha: 1
    )
}
