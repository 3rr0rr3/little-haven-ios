import Foundation

func require(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
}
// Check every neighbor and the house are reachable from the actual starting tile.
var visited: Set<Tile> = [Game().player]
var queue = [Game().player]
var cursor = 0
while cursor < queue.count {
    let tile = queue[cursor]
    cursor += 1
    for (dx, dy) in [(0, 1), (1, 0), (-1, 0), (0, -1)] {
        let next = Tile(x: tile.x + dx, y: tile.y + dy)
        if !Town.blocked(next), visited.insert(next).inserted { queue.append(next) }
    }
}
var game = Game()
require(!game.ask(0), "Cannot collect a gift remotely")
require(!game.buyHouse(), "Cannot buy remotely or without funds")
for neighbor in Town.neighbors {
    guard let approach = visited.first(where: { $0.distance(to: neighbor.tile) == 1 }) else { fatalError("Unreachable neighbor: \(neighbor.name)") }
    game.player = approach
    require(game.ask(neighbor.id), "First gift must succeed")
    let balance = game.coins
    require(!game.ask(neighbor.id), "Repeated gift must be rejected")
    require(game.coins == balance, "Repeated gift changed balance")
}
require(game.coins == 545, "Town gifts should total 545")
require(visited.contains(Town.door), "House must be reachable")
game.player = Town.door
require(game.buyHouse(), "Funded player can buy house")
require(game.coins == 45 && game.ownsHouse, "Purchase deducts exactly 500")
require(!game.buyHouse(), "Cannot buy twice")
game.enterHouse()
require(game.inside, "Owner can enter")
game.move(dx: 0, dy: 1)
game.move(dx: 0, dy: 1)
require(!game.inside && game.player == Town.door, "Interior door returns to town")
game.player = Tile(x: 1, y: 1)
game.move(dx: -1, dy: 0)
require(game.player == Tile(x: 1, y: 1), "Map boundaries block movement")
game.move(dx: 1, dy: 1)
require(game.player == Tile(x: 1, y: 1), "Diagonal inputs rejected")
let defaults = UserDefaults(suiteName: "LittleHaven.Tests")!
game.save(to: defaults)
let loaded = Game.load(from: defaults)
require(loaded.ownsHouse && loaded.coins == 45 && loaded.gifts.count == 7, "Save round trip failed")
defaults.set(Data("broken".utf8), forKey: "littlehaven.save.v1")
require(Game.load(from: defaults).coins == 0, "Corrupt save must recover")
defaults.removePersistentDomain(forName: "LittleHaven.Tests")
print("PASS: reachability, gifts, purchase, interior, collision, persistence, corrupt save")
