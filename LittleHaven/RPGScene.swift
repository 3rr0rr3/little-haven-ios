import SwiftUI
import SpriteKit

// Scene renderer for the native RPG engine. Business rules and checkpoints remain
// Codable model state; SpriteKit owns the map, actors, camera and walk animation.
struct RPGActor {
    let id: String
    let tile: Tile
    let color: UInt32
    let variant: Int
    var facing = 0
    var name = ""
    var marker = ""
    var duration = 0.14
    var danger = false
}

struct RPGSceneView: UIViewRepresentable {
    let mapID: String
    let revision: String
    let mapSize: CGSize
    let columns: CGFloat
    let interior: Bool
    let actors: [RPGActor]
    var working = false
    let scenery: () -> AnyView

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.isAccessibilityElement = false
        let scene = RPGScene()
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }
    func updateUIView(_ view: SKView, context: Context) {
        guard let scene = view.scene as? RPGScene else { return }
        scene.configure(mapID: mapID, revision: revision, mapSize: mapSize,
                        columns: columns, interior: interior, actors: actors,
                        working: working, scenery: scenery)
    }
    static func dismantleUIView(_ view: SKView, coordinator: ()) {
        view.scene?.removeAllActions()
        view.presentScene(nil)
    }
}

private struct ActorArtwork: View {
    let actor: RPGActor
    let stride: Double
    var body: some View {
        Canvas { context, _ in
            PaperPerson.draw(context: &context, x: 4, y: 9, color: actor.color,
                             variant: actor.variant, facing: actor.facing, walk: stride)
        }.frame(width: 24, height: 28)
    }
}

final class RPGScene: SKScene {
    private var worldID = ""
    private var revision = ""
    private var dimensions = CGSize.zero
    private var visibleColumns: CGFloat = 14
    private var indoors = false
    private let world = SKNode()
    private let followCamera = SKCameraNode()
    private var playerTarget = CGPoint.zero
    private var textures: [String: SKTexture] = [:]
    private var configured = false
    private var viewSize = CGSize.zero

    override func didMove(to view: SKView) {
        if !configured {
            configured = true
            backgroundColor = UIColor(red: 0.09, green: 0.16, blue: 0.14, alpha: 1)
            addChild(world)
            addChild(followCamera)
            camera = followCamera
        }
    }
    @MainActor func configure(mapID: String, revision newRevision: String,
                             mapSize: CGSize, columns: CGFloat, interior: Bool,
                             actors: [RPGActor], working: Bool, scenery: () -> AnyView) {
        let changedMap = worldID != mapID
        dimensions = mapSize
        visibleColumns = columns
        indoors = interior
        if changedMap || revision != newRevision {
            // Rasterize the original vector scenery once per map/state change,
            // never once per frame. Actor sprites are independent scene nodes.
            let renderer = ImageRenderer(content: scenery().frame(width: mapSize.width, height: mapSize.height))
            renderer.scale = 3
            guard let image = renderer.uiImage else { return }
            let texture = SKTexture(image: image)
            texture.filteringMode = .linear
            if changedMap { world.removeAllChildren() }
            world.childNode(withName: "scenery")?.removeFromParent()
            let map = SKSpriteNode(texture: texture, size: mapSize)
            map.name = "scenery"
            map.anchorPoint = CGPoint(x: 0, y: 1)
            map.position = .zero
            map.zPosition = -10000
            world.addChild(map)
            worldID = mapID
            revision = newRevision
        }
        let ids = Set(actors.map { "actor:" + $0.id })
        for node in world.children where node.name?.hasPrefix("actor:") == true && !ids.contains(node.name!) {
            node.removeFromParent()
        }
        for actor in actors {
            let name = "actor:" + actor.id
            let existing = world.childNode(withName: name) as? SKSpriteNode
            let node = existing ?? SKSpriteNode()
            let target = CGPoint(x: CGFloat(actor.tile.x * 16 + 8), y: -CGFloat(actor.tile.y * 16 + 5))
            let moving = existing != nil && node.userData?["targetX"] as? Int != actor.tile.x || existing != nil && node.userData?["targetY"] as? Int != actor.tile.y
            if existing == nil {
                node.name = name
                node.size = CGSize(width: 24, height: 28)
                node.position = target
                node.userData = NSMutableDictionary()
                world.addChild(node)
            }
            node.userData?["targetX"] = actor.tile.x
            node.userData?["targetY"] = actor.tile.y
            let idle = sprite(actor, stride: 0)
            node.texture = idle
            if moving {
                node.removeAction(forKey: "walk")
                let frames = [sprite(actor, stride: 1), idle, sprite(actor, stride: -1), idle]
                node.run(.animate(with: frames, timePerFrame: actor.duration / 4), withKey: "walk")
                node.removeAction(forKey: "move")
                node.run(.move(to: target, duration: actor.duration), withKey: "move")
            }
            if actor.danger && node.childNode(withName: "detection") == nil {
                let ring = SKShapeNode(circleOfRadius: 15)
                ring.name = "detection"
                ring.position = CGPoint(x: 0, y: -4)
                ring.strokeColor = UIColor.red.withAlphaComponent(0.45)
                ring.lineWidth = 0.8
                ring.zPosition = -1
                node.addChild(ring)
            }
            node.zPosition = CGFloat(actor.tile.y * 16)
            node.childNode(withName: "caption")?.removeFromParent()
            let caption = [actor.name, actor.marker].filter { !$0.isEmpty }.joined(separator: " ")
            if !caption.isEmpty {
                let label = SKLabelNode(fontNamed: "Menlo-Bold")
                label.name = "caption"
                label.text = caption
                label.fontSize = 3.5
                label.fontColor = UIColor(red: 0.18, green: 0.29, blue: 0.23, alpha: 1)
                label.position = CGPoint(x: 0, y: 17)
                label.zPosition = 1
                node.addChild(label)
            }
            if actor.id == "player" {
                playerTarget = target
                if working && node.childNode(withName: "mop") == nil {
                    let mop = SKShapeNode(rectOf: CGSize(width: 1.2, height: 14))
                    mop.name = "mop"
                    mop.fillColor = .brown
                    mop.strokeColor = .clear
                    mop.position = CGPoint(x: 8, y: -6)
                    let head = SKShapeNode(ellipseOf: CGSize(width: 8, height: 3))
                    head.fillColor = .systemMint
                    head.strokeColor = .clear
                    head.position.y = -7
                    mop.addChild(head)
                    mop.run(.repeatForever(.sequence([.rotate(toAngle: -0.4, duration: 0.2), .rotate(toAngle: 0.4, duration: 0.2)])))
                    node.addChild(mop)
                } else if !working { node.childNode(withName: "mop")?.removeFromParent() }
            }
        }
        layoutCamera(jump: changedMap)
    }
    @MainActor private func sprite(_ actor: RPGActor, stride: Double) -> SKTexture {
        let key = "\(actor.color)-\(actor.variant)-\(actor.facing)-\(stride)"
        if let texture = textures[key] { return texture }
        let renderer = ImageRenderer(content: ActorArtwork(actor: actor, stride: stride))
        renderer.scale = 3
        let texture = renderer.uiImage.map { SKTexture(image: $0) } ?? SKTexture()
        textures[key] = texture
        return texture
    }
    private func layoutCamera(jump: Bool) {
        guard let view, view.bounds.width > 0, dimensions.width > 0 else { return }
        let zoom = indoors ? max(144 / view.bounds.width, 144 / view.bounds.height) : 16 * visibleColumns / view.bounds.width
        followCamera.setScale(zoom)
        let viewport = CGSize(width: view.bounds.width * zoom, height: view.bounds.height * zoom)
        let cx = indoors ? dimensions.width / 2 : max(viewport.width / 2, min(playerTarget.x, dimensions.width - viewport.width / 2))
        let cy = indoors ? -dimensions.height / 2 : -max(viewport.height / 2, min(-playerTarget.y, max(viewport.height / 2, dimensions.height - viewport.height / 2)))
        let point = CGPoint(x: cx, y: cy)
        followCamera.removeAllActions()
        if jump { followCamera.position = point }
        else { followCamera.run(.move(to: point, duration: 0.14)) }
    }
    override func didChangeSize(_ oldSize: CGSize) { layoutCamera(jump: true) }
    override func update(_ currentTime: TimeInterval) {
        if view?.bounds.size != viewSize { viewSize = view?.bounds.size ?? .zero; layoutCamera(jump: true) }
        for node in world.children where node.name?.hasPrefix("actor:") == true { node.zPosition = -node.position.y }
    }
}

struct TownRPGView: View {
    let game: Game
    var body: some View {
        let actors = (game.inside ? [] : Town.neighbors.map {
            RPGActor(id: "neighbor-\($0.id)", tile: $0.tile, color: $0.color, variant: $0.id, name: $0.name, marker: game.gifts.contains($0.id) ? "" : "+")
        }) + [RPGActor(id: "player", tile: game.player, color: 0x6AACA3, variant: 7, facing: game.facing)]
        RPGSceneView(mapID: game.inside ? "cottage" : "town", revision: "original", mapSize: CGSize(width: (game.inside ? 9 : Town.width) * 16, height: (game.inside ? 9 : Town.height) * 16), columns: 11, interior: game.inside, actors: actors) {
            AnyView(TownCanvas(game: game, playerX: 0, playerY: 0, sceneryOnly: true, fullMap: true))
        }
    }
}

struct MotelRPGView: View {
    let motel: Motel
    var workProgress = 0.0
    var body: some View {
        let visit = motel.visit
        let room = visit.flatMap { v in motel.rooms.first { $0.id == v.roomID } }
        let interior = visit != nil || motel.worldState.place == .office
        let mapID = visit.map { "room-\($0.roomID)" } ?? motel.worldState.place.rawValue
        let revision = room.map { "\($0.theme)-\($0.furniture)-\($0.dirty)-\(($0.cleanedTasks ?? []).sorted())-\($0.stolen.sorted())-\(visit?.loot.sorted() ?? [])-\(visit?.sneaking ?? false)-\(motel.guestPresent(in: $0.id))" } ?? "\(motel.officeTheme)-\(motel.officeLevel)-\(motel.rooms.map { "\($0.theme):\($0.dirty):\($0.guest?.id ?? -1)" }.joined(separator: ","))"
        var actors = [RPGActor(id: "player", tile: motel.actorTile, color: 0x6AACA3, variant: 7, facing: motel.actorFacing)]
        if !interior {
            actors += motel.waiting.map { RPGActor(id: "guest-\($0.id)", tile: MotelGrounds.guestTile($0.id), color: $0.color, variant: $0.id % 8, name: $0.name) }
            actors += motel.worldState.travellers.map {
                RPGActor(id: "guest-\($0.id)", tile: $0.player, color: $0.color, variant: $0.id % 8, facing: $0.player.y > $0.previous.y ? 0 : $0.player.x < $0.previous.x ? 1 : $0.player.x > $0.previous.x ? 2 : 3, duration: 0.35)
            }
        } else if let room, let guest = room.guest, let visit, motel.guestPresent(in: room.id) {
            actors.append(RPGActor(id: "guest-\(guest.id)", tile: visit.guestTile, color: guest.color, variant: guest.id % 8, danger: true))
        }
        return RPGSceneView(mapID: mapID, revision: revision, mapSize: CGSize(width: interior ? 144 : 640, height: interior ? 144 : 608), columns: 14, interior: interior, actors: actors, working: workProgress > 0) {
            if let visit, let room { return AnyView(MotelRoomCanvas(room: room, visit: visit, x: 0, y: 0, guestPresent: motel.guestPresent(in: room.id), sceneryOnly: true)) }
            if motel.worldState.place == .office { return AnyView(MotelOfficeCanvas(sceneryOnly: true, motel: motel, x: 0, y: 0)) }
            return AnyView(MotelGroundsCanvas(motel: motel, x: 0, y: 0, npcTick: 0, sceneryOnly: true, fullMap: true))
        }
    }
}
