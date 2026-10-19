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
    var animal = 0
    var displayScale = 1.0
    var effect = 0
    var action = ""
    var expression = ""
}

struct RPGSceneView: UIViewRepresentable {
    let mapID: String
    let revision: String
    let mapSize: CGSize
    let columns: CGFloat
    let interior: Bool
    let actors: [RPGActor]
    var working = false
    var workKind = "mop"
    var visual: HotelVisual?
    var weather: HotelWeather = .sunny
    var cars: [HotelCar] = []
    var day = 1
    var night = false
    var nightVision = false
    var powerOut = false
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
                        working: working, workKind: workKind, visual: visual,
                        weather:weather,cars:cars,day:day,night:night,nightVision:nightVision,powerOut:powerOut,scenery: scenery)
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
            if actor.effect > 0 {
                ChaosArt.draw(context:&context,kind:actor.effect,stride:stride,color:actor.color,variant:actor.variant,facing:actor.facing)
            } else if actor.animal > 0 { CatArt.draw(context:&context,gray:actor.animal == 1,walk:stride) }
            else { PaperPerson.draw(context:&context,x:4,y:9,color:actor.color,variant:actor.variant,facing:actor.facing,walk:stride,expression:actor.expression) }
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
    private var activeWeather: HotelWeather = .sunny
    private let weatherLayer = SKNode()
    private let ambientLayer=SKSpriteNode(color:.black,size:CGSize(width:1600,height:1600))
    private var weatherParticles: [SKShapeNode] = []
    private var weatherTime = 0.0
    private var previousTime = 0.0
    private var visualSeen = -1
    private var visualMapSeen = ""
    private var actionTextures: [String:[SKTexture]] = [:]
    private var carTextures: [String:SKTexture] = [:]

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
                             actors: [RPGActor], working: Bool, workKind:String,
                             visual:HotelVisual?,weather:HotelWeather,cars:[HotelCar],day:Int,night:Bool,nightVision:Bool,powerOut:Bool,
                             scenery: () -> AnyView) {
        let changedMap = worldID != mapID
        dimensions = mapSize
        visibleColumns = columns
        indoors = interior
        if changedMap || revision != newRevision {
            // Rasterize the original vector scenery once per map/state change,
            // never once per frame. Actor sprites are independent scene nodes.
            let renderer = ImageRenderer(content: scenery().frame(width: mapSize.width, height: mapSize.height))
            renderer.scale = 1
            guard let image = renderer.uiImage else { return }
            let texture = SKTexture(image: image)
            texture.filteringMode = .nearest
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
        configureAmbient(night:night && !interior,nightVision:nightVision,powerOut:powerOut)
        configureWeather(interior ? .sunny : weather)
        if !interior { configureCars(cars,day:day) }
        if let visual, visual.map == mapID, visual.id != visualSeen || visual.map != visualMapSeen {
            visualSeen = visual.id; visualMapSeen = visual.map
            if !changedMap || ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--ui-action") }) { showVisual(visual) }
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
                node.size = CGSize(width: 24 * actor.displayScale, height: 28 * actor.displayScale)
                node.position = target
                node.userData = NSMutableDictionary()
                world.addChild(node)
                if actor.id == "player" {
                    for facing in 0..<4 {
                        var preview=actor; preview.facing=facing
                        for stride in [-1.0,0,1] { _ = sprite(preview,stride:stride) }
                    }
                }
            }
            node.userData?["targetX"] = actor.tile.x
            node.userData?["targetY"] = actor.tile.y
            let idle = sprite(actor, stride: 0)
            let appearance = "\(actor.color)-\(actor.variant)-\(actor.effect)-\(actor.expression)-\(actor.facing)"
            if node.userData?["appearance"] as? String != appearance {
                node.removeAction(forKey:"effect"); node.removeAction(forKey:"walk"); node.removeAction(forKey:"spar")
                node.removeAction(forKey:"walkEnd")
                node.zRotation = 0; node.texture = idle; node.userData?["appearance"] = appearance
            }
            if actor.effect == 0 && node.action(forKey:"walk") == nil { node.texture = idle }
            if moving {
                let frames = [sprite(actor, stride: 1), idle, sprite(actor, stride: -1), idle]
                if node.action(forKey:"walk") == nil {node.run(.repeatForever(.animate(with:frames,timePerFrame:actor.duration/4)),withKey:"walk")}
                node.removeAction(forKey:"walkEnd")
                node.run(.sequence([.wait(forDuration:actor.duration*1.5),.run { [weak node] in
                    node?.removeAction(forKey:"walk");node?.texture=idle
                }]),withKey:"walkEnd")
                node.removeAction(forKey: "move")
                node.run(.move(to: target, duration: actor.duration), withKey: "move")
            }
            if actor.effect > 0 && node.action(forKey:"effect") == nil {
                node.run(.repeatForever(.animate(with:(0..<8).map { sprite(actor,stride:Double($0)) },timePerFrame:0.1)),withKey:"effect")
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
            if node.userData?["activityKind"] as? String != actor.action {
                node.childNode(withName:"activity")?.removeFromParent()
                node.userData?["activityKind"] = actor.action
            }
            if !actor.action.isEmpty && node.childNode(withName:"activity") == nil {
                let frames=activityFrames(actor.action)
                let prop=SKSpriteNode(texture:frames[0])
                prop.name="activity"; prop.size=CGSize(width:40,height:40)
                prop.position = actor.action == "carwash" ? CGPoint(x:0,y:24) : actor.action == "extinguish" ? CGPoint(x:0,y:14) : actor.action == "rescue" ? CGPoint(x:0,y:22) : CGPoint(x:10,y:-1)
                prop.zPosition=5
                prop.run(.repeatForever(.animate(with:frames,timePerFrame:0.12)))
                node.addChild(prop)
            } else if actor.action.isEmpty { node.childNode(withName:"activity")?.removeFromParent() }
            if actor.effect == 3 && node.action(forKey:"spar") == nil {
                node.run(.repeatForever(.sequence([.rotate(toAngle:0.18,duration:0.12),.rotate(toAngle:-0.18,duration:0.12),.rotate(toAngle:0,duration:0.16)])),withKey:"spar")
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
                if node.userData?["workKind"] as? String != workKind {
                    node.childNode(withName:"work")?.removeFromParent()
                    node.userData?["workKind"] = workKind
                }
                if working && node.childNode(withName:"work") == nil {
                    let frames=activityFrames(workKind)
                    let prop=SKSpriteNode(texture:frames[0])
                    prop.name="work"; prop.size=CGSize(width:42,height:42)
                    prop.position=CGPoint(x:7,y:-3); prop.zPosition=6
                    prop.run(.repeatForever(.animate(with:frames,timePerFrame:0.12)))
                    node.addChild(prop)
                } else if !working { node.childNode(withName:"work")?.removeFromParent() }
            }
        }
        layoutCamera(jump: changedMap)
    }
    @MainActor private func sprite(_ actor: RPGActor, stride: Double) -> SKTexture {
        let key = "\(actor.color)-\(actor.variant)-\(actor.facing)-\(stride)-\(actor.animal)-\(actor.effect)-\(actor.expression)"
        if let texture = textures[key] { return texture }
        let renderer = ImageRenderer(content: ActorArtwork(actor: actor, stride: stride))
        renderer.scale = 3
        let texture = renderer.uiImage.map { SKTexture(image: $0) } ?? SKTexture()
        textures[key] = texture
        return texture
    }

    @MainActor private func activityFrames(_ kind:String) -> [SKTexture] {
        if let cached=actionTextures[kind] { return cached }
        let frames=(0..<8).map { frame -> SKTexture in
            let renderer=ImageRenderer(content:HotelActionArtwork(kind:kind,frame:frame))
            renderer.scale=1
            let texture=renderer.uiImage.map { SKTexture(image:$0) } ?? SKTexture()
            texture.filteringMode = .nearest
            return texture
        }
        actionTextures[kind]=frames
        return frames
    }
    @MainActor private func showVisual(_ visual:HotelVisual) {
        let frames=activityFrames(visual.kind)
        let sprite=SKSpriteNode(texture:frames[0])
        sprite.size=CGSize(width:48,height:48)
        sprite.position=CGPoint(x:CGFloat(visual.target.x*16+8),y: -CGFloat(visual.target.y*16+5))
        sprite.zPosition=CGFloat(visual.target.y*16+100)
        world.addChild(sprite)
        if visual.kind.hasPrefix("steal-") {
            sprite.size=CGSize(width:32,height:32)
            let target=CGPoint(x:CGFloat(visual.origin.x*16+8),y: -CGFloat(visual.origin.y*16+5))
            sprite.run(.sequence([
                .group([.move(to:target,duration:0.85),.rotate(byAngle:0.3,duration:0.85),.scale(to:0.45,duration:0.85)]),
                .fadeOut(withDuration:0.15),.removeFromParent()
            ]))
        } else {
            sprite.run(.sequence([.repeat(.animate(with:frames,timePerFrame:0.1),count:3),.fadeOut(withDuration:0.25),.removeFromParent()]))
        }
    }
    @MainActor private func configureCars(_ cars:[HotelCar],day:Int) {
        let ids=Set(cars.map { "car:\($0.id)" })
        for node in world.children where node.name?.hasPrefix("car:") == true && !ids.contains(node.name!) { node.removeFromParent() }
        for car in cars {
            let name="car:\(car.id)"
            let existing=world.childNode(withName:name) as? SKSpriteNode
            let key="\(car.color)-\(car.id%3)-\(car.washedDay == day)"
            let texture:SKTexture
            if let cached=carTextures[key] { texture=cached }
            else {
                let renderer=ImageRenderer(content:HotelCarArtwork(color:car.color,dirty:car.washedDay != day,model:car.id%3))
                renderer.scale=1
                texture=renderer.uiImage.map { SKTexture(image:$0) } ?? SKTexture()
                texture.filteringMode = .nearest
                carTextures[key]=texture
            }
            let node=existing ?? SKSpriteNode(texture:texture)
            node.texture=texture; node.name=name; node.size=CGSize(width:48,height:34)
            let bay=HotelCar.tile(car.slot)
            let fraction=min(1,Double(car.arrival)/4)
            let x=6+Double(bay.x-6)*fraction
            let y=34+Double(bay.y-34)*max(0,Double(car.arrival-4))/4
            let target=CGPoint(x:x*16+8,y: -(y*16+8))
            if existing == nil { node.position=CGPoint(x:104,y:-552); world.addChild(node) }
            if node.userData == nil { node.userData=NSMutableDictionary() }
            if node.userData?["arrival"] as? Int != car.arrival {
                node.removeAction(forKey:"drive")
                node.run(.move(to:target,duration:0.95),withKey:"drive")
                node.userData?["arrival"]=car.arrival
            }
            node.zPosition=CGFloat(bay.y*16+20)
        }
    }
    private func configureAmbient(night:Bool,nightVision:Bool,powerOut:Bool) {
        if ambientLayer.parent == nil {ambientLayer.zPosition=40000;world.addChild(ambientLayer)}
        ambientLayer.color=nightVision ? UIColor(red:0.16,green:0.75,blue:0.25,alpha:1) : .black
        ambientLayer.alpha=nightVision ? 0.18 : powerOut ? 0.72 : night ? 0.5 : 0
        ambientLayer.position=followCamera.position
    }
    private func configureWeather(_ weather:HotelWeather) {
        if weatherLayer.parent == nil { weatherLayer.zPosition=50000; world.addChild(weatherLayer) }
        guard activeWeather != weather || weatherParticles.isEmpty && weather != .sunny else { return }
        activeWeather=weather
        weatherLayer.removeAllChildren(); weatherParticles=[]
        if weather == .sunny { return }
        let count=UIAccessibility.isReduceMotionEnabled ? 18 : 56
        for i in 0..<count {
            let node:SKShapeNode
            if weather == .snow { node=SKShapeNode(circleOfRadius:i%3 == 0 ? 1.2 : 0.7) }
            else if weather == .wind { node=SKShapeNode(ellipseOf:CGSize(width:3,height:1.2)) }
            else {
                var path=CGMutablePath(); path.move(to:.zero); path.addLine(to:CGPoint(x:-2,y:7))
                node=SKShapeNode(path:path)
            }
            node.fillColor=weather == .wind ? UIColor(red:0.68,green:0.6,blue:0.32,alpha:1) : .white
            node.strokeColor=weather == .rain || weather == .storm ? UIColor(red:0.7,green:0.87,blue:0.96,alpha:0.6) : .clear
            node.lineWidth=0.6
            weatherLayer.addChild(node); weatherParticles.append(node)
        }
        if weather == .rain || weather == .storm {
            let shade=SKSpriteNode(color:.black,size:CGSize(width:1500,height:1500))
            shade.name="cloudShade"; shade.alpha=weather == .storm ? 0.2 : 0.08
            shade.zPosition = -1; weatherLayer.addChild(shade)
        }
        if weather == .storm {
            let flash=SKSpriteNode(color:.white,size:CGSize(width:1500,height:1500))
            flash.name="lightning"; flash.alpha=0
            weatherLayer.addChild(flash)
            flash.run(.repeatForever(.sequence([.wait(forDuration:7),.fadeAlpha(to:0.32,duration:0.05),.fadeOut(withDuration:0.12),.wait(forDuration:0.08),.fadeAlpha(to:0.18,duration:0.05),.fadeOut(withDuration:0.25)])))
        }
    }
    private func updateWeather() {
        guard activeWeather != .sunny,let view else { return }
        let width=max(250,Double(view.bounds.width*followCamera.xScale)+40)
        let height=max(250,Double(view.bounds.height*followCamera.yScale)+40)
        let speed=activeWeather == .snow ? 12.0 : activeWeather == .wind ? 32 : 90
        let time=weatherTime*(UIAccessibility.isReduceMotionEnabled ? 0.35 : 1)
        for (i,node) in weatherParticles.enumerated() {
            let seed=Double(i)
            let randomY=sin(seed*269.5+183.3)*21656.4
            let randomX=sin(seed*127.1+311.7)*43758.5453
            let travel=((randomY-floor(randomY))*height+time*speed).truncatingRemainder(dividingBy:height)
            let wind=activeWeather == .wind ? time*speed : time*10
            let x=((randomX-floor(randomX))*width+wind).truncatingRemainder(dividingBy:width)-width/2
            let sway=activeWeather == .snow ? sin(time+seed)*4 : 0
            node.position=CGPoint(x:Double(followCamera.position.x)+x+sway,y:Double(followCamera.position.y)+height/2-travel)
            node.zRotation=activeWeather == .wind ? time+seed : 0
            node.alpha=activeWeather == .storm ? 0.7 : 0.5
        }
        weatherLayer.childNode(withName:"lightning")?.position=followCamera.position
        weatherLayer.childNode(withName:"cloudShade")?.position=followCamera.position
    }
    private func layoutCamera(jump: Bool) {
        guard let view, view.bounds.width > 0, dimensions.width > 0 else { return }
        let zoom = indoors ? max(dimensions.width / view.bounds.width, dimensions.height / view.bounds.height) : 16 * visibleColumns / view.bounds.width
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
        if previousTime > 0 { weatherTime += min(0.05,max(0,currentTime-previousTime)) }
        previousTime = currentTime
        updateWeather()
        ambientLayer.position=followCamera.position
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
        let worldRevision="pixel-world-15-\(motel.household.level)-"+revision+"-floor\(motel.viewingFloor)-facilities\(motel.simulation.facilities.count)-"+motel.rooms.map{"\($0.health.kind.rawValue):\($0.health.upgrades.count):\($0.health.faults.count)"}.joined(separator:",")
        var actors = [RPGActor(id: "player", tile: motel.actorTile, color: FamilyHome.outfitColors[motel.household.outfit], variant: 7, facing: motel.actorFacing)]
        if !interior {
            actors += motel.neighborhoodActors
            let incident = motel.operationsState.incident
            let victim = incident?.guest ?? motel.rooms.compactMap(\.guest).first
            let other = incident?.otherGuest ?? motel.rooms.compactMap(\.guest).dropFirst().first
            actors += motel.waiting.filter { $0.id != motel.reception.visitor?.guest.id }.map { RPGActor(id: "guest-\($0.id)", tile: motel.worldState.guestPositions?[$0.id] ?? MotelGrounds.guestTile($0.id), color: $0.color, variant: $0.appearanceSeed, name: $0.name,duration:incident == nil ? MotelCadence.guestWalk : MotelCadence.travel,expression:incident == nil ? "" : "scared") }
            actors += motel.worldState.travellers.map {
                RPGActor(id: "guest-\($0.id)", tile: $0.player, color: $0.color, variant: $0.appearanceSeed, facing: $0.player.y > $0.previous.y ? 0 : $0.player.x < $0.previous.x ? 1 : $0.player.x > $0.previous.x ? 2 : 3, duration: incident == nil ? MotelCadence.guestWalk : MotelCadence.travel,expression:incident == nil ? "" : "scared")
            }
            for worker in motel.operationsState.workers where worker.role != .clerk || worker.tile.distance(to:worker.role.home)>1 {
                var workerActor = RPGActor(id:"worker-"+worker.id,tile:worker.tile,color:worker.role.color,variant:200+(StaffRole.allCases.firstIndex(of:worker.role) ?? 0),facing:worker.tile.x < (worker.previous?.x ?? worker.tile.x) ? 1 : worker.tile.x > (worker.previous?.x ?? worker.tile.x) ? 2 : worker.tile.y < (worker.previous?.y ?? worker.tile.y) ? 3 : 0,name:worker.role.name,duration:MotelCadence.travel)
                if let incident {
                    workerActor.expression = worker.role == incident.kind.responder ? (incident.kind == .pool ? "concerned" : "determined") : "scared"
                }
                if worker.progress > 0 && (worker.previous == nil || worker.previous == worker.tile) && !(worker.status?.hasPrefix("NEED") ?? false) {
                    workerActor.action = worker.role == .valet ? "carwash" : worker.role == .maintenance ? "repair" : worker.role == .security ? "calm" : "mop"
                }
                if incident == nil {workerActor.marker=worker.status ?? "AT POST"}
                if let incident=motel.operationsState.incident,incident.kind.responder == worker.role,
                   worker.tile.distance(to:incident.approach) <= 1 {
                    workerActor.action = incident.kind == .fire ? "extinguish" : incident.kind == .pool ? "rescue" : "calm"
                    workerActor.expression = incident.kind == .pool ? "concerned" : "determined"
                }
                actors.append(workerActor)
            }
            if motel.managementEnabled {
                for issue in motel.simulation.issues {
                    let special=[HotelIssueKind.adultVisitor,.drugDeal,.cult,.celebrity].contains(issue.kind)
                    if special {
                        actors.append(RPGActor(id:"request-\(issue.id)",tile:motel.worldState.witnessPositions?[issue.id] ?? Tile(x:8+issue.id%3,y:14),color:issue.kind == .cult ? 0x976AB0 : 0xD6BD71,variant:issue.id+220,name:issue.kind == .celebrity ? "VIP" : "Visitor",marker:"!",duration:incident == nil ? MotelCadence.guestWalk : MotelCadence.travel,expression:incident == nil ? "" : "scared"))
                    } else if issue.roomID / 9 == motel.viewingFloor {
                        let effect=issue.kind == .leak ? 4 : issue.kind == .ac || issue.kind == .temperature ? 5 : issue.kind == .bedbugs || issue.kind == .roaches ? 6 : issue.kind == .noise ? 7 : 0
                        if effect>0 {actors.append(RPGActor(id:"issue-\(issue.id)",tile:MotelGrounds.roomDoor(issue.roomID),color:0xD9AA71,variant:0,name:issue.kind.title,effect:effect))}
                    }
                }
            }
            if let police = motel.business.police {
                actors.append(RPGActor(id:"police",tile:police.tile,color:0x54739C,variant:0,name:"Officer Vega",marker:"!",duration:MotelCadence.travel*Double(MotelCadence.businessSteps),expression:incident == nil ? "serious" : "determined"))
            }
            if let incident = motel.operationsState.incident {
                let kind = incident.kind
                if kind != .fire {
                    actors.removeAll { $0.id == "guest-\(victim?.id ?? -999)" || (kind == .fight && $0.id == "guest-\(other?.id ?? -999)") }
                }
                actors.append(RPGActor(id:"chaos",tile:incident.tile,color:victim?.color ?? 0xD99B7E,variant:victim?.appearanceSeed ?? 100,facing:2,name:kind == .fire ? "FIRE!" : kind == .pool ? "HELP!" : "FIGHT!",effect:kind == .fire ? 1 : kind == .pool ? 2 : 3))
                if kind == .fight { actors.append(RPGActor(id:"chaos-other",tile:Tile(x:incident.tile.x+1,y:incident.tile.y),color:other?.color ?? 0x82AFC1,variant:other?.appearanceSeed ?? 104,facing:1,marker:"!",effect:3)) }
            }
        } else if let room, let guest = room.guest, let visit, motel.guestPresent(in: room.id) {
            actors.append(RPGActor(id: "guest-\(guest.id)", tile: visit.guestTile, color: guest.color, variant: guest.appearanceSeed, danger: true))
        }
        actors += motel.petActors
        return RPGSceneView(mapID: mapID, revision: worldRevision, mapSize: CGSize(width: interior ? 144 : MotelGrounds.width*16, height: interior ? 144 : MotelGrounds.height*16), columns: 14, interior: interior, actors: actors, working: workProgress > 0,
                            workKind:motel.cleaningTarget == 0 ? "bed" : motel.cleaningTarget == 1 ? "trash" : "mop",
                            visual:motel.operationsState.visual,weather:motel.weather,cars:motel.operationsState.cars ?? [],day:motel.day,
                            night:motel.isNight,nightVision:motel.simulation.nightVision,powerOut:motel.simulation.powerOut || (room?.health.faults.contains(.light) ?? false)) {
            if let visit, let room { return AnyView(MotelRoomCanvas(room: room, visit: visit, x: 0, y: 0, guestPresent: motel.guestPresent(in: room.id), sceneryOnly: true)) }
            if motel.worldState.place == .office { return AnyView(MotelOfficeCanvas(sceneryOnly: true, motel: motel, x: 0, y: 0)) }
            return AnyView(MotelGroundsCanvas(motel: motel, x: 0, y: 0, npcTick: 0, sceneryOnly: true, fullMap: true))
        }
    }
}

