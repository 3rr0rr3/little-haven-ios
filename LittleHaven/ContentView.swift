import SwiftUI

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}

struct ContentView: View {
    @State private var game = Game.load()
    @State private var conversation: Neighbor?
    @State private var message: String?
    @State private var showHouse = false
    @State private var showJournal = false
    @State private var reset = false
    private let cream = Color(hex: 0xF5E7C8)
    private let gold = Color(hex: 0xEFC977)

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LITTLE HAVEN").font(.system(size: 22, weight: .black, design: .rounded)).tracking(2)
                        Text(game.inside ? "YOUR COTTAGE · HOME AT LAST" : "WILLOW TOWN · A NEW BEGINNING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                            .foregroundStyle(cream.opacity(0.6))
                    }
                    Spacer(minLength: 4)
                    Button { showJournal = true } label: { Image(systemName: "book.closed.fill").frame(width: 44, height: 44).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)) }
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
                    TownCanvas(game: game)
                    Text(game.inside ? "HOME, SWEET HOME" : "WILLOW TOWN")
                        .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1.5)
                        .padding(9).background(Color(hex: 0x203A30).opacity(0.9), in: Capsule()).padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(cream.opacity(0.15), lineWidth: 2))
                .accessibilityLabel(game.inside ? "Inside your cottage" : "Town map. Your position: column \(game.player.x), row \(game.player.y)")
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    Circle().fill(gold).frame(width: 5, height: 5)
                    Text(hint).font(.system(size: 11, weight: .medium)).lineLimit(2)
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
            Text(game.ownsHouse ? "Your own little corner of Little Haven. Welcome home." : game.coins >= 500 ? "A sunny room, a warm bed, and a fresh start. Ready to make it yours?" : "FOR SALE · 500 coins\nYou need \(500 - game.coins) more. Ask the townspeople if they can help with your cottage fund.")
        }
        .alert("Little Haven", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Continue") { message = nil }
        } message: { Text(message ?? "") }
    }

    private var hint: String {
        if game.inside { return "You made it home. Walk down through the door to go outside." }
        if let person = game.nearby { return "\(person.name), the \(person.role.lowercased()) · Tap TALK" }
        if game.atHouse { return game.ownsHouse ? "Your cottage · Tap ENTER" : "Cottage for sale · Tap COTTAGE" }
        return game.coins >= 500 && !game.ownsHouse ? "Your fund is ready! Find the cottage in the northeast." : "Walk beside a neighbor, then tap TALK to ask for help."
    }
    private func direction(_ symbol: String, dx: Int, dy: Int, label: String) -> some View {
        Button { game.move(dx: dx, dy: dy); game.save() } label: {
            Image(systemName: symbol).font(.system(size: 16, weight: .black)).frame(width: 44, height: 40)
                .background(Color(hex: 0x344B40), in: RoundedRectangle(cornerRadius: 10))
        }.accessibilityLabel(label)
    }
    private func interact() {
        if let person = game.nearby { conversation = person }
        else if game.atHouse { showHouse = true }
        else { message = game.inside ? "A little bed, a well-loved rug, and room for new memories. This is your home now." : "Move right next to a neighbor to talk. Look for the people with a gold dot above their heads. The cottage is in the northeast." }
    }
    private func dialogue(_ person: Neighbor) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "person.crop.square.fill").font(.system(size: 42)).foregroundStyle(Color(hex: person.color))
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
                Label("\(person.gift) coins contributed · Thank you!", systemImage: "heart.fill").font(.subheadline.bold()).foregroundStyle(gold)
            }
        }.padding(24).foregroundStyle(cream).presentationBackground(Color(hex: 0x263D33))
    }
    private var journal: some View {
        NavigationStack {
            List {
                Section("A place to call home") {
                    Text(game.ownsHouse ? "You bought the Willow Cottage! Visit your home whenever you like." : "Raise 500 coins by asking the seven neighbors for help. Each can contribute once. Buy the cottage in the northeast, then step inside.")
                    Text("Use the direction buttons to walk. Stand one tile beside a person and tap TALK. Buildings, trees, and the pond block your way.")
                }
                Section("Your neighbors · \(game.gifts.count)/7") {
                    ForEach(Town.neighbors) { person in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(person.name + " · " + person.role).font(.headline)
                                Text("Column \(person.tile.x), row \(person.tile.y)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(game.gifts.contains(person.id) ? "+\(person.gift) ✓" : "Say hello").foregroundStyle(gold).font(.caption.bold())
                        }
                    }
                }
                Section {
                    Text("Progress saves automatically on this device. All coins are fictional game currency.").font(.footnote)
                    Button("Start a new adventure", role: .destructive) { reset = true }
                }
            }.navigationTitle("Your journal").toolbar { Button("Done") { showJournal = false } }
                .confirmationDialog("Erase your saved adventure?", isPresented: $reset, titleVisibility: .visible) {
                    Button("Start over", role: .destructive) { game = Game(); game.save(); showJournal = false }
                }
        }.tint(gold)
    }
}
