import SwiftUI

// MARK: - Chase Animation Helpers

private struct ChaseArena {
    let width: CGFloat
    let height: CGFloat
    var margin: CGFloat { 30 }

    func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, margin), width - margin),
            y: min(max(point.y, margin), height - margin)
        )
    }

    func randomPoint() -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: margin...(width - margin)),
            y: CGFloat.random(in: margin...(height - margin))
        )
    }
}

/// Direction vector for the mouse's smooth random walk
private struct MouseWalk {
    var dx: CGFloat
    var dy: CGFloat

    /// Slightly rotate direction + random speed change — creates natural wandering
    mutating func tick() {
        let angle = atan2(dy, dx) + CGFloat.random(in: -0.35...0.35)
        let speed = CGFloat.random(in: 0.8...2.2)
        dx = cos(angle) * speed
        dy = sin(angle) * speed
    }

    /// Flee in the opposite direction (when caught)
    mutating func flee(from cat: CGPoint, mouse: CGPoint) {
        let angle = atan2(mouse.y - cat.y, mouse.x - cat.x)
        let scatter = angle + CGFloat.random(in: -0.6...0.6)
        let speed = CGFloat.random(in: 3.0...6.0)
        dx = cos(scatter) * speed
        dy = sin(scatter) * speed
    }
}

// MARK: - Scanning View

struct ScanningView: View {
    let category: String
    let progress: Double
    let onCancel: () -> Void

    @State private var catPos = CGPoint.zero
    @State private var mousePos = CGPoint.zero
    @State private var walk = MouseWalk(dx: 1.5, dy: -0.8)
    @State private var dots = ""
    @State private var caughtCount = 0
    @State private var arenaSize: CGSize = .zero

    /// Single 60fps timer — all motion in one synchronized loop
    private let tickTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let dotsTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    /// Tweak these for feel:
    private let catchDistance: CGFloat = 50
    private let catLerp: CGFloat = 0.035       // cat closes 3.5% of the gap per frame
    private let directionChangeChance: Float = 0.015  // mouse changes course ~1.5% per frame

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // ── Chase Arena ──
            GeometryReader { geo in
                ZStack {
                    // Mouse — smooth random walk + flee on catch
                    Text("🐭")
                        .font(.system(size: 32))
                        .position(mousePos)

                    // Cat — smooth pursuit, flips to face direction
                    Text("🐱")
                        .font(.system(size: 40))
                        .scaleEffect(x: catPos.x < mousePos.x ? 1 : -1, y: 1)
                        .position(catPos)
                }
                .onAppear {
                    arenaSize = geo.size
                    catPos = CGPoint(x: geo.size.width * 0.25, y: geo.size.height / 2)
                    mousePos = CGPoint(x: geo.size.width * 0.7, y: geo.size.height / 2)
                }
                .onReceive(tickTimer) { _ in
                    tick(arena: ChaseArena(width: arenaSize.width, height: arenaSize.height))
                }
            }
            .frame(height: 150)
            .padding(.horizontal, 8)

            // ── Catch counter ──
            if caughtCount > 0 {
                Text("已捕获 \(caughtCount) 只老鼠")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .transition(.opacity)
                    .animation(.easeInOut, value: caughtCount)
            }

            // ── Progress bar ──
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 280)

            // ── Current task ──
            VStack(spacing: 6) {
                Text("正在嗅探...")
                    .font(.headline)
                Text("\(category)\(dots)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .onReceive(dotsTimer) { _ in
                dots = dots.count >= 3 ? "" : dots + "."
            }

            Spacer()

            // ── Cancel ──
            Button(action: onCancel) {
                Text("取消扫描")
                    .font(.caption)
            }
            .padding(.bottom, 8)

            Text("TrashCat 正在翻你 Mac 的角落...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    // MARK: - Single-frame tick

    private func tick(arena: ChaseArena) {
        // 1. Mouse: smooth random walk with course changes
        if Float.random(in: 0...1) < directionChangeChance {
            walk.tick()
        }
        var nextMouse = CGPoint(
            x: mousePos.x + walk.dx,
            y: mousePos.y + walk.dy
        )
        // Bounce off walls
        if nextMouse.x < arena.margin || nextMouse.x > arena.width - arena.margin {
            walk.dx = -walk.dx
            nextMouse.x = mousePos.x + walk.dx
        }
        if nextMouse.y < arena.margin || nextMouse.y > arena.height - arena.margin {
            walk.dy = -walk.dy
            nextMouse.y = mousePos.y + walk.dy
        }
        mousePos = arena.clamp(nextMouse)

        // 2. Cat: smooth pursuit (lerp toward mouse)
        let dx = mousePos.x - catPos.x
        let dy = mousePos.y - catPos.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < catchDistance {
            // Caught! Teleport mouse to a new location + reset to gentle walk
            mousePos = arena.randomPoint()
            walk = MouseWalk(
                dx: CGFloat.random(in: 0.5...1.8) * (Bool.random() ? 1 : -1),
                dy: CGFloat.random(in: 0.5...1.8) * (Bool.random() ? 1 : -1)
            )
            caughtCount += 1
        }

        // Lerp toward mouse
        catPos = arena.clamp(CGPoint(
            x: catPos.x + dx * catLerp,
            y: catPos.y + dy * catLerp
        ))
    }
}
