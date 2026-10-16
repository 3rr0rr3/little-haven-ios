import Foundation

struct Tile: Codable, Hashable {
    var x: Int
    var y: Int
    func distance(to other: Tile) -> Int { abs(x - other.x) + abs(y - other.y) }
}

struct Neighbor: Identifiable {
    let id: Int
    let name: String
    let role: String
    let tile: Tile
    let gift: Int
    let color: UInt32
    let greeting: String
    let reply: String
}

enum Town {
    static let width = 20
    static let height = 23
    static let door = Tile(x: 15, y: 7)
    static let neighbors: [Neighbor] = [
        .init(id: 0, name: "Milo", role: "Gardener", tile: .init(x: 8, y: 17), gift: 65, color: 0xDD9567, greeting: "New roots take a little help. Are you the traveler hoping to buy the empty cottage?", reply: "Here's 65 coins from my flower stall. Plant something beautiful when you move in!"),
        .init(id: 1, name: "June", role: "Baker", tile: .init(x: 4, y: 9), gift: 80, color: 0xE7B7C8, greeting: "A home is where the bread smells best. What brings you to Little Haven?", reply: "Take 80 coins. When you get your keys, I'll bring the first loaf."),
        .init(id: 2, name: "Theo", role: "Fisher", tile: .init(x: 14, y: 17), gift: 70, color: 0x71A8C9, greeting: "The pond is quiet today. Sit a while. What's on your mind?", reply: "I saved 70 coins from yesterday's catch. Your dream sounds worth sharing."),
        .init(id: 3, name: "Fern", role: "Librarian", tile: .init(x: 8, y: 5), gift: 90, color: 0xA998C8, greeting: "Every good story needs a place to begin. Have you found yours?", reply: "90 coins for your next chapter. You can borrow a book for the new shelf, too."),
        .init(id: 4, name: "Otis", role: "Carpenter", tile: .init(x: 4, y: 15), gift: 100, color: 0xC98559, greeting: "That little cottage has solid beams. Built them myself, years ago.", reply: "Let me put 100 coins toward it. A house deserves someone who cares."),
        .init(id: 5, name: "Pip", role: "Courier", tile: .init(x: 11, y: 11), gift: 55, color: 0xE2BD58, greeting: "Letters, parcels, big dreams! Got an address for me yet?", reply: "Here are 55 coins. I can't wait to deliver your first letter!"),
        .init(id: 6, name: "Rose", role: "Town elder", tile: .init(x: 16, y: 10), gift: 85, color: 0xB47EAD, greeting: "We all arrived as strangers once. What would help you feel at home?", reply: "Take 85 coins, dear. One day you'll welcome someone new, too.")
    ]
    // Inclusive building footprints; doors are approached from the path below.
    static let buildings = [(2, 3, 5, 6), (13, 3, 17, 6), (2, 11, 5, 13)]
    static func blocked(_ t: Tile) -> Bool {
        if t.x < 1 || t.x >= width - 1 || t.y < 1 || t.y >= height - 1 { return true }
        if buildings.contains(where: { t.x >= $0.0 && t.x <= $0.2 && t.y >= $0.1 && t.y <= $0.3 }) { return true }
        if (14...17).contains(t.x) && (13...15).contains(t.y) { return true }
        return neighbors.contains(where: { $0.tile == t })
    }
}

struct Game: Codable {
    static let housePrice = 500
    var player = Tile(x: 9, y: 19)
    var coins = 0
    var gifts: Set<Int> = []
    var ownsHouse = false
    var inside = false
    var facing = 0
    var steps = 0
    var motel: Motel?
    var readyToWake: Bool { motel == nil && (coins >= Self.housePrice || ownsHouse) }

    mutating func wakeUp() {
        guard readyToWake else { return }
        motel = Motel()
        inside = false
    }

    var nearby: Neighbor? {
        guard !inside else { return nil }
        return Town.neighbors.first { player.distance(to: $0.tile) <= 1 }
    }
    var atHouse: Bool { !inside && player.distance(to: Town.door) <= 1 }
    mutating func move(dx: Int, dy: Int) {
        guard abs(dx) + abs(dy) == 1 else { return }
        facing = dy > 0 ? 0 : dx < 0 ? 1 : dx > 0 ? 2 : 3
        let next = Tile(x: player.x + dx, y: player.y + dy)
        if inside {
            if next == Tile(x: 4, y: 8) {
                inside = false
                player = Town.door
                return
            }
            guard (1...7).contains(next.x), (2...7).contains(next.y) else { return }
            guard !((1...2).contains(next.x) && (2...3).contains(next.y)), next != Tile(x: 6, y: 2) else { return }
        } else if Town.blocked(next) { return }
        player = next
        steps += 1
    }
    @discardableResult mutating func ask(_ id: Int) -> Bool {
        guard let person = nearby, person.id == id, !gifts.contains(id) else { return false }
        gifts.insert(id)
        coins += person.gift
        return true
    }
    @discardableResult mutating func buyHouse() -> Bool {
        guard atHouse, !ownsHouse, coins >= Self.housePrice else { return false }
        coins -= Self.housePrice
        ownsHouse = true
        return true
    }
    mutating func enterHouse() {
        guard ownsHouse, atHouse else { return }
        inside = true
        player = Tile(x: 4, y: 6)
    }
    static func load(from defaults: UserDefaults = .standard) -> Game {
        guard let data = defaults.data(forKey: "littlehaven.save.v1"),
              let game = try? JSONDecoder().decode(Game.self, from: data),
              game.coins >= 0, game.gifts.isSubset(of: Set(Town.neighbors.map(\.id))),
              (!game.inside || game.ownsHouse) else { return Game() }
        return game
    }
    func save(to defaults: UserDefaults = .standard) {
        guard motel?.canSave ?? true else { return }
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "littlehaven.save.v1") }
    }
}
