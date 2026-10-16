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
            Text("The town, the coins, the little house... a dream.\nOn your desk: three room keys and the deed to a tired roadside motel.\n\nYour first guests are already outside.")
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

private enum MotelPanel: Equatable { case guest(Int), paint(Int?), desk, construction }
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
    private var paused: Bool { panel != nil || showMap || showPause || confirmRest || showSneak || confirmRestore }

    var body: some View {
        Group {
            if motel.caught { gameOver }
            else { worldScreen }
        }
        .foregroundStyle(cream).background(Color(hex: 0x172A25))
        .transaction { if testingUI { $0.disablesAnimations = true } }
        .task { change { $0.initializeWorld() } }
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
                    if ticks % 3 == 0 && motel.visit?.sneaking == true { change { $0.tick() } }
                }
            }
        }
        .task(id: working) {
            guard working, motel.worldState.hasCleaningKit, let target = motel.cleaningTarget else { return }
            let start = motel.actorTile
            workProgress = 0
            for step in 1...14 {
                do { try await Task.sleep(for: .seconds(0.1)) } catch { workProgress = 0; return }
                guard !Task.isCancelled, working, !paused, scenePhase == .active,
                      motel.actorTile == start, motel.cleaningTarget == target else { workProgress = 0; return }
                workProgress = Double(step) / 14
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
        .onDisappear { stop() }
        .sheet(isPresented: $showMap) {
            MotelPocketMap(motel: motel).presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPause) { pauseSheet.presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        .alert("Sneak into room \(101 + (confirmSneak ?? 0))?", isPresented: $showSneak) {
            Button("Enter quietly") {
                if let id = confirmSneak, motel.nearbyAction == .room(id) { change { _ = $0.useEntrance() } }
                confirmSneak = nil
            }
            Button("Stay outside", role: .cancel) { confirmSneak = nil }
        } message: { Text("Keep away from the guest. Taking belongings makes noise. Escape by the door before suspicion reaches 100%, or load your last checkpoint after getting caught.") }
        .confirmationDialog("Sleep until morning and save?", isPresented: $confirmRest, titleVisibility: .visible) {
            Button("Sleep until morning") {
                if motel.nearbyAction == .rest {
                    change { _ = $0.restAtBed() }
                    game.save()
                    toast = "Morning checkpoint saved. Go outside for new arrivals."
                }
            }
        } message: { Text("Finished stays check out. Visit their rooms to make beds, collect trash and mop spills. Remaining arrivals leave.") }
        .confirmationDialog("Discard unsaved progress?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Load last save", role: .destructive) { stop(); panel = nil; game = Game.load(); toast = "Checkpoint restored." }
        }
    }

    private var worldScreen: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(motel.mapName).font(.system(size: 20, weight: .black, design: .rounded))
                    Text("DAY \(motel.day) / \(motel.occupancy) GUESTS / \(motel.rooms.count) ROOMS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(gold)
                }
                Spacer(minLength: 4)
                Label("\(motel.cash)", systemImage: "circle.circle.fill").font(.system(size: 18, weight: .heavy, design: .monospaced)).foregroundStyle(gold).accessibilityElement(children: .ignore).accessibilityLabel("Cash \(motel.cash) coins").accessibilityIdentifier("motelCash")
                Button { stop(); showMap = true } label: { Image(systemName: "map.fill").frame(width: 36, height: 40) }.accessibilityLabel("Motel map")
                Button { stop(); showPause = true } label: { Image(systemName: "pause.fill").frame(width: 28, height: 40) }.accessibilityLabel("Pause game")
            }
            ZStack(alignment: .bottom) {
                scene
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(cream.opacity(0.18), lineWidth: 1))
                if let panel {
                    interactionPanel(panel).padding(10).background(Color(hex: 0x20392E).opacity(0.98), in: RoundedRectangle(cornerRadius: 18)).padding(9)
                } else if let toast {
                    Text(toast).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center)
                        .padding(12).frame(maxWidth: .infinity).background(Color(hex: 0x20392E).opacity(0.94), in: RoundedRectangle(cornerRadius: 13)).padding(10).allowsHitTesting(false)
                }
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
            Text(hint).font(.system(size: 11, weight: .medium)).foregroundStyle(cream.opacity(0.8)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 29, alignment: .leading)
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
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }

    @ViewBuilder private var scene: some View {
        let tile = motel.actorTile
        if let visit = motel.visit, let room = motel.rooms.first(where: { $0.id == visit.roomID }) {
            MotelRoomCanvas(room: room, visit: visit, x: Double(tile.x), y: Double(tile.y), guestPresent: motel.guestPresent(in: room.id), workProgress: workProgress)
                .animation(.linear(duration: movementDuration), value: tile).id(mapIdentity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(motel.mapName). Column \(tile.x), row \(tile.y).")
                .accessibilityValue("\(room.dirty ? "Cleaning \(room.cleanedTasks?.count ?? 0)/3" : "Ready for guests"). Theme \(room.theme). Furnishings \(room.furniture).")
                .accessibilityIdentifier("motelWorld")
        } else if motel.worldState.place == .office {
            MotelOfficeCanvas(motel: motel, x: Double(tile.x), y: Double(tile.y))
                .animation(.linear(duration: movementDuration), value: tile).id(mapIdentity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("YOUR OFFICE. Column \(tile.x), row \(tile.y).")
                .accessibilityIdentifier("motelWorld")
        } else {
            MotelGroundsCanvas(motel: motel, x: Double(tile.x), y: Double(tile.y), npcTick: Double(motel.worldState.tick))
                .animation(.linear(duration: movementDuration), value: tile)
                .animation(.linear(duration: 0.35), value: motel.worldState.tick).id(mapIdentity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("MOTEL GROUNDS. Column \(tile.x), row \(tile.y).")
                .accessibilityValue("\(motel.worldState.travellers.count) guests walking to their destinations.")
                .accessibilityIdentifier("motelWorld")
        }
    }

    private var actionName: String {
        switch motel.nearbyAction {
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
        case .save: return "Logbook: save your current motel, guests and upgrades."
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
        case .office, .exit: change { _ = $0.useEntrance() }
        case .room(let id):
            if motel.rooms.first(where: { $0.id == id })?.guest != nil { confirmSneak = id; showSneak = true }
            else { change { _ = $0.useEntrance() } }
        case .guest(let id): selectedRoom = motel.rooms.first(where: \.available)?.id; panel = .guest(id)
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
                        PaperPortrait(color: guest.color, variant: guest.id % 8).frame(width: 43, height: 55)
                        Text("\(guest.nights) night\(guest.nights == 1 ? "" : "s"). \(guest.story)").font(.caption)
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
                    Button("Collect payment and hand over key") {
                        if let roomID = selectedRoom { change { _ = $0.chargeGuest(id, roomID: roomID) } }
                        panel = nil
                    }.buttonStyle(MotelButtonStyle()).disabled(selectedRoom == nil).accessibilityIdentifier("chargeGuest")
                    if selectedRoom == nil { Text("No clean, empty rooms. Clean a room or build another.").font(.caption) }
                }
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
        case .desk: return "Front desk"
        case .construction: return "Motel expansion"
        }
    }
    private var pauseSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("On a break").font(.title.bold())
            Text("Move around the motel to do your work. Visit the desk or logbook to save, the tools closet for a mop, and your bed for the next day. Clean all three messes inside a vacated room before renting it again.").font(.body)
            Text("Getting caught while stealing means loading your latest checkpoint. Changes since that save will be lost.").font(.subheadline).foregroundStyle(.secondary)
            Button("Back to the motel") { showPause = false }.buttonStyle(MotelButtonStyle())
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
    private func saveHere() {
        guard motel.atSavePoint else { return }
        stop(); game.save(); panel = nil; toast = "Checkpoint saved at the office."
    }
    private func stop() { movement = nil; working = false; workProgress = 0 }
    private func change(_ action: (inout Motel) -> Void) {
        guard var current = game.motel else { return }
        let before = current.lastEvent
        action(&current)
        game.motel = current
        if current.lastEvent != before { toast = current.lastEvent }
    }
}
