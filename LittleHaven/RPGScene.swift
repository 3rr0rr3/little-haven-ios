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
    var cycling = false
    var bikeColor:UInt32 = 0x5F9E91
    var corralCreature = 0
    var creature = false
    var animal = 0
    var displayScale = 1.0
    var seated = false
    var effect = 0
    var action = ""
    var expression = ""
    var wornClothes = false
    var shopUniform = 0
    var beachwear = false
    var resting = false
    var routine = ""
    var celebrating = false
    var dirty = false
    var ambient = ""
    var lifeKind:String {
        guard action.isEmpty,effect==0,!cycling,expression != "scared",(!danger || ambient=="sleep") else{return ""}
        if !ambient.isEmpty {return ambient}
        if animal>0 || creature || corralCreature>0 {return "creature"}
        if id=="hildarelys" {return "family"}
        if id=="samhil" {return "legs"}
        if id.hasPrefix("fish-diner-") {return "eat"}
        if id.hasPrefix("bar-patron-") {return "sip"}
        if id=="shopkeeper-bar" {return "pour"}
        if id=="shopkeeper-fish" {return "clear"}
        if id.hasPrefix("shopkeeper-") {return "wave"}
        if id=="reception-guest" {return "nod"}
        if expression=="scared" || id=="player" {return ""}
        switch routine {
        case "breakfast":return "eat"
        case "bar":return "sip"
        case "beach":return "sit"
        case "room":return "knock"
        case "complaint":return "shrug"
        case "walk","shelter","luggage":return "phone"
        default:return id.hasPrefix("guest-") ? "phone" : ""
        }
    }
    var lifeOffset:Int {id.utf8.reduce(0){($0+Int($1))%16}}
}

private struct WorldTouchKey: EnvironmentKey {
    static let defaultValue: ((Tile, (() -> Void)?) -> Void)? = nil
}
extension EnvironmentValues {
    var worldTouch: ((Tile, (() -> Void)?) -> Void)? {
        get {self[WorldTouchKey.self]}
        set {self[WorldTouchKey.self]=newValue}
    }
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
    var bikePositions:[Int:Tile]=[:]
    var day = 1
    var night = false
    var nightVision = false
    var powerOut = false
    var pumpFault = false
    var poolOffset=Tile(x:0,y:0)
    var pumpPosition=Tile(x:10,y:21)
    var lifeProps:[HavenWorldProp] = []
    let scenery: () -> AnyView

    @MainActor final class Coordinator {
        let scene = RPGScene()
        private var pending: (() -> Void)?
        private var scheduled = false
        func enqueue(in view: SKView, update: @escaping () -> Void) {
            pending = update
            schedule(in: view)
        }
        func schedule(in view: SKView) {
            guard !scheduled, pending != nil else { return }
            scheduled = true
            // ImageRenderer must not start another SwiftUI render inside updateUIView.
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self else { return }
                self.scheduled = false
                guard let view, view.window != nil,
                      RPGViewport.cameraScale(mapWidth: 1, mapHeight: 1,
                        viewportWidth: Double(view.bounds.width), viewportHeight: Double(view.bounds.height),
                        columns: 1, interior: true) != nil else { return }
                let update = self.pending
                self.pending = nil
                autoreleasepool { update?() }
            }
        }
        func cancel() { pending = nil }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SKView {
        let view = LayoutReadyRPGView()
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.isAccessibilityElement = false
        view.isMultipleTouchEnabled = true
        view.onLayoutReady = { [weak coordinator = context.coordinator, weak view] in
            if let view { coordinator?.schedule(in: view) }
        }
        return view
    }
    func updateUIView(_ view: SKView, context: Context) {
        let scene = context.coordinator.scene
        context.coordinator.enqueue(in: view) { [weak view, weak scene] in
        guard let view, let scene else { return }
        if view.scene !== scene {
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
        }
        scene.configure(mapID: mapID, revision: revision, mapSize: mapSize,
                        columns: columns, interior: interior, actors: actors,
                        working: working, workKind: workKind, visual: visual,
                        weather:weather,cars:cars,bikePositions:bikePositions,day:day,night:night,nightVision:nightVision,powerOut:powerOut,pumpFault:pumpFault,pumpPosition:pumpPosition,poolOffset:poolOffset,lifeProps:lifeProps,scenery: scenery)
        }
    }
    static func dismantleUIView(_ view: SKView, coordinator: Coordinator) {
        coordinator.cancel()
        (view as? LayoutReadyRPGView)?.onLayoutReady = nil
        view.scene?.removeAllActions()
        view.presentScene(nil)
    }
}

private final class LayoutReadyRPGView: SKView {
    var onLayoutReady: (() -> Void)?
    override func layoutSubviews() { super.layoutSubviews(); onLayoutReady?() }
    override func didMoveToWindow() { super.didMoveToWindow(); onLayoutReady?() }
}

enum OfficeRenderPolicy {
    static var homeCompatibility:Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-home-compatibility") {return true}
        #endif
        return compatibility
    }
    static var compatibility: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-office-compatibility") { return true }
        #endif
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ||
            UserDefaults.standard.bool(forKey:"littlehaven.compatibleOffice")
    }
}

// Uses the same illustrated scene and actor frames, without a SpriteKit view or
// ImageRenderer texture upload. Gameplay and all office touch targets stay outside.
struct CompatibleOfficeScene: View {
    let theme: Int
    let clerkHired: Bool
    let actors: [RPGActor]
    let visual: HotelVisual?
    let props: [HavenWorldProp]
    @State private var visualStarted = Date.distantPast
    var body: some View {
        GeometryReader { proxy in
            let scale = max(0, min(proxy.size.width / 240, proxy.size.height / 240))
            ZStack(alignment: .topLeading) {
                ExpandedOfficeArt(theme: theme, clerkHired: clerkHired).frame(width:240,height:240)
                ForEach(props.filter { $0.kind == 41 }, id: \.id) { prop in
                    CompatibilityCelebrationTable()
                        .position(x:CGFloat(prop.tile.x*16+8),y:CGFloat(prop.tile.y*16+5))
                        .zIndex(20)
                }
                ForEach(actors, id: \.id) { actor in
                    CompatibleOfficeActor(actor: actor)
                        .position(x:CGFloat(actor.tile.x*16+8),y:CGFloat(actor.tile.y*16+5))
                        .animation(.linear(duration:actor.duration), value:actor.tile)
                        .zIndex(Double(actor.tile.y*16))
                }
                if let visual {
                    TimelineView(.animation(minimumInterval:0.1,paused:Date().timeIntervalSince(visualStarted)>2.65)) { timeline in
                        let elapsed = timeline.date.timeIntervalSince(visualStarted)
                        if elapsed >= 0 && elapsed < 2.65 {
                            HotelActionArtwork(kind:visual.kind,frame:Int(elapsed/0.1)%8)
                                .scaleEffect(22.0/64.0)
                                .position(x:CGFloat(visual.target.x*16+8),y:CGFloat(visual.target.y*16+5))
                        }
                    }.zIndex(10000)
                }
            }.frame(width:240,height:240)
                .scaleEffect(scale,anchor:.topLeading)
                .offset(x:(proxy.size.width-240*scale)/2,y:(proxy.size.height-240*scale)/2)
        }
        .onChange(of:visual?.id) { _,_ in visualStarted = Date() }
        .onAppear {StartupTrace.stage("compatible_office_appeared")}
        .allowsHitTesting(false)
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("Reception compatibility renderer")
        .accessibilityIdentifier("officeCompatibilityRenderer")
    }
}

// The iOS 27 home path shares the proven direct reception renderer. No SKView,
// SKCropNode, ImageRenderer snapshot or texture upload is involved in this room.
struct CompatibleHomeScene:View {
    let actors:[RPGActor]
    var livingRoom=false
    let scenery:AnyView
    var body:some View {
        GeometryReader {proxy in
            let scale=max(0,min(proxy.size.width/240,proxy.size.height/240))
            ZStack(alignment:.topLeading) {
                scenery.frame(width:240,height:240)
                if livingRoom {
                    CompatibleHomeTV().frame(width:38,height:20).clipShape(RoundedRectangle(cornerRadius:2)).position(x:186,y:57)
                }
                ForEach(actors,id:\.id) {actor in
                    CompatibleOfficeActor(actor:actor)
                        .position(x:CGFloat(actor.tile.x*16+8),y:CGFloat(actor.tile.y*16+5))
                        .animation(.linear(duration:actor.duration),value:actor.tile)
                        .zIndex(Double(actor.tile.y*16))
                }
                if livingRoom {CompatibleHomeSofaFront().zIndex(159)}
            }.frame(width:240,height:240).scaleEffect(scale,anchor:.topLeading)
                .offset(x:(proxy.size.width-240*scale)/2,y:(proxy.size.height-240*scale)/2)
        }.allowsHitTesting(false).accessibilityElement(children:.ignore)
            .accessibilityLabel(livingRoom ? "Home compatibility renderer" : "Bedroom compatibility renderer")
            .accessibilityIdentifier(livingRoom ? "homeCompatibilityRenderer" : "bedroomCompatibilityRenderer")
            .onAppear {StartupTrace.stage(livingRoom ? "compatible_home_appeared" : "compatible_bedroom_appeared")}
    }
}
private struct CompatibleHomeSofaFront:View {
    var body:some View {
        Canvas {context,_ in
            guard let image=PaintedArt.image("bh-sofa-back")?.cgImage else{return}
            let top=Int(Double(image.height)*0.52)
            guard let piece=image.cropping(to:CGRect(x:0,y:top,width:image.width,height:image.height-top)) else{return}
            let fraction=Double(top)/Double(image.height)
            context.draw(Image(decorative:piece,scale:1),in:CGRect(x:161,y:141+34*fraction,width:54,height:34*(1-fraction)))
        }.frame(width:240,height:240)
    }
}
private struct CompatibleHomeTV:View {
    var body:some View {
        TimelineView(.animation(minimumInterval:0.12)) {timeline in
            Canvas {context,_ in
                let t=timeline.date.timeIntervalSinceReferenceDate
                context.fill(Path(CGRect(x:0,y:0,width:38,height:20)),with:.color(Color(hex:0xA3D1DB)))
                context.fill(Path(CGRect(x:0,y:11,width:38,height:9)),with:.color(Color(hex:0x52A6B2)))
                context.fill(Path(ellipseIn:CGRect(x:27,y:2,width:5,height:5)),with:.color(Color(hex:0xFFE39A)))
                for i in 0..<2 {
                    let x=(t*Double(i+2)+Double(i*16)).truncatingRemainder(dividingBy:47)-9
                    context.fill(Path(ellipseIn:CGRect(x:x,y:3+Double(i*3),width:9,height:3)),with:.color(.white))
                }
                let x=(t*8).truncatingRemainder(dividingBy:49)-8,y=13+sin(t*7)*0.6
                context.fill(Path(roundedRect:CGRect(x:x,y:y,width:8,height:2),cornerRadius:0.6),with:.color(Color(hex:0xC27657)))
                var sail=Path();sail.move(to:CGPoint(x:x+3,y:y));sail.addLine(to:CGPoint(x:x+3,y:y-7));sail.addLine(to:CGPoint(x:x+8,y:y));sail.closeSubpath()
                context.fill(sail,with:.color(Color(hex:0xFFF2C7)))
            }
        }
    }
}

private struct CompatibleOfficeActor: View {
    let actor: RPGActor
    @State private var walkingUntil = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval:actor.action.hasPrefix("care-") ? 0.075 : 0.095,paused:Date()>walkingUntil && actor.action.isEmpty)) { timeline in
            let walking = timeline.date < walkingUntil
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate/0.095)%4
            let stride = walking ? [1.0,0,-1,0][phase] : 0
            ZStack {
                if actor.action.isEmpty {
                    Group {
                        if !walking,!reduceMotion,!actor.lifeKind.isEmpty {
                            TimelineView(.periodic(from:.now,by:actor.animal>0 ? 0.6 : 0.25)) {idleTime in
                                HavenLifeArtwork(actor:actor,kind:actor.lifeKind,frame:(Int(idleTime.date.timeIntervalSinceReferenceDate/(actor.animal>0 ? 0.6 : 0.25))+actor.lifeOffset)%16)
                            }
                        } else {ActorArtwork(actor:actor,stride:stride)}
                    }.scaleEffect(actor.displayScale)
                        .offset(y:(actor.animal > 0 || actor.creature) ? 11*(1-actor.displayScale) : 0)
                } else {
                    WorkingCharacterArtwork(kind:actor.action,frame:actor.action.hasPrefix("care-") ? Int(timeline.date.timeIntervalSinceReferenceDate/0.075)%12 : phase*3,color:actor.color,variant:actor.variant,facing:actor.facing)
                }
                if !actor.marker.isEmpty {
                    Text(actor.marker).font(.system(size:3.5,weight:.bold,design:.monospaced))
                        .foregroundStyle(Color(hex:0x304A3B)).offset(y:-17)
                }
            }.frame(width:48,height:48)
        }
        .onChange(of:actor.tile) { _,_ in walkingUntil=Date().addingTimeInterval(actor.duration*1.5) }
    }
}

private struct CompatibilityCelebrationTable: View {
    var body: some View {
        Canvas { c,_ in
            c.fill(Path(roundedRect:CGRect(x:4,y:22,width:34,height:14),cornerRadius:3),with:.color(Color(hex:0xF5E7C8)))
            c.fill(Path(CGRect(x:5,y:32,width:32,height:3)),with:.color(Color(hex:0xD99B7E)))
            for x in [3.0,39] {
                c.fill(Path(CGRect(x:x,y:8,width:0.5,height:16)),with:.color(Color(hex:0xD7CBAA)))
                c.fill(Path(ellipseIn:CGRect(x:x-3,y:0,width:7,height:9)),with:.color(Color(hex:x<20 ? 0xD99B7E : 0x91B7A1)))
            }
            c.fill(Path(roundedRect:CGRect(x:17,y:17,width:8,height:7),cornerRadius:2),with:.color(Color(hex:0xE4AB9A)))
            c.fill(Path(CGRect(x:20,y:13,width:1,height:4)),with:.color(Color(hex:0xEFC977)))
            for x in [9.0,33] {
                c.fill(Path(CGRect(x:x,y:19,width:3,height:5)),with:.color(Color(hex:0x91B7A1)))
                c.fill(Path(ellipseIn:CGRect(x:x-2,y:14,width:6,height:6)),with:.color(Color(hex:0xEFC977)))
            }
        }.frame(width:42,height:42)
    }
}

private struct ActorArtwork: View {
    let actor: RPGActor
    let stride: Double
    var body: some View {
        Canvas { context, _ in
            if actor.cycling {
                var bicycle=context
                bicycle.translateBy(x:0,y:12)
                BicycleArt.draw(context:&bicycle,color:actor.bikeColor,facing:actor.facing,pedal:stride*2)
            }
            if actor.effect > 0 {
                ChaosArt.draw(context:&context,kind:actor.effect,stride:stride,color:actor.color,variant:actor.variant,facing:actor.facing)
            } else if actor.corralCreature > 0 {CorralCreatureArt.draw(context:&context,kind:actor.corralCreature,facing:actor.facing,walk:stride)}
            else if actor.creature {MochiArt.draw(context:&context,facing:actor.facing,walk:stride)}
            else if actor.animal > 0 { CatArt.draw(context:&context,gray:actor.animal == 1,walk:stride,facing:actor.facing) }
            else if actor.seated {
                var sitter=context;sitter.clip(to:Path(CGRect(x:0,y:0,width:24,height:22)))
                PaperPerson.draw(context:&sitter,x:4,y:9,color:actor.color,variant:actor.variant,facing:actor.facing,walk:0,kneeling:true)
            }
            else { PaperPerson.draw(context:&context,x:4,y:actor.cycling ? 7.5 : 9,color:actor.color,variant:actor.variant,facing:actor.facing,walk:actor.cycling ? stride*0.4 : stride,expression:actor.expression,beachwear:actor.beachwear) }
            if actor.cycling && (actor.facing == 0 || actor.facing == 3) {
                var handlebar=Path();handlebar.move(to:CGPoint(x:6,y:21));handlebar.addLine(to:CGPoint(x:18,y:21))
                context.stroke(handlebar,with:.color(Color(hex:0x344D48)),style:StrokeStyle(lineWidth:1.2,lineCap:.round))
            }
            if actor.dirty {PlayerDirtArt.draw(context:&context,facing:actor.facing)}
            if actor.wornClothes {
                // Visible elbow/knee patches and a shoulder bag, with direction-aware placement.
                let patch=Path(roundedRect:CGRect(x:actor.facing == 1 ? 6 : 15,y:19,width:3,height:3),cornerRadius:0.3)
                context.fill(patch,with:.color(Color(hex:0xB29B75)))
                context.stroke(Path(CGRect(x:10,y:17,width:1,height:6)),with:.color(Color(hex:0x554B40)),lineWidth:0.5)
                context.fill(Path(roundedRect:CGRect(x:actor.facing == 1 ? 16 : 3,y:20,width:5,height:5),cornerRadius:1),with:.color(Color(hex:0x786646)))
            }
            if actor.shopUniform > 0 {ShopKeeperArt.uniform(context:&context,kind:actor.shopUniform,facing:actor.facing)}
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
    private var cameraDestination: CGPoint?
    private var cameraMoveDuration = 0.14
    private var textures: [String: SKTexture] = [:]
    private var configured = false
    private var viewSize = CGSize.zero
    private var activeWeather: HotelWeather = .sunny
    private let weatherLayer = SKNode()
    private let nightSky=SKNode()
    private var skyNight=false
    private var skyViewport=CGSize.zero
    private let ambientLayer=SKSpriteNode(color:.black,size:CGSize(width:1600,height:1600))
    private var weatherParticles: [SKShapeNode] = []
    private var weatherTime = 0.0
    private var previousTime = 0.0
    private var visualSeen = -1
    private var visualMapSeen = ""
    private var actionTextures: [String:[SKTexture]] = [:]
    private var carTextures: [String:SKTexture] = [:]
    private var lifeTextures:[String:[SKTexture]]=[:]
    private var lifeBuildBudget=2
    private var palmFrames:[SKTexture]=[]

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
                             visual:HotelVisual?,weather:HotelWeather,cars:[HotelCar],bikePositions:[Int:Tile],day:Int,night:Bool,nightVision:Bool,powerOut:Bool,pumpFault:Bool,pumpPosition:Tile,poolOffset:Tile,lifeProps:[HavenWorldProp],
                             scenery: () -> AnyView) {
        StartupTrace.stage("spritekit_configure_"+mapID)
        let changedMap = worldID != mapID
        if changedMap {lifeTextures.removeAll(keepingCapacity:true)}
        lifeBuildBudget=2
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
        configureWater(mapID:mapID,poolOffset:poolOffset)
        configureHomeTV(mapID:mapID)
        configureHomeSofa(mapID:mapID)
        configurePumpFault(active:mapID == "grounds" && pumpFault,at:pumpPosition)
        configureAmbient(night:night && !interior,nightVision:nightVision,powerOut:powerOut)
        configureWeather(interior ? .sunny : weather)
        configureLifeProps(lifeProps)
        configureDiningService(mapID:mapID)
        if !interior { configureCars(cars,day:day,positions:bikePositions) }
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
            let footOffset = actor.effect == 1 ? -10 : actor.resting ? 10 : (actor.animal > 0 || actor.creature) ? 11 * (1 - actor.displayScale) : 0
            let target = CGPoint(x: CGFloat(actor.tile.x * 16 + 8), y: -CGFloat(actor.tile.y * 16 + 5) - CGFloat(footOffset))
            let moving = existing != nil && node.userData?["targetX"] as? Int != actor.tile.x || existing != nil && node.userData?["targetY"] as? Int != actor.tile.y
            let diagonal = existing != nil && node.userData?["targetX"] as? Int != actor.tile.x && node.userData?["targetY"] as? Int != actor.tile.y
            let stepDuration = actor.id == "player" && diagonal ? (actor.cycling ? 0.12 : 0.19) : actor.duration
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
            let appearance = "\(actor.dirty)-\(actor.wornClothes)-\(actor.color)-\(actor.variant)-\(actor.effect)-\(actor.expression)-\(actor.facing)-\(actor.beachwear)-\(actor.seated)"
            if node.userData?["appearance"] as? String != appearance {
                node.removeAction(forKey:"effect"); node.removeAction(forKey:"walk"); node.removeAction(forKey:"spar")
                node.removeAction(forKey:"walkEnd")
                node.zRotation = 0; node.texture = idle; node.userData?["appearance"] = appearance
            }
            if actor.effect == 0 && node.action(forKey:"walk") == nil && node.action(forKey:"working-pose") == nil && node.action(forKey:"life-pose") == nil { node.texture = idle }
            if moving {
                let frames = [sprite(actor, stride: 1), idle, sprite(actor, stride: -1), idle]
                if node.action(forKey:"walk") == nil {node.run(.repeatForever(.animate(with:frames,timePerFrame:actor.id == "player" ? 0.095 : stepDuration/4)),withKey:"walk")}
                node.removeAction(forKey:"walkEnd")
                node.run(.sequence([.wait(forDuration:stepDuration*1.5),.run { [weak node] in
                    node?.removeAction(forKey:"walk");node?.texture=idle
                }]),withKey:"walkEnd")
                node.removeAction(forKey: "move")
                node.run(.move(to: target, duration: stepDuration), withKey: "move")
            }
            configureEverydayAnimation(actor,node:node,moving:moving)
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
            let poseKind=actor.id == "player" && working ? workKind : actor.action
            let poseKey=poseKind+"-\(actor.dirty)-\(actor.wornClothes)-\(actor.color)-\(actor.variant)-\(actor.facing)"
            if node.userData?["poseKey"] as? String != poseKey {
                node.removeAction(forKey:"working-pose")
                node.userData?["poseKey"]=poseKey
                if !poseKind.isEmpty {
                    node.removeAction(forKey:"walk");node.removeAction(forKey:"walkEnd")
                    let frames=workingFrames(poseKind,color:actor.color,variant:actor.variant,facing:actor.facing)
                    node.texture=frames[0];node.size=CGSize(width:48,height:48)
                    node.run(.repeatForever(.animate(with:frames,timePerFrame:0.075)),withKey:"working-pose")
                } else {
                    node.texture=idle
                    node.size=CGSize(width:actor.effect == 1 ? 48 : 24*actor.displayScale,height:actor.effect == 1 ? 56 : 28*actor.displayScale)
                }
            }
            if moving {node.childNode(withName:"temporary-work")?.removeFromParent()}
            if node.childNode(withName:"temporary-work") != nil {node.texture=nil}
            if actor.effect == 3 && node.action(forKey:"spar") == nil {
                node.run(.repeatForever(.sequence([.rotate(toAngle:0.18,duration:0.12),.rotate(toAngle:-0.18,duration:0.12),.rotate(toAngle:0,duration:0.16)])),withKey:"spar")
            }
            configureLifePose(actor,node:node,moving:moving,working:!poseKind.isEmpty)
            configureServiceRoute(actor,node:node)
            if actor.effect == 0 {node.zRotation=actor.resting ? -0.12 : 0}
            node.zPosition = CGFloat(actor.tile.y * 16)
            if actor.id == "player" {node.alpha=world.childNode(withName:"player-response") == nil ? 1 : 0}
            let caption = actor.marker
            if caption.isEmpty { node.childNode(withName:"caption")?.removeFromParent() }
            else {
                let label = (node.childNode(withName:"caption") as? SKLabelNode) ?? SKLabelNode(fontNamed:"Menlo-Bold")
                if label.parent == nil {
                    label.name="caption";label.fontSize=3.5
                    label.fontColor=UIColor(red:0.18,green:0.29,blue:0.23,alpha:1)
                    label.position=CGPoint(x:0,y:actor.animal > 0 ? 17 * actor.displayScale : 17)
                    label.zPosition=1;node.addChild(label)
                }
                if label.text != caption { label.text=caption }
            }
            if actor.id == "player" {
                playerTarget = target
                cameraMoveDuration=stepDuration

            }
        }
        layoutCamera(jump: changedMap)
        StartupTrace.stage("spritekit_ready_"+mapID)
    }

    // Small reusable props animate on the scene, without per-frame map redraws.
    private func configureEverydayAnimation(_ actor:RPGActor,node:SKSpriteNode,moving:Bool) {
        let key=actor.routine+"-\(actor.celebrating)-\(actor.animal>0 && !moving)"
        guard node.userData?["everyday"] as? String != key else{return}
        node.userData?["everyday"]=key
        node.childNode(withName:"everyday")?.removeFromParent()
        let detail=SKNode();detail.name="everyday";detail.zPosition=3
        if actor.routine=="luggage" {
            let bag=SKShapeNode(rectOf:CGSize(width:5,height:7),cornerRadius:1)
            bag.fillColor=UIColor(Color(hex:0xB58B63));bag.strokeColor=UIColor(Color(hex:0x69523E));bag.lineWidth=0.6
            bag.position=CGPoint(x:8,y:-8);detail.addChild(bag)
        }
        if actor.celebrating {
            let star=SKShapeNode(circleOfRadius:1.6);star.fillColor=UIColor(Color(hex:0xEFC977));star.strokeColor = .clear
            star.position=CGPoint(x:8,y:10);detail.addChild(star)
            if !UIAccessibility.isReduceMotionEnabled {star.run(.repeatForever(.sequence([.fadeAlpha(to:0.3,duration:1),.fadeAlpha(to:1,duration:1)])))}
        }
        if actor.animal>0 && !moving && !actor.creature && !UIAccessibility.isReduceMotionEnabled {
            let breath=SKShapeNode(ellipseOf:CGSize(width:4,height:1.5));breath.fillColor=UIColor.white.withAlphaComponent(0.5);breath.strokeColor = .clear
            breath.position=CGPoint(x:5,y:8);detail.addChild(breath)
            breath.run(.repeatForever(.sequence([.fadeAlpha(to:0,duration:1.4),.fadeAlpha(to:0.5,duration:1.4)])))
        }
        if !detail.children.isEmpty {node.addChild(detail)}
    }

    @MainActor private func configureLifePose(_ actor:RPGActor,node:SKSpriteNode,moving:Bool,working:Bool) {
        let kind=actor.lifeKind
        let nearby=abs(node.position.x-followCamera.position.x)<CGFloat(visibleColumns*20) && abs(node.position.y-followCamera.position.y)<CGFloat(visibleColumns*30)
        guard !kind.isEmpty,!moving,!working,node.childNode(withName:"temporary-work")==nil,node.action(forKey:"walk")==nil,node.action(forKey:"walkEnd")==nil,nearby,!UIAccessibility.isReduceMotionEnabled else {
            node.removeAction(forKey:"life-pose");node.userData?["life-key"]=nil;return
        }
        let key="\(kind)-\(actor.color)-\(actor.variant)-\(actor.facing)-\(actor.animal)-\(actor.corralCreature)-\(actor.creature)-\(actor.seated)-\(actor.beachwear)-\(actor.shopUniform)-\(actor.dirty)"
        guard node.userData?["life-key"] as? String != key else{return}
        var frames=lifeTextures[key]
        if frames==nil {
            guard lifeBuildBudget>0 else{return};lifeBuildBudget-=1
            if lifeTextures.count>=48 {lifeTextures.removeAll(keepingCapacity:true)}
            frames=(0..<16).map {frame in
                let renderer=ImageRenderer(content:HavenLifeArtwork(actor:actor,kind:kind,frame:frame));renderer.scale=3
                let texture=renderer.uiImage.map{SKTexture(image:$0)} ?? SKTexture();texture.filteringMode = .linear;return texture
            }
            lifeTextures[key]=frames
        }
        guard let frames else{return}
        node.removeAction(forKey:"life-pose");node.userData?["life-key"]=key
        let stagger=(0..<16).map{frames[($0+actor.lifeOffset)%16]}
        node.run(.repeatForever(.animate(with:stagger,timePerFrame:actor.animal>0 ? 0.6 : 0.25)),withKey:"life-pose")
    }
    private func configureDiningService(mapID:String) {
        guard mapID=="shop-bar" || mapID=="shop-fish" else{return}
        guard world.childNode(withName:"dining-service")==nil else{return}
        let root=SKNode();root.name="dining-service";root.zPosition=300;world.addChild(root)
        for (index,table) in BarLayout.tables.enumerated() {
            let cup=SKShapeNode(rectOf:CGSize(width:2.5,height:3.5),cornerRadius:0.4)
            cup.fillColor=UIColor(Color(hex:0xD7C5A2));cup.strokeColor=UIColor(Color(hex:0x6A5944));cup.lineWidth=0.3
            cup.position=CGPoint(x:table.x*16+20,y:-(table.y*16+4));root.addChild(cup)
            if !UIAccessibility.isReduceMotionEnabled {
                cup.run(.repeatForever(.sequence([.wait(forDuration:5+Double(index)*3),.fadeOut(withDuration:0.6),.wait(forDuration:4),.fadeIn(withDuration:0.6)])))
            }
        }
    }
    private func configureServiceRoute(_ actor:RPGActor,node:SKSpriteNode) {
        guard actor.id=="shop-server",node.action(forKey:"service-route")==nil,!UIAccessibility.isReduceMotionEnabled else{return}
        // Central aisles avoid tables, seats and the entrance. This actor is decorative.
        let tiles=[Tile(x:7,y:7),Tile(x:8,y:7),Tile(x:7,y:7),Tile(x:7,y:10),Tile(x:7,y:7),Tile(x:7,y:5)]
        let route=tiles.flatMap{tile in [SKAction.move(to:CGPoint(x:tile.x*16+8,y:-(tile.y*16+5)),duration:1.8),SKAction.wait(forDuration:1.6)]}
        node.run(.repeatForever(.sequence(route)),withKey:"service-route")
    }

    @MainActor private func sprite(_ actor: RPGActor, stride: Double) -> SKTexture {
        let key = "\(actor.dirty)-\(actor.wornClothes)-\(actor.color)-\(actor.variant)-\(actor.facing)-\(stride)-\(actor.animal)-\(actor.cycling)-\(actor.bikeColor)-\(actor.corralCreature)-\(actor.creature)-\(actor.effect)-\(actor.expression)-\(actor.shopUniform)-\(actor.beachwear)-\(actor.seated)"
        if let texture = textures[key] { return texture }
        let renderer = ImageRenderer(content: ActorArtwork(actor: actor, stride: stride))
        renderer.scale = 4
        let texture = renderer.uiImage.map { SKTexture(image: $0) } ?? SKTexture()
        textures[key] = texture
        return texture
    }


    // Native scene animation: no SwiftUI timer, map rerender or per-frame textures.
    // Bounded, reusable animated nodes. No image generation, map rasterization,
    // collision work or SwiftUI state updates happen on water animation frames.
    private func configureWater(mapID:String,poolOffset:Tile) {
        guard mapID=="grounds" || mapID=="town" else {
            world.childNode(withName:"living-water")?.removeFromParent();return
        }
        let key="\(mapID)-\(poolOffset.x)-\(poolOffset.y)-\(UIAccessibility.isReduceMotionEnabled)"
        if let old=world.childNode(withName:"living-water"),old.userData?["key"] as? String==key {return}
        world.childNode(withName:"living-water")?.removeFromParent()
        let root=SKNode();root.name="living-water";root.zPosition = -9999
        root.userData=NSMutableDictionary(dictionary:["key":key]);world.addChild(root)
        let pool=mapID=="town" ? CGRect(x:227,y:211,width:58,height:42) : CGRect(x:51+poolOffset.x*16,y:291+poolOffset.y*16,width:107,height:75)
        func surface(_ shape:Path)->SKCropNode {
            var flip=CGAffineTransform(scaleX:1,y:-1)
            let crop=SKCropNode(),mask=SKShapeNode(path:shape.cgPath.copy(using:&flip)!)
            mask.fillColor = .white;mask.strokeColor = .clear;crop.maskNode=mask;root.addChild(crop);return crop
        }
        func ripple(_ parent:SKNode,x:Double,y:Double,width:Double,index:Int) {
            let curve=CGMutablePath();curve.move(to:CGPoint(x:0,y:0))
            curve.addQuadCurve(to:CGPoint(x:width,y:0.2),control:CGPoint(x:width*0.46,y:1.8))
            let wave=SKShapeNode(path:curve);wave.strokeColor=UIColor(red:0.84,green:0.97,blue:0.92,alpha:1)
            wave.lineWidth=index%3==0 ? 0.65 : 0.4;wave.lineCap = .round
            wave.position=CGPoint(x:x,y:-y);wave.alpha=0.12;parent.addChild(wave)
            guard !UIAccessibility.isReduceMotionEnabled else{return}
            let duration=3.2+Double(index%5)*0.37,origin=wave.position
            let reset=SKAction.run { [weak wave] in wave?.position=origin;wave?.xScale=0.72;wave?.alpha=0 }
            wave.run(.repeatForever(.sequence([reset,.wait(forDuration:Double(index%7)*0.21),.group([
                .moveBy(x:2.5,y:1.2,duration:duration),.scaleX(to:1.12,duration:duration),
                .sequence([.fadeAlpha(to:0.34,duration:duration*0.42),.fadeOut(withDuration:duration*0.58)])
            ])])))
        }
        let poolSurface=surface(Path(roundedRect:pool.insetBy(dx:1,dy:1),cornerRadius:4))
        for i in 0..<12 {
            ripple(poolSurface,x:pool.minX+4+Double((i*29)%max(1,Int(pool.width-22))),y:pool.minY+5+Double((i*17)%max(1,Int(pool.height-10))),width:8+Double(i%4)*2,index:i)
        }
        if mapID=="grounds" {
            let sea=surface(BeachArt.waterShape())
            for i in 0..<36 {
                let y=681+Double((i*47)%336),row=min(63,Int(y/16))
                let x=Double(BeachLayout.shoreline(row)*16)+12+Double((i*31)%135)
                ripple(sea,x:x,y:y,width:12+Double(i%5)*3,index:i)
            }
            for i in 0..<3 {
                var flip=CGAffineTransform(scaleX:1,y:-1)
                let foam=SKShapeNode(path:BeachArt.coastline().cgPath.copy(using:&flip)!)
                foam.strokeColor=UIColor(red:0.94,green:0.98,blue:0.9,alpha:1)
                foam.lineWidth=0.8+Double(i)*0.25;foam.lineCap = .round;foam.alpha=0.18
                foam.position.x=CGFloat(3+i*4);sea.addChild(foam)
                guard !UIAccessibility.isReduceMotionEnabled else{continue}
                let reset=SKAction.run { [weak foam] in foam?.position.x=13;foam?.alpha=0 }
                foam.run(.repeatForever(.sequence([reset,.wait(forDuration:Double(i)*1.5),.group([
                    .moveBy(x:-12,y:0,duration:4.6),
                    .sequence([.fadeAlpha(to:0.48,duration:2.1),.fadeOut(withDuration:2.5)])
                ])])))
            }
        }
    }

    private func configurePumpFault(active:Bool,at tile:Tile) {
        if !active {world.childNode(withName:"pool-pump-fault")?.removeFromParent();return}
        if let existing=world.childNode(withName:"pool-pump-fault") {existing.position=CGPoint(x:tile.x*16+8,y:-(tile.y*16+15));return}
        let fault=SKNode();fault.name="pool-pump-fault";fault.position=CGPoint(x:tile.x*16+8,y:-(tile.y*16+15));fault.zPosition=360
        for i in 0..<5 {
            let spark=SKShapeNode()
            let path=CGMutablePath();path.move(to:.zero);path.addLine(to:CGPoint(x:Double(i-2)*2,y:5+Double(i%2)*3));path.addLine(to:CGPoint(x:Double(i-2)*3,y:3))
            spark.path=path;spark.strokeColor=UIColor(red:1,green:0.79,blue:0.3,alpha:1);spark.lineWidth=0.9;spark.alpha=0
            spark.run(.repeatForever(.sequence([.wait(forDuration:0.15+Double(i)*0.11),.fadeIn(withDuration:0.06),.fadeOut(withDuration:0.12),.wait(forDuration:0.6)])))
            fault.addChild(spark)
        }
        world.addChild(fault)
    }

    private func configureHomeSofa(mapID:String) {
        guard mapID=="family-house" else {world.childNode(withName:"home-sofa-front")?.removeFromParent();return}
        guard world.childNode(withName:"home-sofa-front")==nil,
              let image=PaintedArt.image("bh-sofa-back")?.cgImage else{return}
        // The backrest is in front of a sitter's lower body, not underneath her feet.
        let top=Int(Double(image.height)*0.52)
        guard let piece=image.cropping(to:CGRect(x:0,y:top,width:image.width,height:image.height-top)) else{return}
        let fraction=Double(top)/Double(image.height),height=34*(1-fraction)
        let front=SKSpriteNode(texture:SKTexture(cgImage:piece),size:CGSize(width:54,height:height))
        front.name="home-sofa-front";front.position=CGPoint(x:188,y:-(141+34*fraction+height/2));front.zPosition=159
        world.addChild(front)
    }

    private func configureHomeTV(mapID:String) {
        guard mapID == "family-house",world.childNode(withName:"home-tv") == nil else{return}
        let screen=SKCropNode();screen.name="home-tv";screen.position=CGPoint(x:186,y:-57);screen.zPosition = -9999
        let mask=SKShapeNode(rectOf:CGSize(width:38,height:20),cornerRadius:2);mask.fillColor = .white;mask.strokeColor = .clear;screen.maskNode=mask
        let sky=SKSpriteNode(color:UIColor(red:0.64,green:0.82,blue:0.86,alpha:1),size:CGSize(width:40,height:22));screen.addChild(sky)
        let sea=SKSpriteNode(color:UIColor(red:0.32,green:0.65,blue:0.7,alpha:1),size:CGSize(width:40,height:9));sea.position.y = -6;screen.addChild(sea)
        let sun=SKShapeNode(circleOfRadius:2.6);sun.fillColor=UIColor(red:1,green:0.89,blue:0.6,alpha:1);sun.strokeColor = .clear;sun.position=CGPoint(x:11,y:5);screen.addChild(sun)
        for index in 0..<2 {
            let cloud=SKShapeNode(ellipseOf:CGSize(width:9,height:3));cloud.fillColor = .white;cloud.strokeColor = .clear
            cloud.position=CGPoint(x:CGFloat(index*16-16),y:CGFloat(4+index*3))
            cloud.run(.repeatForever(.sequence([.moveBy(x:34,y:0,duration:Double(7+index*3)),.moveBy(x:-34,y:0,duration:0)])))
            screen.addChild(cloud)
        }
        let travel=SKNode();travel.position=CGPoint(x:-24,y:-3)
        let boat=SKNode();travel.addChild(boat)
        let hull=SKShapeNode(rectOf:CGSize(width:8,height:2),cornerRadius:1);hull.fillColor=UIColor(red:0.76,green:0.46,blue:0.34,alpha:1);hull.strokeColor = .clear;boat.addChild(hull)
        let sailPath=CGMutablePath();sailPath.move(to:CGPoint(x:0,y:1));sailPath.addLine(to:CGPoint(x:0,y:7));sailPath.addLine(to:CGPoint(x:5,y:1));sailPath.closeSubpath()
        let sail=SKShapeNode(path:sailPath);sail.fillColor=UIColor(red:1,green:0.95,blue:0.78,alpha:1);sail.strokeColor = .clear;boat.addChild(sail)
        travel.run(.repeatForever(.sequence([.moveTo(x:25,duration:6),.moveTo(x:-24,duration:0)])))
        boat.run(.repeatForever(.sequence([.moveBy(x:0,y:0.7,duration:0.4),.moveBy(x:0,y:-0.7,duration:0.4)])))
        screen.addChild(travel);world.addChild(screen)
    }

    @MainActor private func workingFrames(_ kind:String,color:UInt32,variant:Int=7,facing:Int=2)->[SKTexture] {
        let key="person-\(kind)-\(color)-\(variant)-\(facing)"
        if let cached=actionTextures[key] {return cached}
        let frames=(0..<12).map { frame -> SKTexture in
            let renderer=ImageRenderer(content:WorkingCharacterArtwork(kind:kind,frame:frame,color:color,variant:variant,facing:facing))
            renderer.scale=3
            let texture=renderer.uiImage.map {SKTexture(image:$0)} ?? SKTexture()
            texture.filteringMode = .linear
            return texture
        }
        actionTextures[key]=frames;return frames
    }
    @MainActor private func activityFrames(_ kind:String) -> [SKTexture] {
        if let cached=actionTextures[kind] { return cached }
        let frames=(0..<8).map { frame -> SKTexture in
            let renderer=ImageRenderer(content:HotelActionArtwork(kind:kind,frame:frame))
            renderer.scale=3
            let texture=renderer.uiImage.map { SKTexture(image:$0) } ?? SKTexture()
            texture.filteringMode = .linear
            return texture
        }
        actionTextures[kind]=frames
        return frames
    }
    @MainActor private func showVisual(_ visual:HotelVisual) {
        if visual.response == true {showResponse(visual);return}
        if !visual.kind.hasPrefix("steal-") && visual.kind != "checkin",
           let player=world.childNode(withName:"actor:player") as? SKSpriteNode {
            player.childNode(withName:"temporary-work")?.removeFromParent()
            let frames=workingFrames(visual.kind,color:visual.outfit ?? 0xC7D0D4)
            let worker=SKSpriteNode(texture:frames[0]);worker.name="temporary-work"
            worker.size=CGSize(width:48,height:48);worker.zPosition=6;player.addChild(worker)
            player.texture=nil
            worker.run(.sequence([.repeat(.animate(with:frames,timePerFrame:0.075),count:3),.removeFromParent()]))
            return
        }
        let frames=activityFrames(visual.kind)
        let sprite=SKSpriteNode(texture:frames[0])
        sprite.size=CGSize(width:visual.kind == "checkin" ? 22 : 28,height:visual.kind == "checkin" ? 22 : 28)
        sprite.position=CGPoint(x:CGFloat(visual.target.x*16+8),y: -CGFloat(visual.target.y*16+5))
        if !visual.kind.hasPrefix("steal-") && visual.kind != "checkin" {sprite.position=CGPoint(x:visual.origin.x*16+15,y:-(visual.origin.y*16+9))}
        sprite.zPosition=CGFloat(visual.origin.y*16+100)
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

    @MainActor private func showResponse(_ visual:HotelVisual) {
        if visual.kind == "rescue" {showPreviousPoolRescue(visual);return}
        world.childNode(withName:"player-response")?.removeFromParent()
        let root=SKNode();root.name="player-response";root.zPosition=30000;world.addChild(root)
        world.childNode(withName:"actor:player")?.alpha=0
        func point(_ tile:Tile)->CGPoint {CGPoint(x:tile.x*16+8,y:-(tile.y*16+5))}
        let origin=point(visual.origin),target=point(visual.target)
        let outfit=visual.outfit ?? 0xC7D0D4
        func person(_ guest:MotelGuest?)->SKSpriteNode {
            let actor=RPGActor(id:"response",tile:visual.origin,color:guest?.color ?? 0xD99B7E,variant:guest?.appearanceSeed ?? 100,facing:0)
            let node=SKSpriteNode(texture:sprite(actor,stride:0));node.size=CGSize(width:24,height:28)
            root.addChild(node);return node
        }
        func posed(_ kind:String)->SKSpriteNode {
            let frames=workingFrames(kind,color:outfit)
            let node=SKSpriteNode(texture:frames[0]);node.size=CGSize(width:48,height:48)
            node.run(.repeatForever(.animate(with:frames,timePerFrame:0.075)),withKey:"pose")
            root.addChild(node);return node
        }
        let caption=SKLabelNode(fontNamed:"AvenirNext-Bold")
        caption.fontSize=4.5;caption.fontColor=UIColor(red:1,green:0.93,blue:0.74,alpha:1)
        caption.position=CGPoint(x:origin.x,y:origin.y+50);caption.zPosition=10;root.addChild(caption)
        let duration:Double
        if visual.kind == "extinguish" {
            duration=ChaosKind.fire.responseDuration;caption.text="AIMING AT THE BASE OF THE FIRE"
            let player=posed("extinguish");player.position=CGPoint(x:origin.x-12,y:origin.y);player.zPosition=5
            let fireActor=RPGActor(id:"response-fire",tile:visual.target,color:0xE78245,variant:0,effect:1)
            let frames=(0..<8).map {sprite(fireActor,stride:Double($0))}
            let fire=SKSpriteNode(texture:frames[0]);fire.size=CGSize(width:48,height:56)
            fire.position=CGPoint(x:target.x,y:target.y+10);fire.zPosition=2;root.addChild(fire)
            fire.run(.repeatForever(.animate(with:frames,timePerFrame:0.09)))
            fire.run(.sequence([.wait(forDuration:1),.group([.fadeOut(withDuration:3.4),.scale(to:0.18,duration:3.4)])]))
            // Foam begins exactly at the held nozzle and sweeps across the fire base.
            for i in 0..<64 {
                let start=Double(i)*0.055+0.7
                let sweep=sin(Double(i)*0.45)
                let foam=SKShapeNode(circleOfRadius:0.9+CGFloat(i%3)*0.25)
                foam.fillColor=UIColor(red:0.94,green:0.96,blue:0.84,alpha:0.9);foam.strokeColor = .clear
                foam.position=CGPoint(x:player.position.x+16,y:player.position.y+1)
                foam.alpha=0;foam.zPosition=6;root.addChild(foam)
                let destination=CGPoint(x:target.x+sweep*13,y:target.y-8+Double(i%3))
                foam.run(.sequence([.wait(forDuration:start),.fadeIn(withDuration:0.03),
                    .group([.move(to:destination,duration:0.32),.scale(to:2.5,duration:0.32)]),
                    .fadeOut(withDuration:0.3),.removeFromParent()]))
            }
            caption.run(.sequence([.wait(forDuration:4.5),.run {caption.text="FIRE EXTINGUISHED"}]))
        } else {
            duration=ChaosKind.fight.responseDuration;caption.text="STEPPING BETWEEN THE GUESTS"
            let first=person(visual.guest),second=person(visual.otherGuest)
            first.position=target;second.position=CGPoint(x:target.x+20,y:target.y)
            first.zPosition=2;second.zPosition=2
            let player=posed("calm");player.position=origin;player.zPosition=4
            let center=CGPoint(x:target.x+10,y:target.y-5)
            let walkActor=RPGActor(id:"response",tile:visual.origin,color:outfit,variant:7,facing:3)
            let walkFrames=[sprite(walkActor,stride:1),sprite(walkActor,stride:0),sprite(walkActor,stride:-1)]
            let calmFrames=workingFrames("calm",color:outfit)
            player.removeAction(forKey:"pose");player.size=CGSize(width:24,height:28)
            player.run(.repeatForever(.animate(with:walkFrames,timePerFrame:0.1)),withKey:"pose")
            player.run(.sequence([.move(to:center,duration:0.8),.run {
                player.removeAction(forKey:"pose");player.size=CGSize(width:48,height:48)
                player.run(.repeatForever(.animate(with:calmFrames,timePerFrame:0.1)),withKey:"pose")
                caption.text="GIVE EACH OTHER SPACE"
            }]))
            for (node,guest,direction) in [(first,visual.guest,1),(second,visual.otherGuest,2)] {
                let walker=RPGActor(id:"separated",tile:visual.target,color:guest?.color ?? 0xD99B7E,variant:guest?.appearanceSeed ?? 100,facing:direction)
                let frames=[sprite(walker,stride:1),sprite(walker,stride:0),sprite(walker,stride:-1)]
                let idle=sprite(walker,stride:0)
                node.run(.sequence([.wait(forDuration:1),.repeat(.animate(with:frames,timePerFrame:0.12),count:4),
                    .setTexture(idle),.wait(forDuration:1),.repeat(.animate(with:frames,timePerFrame:0.12),count:2),.setTexture(idle)]))
            }
            first.run(.sequence([.wait(forDuration:1),.moveBy(x:-14,y:1,duration:1.4),.wait(forDuration:1),.moveBy(x:-8,y:3,duration:0.8)]))
            second.run(.sequence([.wait(forDuration:1),.moveBy(x:14,y:1,duration:1.4),.wait(forDuration:1),.moveBy(x:8,y:3,duration:0.8)]))
            caption.run(.sequence([.wait(forDuration:4.3),.run {caption.text="EVERYONE HAS CALMED DOWN"}]))
        }
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if let index=args.firstIndex(of:"--ui-response-time"),args.indices.contains(index+1),let time=Double(args[index+1]) {
            root.run(.sequence([.wait(forDuration:time),.run {root.isPaused=true}]))
        }
        #endif
        root.run(.sequence([.wait(forDuration:duration),.fadeOut(withDuration:0.15),.run { [weak self] in
            self?.world.childNode(withName:"actor:player")?.alpha=1
        },.removeFromParent()]))
    }

    @MainActor private func showPreviousPoolRescue(_ visual:HotelVisual) {
        world.childNode(withName:"player-response")?.removeFromParent()
        let root=SKNode();root.name="player-response";root.zPosition=30000
        world.addChild(root)
        world.childNode(withName:"actor:player")?.alpha=0
        func point(_ tile:Tile)->CGPoint {CGPoint(x:tile.x*16+8,y:-(tile.y*16+5))}
        func person(_ guest:MotelGuest?,player:Bool=false)->SKSpriteNode {
            let actor=RPGActor(id:"response",tile:visual.origin,color:player ? (visual.outfit ?? 0x6AACA3) : (guest?.color ?? 0xD99B7E),variant:player ? 7 : (guest?.appearanceSeed ?? 100),facing:2)
            let node=SKSpriteNode(texture:sprite(actor,stride:0));node.size=CGSize(width:24,height:28)
            if player {
                let frames=[sprite(actor,stride:1),sprite(actor,stride:0),sprite(actor,stride:-1),sprite(actor,stride:0)]
                node.run(.repeatForever(.animate(with:frames,timePerFrame:0.14)),withKey:"response-limbs")
            }
            root.addChild(node);return node
        }
        func arm(on node:SKNode,x:CGFloat)->SKShapeNode {
            let arm=SKShapeNode(rectOf:CGSize(width:3,height:8),cornerRadius:1.5)
            arm.fillColor=UIColor(red:0.88,green:0.71,blue:0.55,alpha:1);arm.strokeColor = .clear
            arm.position=CGPoint(x:x,y:-2);arm.zPosition=4;node.addChild(arm);return arm
        }
        let player=person(nil,player:true);player.position=point(visual.origin);player.zPosition=4
        let hand=arm(on:player,x:8)
        let caption=SKLabelNode(fontNamed:"AvenirNext-Bold")
        caption.fontSize=5;caption.fontColor=UIColor(red:1,green:0.93,blue:0.74,alpha:1)
        caption.position=CGPoint(x:point(visual.origin).x,y:point(visual.origin).y+26)
        root.addChild(caption)
        let duration=9.0
            caption.text="SWIMMING TO GUEST"
            let victim=person(visual.guest);victim.position=point(visual.target);victim.zPosition=3
            let waterline=SKShapeNode(ellipseOf:CGSize(width:30,height:8))
            waterline.fillColor=UIColor(red:0.38,green:0.76,blue:0.8,alpha:0.75)
            waterline.strokeColor=UIColor(white:0.95,alpha:0.8);waterline.lineWidth=0.7
            waterline.position=CGPoint(x:0,y:-7);waterline.zPosition=6;player.addChild(waterline)
            hand.run(.repeatForever(.sequence([.rotate(toAngle:1.4,duration:0.2),.rotate(toAngle:-1.1,duration:0.2)])),withKey:"swim-stroke")
            let left=arm(on:player,x:-8)
            left.run(.repeatForever(.sequence([.rotate(toAngle:-1.2,duration:0.2),.rotate(toAngle:1.1,duration:0.2)])))
            player.run(.sequence([.rotate(toAngle:-0.65,duration:0.2),.move(to:point(visual.target),duration:1.8),
                .run {caption.text="PULLING GUEST TO SAFETY"},
                .move(to:point(visual.origin),duration:2),.rotate(toAngle:0,duration:0.2),
                .run {waterline.removeFromParent();left.removeFromParent();hand.removeAction(forKey:"swim-stroke");player.removeAction(forKey:"response-limbs");caption.text="HELPING GUEST RECOVER"},
                .repeat(.sequence([.moveBy(x:0,y:-2,duration:0.18),.moveBy(x:0,y:2,duration:0.18)]),count:10),
                .run {caption.text="GUEST IS SAFE"}]))
            let shore=CGPoint(x:point(visual.origin).x+14,y:point(visual.origin).y-5)
            victim.run(.sequence([.wait(forDuration:2),.group([.move(to:shore,duration:2),.rotate(toAngle:0.35,duration:2)]),
                .rotate(toAngle:.pi/2,duration:0.2),.wait(forDuration:3.6),.rotate(toAngle:0,duration:0.3),
                .moveBy(x:10,y:0,duration:0.5)]))
            // Both hands compress together over the rescued guest during the recovery phase.
            let compression=arm(on:player,x:11);compression.isHidden=true
            compression.run(.sequence([.wait(forDuration:4.2),.unhide(),
                .repeat(.sequence([.moveBy(x:2,y:-3,duration:0.18),.moveBy(x:-2,y:3,duration:0.18)]),count:10),.hide()]))
            hand.run(.sequence([.wait(forDuration:4.2),.repeat(.sequence([.moveBy(x:2,y:-3,duration:0.18),.moveBy(x:-2,y:3,duration:0.18)]),count:10)]))
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if let index=args.firstIndex(of:"--ui-response-time"),args.indices.contains(index+1),let time=Double(args[index+1]) {
            root.run(.sequence([.wait(forDuration:time),.run {root.isPaused=true}]))
        }
        #endif
        root.run(.sequence([.wait(forDuration:duration),.fadeOut(withDuration:0.15),.run { [weak self] in
            self?.world.childNode(withName:"actor:player")?.alpha=1
        },.removeFromParent()]))
    }

    @MainActor private func configureLifeProps(_ props:[HavenWorldProp]) {
        let ids=Set(props.map{"life-"+$0.id})
        for child in world.children where child.name?.hasPrefix("life-") == true && !ids.contains(child.name!) {child.removeFromParent()}
        for prop in props {
            let name="life-"+prop.id
            let node:SKNode
            if let existing=world.childNode(withName:name) {node=existing}
            else {
                node=SKNode();node.name=name;node.zPosition=20
                func block(_ rect:CGRect,_ color:UInt32,_ radius:CGFloat=1) {
                    let shape=SKShapeNode(rect:rect,cornerRadius:radius);shape.fillColor=UIColor(Color(hex:color));shape.strokeColor = .clear;node.addChild(shape)
                }
                if prop.kind==90 {
                    if palmFrames.isEmpty {
                        palmFrames=(0..<8).map{frame in
                            let renderer=ImageRenderer(content:NatureMotionArtwork(frame:frame));renderer.scale=2
                            let texture=renderer.uiImage.map{SKTexture(image:$0)} ?? SKTexture();return texture
                        }
                    }
                    let palm=SKSpriteNode(texture:palmFrames[0]);palm.size=CGSize(width:64,height:72);palm.position=CGPoint(x:-8,y:20)
                    node.addChild(palm);node.zPosition=CGFloat(prop.tile.y*16+12)
                    if !UIAccessibility.isReduceMotionEnabled {palm.run(.repeatForever(.animate(with:palmFrames,timePerFrame:0.42)))}
                } else if prop.kind==91 {
                    let glow=SKShapeNode(ellipseOf:CGSize(width:22,height:30));glow.fillColor=UIColor(Color(hex:0xF1C16B)).withAlphaComponent(0.12);glow.strokeColor = .clear;glow.blendMode = .add
                    node.addChild(glow);node.zPosition=CGFloat(prop.tile.y*16+9)
                    if !UIAccessibility.isReduceMotionEnabled {glow.run(.repeatForever(.sequence([.fadeAlpha(to:0.5,duration:0.8),.fadeAlpha(to:1,duration:1.2)])))}
                } else if prop.kind==92 {
                    let leaf=SKShapeNode(ellipseOf:CGSize(width:3,height:1.2));leaf.fillColor=UIColor(Color(hex:0xBFC376));leaf.strokeColor = .clear;leaf.alpha=0;node.addChild(leaf)
                    if !UIAccessibility.isReduceMotionEnabled {leaf.run(.repeatForever(.sequence([.wait(forDuration:Double(prop.tile.x%5)+3),.fadeIn(withDuration:0.5),.group([.moveBy(x:9,y:-14,duration:3),.rotate(byAngle:2,duration:3),.sequence([.wait(forDuration:2),.fadeOut(withDuration:1)])]),.run{[weak leaf] in leaf?.position = .zero}])))}
                } else if prop.kind==93 {
                    for i in 0..<3 {
                        let blade=SKShapeNode();var path=CGMutablePath();path.move(to:.zero);path.addQuadCurve(to:CGPoint(x:Double(i-1)*2,y:4+Double(i%2)),control:CGPoint(x:Double(i-1),y:3))
                        blade.path=path;blade.strokeColor=UIColor(Color(hex:0x7C9B59));blade.lineWidth=0.8;blade.fillColor = .clear;node.addChild(blade)
                        if !UIAccessibility.isReduceMotionEnabled {blade.run(.repeatForever(.sequence([.rotate(toAngle:0.12,duration:1.6+Double(i)*0.2),.rotate(toAngle:-0.08,duration:1.8)])))}
                    }
                } else if prop.kind==41 {
                    block(CGRect(x:-17,y:-6,width:34,height:14),0xF5E7C8,3)
                    block(CGRect(x:-16,y:-5,width:32,height:3),0xD99B7E,1)
                    for x in [-12,12] {
                        block(CGRect(x:CGFloat(x),y:0,width:3,height:5),0x91B7A1,1)
                        let flower=SKShapeNode(circleOfRadius:3);flower.fillColor=UIColor(Color(hex:0xEFC977));flower.strokeColor = .clear
                        flower.position=CGPoint(x:x+1,y:7);node.addChild(flower)
                    }
                    block(CGRect(x:-4,y:1,width:8,height:7),0xE4AB9A,2)
                    block(CGRect(x:-1,y:8,width:1,height:4),0xEFC977,0)
                    for x in [-18,18] {
                        let balloon=SKShapeNode(ellipseOf:CGSize(width:7,height:9));balloon.fillColor=UIColor(Color(hex:x<0 ? 0xD99B7E : 0x91B7A1));balloon.strokeColor = .clear
                        balloon.position=CGPoint(x:x,y:20);node.addChild(balloon)
                        block(CGRect(x:CGFloat(x),y:0,width:0.5,height:16),0xD7CBAA,0)
                    }
                } else if prop.kind==40 {
                    block(CGRect(x:-8,y:-3,width:16,height:7),0x657E73,1)
                    block(CGRect(x:-6,y:3,width:12,height:2),0xD8DDCF,1)
                    let pan=SKShapeNode(ellipseOf:CGSize(width:8,height:4));pan.fillColor=UIColor(Color(hex:0x334F48));pan.strokeColor=UIColor(Color(hex:0xF3DDA5));pan.lineWidth=0.5
                    pan.position=CGPoint(x:0,y:6);node.addChild(pan)
                    block(CGRect(x:4,y:5,width:6,height:1),0x76624F,0)
                } else if prop.kind>=20 {
                    let code=prop.kind>=100 ? prop.kind-100 : prop.kind
                    block(CGRect(x:-7,y:-4,width:14,height:9),0x9B7851,1)
                    block(CGRect(x:-6,y:-3,width:12,height:7),prop.kind>=100 ? 0x624F3A : 0x81664A,1)
                    if code>20 {
                        let crop=(code-21)/4,stage=(code-21)%4
                        for x in [-3,3] {
                            block(CGRect(x:CGFloat(x),y:0,width:1,height:CGFloat(3+stage*2)),0x61844E,0)
                            for side in [-1,1] {
                                let leaf=SKShapeNode(ellipseOf:CGSize(width:CGFloat(3+stage),height:2))
                                leaf.fillColor=UIColor(Color(hex:0x81A260));leaf.strokeColor = .clear
                                leaf.position=CGPoint(x:CGFloat(x+side*2),y:CGFloat(2+stage));leaf.zRotation=CGFloat(side)*0.4
                                node.addChild(leaf)
                            }
                            if stage==3 {
                                let fruit=SKShapeNode(ellipseOf:CGSize(width:crop==2 ? 2 : 3,height:crop==2 ? 5 : 3))
                                fruit.fillColor=UIColor(Color(hex:crop==1 ? 0xD97858 : crop==2 ? 0xE8A45D : crop==3 ? 0xD9B457 : 0x9BB66A));fruit.strokeColor = .clear
                                fruit.position=CGPoint(x:CGFloat(x),y:4);node.addChild(fruit)
                            }
                        }
                    }
                } else if prop.kind>=5 {
                    if prop.kind==6 {
                        for x in [CGFloat(-22),CGFloat(-5)] {
                            block(CGRect(x:x,y:-8,width:15,height:29),0xF5E7C8,2)
                            block(CGRect(x:x+1,y:-7,width:13,height:18),0x91B7A1,1)
                            block(CGRect(x:x+2,y:13,width:11,height:6),0xFFF2D9,2)
                        }
                    } else if prop.kind==7 {
                        block(CGRect(x:-11,y:-4,width:24,height:10),0xA1805D,1)
                        block(CGRect(x:-6,y:3,width:10,height:7),0x3C5151,1)
                        block(CGRect(x:-5,y:4,width:8,height:5),0x82AFC1,1)
                        block(CGRect(x:5,y:-1,width:6,height:4),0xF5E7C8,0)
                    } else {
                        block(CGRect(x:-18,y:-4,width:29,height:8),prop.kind==5 ? 0xD99B7E : 0xEFC977,2)
                        block(CGRect(x:-14,y:3,width:8,height:6),0xF5E7C8,2)
                    }
                } else if prop.kind==0 {
                    let glimmer=SKShapeNode(circleOfRadius:3);glimmer.fillColor=UIColor(Color(hex:0xF3D77A));glimmer.strokeColor = .white
                    glimmer.run(.repeatForever(.sequence([.fadeAlpha(to:0.4,duration:0.8),.fadeAlpha(to:1,duration:0.8)])))
                    node.addChild(glimmer)
                } else if prop.kind==2 {
                    block(CGRect(x:-1,y:0,width:2,height:19),0x8E704A)
                    block(CGRect(x:0,y:15,width:13,height:1),0x455E5D)
                    block(CGRect(x:11,y:1,width:1,height:14),0xD6DCD2)
                    block(CGRect(x:9,y:1,width:4,height:4),0xD97E68,2)
                } else {
                    block(CGRect(x:-10,y:0,width:20,height:5),0x876347)
                    block(CGRect(x:-9,y:-4,width:2,height:5),0x69523E)
                    block(CGRect(x:7,y:-4,width:2,height:5),0x69523E)
                    block(CGRect(x:-11,y:10,width:22,height:4),prop.kind==4 ? 0xD89777 : 0x91B7A1,2)
                    for index in 0..<3 {block(CGRect(x:CGFloat(-8+index*6),y:5,width:4,height:5),prop.kind==3 ? 0xD9B76C : 0xC98D7F,2)}
                }
                world.addChild(node)
            }
            node.position=CGPoint(x:CGFloat(prop.tile.x*16+8),y:-CGFloat(prop.tile.y*16+8))
        }
    }

    @MainActor private func configureCars(_ cars:[HotelCar],day:Int,positions:[Int:Tile]) {
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
                renderer.scale=3
                texture=renderer.uiImage.map { SKTexture(image:$0) } ?? SKTexture()
                texture.filteringMode = .linear
                carTextures[key]=texture
            }
            let node=existing ?? SKSpriteNode(texture:texture)
            node.texture=texture; node.name=name; node.size=CGSize(width:24,height:16)
            let bay=positions[car.id] ?? HotelCar.tile(car.slot)
            let target=CGPoint(x:CGFloat(bay.x*16+8),y:-CGFloat(bay.y*16+8))
            if existing == nil {node.position=target;world.addChild(node)}
            if node.userData == nil {node.userData=NSMutableDictionary()}
            let destination="\(bay.x):\(bay.y)"
            if node.userData?["destination"] as? String != destination {
                node.run(.move(to:target,duration:0.14),withKey:"drive")
                node.userData?["destination"]=destination
            }
            node.zPosition=CGFloat(bay.y*16+20)
        }
    }
    private func configureNightSky(_ visible:Bool) {
        if nightSky.parent == nil {nightSky.zPosition=60000;followCamera.addChild(nightSky)}
        nightSky.isHidden = !visible
        guard visible,let view else{return}
        // Camera children already use screen points. Applying camera zoom here
        // places a HUD sky across the floor instead of at the screen's top edge.
        let viewport=view.bounds.size
        guard skyViewport != viewport || nightSky.children.isEmpty else{return}
        skyViewport=viewport
        let w=viewport.width,h=viewport.height
        nightSky.position=CGPoint(x:0,y:h/2-32)
        if nightSky.children.isEmpty {
            let image=UIGraphicsImageRenderer(size:CGSize(width:2,height:64)).image {renderer in
                let colors=[UIColor(red:0.06,green:0.11,blue:0.20,alpha:0.98).cgColor,UIColor(red:0.06,green:0.11,blue:0.20,alpha:0).cgColor] as CFArray
                if let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,1]) {
                    renderer.cgContext.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:0,y:64),options:[])
                }
            }
            let band=SKSpriteNode(texture:SKTexture(image:image),size:CGSize(width:2000,height:64));nightSky.addChild(band)
            for i in 0..<22 {
                let star=SKShapeNode(circleOfRadius:i%4==0 ? 0.85 : 0.5);star.name="sky-star-\(i)";star.fillColor = .white;star.strokeColor = .clear
                star.position.y=CGFloat(i*11%37)-18;nightSky.addChild(star)
                if !UIAccessibility.isReduceMotionEnabled {star.run(.repeatForever(.sequence([.fadeAlpha(to:0.35,duration:1.6+Double(i%3)),.fadeAlpha(to:0.9,duration:1.8)])))}
            }
            let crescent=CGMutablePath();crescent.addArc(center:.zero,radius:8,startAngle:.pi/2,endAngle:.pi*1.5,clockwise:false)
            crescent.addQuadCurve(to:CGPoint(x:0,y:8),control:CGPoint(x:-5,y:0));crescent.closeSubpath()
            let moon=SKShapeNode(path:crescent);moon.name="moon";moon.fillColor=UIColor(red:1,green:0.94,blue:0.73,alpha:1);moon.strokeColor = .clear;nightSky.addChild(moon)
        }
        for i in 0..<22 {nightSky.childNode(withName:"sky-star-\(i)")?.position.x=(CGFloat(i*43%240)/240-0.5)*w}
        nightSky.childNode(withName:"moon")?.position=CGPoint(x:w/2-22,y:12)
    }
    private func configureAmbient(night:Bool,nightVision:Bool,powerOut:Bool) {
        skyNight=night;configureNightSky(night)
        if ambientLayer.parent == nil {ambientLayer.zPosition=40000;world.addChild(ambientLayer)}
        ambientLayer.color=nightVision ? UIColor(red:0.16,green:0.75,blue:0.25,alpha:1) : .black
        ambientLayer.alpha=Motel.ambientOpacity(night:night,nightVision:nightVision,powerOut:powerOut)
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
        guard let view,let scale=RPGViewport.cameraScale(mapWidth:Double(dimensions.width),mapHeight:Double(dimensions.height),viewportWidth:Double(view.bounds.width),viewportHeight:Double(view.bounds.height),columns:Double(visibleColumns),interior:indoors) else { return }
        let zoom=CGFloat(scale)
        followCamera.setScale(zoom)
        let viewport = CGSize(width: view.bounds.width * zoom, height: view.bounds.height * zoom)
        let cx = indoors ? dimensions.width / 2 : max(viewport.width / 2, min(playerTarget.x, dimensions.width - viewport.width / 2))
        let cy = indoors ? -dimensions.height / 2 : -max(viewport.height / 2, min(-playerTarget.y, max(viewport.height / 2, dimensions.height - viewport.height / 2)))
        let point = CGPoint(x: cx, y: cy)
        guard jump || cameraDestination != point else { return }
        cameraDestination=point
        followCamera.removeAction(forKey:"follow")
        if jump { followCamera.position=point }
        else { followCamera.run(.move(to:point,duration:cameraMoveDuration),withKey:"follow") }
    }
    override func didChangeSize(_ oldSize: CGSize) { layoutCamera(jump: true) }
    override func update(_ currentTime: TimeInterval) {
        if previousTime > 0 { weatherTime += min(0.05,max(0,currentTime-previousTime)) }
        previousTime = currentTime
        updateWeather()
        ambientLayer.position=followCamera.position
        configureNightSky(skyNight)
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
        let revision = room.map { "\($0.theme)-\($0.furniture)-\($0.squatters == true)-\($0.dirty)-\(($0.cleanedTasks ?? []).sorted())-\($0.stolen.sorted())-\(visit?.loot.sorted() ?? [])-\(visit?.sneaking ?? false)-\(motel.guestPresent(in: $0.id))" } ?? "\(motel.officeTheme)-\(motel.officeLevel)-\(motel.rooms.map { "\($0.theme):\($0.dirty):\($0.guest?.id ?? -1)" }.joined(separator: ","))"
        let layoutRevision=(motel.worldState.structureOffsets ?? [:]).keys.sorted().map{key in "\(key):\(motel.creativeOffset(key).x):\(motel.creativeOffset(key).y)"}.joined(separator:",")
        let worldRevision=layoutRevision+"facilities-world-29-\(motel.serviceAvailable(.repair))-" + motel.staffStations.map(\.rawValue).joined(separator:",") + "-\(motel.household.level)-"+revision+"-floor\(motel.viewingFloor)-facilities\(motel.simulation.facilities.count)-"+motel.rooms.map{"\($0.health.kind.rawValue):\($0.health.upgrades.count):\($0.health.faults.count)"}.joined(separator:",")
        var actors = [RPGActor(id: "player", tile: motel.relaxingTile ?? motel.actorTile, color: FamilyHome.outfitColors[motel.household.outfit], variant: 7, facing: motel.isRelaxing ? 0 : motel.actorFacing, resting:motel.isRelaxing,dirty:motel.isPlayerDirty)]
        if !interior {
            actors += motel.neighborhoodActors + motel.neighborActors + motel.routineActors
            let incident = motel.operationsState.incident
            let victim = incident?.guest ?? motel.rooms.compactMap(\.guest).first
            let other = incident?.otherGuest ?? motel.rooms.compactMap(\.guest).dropFirst().first
            actors += motel.waiting.filter{$0.id != motel.reception.visitor?.guest.id}.map {guest in
                let tile=motel.waitingTile(guest.id)
                let previous=motel.worldState.guestPrevious?[guest.id] ?? tile
                return RPGActor(id:"guest-\(guest.id)",tile:tile,color:guest.color,variant:guest.appearanceSeed,
                    facing:tile.x<previous.x ? 1 : tile.x>previous.x ? 2 : tile.y<previous.y ? 3 : 0,
                    duration:incident == nil ? MotelCadence.guestWalk : MotelCadence.travel,
                    expression:incident == nil ? "" : "scared")
            }
            actors += motel.worldState.travellers.map {
                RPGActor(id: "guest-\($0.id)", tile: $0.player, color: $0.color, variant: $0.appearanceSeed, facing: $0.player.y > $0.previous.y ? 0 : $0.player.x < $0.previous.x ? 1 : $0.player.x > $0.previous.x ? 2 : 3, duration: incident == nil ? MotelCadence.guestWalk : MotelCadence.travel,expression:incident == nil ? "" : "scared",routine:"luggage",ambient:$0.player.distance(to:$0.destination)<=1 ? "knock" : "")
            }
            for worker in motel.operationsState.workers where worker.role != .clerk || worker.tile.distance(to:motel.staffHome(worker.role))>1 {
                var workerActor = RPGActor(id:"worker-"+worker.id,tile:worker.tile,color:worker.role.color,variant:200+(StaffRole.allCases.firstIndex(of:worker.role) ?? 0),facing:worker.tile.x < (worker.previous?.x ?? worker.tile.x) ? 1 : worker.tile.x > (worker.previous?.x ?? worker.tile.x) ? 2 : worker.tile.y < (worker.previous?.y ?? worker.tile.y) ? 3 : 0,name:worker.role.name,duration:MotelCadence.travel)
                if let incident {
                    workerActor.expression = worker.role == incident.kind.responder ? (incident.kind == .pool ? "concerned" : "determined") : "scared"
                }
                if worker.progress > 0 && (worker.previous == nil || worker.previous == worker.tile) && !(worker.status?.hasPrefix("NEED") ?? false) {
                    workerActor.action = worker.role == .valet ? "carwash" : (worker.role == .maintenance || worker.role == .repair) ? "repair" : worker.role == .pestControl ? "pest" : worker.role == .security ? "calm" : "mop"
                }
                if incident == nil {workerActor.marker=worker.status ?? "AT POST"}
                if let incident=motel.operationsState.incident,incident.kind.responder == worker.role,
                   worker.tile.distance(to:incident.approach) <= 1 {
                    workerActor.action = incident.kind == .fire ? "extinguish" : incident.kind == .pool ? "rescue" : "calm"
                    workerActor.expression = incident.kind == .pool ? "concerned" : "determined"
                }
                workerActor.celebrating=(motel.haven.employees[worker.role.rawValue]?.level ?? 1)>1
                actors.append(workerActor)
            }
            if motel.managementEnabled {
                for issue in motel.simulation.issues {
                    let special=[HotelIssueKind.adultVisitor,.drugDeal,.cult,.celebrity].contains(issue.kind)
                    if special {
                        actors.append(RPGActor(id:"request-\(issue.id)",tile:motel.worldState.witnessPositions?[issue.id] ?? Tile(x:8+issue.id%3,y:14),color:issue.kind == .cult ? 0x976AB0 : 0xD6BD71,variant:issue.id+220,name:issue.kind == .celebrity ? "VIP" : "Visitor",marker:"!",duration:incident == nil ? MotelCadence.guestWalk : MotelCadence.travel,expression:incident == nil ? "" : "scared"))
                    } else if issue.roomID / 9 == motel.viewingFloor {
                        let effect=issue.kind == .leak ? 4 : issue.kind == .ac || issue.kind == .temperature ? 5 : issue.kind == .bedbugs || issue.kind == .roaches ? 6 : issue.kind == .noise ? 7 : 0
                        if effect>0 {actors.append(RPGActor(id:"issue-\(issue.id)",tile:motel.groundRoomDoor(issue.roomID),color:0xD9AA71,variant:0,name:issue.kind.title,effect:effect))}
                    }
                }
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
            actors.append(RPGActor(id: "guest-\(guest.id)", tile: visit.guestTile, color: guest.color, variant: guest.appearanceSeed, danger: true,ambient:motel.isNight ? "sleep" : ""))
        }
        if interior,let room,room.squatters == true {
            for i in 0..<2 {
                var resident=RPGActor(id:"squatter-\(room.id)-\(i)",tile:Tile(x:3+i*2,y:4),color:i==0 ? 0x827661 : 0x6C7565,variant:330+room.id*2+i,facing:i==0 ? 2 : 1)
                resident.wornClothes=true;actors.append(resident)
            }
        }
        for index in actors.indices where actors[index].id.hasPrefix("guest-") || actors[index].id.hasPrefix("routine-") {
            actors[index].beachwear=motel.guestUsesBeachwear(at:actors[index].tile)
        }
        actors += motel.petActors + motel.policeActors
        if let index=actors.firstIndex(where:{$0.id == "player"}) {
            actors[index].cycling=motel.isRidingBike
            actors[index].bikeColor=motel.bicycleColor
            if motel.isRidingBike {actors[index].duration=0.09}
        }
        return RPGSceneView(mapID: mapID, revision: worldRevision, mapSize: CGSize(width: interior ? 144 : MotelGrounds.width*16, height: interior ? 144 : MotelGrounds.height*16), columns: 14, interior: interior, actors: actors, working: workProgress > 0,
                            workKind:motel.cleaningTarget == 0 ? "bed" : motel.cleaningTarget == 1 ? "trash" : "mop",
                            visual:motel.operationsState.visual,weather:motel.weather,cars:motel.parkedBikes,bikePositions:motel.bikeParking,day:motel.day,
                            night:motel.isNight,nightVision:motel.simulation.nightVision,powerOut:motel.simulation.powerOut || (room?.health.faults.contains(.light) ?? false),pumpFault:!interior && motel.serviceAvailable(.repair),poolOffset:motel.creativeOffset("pool"),pumpPosition:motel.groundTile(Tile(x:10,y:21)),lifeProps:motel.havenWorldProps+motel.expansionWorldProps+motel.gardenWorldProps+motel.celebrationWorldProps+motel.natureMotionProps) {
            if let visit, let room { return AnyView(MotelRoomCanvas(room: room, visit: visit, x: 0, y: 0, guestPresent: motel.guestPresent(in: room.id), sceneryOnly: true)) }
            if motel.worldState.place == .office { return AnyView(MotelOfficeCanvas(sceneryOnly: true, motel: motel, x: 0, y: 0)) }
            return AnyView(MotelGroundsCanvas(motel: motel, x: 0, y: 0, npcTick: 0, sceneryOnly: true, fullMap: true))
        }
    }
}



extension Motel {
    var natureMotionProps:[HavenWorldProp] {
        if worldState.place == .basement {
            return BasementLayout.residents.map{id in let p=BasementLayout.pen(id);return HavenWorldProp(id:"lantern-glow-\(id)",tile:Tile(x:p.x+(id%2==0 ? 7 : 0),y:p.y+2),kind:91)}
        }
        guard worldState.place == .grounds,visit==nil else{return []}
        var props=BeachLayout.palms.enumerated().map{id,tile in
            let d=creativeOffset("palm-\(id)")
            return HavenWorldProp(id:"living-palm-\(id)",tile:Tile(x:tile.x+d.x,y:tile.y+d.y),kind:90)
        }
        for id in ResidentialLayout.origins.indices {
            let t=ResidentialLayout.origins[id]
            props.append(HavenWorldProp(id:"falling-leaf-\(id)",tile:Tile(x:t.x-1,y:t.y+1),kind:92))
            props.append(HavenWorldProp(id:"swaying-grass-\(id)",tile:Tile(x:t.x-2,y:t.y+4),kind:93))
        }
        return props
    }
    var routineActors:[RPGActor] {
        guard havenExpansion != nil,worldState.place == .grounds,visit==nil else{return []}
        return rooms.compactMap {room in
            guard let guest=room.guest,let r=expansion.routines[guest.id],!worldState.travellers.contains(where:{$0.id==guest.id}) else{return nil}
            let happy=expansion.satisfaction[guest.id,default:50]
            return RPGActor(id:"routine-\(guest.id)",tile:r.tile,color:guest.color,variant:guest.appearanceSeed,
                facing:r.tile.x<r.previous.x ? 1 : r.tile.x>r.previous.x ? 2 : r.tile.y<r.previous.y ? 3 : 0,
                duration:MotelCadence.guestWalk,expression:operationsState.incident == nil ? happy>=70 ? "cheerful" : happy<35 ? "angry" : "calm" : "scared",
                routine:r.tile==routineDestination(guest,room:room) ? r.activity.rawValue : "luggage")
        }
    }
    var expansionWorldProps:[HavenWorldProp] {
        guard havenExpansion != nil else{return []}
        if let visit,let room=rooms.first(where:{$0.id==visit.roomID}),roomDesign(room) != .classic {
            let kind=roomDesign(room) == .cozy ? 5 : roomDesign(room) == .family ? 6 : 7
            return [.init(id:"room-design-\(room.id)-\(kind)",tile:kind==7 ? Tile(x:6,y:6) : Tile(x:3,y:3),kind:kind)]
        }
        if visit==nil,worldState.place == .office {
            return Self.discoveries.filter{$0.group=="furniture" && expansion.discoveries.contains($0.id)}.enumerated().map {i,item in
                HavenWorldProp(id:"display-"+item.id,tile:Tile(x:2+i%2,y:11+i/2),kind:8)
            }
        }
        guard visit==nil,worldState.place == .grounds else{return []}
        var props=[HavenWorldProp]()
        if breakfastOpen && expansion.buffet>0 {props.append(.init(id:"fresh-buffet",tile:groundTile(HotelService.breakfast.tile),kind:3))}
        for item in Self.discoveries where !expansion.discoveries.contains(item.id) && item.group=="shell" {
            if item.id != "shell-moon" || simulation.hour>=19 {props.append(.init(id:item.id,tile:expansionWalkable(to:groundTile(item.tile)),kind:0))}
        }

        return props
    }
}


extension Motel {
    var gardenWorldProps:[HavenWorldProp] {
        guard visit==nil,worldState.place == .grounds else{return []}
        var props=Self.gardenPlots.indices.map {id -> HavenWorldProp in
            let plot=kitchenPlot(id)
            let code:Int
            if let crop=plot.crop {
                let stage=plotReady(id) ? 3 : min(2,plot.growth)
                code=21+(GardenCrop.allCases.firstIndex(of:crop) ?? 0)*4+stage+(plotWatered(id) ? 100 : 0)
            } else {code=20}
            return .init(id:"garden-plot-\(id)-\(code)",tile:gardenTile(id),kind:code)
        }
        props.append(.init(id:"garden-kitchen-hob",tile:groundTile(Tile(x:3,y:26)),kind:40))
        return props
    }
}

extension Motel {
    var celebrationWorldProps:[HavenWorldProp] {
        guard visit==nil,worldState.place == .office,let event=occasions.celebration,event.day==day,event.decorated else{return []}
        return [.init(id:"celebration-table-\(day)",tile:Tile(x:6,y:10),kind:41)]
    }
}
