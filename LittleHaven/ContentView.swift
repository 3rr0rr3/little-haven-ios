import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}

struct ContentView: View {
    @State private var game = ContentView.initialGame()
    @State private var playing = ContentView.bypassTitle
    @State private var sessionID = UUID()
    @AppStorage("littlehaven.hints") private var showHints = true
    private static var bypassTitle: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--ui-") }) && !ProcessInfo.processInfo.arguments.contains("--ui-title")
        #else
        return false
        #endif
    }
    @State private var conversation: Neighbor?
    @State private var message: String?
    @State private var showHouse = false
    @State private var showJournal = false
    @State private var reset = false
    @State private var heldDirection: Tile?
    @Environment(\.scenePhase) private var scenePhase
    private let stepDuration = 0.16
    private let cream = Color(hex: 0xF5E7C8)
    private let gold = Color(hex: 0xEFC977)

    private static func initialGame() -> Game {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains(where:{$0.hasPrefix("--ui-management")}) {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement()
            sample.motel!.cash=6000
            var sim=sample.motel!.simulation;sim.reputation=75;sample.motel!.simulation=sim
            _=sample.motel!.checkIn(guestID:10,roomID:0)
            sample.motel!.rooms[1].dirty=true
            var health=sample.motel!.rooms[1].health;health.cleanliness=35;health.faults=[.pipe];sample.motel!.rooms[1].hospitality=health
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:11,y:14)
            sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-management-night") || args.contains("--ui-management-cameras") {
                var state=sample.motel!.simulation;state.hour=22;state.absoluteHour=22;state.facilities=[.cameras,.nightVision,.adjacentLot,.upperFloor];state.nightVision=args.contains("--ui-management-cameras");sample.motel!.simulation=state
                sample.motel!.injectIssue(.leak,roomID:0)
            }
            if args.contains("--ui-management-events") {
                sample.motel!.injectIssue(.outage,roomID:0);sample.motel!.injectIssue(.bedbugs,roomID:1)
                var state=sample.motel!.simulation;state.powerOut=true;sample.motel!.simulation=state
            }
            sample.save();return sample
        }
        if args.contains(where: { $0.hasPrefix("--ui-parking") || $0.hasPrefix("--ui-weather") || $0.hasPrefix("--ui-action") }) {
            var sample=Game()
            sample.coins=545; sample.wakeUp(); sample.motel!.initializeWorld()
            sample.motel!.cash=900
            sample.motel!.world!.place = .grounds
            sample.motel!.world!.player = Tile(x:18,y:32)
            for _ in 0..<8 { sample.motel!.tickManagement() }
            sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-parking-staff") {
                _ = sample.motel!.hire(.valet)
                sample.motel!.operations!.workers[0].tile=HotelCar.approach(0)
                sample.motel!.operations!.workers[0].progress=3
            }
            for weather in HotelWeather.allCases where args.contains("--ui-weather-"+weather.rawValue) {
                sample.motel!.operations!.weatherOverride=weather
                sample.motel!.world!.player=Tile(x:9,y:23)
            }
            if args.contains("--ui-action-theft") {
                _ = sample.motel!.checkIn(guestID:10,roomID:0)
                _ = sample.motel!.enter(0); sample.motel!.visit!.player=Tile(x:3,y:3)
                _ = sample.motel!.steal()
            }
            if args.contains("--ui-action-wash") { _ = sample.motel!.washNearbyCar() }
            sample.save(); return sample
        }
        if args.contains("--ui-police") || args.contains("--ui-hiring") || args.contains("--ui-operations") || args.contains("--ui-chaos-fire") || args.contains("--ui-chaos-pool") || args.contains("--ui-chaos-fight") || args.contains("--ui-dialogue") {
            var sample = Game()
            sample.coins = 545; sample.wakeUp(); sample.motel!.initializeWorld()
            sample.motel!.waiting = []; sample.motel!.cash = 900
            sample.motel!.operations = MotelOperations()
            if args.contains("--ui-operations") {
                sample.motel!.operations!.reviews = [GuestReview(id:"good",guest:"Robin",day:2,room:101,stars:5,text:"Lovely room and a peaceful stay!"),GuestReview(id:"bad",guest:"Sasha",day:2,room:102,stars:1,text:"The trouble outside spoiled my stay.")]
            }
            let kind: ChaosKind? = args.contains("--ui-chaos-fire") ? .fire : args.contains("--ui-chaos-pool") ? .pool : args.contains("--ui-chaos-fight") ? .fight : nil
            if let kind {
                sample.motel!.world!.place = .grounds
                sample.motel!.world!.player = kind.approach
                sample.motel!.operations!.incident = MotelIncident(kind:kind)
            }
            if args.contains("--ui-police") {
                _ = sample.motel!.checkIn(guestID:10,roomID:0)
                sample.motel!.rooms[0].guest = Motel.arrivals(day:1,count:1)[0]
                sample.motel!.operations!.incident = MotelIncident(kind:.pool,elapsed:89)
                sample.motel!.tickManagement()
                sample.motel!.operations!.consequences!.police!.tile = Tile(x:6,y:10)
                sample.motel!.operations!.consequences!.police!.arrived = true
                sample.motel!.operations!.consequences!.police!.acceptsBribe = false
            }
            sample.save()
            return sample
        }
        if args.contains("--ui-office-preview") || args.contains("--ui-office-family") {
            var sample = Game()
            sample.coins = 545
            sample.wakeUp()
            sample.motel!.initializeWorld()
            if args.contains("--ui-office-family") { sample.motel!.waiting = [] }
            sample.save()
            return sample
        }
        if args.contains("--ui-fresh") {
            UserDefaults.standard.removeObject(forKey: "littlehaven.save.v1")
            return Game()
        }
        if args.contains(where: { $0.hasPrefix("--ui-world") || $0.hasPrefix("--ui-motel") || $0 == "--ui-wake" }) {
            var fresh = Game()
            fresh.coins = 545
            if !args.contains("--ui-wake") {
                fresh.wakeUp()
                fresh.motel!.initializeWorld()
                if args.contains("--ui-motel") {
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 12, y: 10)
                }
                if args.contains("--ui-world-clean") || args.contains("--ui-world-decor") {
                    fresh.motel!.world!.hasCleaningKit = true
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 16, y: 9)
                    fresh.motel!.rooms[0].dirty = args.contains("--ui-world-clean")
                    fresh.save()
                    _ = fresh.motel!.enter(0)
                    fresh.motel!.visit!.player = args.contains("--ui-world-clean") ? Tile(x: 3, y: 3) : Tile(x: 6, y: 2)
                    return fresh
                }
                if args.contains("--ui-world-build") {
                    fresh.motel!.cash = 600
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 12, y: 27)
                }
                if args.contains("--ui-motel-risk") || args.contains("--ui-motel-preview") {
                    _ = fresh.motel!.checkIn(guestID: 10, roomID: 0)
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 16, y: 9)
                    fresh.save()
                    _ = fresh.motel!.enter(0)
                    fresh.motel!.visit!.alert = args.contains("--ui-motel-risk") ? 98 : 10
                    return fresh
                }
            }
            fresh.save()
            return fresh
        }
        #endif
        return Game.load()
    }
    var body: some View {
        Group {
            if playing { gameplay.id(sessionID) }
            else {
                MotelTitleScreen(hasSave: UserDefaults.standard.data(forKey:"littlehaven.save.v1") != nil, start: {
                    game = Game.load(); sessionID = UUID(); playing = true
                }, newGame: {
                    heldDirection = nil; conversation = nil; message = nil; showHouse = false; showJournal = false
                    game = Game(); game.save(); sessionID = UUID(); playing = true
                })
            }
        }.environment(\.returnToTitle, {
            heldDirection = nil; game.save(); playing = false
        }).onChange(of:scenePhase) { _, phase in if phase != .active { heldDirection = nil } }
    }
    private var gameplay: some View {
        Group {
            if game.motel != nil {
                MotelView(game: $game)
            } else if game.readyToWake {
                WakeUpView {
                    conversation = nil
                    heldDirection = nil
                    game.wakeUp()
                    game.save()
                }
            } else {
                townBody
            }
        }
    }

    private var townBody: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LITTLE HAVEN").font(.system(size: 22, weight: .black, design: .rounded)).tracking(2)
                        Text(game.inside ? "YOUR COTTAGE / HOME AT LAST" : "WILLOW TOWN / A NEW BEGINNING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                            .foregroundStyle(cream.opacity(0.6))
                    }
                    Spacer(minLength: 4)
                    Button { stopMoving(); showJournal = true } label: { Image(systemName: "book.closed.fill").frame(width: 44, height: 44).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)) }
                        .accessibilityLabel("Open journal")
                }
                HStack {
                    Label("\(game.coins)", systemImage: "circle.circle.fill").font(.system(size: 21, weight: .heavy, design: .monospaced)).foregroundStyle(gold)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(game.ownsHouse ? "A PLACE TO CALL YOURS" : "COTTAGE FUND  \(game.coins) / 500")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                        ProgressView(value: game.ownsHouse ? 1 : min(Double(game.coins) / 500, 1)).tint(gold).frame(width: 160)
                    }
                }.padding(14).background(Color(hex: 0x283D36), in: RoundedRectangle(cornerRadius: 16))

                ZStack(alignment: .topLeading) {
                    TownRPGView(game: game)
                        .animation(.linear(duration: stepDuration), value: game.player)
                        .id(game.inside)
                    Text(game.inside ? "HOME, SWEET HOME" : "WILLOW TOWN")
                        .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1.5)
                        .padding(9).background(Color(hex: 0x203A30).opacity(0.9), in: Capsule()).padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(cream.opacity(0.15), lineWidth: 2))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("townMap")
                .accessibilityLabel(game.inside ? "Inside your cottage" : "Town map. Your position: column \(game.player.x), row \(game.player.y)")
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    Circle().fill(gold).frame(width: 5, height: 5)
                    Text(showHints ? hint : "").font(.system(size: 11, weight: .medium)).lineLimit(2)
                    Spacer(minLength: 0)
                }.frame(height: 28)

                HStack(alignment: .center) {
                    VStack(spacing: 3) {
                        direction("chevron.up", dx: 0, dy: -1, label: "Walk north")
                        HStack(spacing: 3) {
                            direction("chevron.left", dx: -1, dy: 0, label: "Walk west")
                            Image(systemName: "sparkle").foregroundStyle(cream.opacity(0.3)).frame(width: 40, height: 40)
                            direction("chevron.right", dx: 1, dy: 0, label: "Walk east")
                        }
                        direction("chevron.down", dx: 0, dy: 1, label: "Walk south")
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        Button(action: interact) {
                            VStack(spacing: 4) {
                                Image(systemName: game.atHouse ? "key.fill" : "bubble.left.fill").font(.system(size: 23))
                                Text(game.atHouse ? (game.ownsHouse ? "ENTER" : "COTTAGE") : "TALK").font(.system(size: 10, weight: .black, design: .monospaced))
                            }.frame(width: 94, height: 82).foregroundStyle(Color(hex: 0x243A30))
                                .background(gold, in: RoundedRectangle(cornerRadius: 26))
                        }.accessibilityIdentifier("interact")
                        Text("MEET YOUR NEIGHBORS").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(cream.opacity(0.5))
                    }
                }.frame(height: geometry.size.height < 700 ? 130 : 148).padding(.horizontal, 22)
            }.padding(.horizontal, 18).padding(.vertical, 10)
            .foregroundStyle(cream).background(Color(hex: 0x172A25))
        }
        .task(id: heldDirection) {
            guard let direction = heldDirection else { return }
            while !Task.isCancelled && scenePhase == .active {
                guard conversation == nil, message == nil, !showHouse, !showJournal else { break }
                let wasInside = game.inside
                game.move(dx: direction.x, dy: direction.y)
                if wasInside != game.inside { stopMoving(); break }
                do { try await Task.sleep(for: .seconds(stepDuration)) }
                catch { break }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopMoving() }
        }
        .onDisappear { stopMoving() }
        .sheet(item: $conversation) { person in
            dialogue(person)
                .presentationDetents([.height(340)]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showJournal) { journal }
        .alert("The Willow Cottage", isPresented: $showHouse) {
            if game.ownsHouse {
                Button("Go inside") { game.enterHouse(); game.save() }
            } else if game.coins >= Game.housePrice {
                Button("Buy for 500 coins") {
                    if game.buyHouse() { game.save(); message = "The key is yours! Your neighbors helped you find a home. Walk up to the cottage and tap ENTER to step inside." }
                }
            }
            Button("Keep exploring", role: .cancel) { }
        } message: {
            Text(game.ownsHouse ? "Your own little corner of Little Haven. Welcome home." : game.coins >= 500 ? "A sunny room, a warm bed, and a fresh start. Ready to make it yours?" : "FOR SALE / 500 coins\nYou need \(500 - game.coins) more. Ask the townspeople if they can help with your cottage fund.")
        }
        .alert("Little Haven", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Continue") { message = nil }
        } message: { Text(message ?? "") }
    }

    private var hint: String {
        if game.inside { return "You made it home. Walk down through the door to go outside." }
        if let person = game.nearby { return "\(person.name), the \(person.role.lowercased()) / Tap TALK" }
        if game.atHouse { return game.ownsHouse ? "Your cottage / Tap ENTER" : "Cottage for sale / Tap COTTAGE" }
        return game.coins >= 500 && !game.ownsHouse ? "Your fund is ready! Find the cottage in the northeast." : "Hold an arrow to walk. Stand beside a neighbor to TALK."
    }
    private func direction(_ symbol: String, dx: Int, dy: Int, label: String) -> some View {
        HoldDirection(symbol: symbol, label: label, isActive: heldDirection == Tile(x: dx, y: dy)) { pressed in
            let direction = Tile(x: dx, y: dy)
            if pressed {
                guard scenePhase == .active, conversation == nil, message == nil, !showHouse, !showJournal else { return }
                heldDirection = direction
            } else if heldDirection == direction {
                stopMoving()
            }
        } singleStep: {
            stopMoving()
            game.move(dx: dx, dy: dy)
            game.save()
        }
    }
    private func stopMoving() {
        heldDirection = nil
        game.save()
    }
    private func interact() {
        stopMoving()
        if let person = game.nearby { conversation = person }
        else if game.atHouse { showHouse = true }
        else { message = game.inside ? "A little bed, a well-loved rug, and room for new memories. This is your home now." : "Move right next to a neighbor to talk. Look for the people with a gold dot above their heads. The cottage is in the northeast." }
    }
    private func dialogue(_ person: Neighbor) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PaperPortrait(color: person.color, variant: person.id).frame(width: 54, height: 62)
                VStack(alignment: .leading) {
                    Text(person.name).font(.title2.bold())
                    Text(person.role.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(gold)
                }
                Spacer()
                Button("Close") { conversation = nil }.tint(cream)
            }
            Text(game.gifts.contains(person.id) ? person.reply : person.greeting).font(.system(size: 17)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !game.gifts.contains(person.id) {
                Button {
                    _ = game.ask(person.id)
                    game.save()
                } label: { Text("Could you help me buy a house?").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(15) }
                    .foregroundStyle(Color(hex: 0x172A25)).background(gold, in: RoundedRectangle(cornerRadius: 14))
            } else {
                Label("\(person.gift) coins contributed / Thank you!", systemImage: "heart.fill").font(.subheadline.bold()).foregroundStyle(gold)
            }
        }.padding(24).foregroundStyle(cream).presentationBackground(Color(hex: 0x263D33))
    }
    private var journal: some View {
        NavigationStack {
            List {
                Section("A place to call home") {
                    Text(game.ownsHouse ? "You bought the Willow Cottage! Visit your home whenever you like." : "Raise 500 coins by asking the seven neighbors for help. Each can contribute once. Then a new chapter begins.")
                    Text("Press and hold a direction to keep walking. Release to stop. Stand one tile beside a person and tap TALK. Buildings, trees, and the pond block your way.")
                }
                Section("Your neighbors / \(game.gifts.count)/7") {
                    ForEach(Town.neighbors) { person in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(person.name + " / " + person.role).font(.headline)
                                Text("Column \(person.tile.x), row \(person.tile.y)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(game.gifts.contains(person.id) ? "+\(person.gift) OK" : "Say hello").foregroundStyle(gold).font(.caption.bold())
                        }
                    }
                }
                Section {
                    Text("Progress saves automatically on this device. All coins are fictional game currency.").font(.footnote)
                    Button("Save & return to title") { stopMoving(); showJournal = false; playing = false }
                    Button("Start a new adventure", role: .destructive) { reset = true }
                }
            }.navigationTitle("Your journal").toolbar { Button("Done") { showJournal = false } }
                .confirmationDialog("Erase your saved adventure?", isPresented: $reset, titleVisibility: .visible) {
                    Button("Start over", role: .destructive) { game = Game(); game.save(); showJournal = false }
                }
        }.tint(gold)
    }
}

struct HoldDirection: View {
    @AppStorage("littlehaven.largeControls") private var largeControls = false
    let symbol: String
    let label: String
    let isActive: Bool
    let changed: (Bool) -> Void
    let singleStep: () -> Void
    @GestureState private var pressed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .black))
            .frame(width: largeControls ? 50 : 44, height: largeControls ? 46 : 40)
            .background(Color(hex: isActive ? 0x65866B : 0x344B40), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($pressed) { value, state, _ in
                    state = CGRect(x: 0, y: 0, width: largeControls ? 50 : 44, height: largeControls ? 46 : 40).contains(value.location)
                }.onEnded { _ in changed(false) })
            .onChange(of: pressed) { _, value in changed(value) }
            .onDisappear { changed(false) }
            .accessibilityLabel(label)
            .accessibilityHint("Hold to keep walking; activate to take one step.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { singleStep() }
    }
}


private struct TitleReturnKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
extension EnvironmentValues {
    var returnToTitle: () -> Void {
        get { self[TitleReturnKey.self] }
        set { self[TitleReturnKey.self] = newValue }
    }
}

struct GameOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("littlehaven.hints") private var hints = true
    @AppStorage("littlehaven.haptics") private var haptics = true
    @AppStorage("littlehaven.largeControls") private var largeControls = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Gameplay") {
                    Toggle("Show gameplay hints", isOn: $hints).accessibilityIdentifier("optionHints")
                    Toggle("Action haptics", isOn: $haptics)
                    Toggle("Larger D-pad buttons", isOn: $largeControls).accessibilityIdentifier("optionLargeControls")
                }
                Section("Controls") {
                    Text("Hold an arrow to walk. Release or slide off the button to stop. Nearby tasks never move your character; press their action button when you want to work.")
                    Text("Inside the office, walk freely and tap guests, the desk, tools, family, or the door to interact.")
                }
                Section("Saved game") {
                    Text("Continue loads your last checkpoint. New Game starts from zero after confirmation. Save at the office before leaving. Quit closes the game session; use the Home gesture to leave the app.")
                    Button("Restore default options") { hints = true; haptics = true; largeControls = false }
                }
            }.navigationTitle("Options")
                .toolbar { Button("Done") { dismiss() } }
        }.tint(Color(hex:0xEFC977))
    }
}

struct MotelTitleScreen: View {
    let hasSave: Bool
    let start: () -> Void
    let newGame: () -> Void
    @State private var options = false
    @State private var confirmNew = false
    @State private var confirmQuit = false
    @State private var closed = false
    private let cream = Color(hex:0xF5E7C8)
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MotelTitleLandscape().ignoresSafeArea()
                Color.black.opacity(0.13).ignoresSafeArea()
                if closed {
                    VStack(spacing:24) {
                        Image(systemName:"moon.stars.fill").font(.system(size:48))
                        Text("See you soon").font(.largeTitle.bold())
                        Text("Your game session is closed.\nUse the Home gesture to leave the app.").multilineTextAlignment(.center)
                        menuButton("RETURN TO TITLE", tint:0x344B40, id:"returnTitle") { closed = false }
                    }.padding(30).frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(hex:0x172A25).opacity(0.97))
                } else {
                    VStack(spacing:12) {
                        VStack(spacing:0) {
                            Text("MOTEL").font(.system(size:min(60,proxy.size.width*0.15),weight:.black,design:.rounded)).tracking(3)
                                .foregroundStyle(Color(hex:0xFFB4A4)).shadow(color:.red,radius:8)
                            Text("SIMULATOR").font(.system(size:min(36,proxy.size.width*0.082),weight:.heavy,design:.rounded)).tracking(2)
                                .foregroundStyle(Color(hex:0xB8F2EE)).shadow(color:.cyan,radius:8)
                            Text("A GAME OF HOSPITALITY").font(.system(size:11,weight:.bold,design:.monospaced)).tracking(1).padding(.top,8)
                        }.padding(20).background(Color(hex:0x193D43).opacity(0.96),in:RoundedRectangle(cornerRadius:20))
                            .overlay(RoundedRectangle(cornerRadius:20).stroke(Color(hex:0xA5E1DE),lineWidth:3)).padding(.top,12)
                        Spacer(minLength:20)
                        VStack(spacing:12) {
                            menuButton(hasSave ? "CONTINUE GAME" : "START GAME",tint:0x264E42,id:"startGame",action:start)
                            menuButton("NEW GAME",tint:0x45594A,id:"newGame") { confirmNew = true }
                            HStack(spacing:12) {
                                menuButton("OPTIONS",tint:0x4B495E,id:"titleOptions") { options = true }
                                menuButton("QUIT",tint:0x653C35,id:"titleQuit") { confirmQuit = true }
                            }
                        }.frame(maxWidth:460)
                        Text("LITTLE HAVEN / YOUR NEXT SHIFT AWAITS").font(.system(size:9,weight:.bold,design:.monospaced)).shadow(color:.black,radius:3)
                    }.padding(24)
                }
            }.foregroundStyle(cream)
        }.accessibilityIdentifier("titleScreen")
            .sheet(isPresented:$options) { GameOptionsView() }
            .confirmationDialog("Start again from zero?",isPresented:$confirmNew,titleVisibility:.visible) {
                Button("Erase checkpoint and start new game",role:.destructive,action:newGame)
                Button("Cancel",role:.cancel) {}
            } message: { Text("Your current saved adventure will be replaced. Your options will be kept.") }
            .confirmationDialog("Close this game session?",isPresented:$confirmQuit,titleVisibility:.visible) {
                Button("Quit session") { closed = true }
                Button("Cancel",role:.cancel) {}
            }
    }
    private func menuButton(_ title:String,tint:UInt32,id:String,action:@escaping ()->Void)->some View {
        Button(action:action) {
            Text(title).font(.system(size:16,weight:.black,design:.monospaced))
                .frame(maxWidth:.infinity,minHeight:50)
                .background(Color(hex:tint),in:RoundedRectangle(cornerRadius:5))
                .overlay(RoundedRectangle(cornerRadius:5).stroke(Color(hex:0xC6DDC8),lineWidth:2))
                .shadow(color:.black.opacity(0.45),radius:0,x:0,y:4)
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

/// Code-drawn courtyard, inspired by the supplied title-screen reference.
struct MotelTitleLandscape: View {
    var body: some View {
        Canvas { context,size in
            let w=size.width,h=size.height
            context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(Color(hex:0x91B86D)))
            for y in 0..<22 { for x in 0..<12 where (x+y)%2 == 0 {
                context.fill(Path(CGRect(x:CGFloat(x)*w/12,y:CGFloat(y)*h/22,width:w/12,height:h/22)),with:.color(Color(hex:0x82AA60).opacity(0.45)))
            }}
            var courtyard=Path()
            courtyard.move(to:CGPoint(x:w*0.12,y:h*0.32));courtyard.addLine(to:CGPoint(x:w*0.88,y:h*0.32))
            courtyard.addLine(to:CGPoint(x:w*1.1,y:h));courtyard.addLine(to:CGPoint(x:-w*0.1,y:h));courtyard.closeSubpath()
            context.fill(courtyard,with:.color(Color(hex:0xC9C49A)))
            let colors:[UInt32]=[0x91B8A8,0xDBA083,0x89B3A3,0xAD96C0,0x91B8A8,0xB19BC7]
            for i in 0..<6 {
                let bw=w*0.23,bh=h*0.105,x=w*(0.09+Double(i%3)*0.30),y=h*(i<3 ? 0.37:0.57)
                let r=CGRect(x:x,y:y,width:bw,height:bh)
                context.fill(Path(r),with:.color(Color(hex:colors[i])))
                context.fill(Path(CGRect(x:x-3,y:y-7,width:bw+6,height:bh*0.25)),with:.color(Color(hex:colors[i]).opacity(0.9)))
                for line in 0..<3 {
                    context.fill(Path(CGRect(x:x-3,y:y-7+CGFloat(line)*bh*0.08,width:bw+6,height:2)),with:.color(Color(hex:0x496957).opacity(0.6)))
                }
                context.fill(Path(CGRect(x:x+bw*0.37,y:y+bh*0.45,width:bw*0.24,height:bh*0.55)),with:.color(Color(hex:0x515649)))
                context.fill(Path(CGRect(x:x+bw*0.7,y:y+bh*0.43,width:bw*0.21,height:bh*0.26)),with:.color(Color(hex:0xB4D5CA)))
                context.fill(Path(CGRect(x:x+bw*0.08,y:y+bh*0.24,width:bw*0.84,height:bh*0.14)),with:.color(Color(hex:0x385549)))
                context.draw(Text("\(101+i) / GUEST").font(.system(size:7,weight:.bold,design:.monospaced)).foregroundColor(Color(hex:0xF5E7C8)),at:CGPoint(x:x+bw/2,y:y+bh*0.31))
                context.fill(Path(CGRect(x:x+bw*0.24,y:y+bh*1.22,width:bw*0.5,height:bh*0.12)),with:.color(Color(hex:0x9B7958)))
                for flower in 0..<5 {
                    context.fill(Path(ellipseIn:CGRect(x:x+bw*0.25+CGFloat(flower)*bw*0.09,y:y+bh*1.15,width:bw*0.07,height:bh*0.12)),with:.color(Color(hex:flower%2 == 0 ? 0xEAB7B4:0xEDD189)))
                }
            }
            for i in 0..<10 {
                let x=i%2 == 0 ? w*0.035:w*0.92,y=h*(0.12+Double(i/2)*0.16)
                context.fill(Path(CGRect(x:x+w*0.015,y:y+h*0.03,width:w*0.02,height:h*0.03)),with:.color(Color(hex:0x8F7950)))
                context.fill(Path(ellipseIn:CGRect(x:x-w*0.015,y:y,width:w*0.085,height:h*0.055)),with:.color(Color(hex:i%3 == 0 ? 0x527C48:0x628D4E)))
            }
        }.accessibilityHidden(true)
    }
}
