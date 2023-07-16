//
//  ContentView.swift
//  Boids
//
//  Created by Honma Masaru on 2023/07/16.
//

import SwiftUI
import SpriteKit

/// フィールドのサイズ
var size: CGSize = .init(width: 800, height: 600)

/// Boidの数
let number: Int = 100

/// 各種設定
let visualRange: CGFloat = 75
let centeringFactor: CGFloat = 0.005 // adjust velocity by this %
let minDistance: CGFloat = 20 // The distance to stay away from other boids
let avoidFactor: CGFloat = 0.05 // Adjust velocity by this %
let matchingFactor: CGFloat = 0.05 // Adjust by this % of average velocity
let speedLimit: CGFloat = 15
let margin: CGFloat = 200
let turnFactor: CGFloat = 1

final class Boid: SKShapeNode {
    /// マークのサイズ
    private let markSize: CGSize = .init(width: 10, height: 15)

    /// ベクトル
    private var vector: CGVector = .zero {
        didSet {
            // 角度の設定
            zRotation = atan2(vector.dy, vector.dx) - .pi / 2
        }
    }

    /// 初期化
    func set(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat) {
        position = .init(x: x, y: y)
        vector = .init(dx: dx, dy: dy)
        fillColor = .init(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)

        // マークのパス
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: .init(x: markSize.width, y: 0))
        path.addLine(to: .init(x: markSize.width / 2, y: markSize.height))
        path.closeSubpath()
        self.path = path
    }

    /// 初期化 (ランダム)
    func set(size: CGSize) {
        set(x: .random(in: 0.0...1.0) * size.width,
            y: .random(in: 0.0...1.0) * size.height,
            dx: .random(in: 0.0...1.0) * 10 - 5,
            dy: .random(in: 0.0...1.0) * 10 - 5)
    }
    
    /// 位置の加算
    /// - Parameters:
    ///   - x: X座標
    ///   - y: Y座標
    private func add(x: CGFloat, y: CGFloat) {
        position = .init(x: position.x + x, y: position.y + y)
    }
    
    /// ベクトルの加算
    /// - Parameters:
    ///   - dx: X成分
    ///   - dy: Y成分
    private func add(dx: CGFloat, dy: CGFloat) {
        vector = .init(dx: vector.dx + dx, dy: vector.dy + dy)
    }
    
    // MARK: -
    
    /// 距離の取得
    /// - Parameter boid: Boidのリスト
    /// - Returns: 距離
    private func distance(_ boid: Boid) -> CGFloat {
        sqrt(pow(self.position.x - boid.position.x, 2) + pow(self.position.y - boid.position.y, 2))
    }

    /// Find the center of mass of the other boids and adjust velocity slightly to point towards the center of mass.
    /// - Parameter boids: Boidのリスト
    private func flyTowardsCenter(_ boids: [Boid]) {
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        var numNeighbors: CGFloat = 0

        for otherBoid in boids where distance(otherBoid) < visualRange {
            centerX += otherBoid.position.x
            centerY += otherBoid.position.y
            numNeighbors += 1
        }
        if numNeighbors > 0 {
            centerX /= numNeighbors
            centerY /= numNeighbors
            add(dx: (centerX - position.x) * centeringFactor, dy: (centerY - position.y) * centeringFactor)
        }
    }

    /// Move away from other boids that are too close to avoid colliding
    /// - Parameter boids: Boidのリスト
    private func avoidOthers(_ boids: [Boid]) {
        var moveX: CGFloat = 0
        var moveY: CGFloat = 0
        for otherBoid in boids where otherBoid.position != self.position && distance(otherBoid) < minDistance {
            moveX += position.x - otherBoid.position.x
            moveY += position.y - otherBoid.position.y
        }
        add(dx: moveX * avoidFactor, dy: moveY * avoidFactor)
    }

    /// Find the average velocity (speed and direction) of the other boids and adjust velocity slightly to match.
    /// - Parameter boids: Boidのリスト
    private func matchVelocity(_ boids: [Boid]) {
        var avgDx: CGFloat = 0
        var avgDy: CGFloat = 0
        var numNeighbors: CGFloat = 0

        for otherBoid in boids where distance(otherBoid) < visualRange {
            avgDx += otherBoid.vector.dx
            avgDy += otherBoid.vector.dy
            numNeighbors += 1
        }
        if numNeighbors > 0 {
            avgDx /= numNeighbors
            avgDy /= numNeighbors
            add(dx: (avgDx - vector.dx) * matchingFactor, dy: (avgDy - vector.dy) * matchingFactor)
        }
    }

    /// Speed will naturally vary in flocking behavior, but real animals can't go arbitrarily fast.
    private func limitSpeed() {
        let speed = sqrt(pow(vector.dx, 2) + pow(vector.dy, 2))
        if speed > speedLimit {
            vector = .init(dx: (vector.dx / speed) * speedLimit, dy: (vector.dy / speed) * speedLimit)
        }
    }

    /// Constrain a boid to within the window. If it gets too close to an edge, nudge it back in and reverse its direction.
    private func keepWithinBounds() {
        var dx = vector.dx
        var dy = vector.dy
        if position.x < margin {
            dx += turnFactor
        }
        if position.x > size.width - margin {
            dx -= turnFactor
        }
        if position.y < margin {
            dy += turnFactor
        }
        if position.y > size.height - margin {
            dy -= turnFactor
        }
        vector = .init(dx: dx, dy: dy)
    }
    
    /// 位置の更新
    /// - Parameter boids: Boidのリスト
    func update(_ boids: [Boid]) {
        flyTowardsCenter(boids)
        avoidOthers(boids)
        matchVelocity(boids)
        limitSpeed()
        keepWithinBounds()
        add(x: vector.dx, y: vector.dy)
    }
}

// MARK: -

final class BoidScene: SKScene {
    /// Boidのリスト
    private var boids: [Boid] = []
    
    /// 初期化
    /// - Parameter size: サイズ
    override init(size: CGSize) {
        super.init(size: size)
        setBoid()
    }

    /// 初期化
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Boidの初期化
    func setBoid() {
        boids = []
        (0..<number).forEach { _ in
            let boid = Boid()
            boid.set(size: size)
            boids.append(boid)
        }
    }

    /// 更新処理
    /// - Parameter currentTime: 現在時間
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        view?.scene?.removeAllChildren()
        boids.forEach {
            $0.update(boids)
            view?.scene?.addChild($0)
        }
    }
}

// MARK: -

struct ContentView: View {
    /// シーン
    private var scene: BoidScene = {
        let scene = BoidScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        VStack {
            GeometryReader { proxy in
                SpriteView(scene: scene, debugOptions: [.showsFPS])
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                    .onChange(of: proxy.size) { size = proxy.size }
            }
            // リセットボタン
            Button {
                scene.setBoid()
            } label: {
                Text("Restart")
            }
        }
    }
}
