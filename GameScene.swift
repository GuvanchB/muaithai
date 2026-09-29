import SpriteKit
import AVFoundation
import UIKit

// MARK: - Удары

enum Zone { case eye, temple, jaw, groin }

struct Cry { let text: String; let pitch: Float; let rate: Float }

enum Strike: CaseIterable, Identifiable {
    case jabL, crossR, hookL, hookR, upperL, upperR, groinL, groinR, headKickL, headKickR, spinKick
    var id: Self { self }

    var icon: String {
        switch self {
        case .jabL, .crossR: return "👊"
        case .hookL: return "🤛"
        case .hookR: return "🤜"
        case .upperL, .upperR: return "⤴️"
        case .groinL, .groinR: return "🦵"
        case .headKickL, .headKickR: return "🦶"
        case .spinKick: return "🌀"
        }
    }

    var title: String {
        switch self {
        case .jabL: return "Прямой левой"
        case .crossR: return "Прямой правой"
        case .hookL: return "Хук слева"
        case .hookR: return "Хук справа"
        case .upperL: return "Апперкот слева"
        case .upperR: return "Апперкот справа"
        case .groinL: return "Левой в пах"
        case .groinR: return "Правой в пах"
        case .headKickL: return "Левой в голову"
        case .headKickR: return "Правой в голову"
        case .spinKick: return "С разворота в челюсть"
        }
    }

    var isKick: Bool {
        switch self {
        case .groinL, .groinR, .headKickL, .headKickR, .spinKick: return true
        default: return false
        }
    }

    var zone: Zone {
        switch self {
        case .jabL, .crossR: return .eye
        case .headKickL, .headKickR: return .temple
        case .hookL, .hookR, .upperL, .upperR, .spinKick: return .jaw
        case .groinL, .groinR: return .groin
        }
    }

    var damage: CGFloat {
        switch self {
        case .jabL: return 6
        case .crossR: return 8
        case .hookL, .hookR: return 10
        case .upperL, .upperR: return 12
        case .groinL, .groinR: return 14
        case .headKickL, .headKickR: return 16
        case .spinKick: return 25
        }
    }

    // Разный тембр возгласа на каждый удар
    var cry: Cry {
        switch self {
        case .jabL: return Cry(text: "Ай!", pitch: 1.1, rate: 0.5)
        case .crossR: return Cry(text: "Ох!", pitch: 0.9, rate: 0.5)
        case .hookL: return Cry(text: "Ух!", pitch: 0.8, rate: 0.45)
        case .hookR: return Cry(text: "Уф!", pitch: 0.85, rate: 0.45)
        case .upperL, .upperR: return Cry(text: "Ык!", pitch: 0.7, rate: 0.5)
        case .groinL, .groinR: return Cry(text: "Иииии!", pitch: 1.9, rate: 0.35)
        case .headKickL, .headKickR: return Cry(text: "Ааах!", pitch: 0.65, rate: 0.4)
        case .spinKick: return Cry(text: "Уаааа!", pitch: 0.55, rate: 0.35)
        }
    }
}

// MARK: - Сцена

final class GameScene: SKScene {
    private var hero = SKNode()
    private var heroVisual = SKNode()
    private var heroHalfWidth: CGFloat = 0
    private var foe = SKNode()
    private var foeBaseX: CGFloat = 0
    private var eyes: [SKShapeNode] = []
    private var pupils: [SKShapeNode] = []
    private var brows: [SKShapeNode] = []
    private var mouth = SKShapeNode()
    private var sweat = SKNode()
    private var healthFill = SKShapeNode()

    private var H: CGFloat = 0          // рост героя
    private var u: CGFloat = 0          // 1% роста соперника
    private var health: CGFloat = 100
    private var busy = false
    private var knockedOut = false
    private var canRestart = false
    private var lastTouchX: CGFloat?
    private var builtSize: CGSize = .zero
    private let voice = AVSpeechSynthesizer()

    static func make() -> GameScene {
        let s = GameScene(size: CGSize(width: 390, height: 520))
        s.scaleMode = .resizeFill
        return s
    }

    override func didMove(to view: SKView) { if size != builtSize { build() } }
    override func didChangeSize(_ oldSize: CGSize) { if size != builtSize { build() } }

    // MARK: Построение

    private func build() {
        guard size.width > 50, size.height > 50 else { return }
        builtSize = size
        removeAllChildren(); removeAllActions()
        health = 100; busy = false; knockedOut = false; canRestart = false
        eyes = []; pupils = []; brows = []
        backgroundColor = SKColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
        let ground = size.height * 0.08
        H = min(size.height * 0.62, size.width * 0.5)
        u = H * 1.12 / 100              // соперник выше героя
        drawRing(ground: ground)
        buildFoe(ground: ground)
        buildHero(ground: ground)
        buildHealthBar()
        updateFear()
    }

    private func drawRing(ground: CGFloat) {
        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: ground))
        floor.fillColor = SKColor(white: 0.22, alpha: 1); floor.strokeColor = .clear
        addChild(floor)
        for i in 1...3 {
            let rope = SKShapeNode(rect: CGRect(x: 0, y: ground + CGFloat(i) * H * 0.24, width: size.width, height: 4))
            rope.fillColor = i == 2 ? .red : SKColor(white: 0.03, alpha: 1)
            rope.strokeColor = .clear; rope.zPosition = -1
            addChild(rope)
        }
    }

    private func buildHero(ground: CGFloat) {
        hero = SKNode()
        if let img = UIImage(named: "hero") {
            let s = SKSpriteNode(texture: SKTexture(image: img))
            s.anchorPoint = CGPoint(x: 0.5, y: 0)
            s.setScale(H / s.size.height)
            heroVisual = s
        } else {
            heroVisual = placeholderHero()
        }
        hero.addChild(heroVisual)
        heroHalfWidth = heroVisual.calculateAccumulatedFrame().width / 2
        hero.position = CGPoint(x: max(size.width * 0.2, heroHalfWidth + 4), y: ground)
        hero.zPosition = 2
        addChild(hero)
    }

    private func placeholderHero() -> SKNode {
        let n = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: H * 0.28, height: H * 0.5), cornerRadius: 8)
        body.fillColor = .black; body.strokeColor = .darkGray
        body.position = CGPoint(x: 0, y: H * 0.45); n.addChild(body)
        let head = SKShapeNode(circleOfRadius: H * 0.1)
        head.fillColor = SKColor(red: 0.93, green: 0.76, blue: 0.6, alpha: 1); head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: H * 0.85); n.addChild(head)
        let glove = SKShapeNode(circleOfRadius: H * 0.07)
        glove.fillColor = .red; glove.strokeColor = .clear
        glove.position = CGPoint(x: H * 0.18, y: H * 0.68); n.addChild(glove)
        return n
    }

    private func buildFoe(ground: CGFloat) {
        foe = SKNode()
        foeBaseX = size.width * 0.76
        foe.position = CGPoint(x: foeBaseX, y: ground)
        foe.zPosition = 1
        addChild(foe)

        let skin = SKColor(red: 0.87, green: 0.68, blue: 0.52, alpha: 1)
        let hair = SKColor(red: 0.2, green: 0.12, blue: 0.06, alpha: 1)

        @discardableResult
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: SKColor, r: CGFloat = 0) -> SKShapeNode {
            let s = SKShapeNode(rect: CGRect(x: (x - w / 2) * u, y: y * u, width: w * u, height: h * u), cornerRadius: r * u)
            s.fillColor = c; s.strokeColor = .clear
            foe.addChild(s); return s
        }
        @discardableResult
        func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: SKColor, z: CGFloat = 0) -> SKShapeNode {
            let s = SKShapeNode(ellipseOf: CGSize(width: w * u, height: h * u))
            s.position = CGPoint(x: x * u, y: y * u)
            s.fillColor = c; s.strokeColor = .clear; s.zPosition = z
            foe.addChild(s); return s
        }

        // Руки, ноги, босые ступни
        rect(-13, 50, 6, 30, skin, r: 3); rect(13, 50, 6, 30, skin, r: 3)
        rect(-5, 3, 7, 40, skin, r: 2); rect(5, 3, 7, 40, skin, r: 2)
        oval(-7, 2, 11, 4, skin); oval(3, 2, 11, 4, skin)
        // Простые шорты и майка
        rect(0, 36, 24, 18, SKColor(red: 0.35, green: 0.42, blue: 0.55, alpha: 1), r: 2)
        rect(0, 53, 22, 28, SKColor(white: 0.9, alpha: 1), r: 3)
        // Шея, голова, нос, ухо
        rect(0, 80, 7, 5, skin)
        oval(0, 91, 18, 19, skin)
        oval(-8.8, 90.5, 2.6, 3, skin)
        oval(3, 91, 3, 4, SKColor(red: 0.8, green: 0.6, blue: 0.45, alpha: 1), z: 1)
        // Взлохмаченные волосы
        oval(0.5, 96.5, 19, 9, hair, z: 1)
        for i in 0..<10 {
            let a = CGFloat.pi * (0.1 + 0.8 * CGFloat(i) / 9)
            let tuft = oval(cos(a) * 9, 92 + sin(a) * 9, 4, 8, hair, z: 1)
            tuft.zRotation = a - .pi / 2 + CGFloat.random(in: -0.6...0.6)
        }
        // Глаза, зрачки, брови
        for ex: CGFloat in [-6, -1.5] {
            let e = oval(ex, 92.5, 3.4, 2.6, .white, z: 3)
            let p = SKShapeNode(circleOfRadius: 0.9 * u)
            p.fillColor = .black; p.strokeColor = .clear
            p.position = CGPoint(x: -0.6 * u, y: 0)
            e.addChild(p)
            eyes.append(e); pupils.append(p)

            let path = CGMutablePath()
            path.move(to: CGPoint(x: -1.8 * u, y: 0)); path.addLine(to: CGPoint(x: 1.8 * u, y: 0))
            let b = SKShapeNode(path: path)
            b.strokeColor = hair; b.lineWidth = 0.9 * u; b.lineCap = .round
            b.position = CGPoint(x: ex * u, y: 96 * u); b.zPosition = 3
            foe.addChild(b); brows.append(b)
        }
        // Рот
        mouth = oval(-4, 86, 4, 2, SKColor(red: 0.45, green: 0.08, blue: 0.1, alpha: 1), z: 3)
        // Пот от страха
        sweat = SKNode(); sweat.zPosition = 3
        for (x, y) in [(3.0, 97.0), (-9.0, 95.0)] {
            let d = SKShapeNode(ellipseOf: CGSize(width: 1.4 * u, height: 2.2 * u))
            d.fillColor = SKColor(red: 0.6, green: 0.85, blue: 1, alpha: 0.9); d.strokeColor = .clear
            d.position = CGPoint(x: CGFloat(x) * u, y: CGFloat(y) * u)
            sweat.addChild(d)
        }
        foe.addChild(sweat)
    }

    private func buildHealthBar() {
        let w = size.width * 0.8, h: CGFloat = 16
        let x0 = (size.width - w) / 2, y0 = size.height - 36
        let bg = SKShapeNode(rect: CGRect(x: x0, y: y0, width: w, height: h), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.25, alpha: 1); bg.strokeColor = .white; bg.zPosition = 10
        addChild(bg)
        healthFill = SKShapeNode(rect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: 8)
        healthFill.position = CGPoint(x: x0, y: y0)
        healthFill.strokeColor = .clear; healthFill.zPosition = 11
        addChild(healthFill)
        let label = SKLabelNode(text: "ЗДОРОВЬЕ СОПЕРНИКА")
        label.fontName = "AvenirNext-Bold"; label.fontSize = 12
        label.position = CGPoint(x: size.width / 2, y: y0 + h + 4); label.zPosition = 10
        addChild(label)
        updateHealthBar()
    }

    private func updateHealthBar() {
        let v = max(health, 0) / 100
        healthFill.run(.scaleX(to: max(v, 0.001), duration: 0.2))
        healthFill.fillColor = v > 0.6 ? .systemGreen : v > 0.3 ? .systemYellow : .systemRed
    }

    // MARK: Удары

    func perform(_ s: Strike) {
        guard !busy, !knockedOut, H > 0 else { return }
        busy = true
        let reach = H * (s == .spinKick ? 0.85 : s.isKick ? 0.75 : 0.6)
        let hit = foe.position.x - hero.position.x <= reach
        let base = abs(heroVisual.xScale)
        let t: TimeInterval = s == .spinKick ? 0.28 : 0.12

        if s == .spinKick {
            heroVisual.run(.sequence([.scaleX(to: -base, duration: 0.07), .scaleX(to: base, duration: 0.07),
                                      .scaleX(to: -base, duration: 0.07), .scaleX(to: base, duration: 0.07)]))
        } else {
            heroVisual.run(.sequence([.rotate(toAngle: s.isKick ? -0.12 : -0.05, duration: t),
                                      .rotate(toAngle: 0, duration: 0.12)]))
        }
        hero.run(.sequence([
            .moveBy(x: H * 0.1, y: 0, duration: t),
            .run { [weak self] in self?.launch(s, hit: hit) },
            .wait(forDuration: 0.14),
            .moveBy(x: -H * 0.1, y: 0, duration: 0.15),
            .run { [weak self] in self?.busy = false }
        ]))
    }

    private func point(for zone: Zone) -> CGPoint {
        switch zone {
        case .eye: return CGPoint(x: -6 * u, y: 92.5 * u)
        case .temple: return CGPoint(x: -2 * u, y: 96 * u)
        case .jaw: return CGPoint(x: -6 * u, y: 84.5 * u)
        case .groin: return CGPoint(x: -4 * u, y: 40 * u)
        }
    }

    private func launch(_ s: Strike, hit: Bool) {
        let target = hit
            ? foe.convert(point(for: s.zone), to: self)
            : CGPoint(x: hero.position.x + H * 0.7, y: hero.position.y + (s.zone == .groin ? H * 0.35 : H * 0.8))
        let fx = SKLabelNode(text: s.isKick ? "🦶" : "🥊")
        fx.fontSize = H * 0.12; fx.verticalAlignmentMode = .center; fx.zPosition = 5
        fx.position = CGPoint(x: hero.position.x + H * 0.2, y: hero.position.y + (s.isKick ? H * 0.35 : H * 0.7))
        addChild(fx)
        fx.run(.sequence([
            .move(to: target, duration: 0.08),
            .run { [weak self] in hit ? self?.impact(s, at: target) : self?.miss(at: target) },
            .fadeOut(withDuration: 0.1), .removeFromParent()
        ]))
    }

    private func impact(_ s: Strike, at p: CGPoint) {
        let boom = SKLabelNode(text: "💥")
        boom.fontSize = H * 0.14; boom.verticalAlignmentMode = .center; boom.position = p; boom.zPosition = 6
        addChild(boom)
        boom.run(.sequence([.group([.scale(to: 1.6, duration: 0.15), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))

        addBruise(s)
        health -= s.damage
        updateHealthBar()
        if health <= 0 { knockOut(); return }
        updateFear()
        say(s.cry)
        let lean: CGFloat = s.zone == .groin ? 0.18 : -0.1   // в пах — сгибается, в голову — откидывается
        foe.run(.sequence([.rotate(toAngle: lean, duration: 0.07), .rotate(toAngle: 0, duration: 0.25)]))
    }

    private func miss(at p: CGPoint) {
        let l = SKLabelNode(text: "МИМО")
        l.fontName = "AvenirNext-Bold"; l.fontSize = H * 0.07; l.fontColor = .lightGray
        l.position = p; l.zPosition = 6
        addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 20, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
    }

    private func addBruise(_ s: Strike) {
        var p = point(for: s.zone)
        p.x += CGFloat.random(in: -1.5...1.5) * u
        p.y += CGFloat.random(in: -1.5...1.5) * u
        let r = (s.zone == .groin ? 3.5 : 2.6) * u * CGFloat.random(in: 0.8...1.2)
        let outer = SKShapeNode(ellipseOf: CGSize(width: r * 2.2, height: r * 1.8))
        outer.fillColor = SKColor(red: 0.45, green: 0.15, blue: 0.45, alpha: 0.5); outer.strokeColor = .clear
        let inner = SKShapeNode(ellipseOf: CGSize(width: r * 1.2, height: r))
        inner.fillColor = SKColor(red: 0.3, green: 0.05, blue: 0.25, alpha: 0.6); inner.strokeColor = .clear
        outer.addChild(inner)
        outer.position = p; outer.zPosition = 2; outer.setScale(0.2)
        foe.addChild(outer)
        outer.run(.scale(to: 1, duration: 0.2))
    }

    // Чем меньше здоровья — тем сильнее испуг
    private func updateFear() {
        let f = 1 - max(health, 0) / 100
        eyes.forEach { $0.run(.scale(to: 1 + f * 0.9, duration: 0.15)) }
        pupils.forEach { $0.run(.scale(to: 1 - f * 0.55, duration: 0.15)) }
        if brows.count == 2 {
            brows[0].zRotation = f * 0.6
            brows[1].zRotation = -f * 0.6
            brows.forEach { $0.position.y = (96 + f * 2) * u }
        }
        mouth.run(.group([.scaleY(to: 0.25 + f * 2.2, duration: 0.15), .scaleX(to: 1 + f * 0.3, duration: 0.15)]))
        sweat.alpha = f > 0.3 ? min(1, (f - 0.3) * 2) : 0
        foe.removeAction(forKey: "shake")
        foe.position.x = foeBaseX
        if f > 0.45 {
            let a = 1.2 * f
            foe.run(.repeatForever(.sequence([.moveBy(x: a, y: 0, duration: 0.04),
                                              .moveBy(x: -a, y: 0, duration: 0.04)])), withKey: "shake")
        }
    }

    private func knockOut() {
        knockedOut = true
        foe.removeAllActions()
        foe.position.x = foeBaseX
        eyes.forEach { $0.setScale(1.9) }
        mouth.yScale = 2.6
        say(Cry(text: "Аааааа! Всё, сдаюсь!", pitch: 0.6, rate: 0.38))

        let bodyLen = 104 * u
        let heroRight = hero.position.x + heroHalfWidth
        let targetX = max(heroRight + 8, min(foeBaseX, size.width - 8 - bodyLen))
        foe.run(.sequence([
            .wait(forDuration: 0.15),
            .group([.rotate(toAngle: -.pi / 2, duration: 0.6), .moveTo(x: targetX, duration: 0.6)]),
            .moveBy(x: 0, y: 4, duration: 0.06), .moveBy(x: 0, y: -4, duration: 0.08)
        ]))

        let ko = SKLabelNode(text: "НОКАУТ! 🏆")
        ko.fontName = "AvenirNext-Heavy"; ko.fontSize = H * 0.16; ko.fontColor = .systemYellow
        ko.position = CGPoint(x: size.width / 2, y: size.height * 0.62); ko.zPosition = 20; ko.setScale(0)
        addChild(ko)
        ko.run(.sequence([.wait(forDuration: 0.8), .scale(to: 1, duration: 0.3)]))

        let hint = SKLabelNode(text: "Нажми на экран — заново")
        hint.fontName = "AvenirNext-Medium"; hint.fontSize = 14; hint.alpha = 0
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.62 - H * 0.12); hint.zPosition = 20
        addChild(hint)
        run(.sequence([.wait(forDuration: 1.5), .run { [weak self] in
            self?.canRestart = true; hint.run(.fadeIn(withDuration: 0.3))
        }]))
    }

    private func say(_ c: Cry) {
        voice.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: c.text)
        u.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        u.pitchMultiplier = c.pitch
        u.rate = c.rate
        voice.speak(u)
    }

    // MARK: Свайп — движение героя только по горизонтали

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if knockedOut { if canRestart { build() }; return }
        lastTouchX = touches.first?.location(in: self).x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !knockedOut, !busy, let t = touches.first, let last = lastTouchX else { return }
        let x = t.location(in: self).x
        let minX = heroHalfWidth + 4
        let maxX = foeBaseX - 18 * u - heroHalfWidth * 0.6
        hero.position.x = min(max(hero.position.x + (x - last), minX), maxX)
        lastTouchX = x
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lastTouchX = nil }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lastTouchX = nil }
}
