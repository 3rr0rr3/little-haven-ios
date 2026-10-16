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
private struct RoomChoice: Identifiable { let id: Int }

struct MotelView: View {
    @Binding var game: Game
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var booking: MotelGuest?
    @State private var decorating: RoomChoice?
    @State private var officeEditor = false
    @State private var confirmDay = false
    @State private var confirmRestore = false
    @State private var entry: RoomChoice?
    @State private var showEntry = false
    @State private var held: Tile?
    @State private var notice: String?
    private var motel: Motel { game.motel ?? Motel() }
    private let cream = Color(hex: 0xF5E7C8)
    private let gold = Color(hex: 0xEFC977)
    private var tickKey: String { "\(motel.visit?.roomID ?? -1)-\(scenePhase)" }

    var body: some View {
        Group {
            if motel.caught { gameOver }
            else if let visit = motel.visit { roomScene(visit) }
            else { management }
        }
        .foregroundStyle(cream).background(Color(hex: 0x172A25))
        .task(id: held) {
            guard let direction = held else { return }
            while !Task.isCancelled && scenePhase == .active && motel.visit != nil && !motel.caught {
                change { $0.move(dx: direction.x, dy: direction.y) }
                do { try await Task.sleep(for: .seconds(0.18)) } catch { break }
            }
        }
        .task(id: tickKey) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled && motel.visit?.sneaking == true && !motel.caught {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                guard !Task.isCancelled, scenePhase == .active else { break }
                change { $0.tick() }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { held = nil } }
        .onChange(of: motel.caught) { _, caught in if caught { held = nil } }
        .onChange(of: motel.visit?.roomID) { _, _ in held = nil }
        .onDisappear { held = nil }
        .sheet(item: $booking) { guest in bookingSheet(guest) }
        .sheet(item: $decorating) { room in customization(roomID: room.id) }
        .sheet(isPresented: $officeEditor) { customization(roomID: nil) }
        .alert("Enter an occupied room?", isPresented: $showEntry) {
            Button("Enter quietly") { if let room = entry { change { _ = $0.enter(room.id) } }; entry = nil }
            Button("Stay outside", role: .cancel) { entry = nil }
        } message: {
            Text("The guest is inside. Suspicion rises over time and when you move or search. Stay away from the guest and return to the door to escape. Getting caught loses everything since your last save.")
        }
        .confirmationDialog("End this day and save the next morning?", isPresented: $confirmDay, titleVisibility: .visible) {
            Button("Sleep until morning") { change { _ = $0.nextDay() }; game.save(); notice = "Morning checkpoint saved." }
        } message: { Text("Remaining arrivals leave. Guests with completed stays check out, leaving rooms to clean.") }
        .confirmationDialog("Discard progress since your last save?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Load last save", role: .destructive) { held = nil; game = Game.load(); notice = "Checkpoint restored." }
        }
    }

    private var management: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                MotelOverview(motel: motel).frame(height: 205).clipShape(RoundedRectangle(cornerRadius: 20))
                HStack {
                    Label("\(motel.occupancy)/\(motel.rooms.count) occupied", systemImage: "bed.double.fill")
                    Spacer()
                    Text("GOAL  \(motel.rooms.count)/9 ROOMS").font(.caption.monospaced().bold()).foregroundStyle(gold)
                }.font(.caption)
                ProgressView(value: Double(motel.rooms.count - 3), total: 6).tint(gold)
                if motel.goalReached {
                    Label("A thriving motel! You can keep playing.", systemImage: "star.fill").font(.headline).foregroundStyle(gold)
                }
                Picker("Motel area", selection: $tab) {
                    Text("Desk").tag(0); Text("Rooms").tag(1); Text("Office").tag(2)
                }.pickerStyle(.segmented).accessibilityIdentifier("motelTabs")
                Text(notice ?? motel.lastEvent).font(.subheadline).foregroundStyle(cream.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
                if tab == 0 { reception }
                if tab == 1 { roomList }
                if tab == 2 { office }
            }.padding(18)
        }.accessibilityIdentifier("motelManagement")
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LITTLE HAVEN").font(.system(size: 23, weight: .black, design: .rounded)).tracking(1)
                Text("MOTEL / DAY \(motel.day)").font(.caption.monospaced().bold()).foregroundStyle(gold)
            }
            Spacer()
            Label("\(motel.cash)", systemImage: "circle.circle.fill").font(.title3.monospaced().bold()).foregroundStyle(gold).accessibilityIdentifier("motelCash")
        }
    }
    private var reception: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arrivals").font(.title2.bold())
            Text("Payment is collected at check-in. Better rooms and an upgraded office earn higher nightly rates.").font(.caption).foregroundStyle(.secondary)
            if motel.waiting.isEmpty { Text("Everyone is settled. Prepare your rooms or end the day for new arrivals.").padding(.vertical) }
            ForEach(motel.waiting) { guest in
                HStack(spacing: 12) {
                    PaperPortrait(color: guest.color, variant: guest.id % 8).frame(width: 45, height: 62)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(guest.name).font(.headline)
                        Text("\(guest.nights) night\(guest.nights == 1 ? "" : "s") / \(guest.story)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Check in") { booking = guest; notice = nil }
                        .font(.caption.bold()).padding(11).background(gold, in: Capsule()).foregroundStyle(Color(hex: 0x203B32))
                        .disabled(!motel.rooms.contains(where: \.available))
                        .accessibilityIdentifier("checkIn\(guest.id)")
                }.padding(12).background(Color(hex: 0x283E35), in: RoundedRectangle(cornerRadius: 16))
            }
            if !motel.rooms.contains(where: \.available) { Text("No ready rooms. Clean a vacated room, expand, or end the day for checkouts.").font(.caption).foregroundStyle(gold) }
            HStack {
                Button("Save at desk") { game.save(); notice = "Checkpoint saved. Day \(motel.day), \(motel.cash) coins." }.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("saveMotel")
                Button("End day") { confirmDay = true }.buttonStyle(MotelButtonStyle(subdued: true))
            }
            Text("Save at the desk or start a new day to create a checkpoint. Closing the app or getting caught returns to that checkpoint.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var roomList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(motel.rooms) { room in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ROOM \(room.number)").font(.headline.monospaced())
                        Spacer()
                        Text("\(motel.rate(for: room))/night").font(.caption.bold()).foregroundStyle(gold)
                    }
                    HStack(spacing: 12) {
                        RoomIllustration(theme: room.theme, level: room.furniture, office: false).frame(width: 100, height: 80).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(room.guest.map { "\($0.name) / \(room.nightsLeft) nights left" } ?? (room.dirty ? "Needs cleaning" : "Ready for guests")).font(.subheadline.bold())
                            Text("\(Motel.themeNames[room.theme]) / \(["Basic", "Comfort", "Deluxe"][room.furniture])").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Button(room.guest == nil ? "Enter room" : "Sneak inside") {
                            notice = nil
                            if room.guest != nil { entry = RoomChoice(id: room.id); showEntry = true }
                            else { change { _ = $0.enter(room.id) } }
                        }.buttonStyle(MotelButtonStyle(subdued: room.guest != nil)).accessibilityIdentifier("enterRoom\(room.id)")
                        if room.dirty && room.guest == nil {
                            Button("Clean / free") { change { _ = $0.clean(room.id) }; notice = nil }.buttonStyle(MotelButtonStyle())
                        } else {
                            Button("Customize") { decorating = RoomChoice(id: room.id) }
                                .buttonStyle(MotelButtonStyle(subdued: true)).disabled(room.guest != nil)
                                .accessibilityIdentifier("customizeRoom\(room.id)")
                        }
                    }
                }.padding(14).background(Color(hex: 0x283E35), in: RoundedRectangle(cornerRadius: 18))
            }
            if !motel.goalReached {
                Button("Build room \(101 + motel.rooms.count) / \(motel.expansionCost) coins") { change { _ = $0.expand() }; notice = nil }
                    .buttonStyle(MotelButtonStyle()).disabled(motel.cash < motel.expansionCost).accessibilityIdentifier("expandMotel")
            }
        }
    }
    private var office: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoomIllustration(theme: motel.officeTheme, level: motel.officeLevel, office: true).frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 18))
            Text("Your office").font(.title2.bold())
            Text("\(Motel.themeNames[motel.officeTheme]) walls / \(["Starter", "Welcoming", "Premium"][motel.officeLevel]) desk").font(.subheadline)
            Text("Office upgrades add 15 coins to every room's nightly rate and attract one extra arrival each day.").font(.caption).foregroundStyle(.secondary)
            Button("Customize office") { officeEditor = true }.buttonStyle(MotelButtonStyle())
            HStack {
                stat("GUESTS", value: motel.guestsServed)
                stat("ROOMS", value: motel.rooms.count)
                stat("STOLEN", value: motel.totalStolen)
            }
            Button("Save at desk") { game.save(); notice = "Checkpoint saved." }.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("saveOffice")
            Button("Load last save") { confirmRestore = true }.buttonStyle(MotelButtonStyle(subdued: true))
        }
    }
    private func stat(_ title: String, value: Int) -> some View {
        VStack(spacing: 6) { Text("\(value)").font(.title2.bold()); Text(title).font(.caption2.monospaced()) }
            .frame(maxWidth: .infinity).padding(15).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
    private func bookingSheet(_ guest: MotelGuest) -> some View {
        NavigationStack {
            List {
                Section("Choose a clean, empty room for \(guest.name)") {
                    ForEach(motel.rooms.filter(\.available)) { room in
                        Button {
                            change { _ = $0.checkIn(guestID: guest.id, roomID: room.id) }
                            booking = nil
                        } label: {
                            HStack { Text("Room \(room.number)"); Spacer(); Text("\(motel.rate(for: room) * guest.nights) coins total") }
                        }.accessibilityIdentifier("assignRoom\(room.id)")
                    }
                }
            }.navigationTitle("Check in").toolbar { Button("Cancel") { booking = nil } }
        }.tint(gold).presentationDetents([.medium, .large])
    }
    private func customization(roomID: Int?) -> some View {
        let room = motel.rooms.first { $0.id == roomID }
        let theme = room?.theme ?? motel.officeTheme
        let level = room?.furniture ?? motel.officeLevel
        let price = (level + 1) * (roomID == nil ? 120 : 90)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RoomIllustration(theme: theme, level: level, office: roomID == nil).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 18))
                    Text("Walls / 25 coins per change").font(.headline)
                    HStack {
                        ForEach(0..<4) { index in
                            Button { change { _ = $0.decorate(roomID: roomID, theme: index) }; notice = nil } label: {
                                VStack {
                                    Circle().fill(Color(hex: Motel.themeColors[index])).frame(width: 42, height: 42).overlay(Circle().stroke(index == theme ? gold : .clear, lineWidth: 3))
                                    Text(Motel.themeNames[index]).font(.caption)
                                }.frame(maxWidth: .infinity)
                            }.disabled(theme == index || motel.cash < 25).accessibilityIdentifier("theme\(index)")
                        }
                    }
                    Text("Furniture / level \(level + 1) of 3").font(.headline)
                    Text(roomID == nil ? "Improve your reception desk, add a plant and a lounge corner. Each upgrade increases all room rates by 15." : "Add a better bed, a rug, and a reading nook. Each upgrade increases this room's nightly rate by 30.").font(.subheadline).foregroundStyle(.secondary)
                    Button(level == 2 ? "Fully furnished" : "Upgrade furniture / \(price) coins") { change { _ = $0.upgrade(roomID: roomID) }; notice = nil }
                        .buttonStyle(MotelButtonStyle()).disabled(level == 2 || motel.cash < price).accessibilityIdentifier("upgradeFurniture")
                    Text("Balance: \(motel.cash) coins. Save at the desk to keep your changes.").font(.caption).foregroundStyle(gold)
                }.padding(20)
            }.background(Color(hex: 0x172A25)).navigationTitle(roomID == nil ? "Your office" : "Room \(101 + (roomID ?? 0))")
                .toolbar { Button("Done") { decorating = nil; officeEditor = false } }
        }.tint(gold).presentationDetents([.large])
    }
    private func roomScene(_ visit: RoomVisit) -> some View {
        let room = motel.rooms.first { $0.id == visit.roomID } ?? MotelRoom(id: 0)
        let item = visit.nearbyLoot
        let alreadyTaken = item.map { visit.loot.contains($0) || room.stolen.contains($0) } ?? false
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ROOM \(room.number)").font(.title2.monospaced().bold())
                    Text(visit.sneaking ? "KEEP QUIET. KEEP YOUR DISTANCE." : "YOUR MOTEL, ONE ROOM AT A TIME.").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(gold)
                }
                Spacer()
                Text("\(visit.pocket) coins").font(.subheadline.bold())
            }
            MotelRoomCanvas(room: room, visit: visit, x: Double(visit.player.x), y: Double(visit.player.y))
                .animation(.linear(duration: 0.18), value: visit.player)
                .clipShape(RoundedRectangle(cornerRadius: 20)).frame(maxHeight: .infinity)
                .accessibilityElement(children: .ignore).accessibilityLabel("Room interior. Column \(visit.player.x), row \(visit.player.y)").accessibilityIdentifier("motelRoom")
            if visit.sneaking {
                HStack { Text("SUSPICION").font(.caption.monospaced().bold()); Spacer(); Text("\(visit.alert)%").font(.headline.monospaced()).foregroundStyle(visit.alert >= 70 ? .red : gold) }
                ProgressView(value: Double(visit.alert), total: 100).tint(visit.alert >= 70 ? .red : gold)
                Text("Caught at 100% or beside the guest. Search marked belongings, then leave by the bottom door.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Take a look around. Walk to the bottom door to return to the motel.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                VStack(spacing: 3) {
                    roomDirection("chevron.up", 0, -1, "Creep north")
                    HStack(spacing: 3) {
                        roomDirection("chevron.left", -1, 0, "Creep west")
                        Image(systemName: "figure.walk").frame(width: 44, height: 40)
                        roomDirection("chevron.right", 1, 0, "Creep east")
                    }
                    roomDirection("chevron.down", 0, 1, "Creep south")
                }
                Spacer()
                VStack(spacing: 8) {
                    if visit.sneaking {
                        Button(item.map { alreadyTaken ? "Already taken" : "Take \(RoomVisit.lootNames[$0])" } ?? "Find belongings") {
                            held = nil; change { _ = $0.steal() }
                        }.buttonStyle(MotelButtonStyle()).disabled(item == nil || alreadyTaken).accessibilityIdentifier("stealItem")
                        if let item, !alreadyTaken { Text("+\(RoomVisit.lootValues[item]) coins / +\(RoomVisit.lootNoise[item]) suspicion").font(.caption2).foregroundStyle(gold) }
                    }
                    Button("Leave by door") { held = nil; change { $0.leave() } }
                        .buttonStyle(MotelButtonStyle(subdued: true)).disabled(visit.player.distance(to: Tile(x: 4, y: 8)) > 1).accessibilityIdentifier("leaveRoom")
                }.frame(maxWidth: 180)
            }.frame(height: 145)
        }.padding(18)
    }
    private func roomDirection(_ symbol: String, _ dx: Int, _ dy: Int, _ label: String) -> some View {
        HoldDirection(symbol: symbol, label: label, isActive: held == Tile(x: dx, y: dy)) { pressed in
            if pressed { held = Tile(x: dx, y: dy) }
            else if held == Tile(x: dx, y: dy) { held = nil }
        } singleStep: { held = nil; change { $0.move(dx: dx, dy: dy) } }
    }
    private var gameOver: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "eye.fill").font(.system(size: 60)).foregroundStyle(Color(hex: 0xDE927D))
            Text("CAUGHT").font(.system(size: 46, weight: .black, design: .rounded)).tracking(5)
            Text("The guest saw you.").font(.title2.bold())
            Text("Your motel story ends here.\nRestore your last checkpoint to try again. Anything earned or changed after that save will be lost.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Load last save") { held = nil; game = Game.load(); notice = "Your last checkpoint has been restored." }
                .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("restoreCheckpoint")
            Spacer()
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: 0x2C292A))
    }
    private func change(_ action: (inout Motel) -> Void) {
        guard var current = game.motel else { return }
        action(&current)
        game.motel = current
    }
}
