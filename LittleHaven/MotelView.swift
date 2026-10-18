import SwiftUI

struct WakeUpView: View {
    let begin: () -> Void
    @State private var awake = false
    var body: some View {
        ScrollView {
        VStack(spacing: 22) {
            Text(awake ? "7:00 AM / A NEW CHAPTER" : "THE DREAM FADES")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(3).foregroundStyle(Color(hex: 0xEFC977))
            ZStack {
                RoundedRectangle(cornerRadius: 32).fill(Color(hex: 0x435B52))
                VStack(spacing: 0) {
                    Text(awake ? "RING... RING..." : "Z z z").font(.caption.monospaced()).foregroundStyle(.white.opacity(0.6))
                    PaperPortrait(color: 0x6AACA3, variant: 7).frame(width: 95, height: 100).offset(y: awake ? 0 : 10)
                    RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0xB8C5A0)).frame(width: 140, height: 70)
                }
            }.frame(height: 245)
            Text("You wake up.\nThe keys were real.").font(.system(size: 31, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
            Text("The town, the coins, the little house... a dream.\nOn your desk: three room keys and the deed to a tired roadside Airb&b.\n\nYour first guests are already outside.")
                .font(.body).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button("Start my first shift", action: begin).buttonStyle(MotelButtonStyle()).accessibilityIdentifier("wakeUp")
        }.padding(28)
        }.foregroundStyle(Color(hex: 0xF5E7C8)).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: 0x172A25))
            .task { withAnimation(.easeInOut(duration: 1.5)) { awake = true } }
    }
}
struct MotelButtonStyle: ButtonStyle {
    var subdued = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 10)
            .foregroundStyle(Color(hex: subdued ? 0xF5E7C8 : 0x203B32))
            .background(Color(hex: subdued ? 0x385348 : 0xEFC977), in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private enum MotelPanel: Equatable { case guest(Int), paint(Int?), desk, construction, staff, reviews, roomUpgrades }
struct MotelView: View {
    @Binding var game: Game
    @Environment(\.scenePhase) private var scenePhase
    @State private var movement: Tile?
    @State private var working = false
    @State private var workProgress = 0.0
    @State private var panel: MotelPanel?
    @State private var selectedRoom: Int?
    @State private var showMap = false
    @State private var showPause = false
    @State private var confirmRest = false
    @State private var confirmSneak: Int?
    @State private var showSneak = false
    @State private var confirmRestore = false
    @State private var toast: String?
    @State private var family: OfficeTap?
    @State private var showPolice = false
    @State private var showIncident = false
    private var motel: Motel { game.motel ?? Motel() }
    private var mapIdentity: String { motel.visit.map { "room-\($0.roomID)" } ?? motel.worldState.place.rawValue }
    private var movementDuration: Double { movement.map { $0.x != 0 && $0.y != 0 ? 0.19 : 0.14 } ?? 0.14 }
    private let cream = Color(hex: 0xF5E7C8)
    private let gold = Color(hex: 0xEFC977)
    private var testingUI: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        return false
        #endif
    }
    private var paused: Bool { showPolice || showIncident || family != nil || panel != nil || showMap || showPause || confirmRest || showSneak || confirmRestore }

    var body: some View {
        Group {
            if motel.caught { gameOver }
            else { worldScreen }
        }
        .foregroundStyle(cream).background(Color(hex: 0x172A25))
        .transaction { if testingUI { $0.disablesAnimations = true } }
        .task {
            change { $0.initializeWorld() }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-dialogue") { family = .hildarelys }
            if ProcessInfo.processInfo.arguments.contains("--ui-police") { showPolice = true }
            if ProcessInfo.processInfo.arguments.contains("--ui-hiring") { panel = .staff }
            #endif
        }
        .task(id: movement) {
            guard let direction = movement else { return }
            while !Task.isCancelled && scenePhase == .active && !motel.caught && !paused {
                change { $0.moveActor(dx: direction.x, dy: direction.y) }
                do { try await Task.sleep(for: .seconds(direction.x != 0 && direction.y != 0 ? 0.19 : 0.14)) } catch { break }
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            var ticks = 0
            while !Task.isCancelled && scenePhase == .active {
                do { try await Task.sleep(for: .seconds(0.35)) } catch { break }
                guard !Task.isCancelled, scenePhase == .active else { break }
                if !paused && !motel.caught {
                    ticks += 1
                    if !motel.worldState.travellers.isEmpty { change { $0.tickWorld() } }
                    if motel.isAtReception || motel.reception.visitor != nil { change { $0.tickReception() } }
                    if ticks % 3 == 0 && motel.visit?.sneaking == true { change { $0.tick() } }
                    if ticks % 3 == 0 { change { $0.tickManagement() } }
                }
            }
        }
        .task(id: working) {
            guard working, motel.worldState.hasCleaningKit, let target = motel.cleaningTarget else { return }
            let start = motel.actorTile
            workProgress = 0
            let clock = ContinuousClock()
            let started = clock.now
            while workProgress < 1 {
                do { try await Task.sleep(for: .seconds(0.05)) } catch { workProgress = 0; return }
                guard !Task.isCancelled, working, !paused, scenePhase == .active,
                      motel.actorTile == start, motel.cleaningTarget == target else { workProgress = 0; return }
                let elapsed = started.duration(to: clock.now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                workProgress = min(1, seconds / 1.4)
            }
            change { _ = $0.cleanNearbyTask() }
            working = false
            workProgress = 0
        }
        .task(id: toast) {
            guard let text = toast else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled && toast == text { toast = nil }
        }
        .onChange(of: mapIdentity) { _, _ in stop() }
        .onChange(of: motel.actorTile) { _, _ in working = false; workProgress = 0 }
        .onChange(of: motel.caught) { _, caught in if caught { stop(); panel = nil } }
        .onChange(of: paused) { _, value in if value { stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
        .onChange(of: receptionPrompt) { _, id in
            if let id, panel == nil, family == nil { openReceptionGuest(id) }
        }
        .onDisappear { stop() }
        .sheet(isPresented: $showMap) {
            MotelPocketMap(motel: motel).presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPause) { pauseSheet.presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }

    }

    private var worldScreen: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(motel.mapName).font(.system(size: 20, weight: .black, design: .rounded))
                    Text("DAY \(motel.day) / \(motel.occupancy) GUESTS / \(motel.weather.title)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(gold)
                }
                Spacer(minLength: 4)
                Label("\(motel.cash)", systemImage: "circle.circle.fill").font(.system(size: 18, weight: .heavy, design: .monospaced)).foregroundStyle(gold).accessibilityElement(children: .ignore).accessibilityLabel("Cash \(motel.cash) coins").accessibilityIdentifier("motelCash")
                Button { stop(); showMap = true } label: { Image(systemName: "map.fill").frame(width: 36, height: 40) }.accessibilityLabel("Airb&b map")
                Button { stop(); showPause = true } label: { Image(systemName: "pause.fill").frame(width: 28, height: 40) }.accessibilityLabel("Pause game")
            }
            HStack {
                Button { stop(); panel = .reviews } label: { Text(motel.reviewAverage.map { String(format:"? %.1f",$0) } ?? "? NEW") }.accessibilityIdentifier("openReviews")
                Spacer()
                Button("HIRE / TEAM \(motel.operationsState.workers.count)") { stop(); panel = .staff }.accessibilityIdentifier("openStaff")
                if let incident = motel.operationsState.incident {
                    Button("! \(incident.kind.rawValue.uppercased()) / \(incident.remaining)s") { stop(); showIncident = true }.foregroundStyle(Color(hex:0xEE9E78)).accessibilityIdentifier("incidentAlarm")
                }
            }.font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(gold)
            if let police = motel.business.police {
                Button { stop(); showPolice = true } label: {
                    Label(police.arrived ? "POLICE HERE - FINE / BRIBE" : "POLICE ON THE WAY",systemImage:"light.beacon.max.fill")
                        .font(.system(size:11,weight:.heavy)).frame(maxWidth:.infinity).padding(9).background(Color(hex:0x6A3D3D))
                }.accessibilityIdentifier("policeAlarm")
            }
            ZStack(alignment: .bottom) {
                scene
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(cream.opacity(0.18), lineWidth: 1))
                worldOverlay
            }.frame(maxHeight: .infinity)
            if let visit = motel.visit, visit.sneaking {
                HStack {
                    Text("SUSPICION").font(.system(size: 9, weight: .black, design: .monospaced))
                    ProgressView(value: Double(visit.alert), total: 100).tint(visit.alert >= 70 ? .red : gold)
                    Text("\(visit.alert)%").font(.caption.monospaced().bold())
                    Text("+\(visit.pocket)").font(.caption.monospaced().bold()).foregroundStyle(gold)
                }
            } else if let visit = motel.visit, let room = motel.rooms.first(where: { $0.id == visit.roomID }), room.dirty {
                HStack {
                    Label("CLEANING", systemImage: "sparkles").font(.system(size: 9, weight: .black, design: .monospaced))
                    ProgressView(value: working ? workProgress : Double(room.cleanedTasks?.count ?? 0) / 3).tint(gold)
                    Text("\(room.cleanedTasks?.count ?? 0)/3").font(.caption.monospaced().bold())
                }
            }
            Text(motel.isAtReception ? "Stay at the desk. Tap clients to talk; tap the lower door to walk outside." : hint).font(.system(size: 11, weight: .medium)).foregroundStyle(cream.opacity(0.8)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 29, alignment: .leading)
            if let car = motel.nearbyCar {
                Button("Wash car / +35 coins") { stop(); change { _ = $0.washNearbyCar() } }
                    .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("washCar")
                Text("Parking bay \(car.slot+1) / Hire Diego for automatic washes").font(.system(size:9))
            }
            if let service = motel.nearbyService {
                Button(motel.serviceAvailable(service) ? "\(service.title) / +\(service.reward) coins" : "\(service.title) / done or awaiting guests") {
                    stop(); change { _ = $0.performService(service) }
                }.buttonStyle(MotelButtonStyle()).disabled(!motel.serviceAvailable(service))
            }
            if motel.isAtReception {
                HStack(spacing: 10) {
                    Button("Front desk") { stop(); panel = .desk }.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("receptionDesk")
                    Button("Hire employees") { stop(); panel = .staff }.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("hireEmployees")
                }.frame(height: 65)
            } else {
            HStack(spacing: 16) {
                MotelJoystick(direction: { direction in
                    if !paused && !motel.caught { movement = direction }
                }, active: movement, step: { direction in
                    stop()
                    if !paused && !motel.caught { change { $0.moveActor(dx: direction.x, dy: direction.y) } }
                })
                Spacer(minLength: 0)
                VStack(spacing: 7) {
                    actionButton
                    Label(motel.worldState.hasCleaningKit ? "MOP + FRESH SHEETS" : "GET TOOLS IN OFFICE", systemImage: "sparkles")
                        .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(cream.opacity(0.6))
                }.frame(width: 160)
            }.frame(height: 140).padding(.horizontal, 8)
            }
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func policeDialogue(_ police: PoliceCase) -> some View {
        var choices: [DialogueChoice] = []
        if police.arrived {
            choices.append(DialogueChoice(title:"Pay fine / \(police.fine)",action:{ change { _ = $0.payPoliceFine() }; showPolice = false }))
            if !police.bribeTried && motel.cash >= 80 {
                choices.append(DialogueChoice(title:"Risk a bribe / 80",action:{ change { _ = $0.tryPoliceBribe() }; if motel.business.police == nil { showPolice = false } }))
            }
        }
        let detail = police.arrived ? "\(police.guest) died in the \(police.cause.rawValue) emergency. Your fine is \(police.fine) coins. Bribery may be refused and increase the fine. Unpaid fines are deducted from future room income. \(police.message)" : "An officer is walking from the road to reception after a guest death. Keep the grounds safe. Talk once the officer arrives."
        return GameDialogue(speaker:"Officer Vega",text:detail,portrait:AnyView(PaperPortrait(color:0x54739C,variant:0)),choices:choices) { showPolice = false }
    }

    @ViewBuilder private var worldOverlay: some View {
                if showPolice, let police = motel.business.police {
                    policeDialogue(police).padding(12)
                } else if let family {
                    GameDialogue(speaker:familyTitle,text:familyMessage,portrait:familyPortrait(family),choices:familyChoices(family)) { self.family = nil }.padding(12)
                } else if showIncident, let incident = motel.operationsState.incident {
                    GameDialogue(speaker:incident.kind.title,text:incident.kind.detail,portrait:AnyView(Image(systemName:"exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(gold)),choices:incidentChoices(incident.kind)) { showIncident = false }.padding(12)
                } else if showSneak {
                    GameDialogue(speaker:"Occupied room",text:"Keep away from the guest. Taking belongings makes noise. Get back to the door before you are caught.",portrait:AnyView(PaperPortrait(color:0xC7D0D4,variant:7)),choices:[DialogueChoice(title:"Enter quietly",action:{
                        if let id = confirmSneak { change { _ = $0.enter(id) } }
                        showSneak = false; confirmSneak = nil
                    })]) { showSneak = false; confirmSneak = nil }.padding(12)
                } else if confirmRest {
                    GameDialogue(speaker:"End the day?",text:"Guests check out, reviews arrive, and wages are paid. An ignored emergency can kill a guest. Police cases must be settled before sleeping. Your morning is saved.",portrait:AnyView(PaperPortrait(color:0xC7D0D4,variant:7)),choices:[DialogueChoice(title:"Sleep until morning",action:{
                        change { _ = $0.restAtBed() }; game.save(); confirmRest = false; toast = "Morning checkpoint saved."
                    })]) { confirmRest = false }.padding(12)
                } else if confirmRestore {
                    GameDialogue(speaker:"Load checkpoint?",text:"Progress since your last save will be lost.",portrait:AnyView(PaperPortrait(color:0xC7D0D4,variant:7)),choices:[DialogueChoice(title:"Load last save",action:{ stop(); panel = nil; game = Game.load(); confirmRestore = false })]) { confirmRestore = false }.padding(12)
                } else if let panel {
                    interactionPanel(panel).modifier(RPGFrame()).padding(12)
                } else if let toast {
                    Text(toast).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center)
                        .padding(12).frame(maxWidth: .infinity).background(Color(hex: 0x20392E).opacity(0.94), in: RoundedRectangle(cornerRadius: 13)).padding(10).allowsHitTesting(false)
                }
    }

    @ViewBuilder private var scene: some View {
        let tile = motel.actorTile
        if let visit = motel.visit, let room = motel.rooms.first(where: { $0.id == visit.roomID }) {
            MotelRPGView(motel: motel, workProgress: workProgress)
                .animation(.linear(duration: movementDuration), value: tile).id(mapIdentity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(motel.mapName). Column \(tile.x), row \(tile.y).")
                .accessibilityValue("\(room.dirty ? "Cleaning \(room.cleanedTasks?.count ?? 0)/3" : "Ready for guests"). Theme \(room.theme). Furnishings \(room.furniture).")
                .accessibilityIdentifier("motelWorld")
        } else if motel.isAtReception {
            OfficeReceptionView(motel: motel, tap: officeTap).id(mapIdentity)
        } else {
            MotelRPGView(motel: motel)
                .animation(.linear(duration: movementDuration), value: tile)
                .animation(.linear(duration: 0.35), value: motel.worldState.tick).id(mapIdentity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Airb&b GROUNDS. Column \(tile.x), row \(tile.y).")
                .accessibilityValue("\(motel.worldState.travellers.count) guests walking to their destinations.")
                .accessibilityIdentifier("motelWorld")
        }
    }

    private var actionName: String {
        switch motel.nearbyAction {
        case .incident: return "HELP"
        case .office, .room: return "ENTER"
        case .guest: return "TALK"
        case .construction: return "BUILD"
        case .desk: return "DESK"
        case .save: return "SAVE"
        case .rest: return "SLEEP"
        case .tools: return "TAKE TOOLS"
        case .paint: return "PAINT"
        case .furniture: return "UPGRADE"
        case .clean: return motel.worldState.hasCleaningKit ? "HOLD TO CLEAN" : "NEED MOP"
        case .loot: return "TAKE"
        case .exit: return "LEAVE"
        case .none: return "EXPLORE"
        }
    }
    private var actionSymbol: String {
        switch motel.nearbyAction {
        case .incident: return "exclamationmark.triangle.fill"
        case .guest: return "bubble.left.fill"
        case .clean, .tools: return "sparkles"
        case .save, .desk: return "book.closed.fill"
        case .paint: return "paintbrush.fill"
        case .construction, .furniture: return "hammer.fill"
        case .rest: return "moon.zzz.fill"
        case .loot: return "hand.raised.fill"
        default: return "door.left.hand.open"
        }
    }
    private var actionButton: some View {
        WorkActionButton(title: actionName, symbol: actionSymbol, cleaning: motel.cleaningTarget != nil,
                         enabled: !paused && motel.nearbyAction != .none && (motel.cleaningTarget == nil || motel.worldState.hasCleaningKit),
                         progress: workProgress, pressed: { pressed in
            if pressed { movement = nil }
            working = pressed
        }, action: performAction).accessibilityIdentifier("worldAction")
    }
    private var hint: String {
        switch motel.nearbyAction {
        case .incident: return motel.operationsState.incident?.kind.detail ?? "The grounds are quiet."
        case .guest(let id):
            let guest = motel.waiting.first { $0.id == id }
            return "\(guest?.name ?? "Guest") wants a room. Talk, choose a room and collect payment."
        case .room(let id):
            let room = motel.rooms.first { $0.id == id }
            return room?.guest != nil ? "Room \(101 + id) is occupied. Entering means sneaking." : "Room \(101 + id): \(room?.dirty == true ? "needs cleaning" : "ready"). Walk through the door."
        case .clean(let task): return motel.worldState.hasCleaningKit ? "\(MotelGrounds.cleaningNames[task]): hold the work button until it finishes." : "Get a cleaning kit from the TOOLS closet in your office."
        case .paint: return "Choose wall paint here. 25 coins per change."
        case .furniture: return "Upgrade the bed and room furnishings here to improve its nightly rate."
        case .desk: return "Your front desk: save a checkpoint or upgrade the office."
        case .save: return "Logbook: save your current Airb&b, guests and upgrades."
        case .rest: return "Your bed: end the day, handle checkouts and save the next morning."
        case .tools: return "Pick up a mop, fresh sheets and bin bags for cleaning."
        case .office: return "Office entrance. Walk through the door or tap ENTER."
        case .exit: return "Walk through the lower door to go outside."
        case .construction: return "Build room \(101 + motel.rooms.count) here for \(motel.expansionCost) coins."
        case .loot(let item): return "\(RoomVisit.lootNames[item]): +\(RoomVisit.lootValues[item]) coins, +\(RoomVisit.lootNoise[item]) suspicion. Escape to keep it."
        case .none:
            if motel.visit?.sneaking == true { return "Avoid the guest. Take belongings and return to the door before suspicion reaches 100%." }
            if motel.visit != nil { return "Walk to the bed, trash or spill to clean. Paint cabinet is in the upper right." }
            return motel.worldState.place == .office ? "Move with the stick or hold an arrow. Desk, tools, paint, bed and logbook are physical objects." : "Explore the grounds. Guests wait outside the office. Room entrances lead inside."
        }
    }

    private func performAction() {
        guard !paused else { return }
        stop()
        switch motel.nearbyAction {
        case .incident: showIncident = true
        case .office, .exit: change { _ = $0.useEntrance() }
        case .room(let id):
            if motel.rooms.first(where: { $0.id == id })?.guest != nil { confirmSneak = id; showSneak = true }
            else { change { _ = $0.useEntrance() } }
        case .guest: toast = "Clients check in at reception. Tap the office door to return to your desk."
        case .construction: panel = .construction
        case .desk: panel = .desk
        case .save: saveHere()
        case .rest: confirmRest = true
        case .tools: change { _ = $0.collectTools() }
        case .paint(let roomID): panel = .paint(roomID)
        case .furniture: change { _ = $0.furnishNearby() }
        case .loot: change { _ = $0.steal() }
        case .none, .clean: break
        }
    }
    @ViewBuilder private func interactionPanel(_ selected: MotelPanel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(panelTitle(selected)).font(.headline)
                Spacer()
                Button { panel = nil } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.accessibilityLabel("Close interaction")
            }
            switch selected {
            case .guest(let id):
                if let guest = motel.waiting.first(where: { $0.id == id }) {
                    HStack {
                        PaperPortrait(color: guest.color, variant: guest.id + 100).frame(width: 43, height: 55)
                        Text("Hello! My name is \(guest.name). \(guest.story) Could I stay for \(guest.nights) night\(guest.nights == 1 ? "" : "s")?").font(.caption)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(motel.rooms.filter(\.available)) { room in
                                Button { selectedRoom = room.id } label: {
                                    VStack(spacing: 4) {
                                        RoomIllustration(theme: room.theme, level: room.furniture, office: false).frame(width: 70, height: 48)
                                        Text("\(room.number) / \(motel.rate(for: room) * guest.nights) coins").font(.system(size: 10, weight: .bold))
                                    }.padding(7).background(selectedRoom == room.id ? gold.opacity(0.3) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                }.accessibilityIdentifier("chooseRoom\(room.id)")
                            }
                        }
                    }
                    Button("Accept guest & collect payment") {
                        if let roomID = selectedRoom { change { _ = $0.acceptReceptionGuest(roomID: roomID) } }
                        panel = nil
                    }.buttonStyle(MotelButtonStyle()).disabled(selectedRoom == nil).accessibilityIdentifier("chargeGuest")
                    Button("Decline politely") {
                        change { _ = $0.declineReceptionGuest() }; panel = nil
                    }.buttonStyle(MotelButtonStyle(subdued: true)).accessibilityIdentifier("declineGuest")
                    if selectedRoom == nil { Text("No clean, empty rooms. You can decline or return after preparing a room.").font(.caption) }
                }
            case .staff:
                StaffPanel(motel:motel) { role in change { _ = $0.hire(role) } }
            case .reviews:
                VStack(alignment:.leading,spacing:6) {
                    Text("Safety deaths: \(motel.business.deaths) / Lost daily bookings: \(motel.bookingPenalty) / Fine balance: \(motel.business.debt)").font(.caption)
                    ReviewsPanel(motel:motel)
                }
            case .roomUpgrades:
                RoomUpgradesPanel(motel:motel) { id in change { _ = $0.upgradeFromDesk(id) } }
            case .paint(let roomID):
                let current = roomID.flatMap { id in motel.rooms.first { $0.id == id }?.theme } ?? motel.officeTheme
                HStack {
                    ForEach(0..<4) { theme in
                        Button { change { _ = $0.paintNearby(theme) }; panel = nil } label: {
                            VStack(spacing: 4) {
                                Circle().fill(Color(hex: Motel.themeColors[theme])).frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(current == theme ? gold : .clear, lineWidth: 3))
                                Text(Motel.themeNames[theme]).font(.caption2)
                            }.frame(maxWidth: .infinity)
                        }.disabled(motel.cash < 25 || current == theme).accessibilityIdentifier("paint\(theme)")
                    }
                }
                Text("25 coins per color change.").font(.caption).foregroundStyle(gold)
            case .desk:
                HStack {
                    Button("Staff") { panel = .staff }.accessibilityIdentifier("deskStaff")
                    Button("Reviews") { panel = .reviews }.accessibilityIdentifier("deskReviews")
                    Button("Room upgrades") { panel = .roomUpgrades }.accessibilityIdentifier("deskRooms")
                }.font(.caption.bold()).foregroundStyle(gold).padding(.bottom,6)
                HStack {
                    Button("Save checkpoint", action: saveHere).buttonStyle(MotelButtonStyle()).accessibilityIdentifier("saveCheckpoint")
                    Button("Upgrade / \((motel.officeLevel + 1) * 120)") {
                        change { _ = $0.furnishNearby() }; panel = nil
                    }.buttonStyle(MotelButtonStyle(subdued: true)).disabled(motel.officeLevel >= 2 || motel.cash < (motel.officeLevel + 1) * 120)
                }
                Text("Office upgrades improve every room's nightly rate by 15 coins.").font(.caption)
            case .construction:
                HStack {
                    RoomIllustration(theme: 0, level: 0, office: false).frame(width: 88, height: 70).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Room \(101 + motel.rooms.count)\n\(motel.expansionCost) coins\n\(motel.rooms.count)/9 rooms built").font(.subheadline.bold())
                }
                Button("Build this room") {
                    change { _ = $0.buildNearby() }; panel = nil
                }.buttonStyle(MotelButtonStyle()).disabled(motel.cash < motel.expansionCost || motel.goalReached).accessibilityIdentifier("buildRoom")
            }
        }
    }
    private func panelTitle(_ value: MotelPanel) -> String {
        switch value {
        case .guest(let id): return motel.waiting.first { $0.id == id }?.name ?? "Guest"
        case .paint(let id): return id.map { "Room \(101 + $0) paint" } ?? "Office paint"
        case .staff: return "Your team"
        case .reviews: return "Guest reviews"
        case .roomUpgrades: return "Room upgrades"
        case .desk: return "Front desk"
        case .construction: return "Airb&b expansion"
        }
    }
    private var pauseSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("On a break").font(.title.bold())
            Text("Move around the Airb&b to do your work. Visit the desk or logbook to save, the tools closet for a mop, and your bed for the next day. Clean all three messes inside a vacated room before renting it again.").font(.body)
            Text("Getting caught while stealing means loading your latest checkpoint. Changes since that save will be lost.").font(.subheadline).foregroundStyle(.secondary)
            Button("Back to the Airb&b") { showPause = false }.buttonStyle(MotelButtonStyle())
            Button("Load last save") { showPause = false; confirmRestore = true }.buttonStyle(MotelButtonStyle(subdued: true))
        }.padding(24).foregroundStyle(cream).presentationBackground(Color(hex: 0x172A25))
    }
    private var gameOver: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "eye.fill").font(.system(size: 60)).foregroundStyle(Color(hex: 0xDE927D))
            Text("CAUGHT").font(.system(size: 46, weight: .black, design: .rounded)).tracking(5)
            Text("The guest saw you.").font(.title2.bold())
            Text("Load your last checkpoint to try again. Everything after that save is lost.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Load last save") { stop(); panel = nil; game = Game.load(); toast = "Checkpoint restored." }
                .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("restoreCheckpoint")
            Spacer()
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: 0x2C292A))
    }
    private func familyPortrait(_ person: OfficeTap) -> AnyView {
        if person == .chichu || person == .chichi { return AnyView(CatPortrait(gray:person == .chichu)) }
        return AnyView(PaperPortrait(color:person == .samhil ? 0xD88BAA : 0x292A2C,variant:person == .samhil ? 9 : 8))
    }
    private func familyChoices(_ person: OfficeTap) -> [DialogueChoice] {
        if person == .chichu || person == .chichi {
            return [DialogueChoice(title:"Pet",action:{ toast = "\(familyTitle) purrs happily."; family = nil }),
                    DialogueChoice(title:"Give a treat",action:{ toast = "\(familyTitle) enjoys a little treat."; family = nil })]
        }
        if person == .hildarelys { return [DialogueChoice(title:"Give her a kiss",action:{ toast = "Hildarelys smiles: We make a good team."; family = nil })] }
        return [DialogueChoice(title:"Watch together",action:{ toast = "You share a funny cartoon with Samhil."; family = nil })]
    }
    private func incidentChoices(_ kind: ChaosKind) -> [DialogueChoice] {
        if motel.nearbyIncident { return [DialogueChoice(title:kind.action,action:{ change { _ = $0.resolveNearbyIncident() }; showIncident = false })] }
        if motel.isAtReception { return [DialogueChoice(title:"Go outside",action:{ change { _ = $0.leaveReception() }; showIncident = false })] }
        return []
    }

    private var receptionPrompt: Int? { motel.isAtReception ? motel.receptionGuest?.id : nil }
    private func openReceptionGuest(_ id: Int) {
        guard motel.isAtReception, motel.receptionGuest?.id == id else { return }
        stop(); selectedRoom = motel.rooms.first(where: \.available)?.id; panel = .guest(id)
    }
    private func officeTap(_ item: OfficeTap) {
        guard !paused, motel.isAtReception else { return }
        stop()
        switch item {
        case .door: change { _ = $0.leaveReception() }
        case .player: panel = .desk
        case .save: saveHere()
        case .tools: change { _ = $0.receptionTools() }
        case .paint: panel = .paint(nil)
        case .bed: confirmRest = true
        case .guest:
            if let guest = motel.receptionGuest { openReceptionGuest(guest.id) }
            else { toast = "The client is walking to the desk." }
        case .chichu, .chichi, .samhil, .hildarelys: family = item
        }
    }
    private var familyTitle: String {
        switch family {
        case .chichu: return "Chichu"
        case .chichi: return "Chichi"
        case .samhil: return "Samhil"
        case .hildarelys: return "Hildarelys"
        default: return "Family"
        }
    }
    private var familyMessage: String {
        switch family {
        case .chichu: return "Your gray tabby looks up with green eyes and gives a soft meow."
        case .chichi: return "Chichi flicks her calico tail and waits for some attention."
        case .samhil: return "This cartoon is so funny! Can we watch another episode when you finish helping the guests?"
        case .hildarelys: return "I love our little office. I will keep Samhil and the cats company while you welcome the guests."
        default: return ""
        }
    }
    private func saveHere() {
        guard motel.atSavePoint else { return }
        stop(); game.save(); panel = nil; toast = "Checkpoint saved at the office."
    }
    private func stop() { movement = nil; working = false; workProgress = 0 }
    private func change(_ action: (inout Motel) -> Void) {
        guard var current = game.motel else { return }
        let before = current.lastEvent
        action(&current)
        if current.lastEvent != before {
            var state = current.operationsState
            let event = current.lastEvent.lowercased()
            if (state.actionUntil ?? 0) <= state.tick {
                state.actionLabel = event.contains("fire") ? "??" : event.contains("pool") ? "?" : event.contains("fight") ? "?" : event.contains("paint") ? "?" : event.contains("clean") ? "?" : event.contains("room") ? "?" : "�"
                state.actionUntil = state.tick + 3
                current.operations = state
            }
        }
        if current.lastEvent != before && current.operationsState.visual?.id == game.motel?.operationsState.visual?.id {
            let message = current.lastEvent.lowercased()
            if message.contains("paint") { current.playVisual("paint") }
            else if message.contains("built") || message.contains("furnish") || message.contains("upgraded") { current.playVisual("build") }
            else if message.contains("tools collected") || message.contains("fresh sheets collected") { current.playVisual("laundry") }
        }
        game.motel = current
        if current.lastEvent != before { toast = current.lastEvent }
    }
}
