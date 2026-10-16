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

func motelRules() {
    var dream = Game()
    dream.wakeUp()
    require(dream.motel == nil, "Cannot wake before prologue completes")
    dream.coins = 500
    require(dream.readyToWake, "Reaching the fund must unlock wake-up")
    dream.wakeUp()
    require(dream.motel?.rooms.count == 3 && dream.motel?.cash == 180, "Start with exactly three rooms and working capital")
    dream.motel!.cash = 222
    dream.wakeUp()
    require(dream.motel?.cash == 222, "Wake-up cannot reset a running motel")

    var business = Motel()
    require(!business.expand(), "Expansion requires funds")
    let guest = business.waiting[0]
    require(business.checkIn(guestID: guest.id, roomID: 0), "Guest can check into a ready room")
    require(business.cash == 260 && business.occupancy == 1, "Check-in pays the agreed stay exactly once")
    require(!business.checkIn(guestID: guest.id, roomID: 1), "Cannot charge one guest twice")
    require(!business.checkIn(guestID: business.waiting[0].id, roomID: 0), "Cannot double-book a room")
    require(!business.decorate(roomID: 0, theme: 2), "Do not redecorate occupied rooms")
    require(!business.clean(0), "Cannot clean an occupied room")
    require(business.expand() && business.rooms.count == 4 && business.cash == 10, "Expansion creates one room and charges its price")
    require(!business.upgrade(roomID: 1), "Upgrades cannot overdraw cash")
    require(business.nextDay(), "End day at the desk")
    require(business.rooms[0].dirty && business.rooms[0].guest == nil, "One-night guests leave a dirty room")
    require(!business.checkIn(guestID: business.waiting[0].id, roomID: 0), "Dirty rooms cannot be rented")
    require(business.clean(0) && business.rooms[0].available, "Free cleaning prevents a money softlock")
    require(business.checkIn(guestID: business.waiting[0].id, roomID: 0), "Cleaned rooms can be rented again")

    var decor = Motel()
    decor.cash = 2000
    require(decor.decorate(roomID: 0, theme: 2) && decor.rooms[0].theme == 2, "Room colors are customizable")
    let balance = decor.cash
    require(!decor.decorate(roomID: 0, theme: 2) && decor.cash == balance, "Selected paint is not charged twice")
    require(!decor.decorate(roomID: 0, theme: 9), "Invalid palette indices rejected")
    require(decor.upgrade(roomID: 0) && decor.rate(for: decor.rooms[0]) == 110, "Room furnishing improves nightly rate")
    require(decor.decorate(roomID: nil, theme: 3) && decor.officeTheme == 3, "Office color is independent")
    require(decor.upgrade(roomID: nil) && decor.rate(for: decor.rooms[0]) == 125, "Office upgrade improves all rates")
    require(decor.rooms[1].theme == 0, "Room themes stay independent")
    decor.cash = 10000
    while !decor.goalReached { require(decor.expand(), "Expansion should reach the nine-room goal") }
    require(decor.rooms.count == 9 && !decor.expand(), "Motel goal caps construction at nine rooms")

    var stays = Motel()
    let longStay = stays.waiting[1]
    require(stays.checkIn(guestID: longStay.id, roomID: 1), "Two-night guest can check in")
    require(stays.cash == 340, "Two-night stay is prepaid")
    _ = stays.nextDay()
    require(stays.rooms[1].guest != nil && stays.rooms[1].nightsLeft == 1, "Two-night guest stays another night")
    _ = stays.nextDay()
    require(stays.rooms[1].guest == nil && stays.rooms[1].dirty, "Two-night stay checks out on its due day")

    // Confirm all loot can be approached and the room exit is reachable.
    var seen: Set<Tile> = [Tile(x: 4, y: 7)]
    var frontier = Array(seen)
    var at = 0
    while at < frontier.count {
        let tile = frontier[at]; at += 1
        for (dx, dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
            let next = Tile(x: tile.x + dx, y: tile.y + dy)
            if !RoomVisit.blocked(next), seen.insert(next).inserted { frontier.append(next) }
        }
    }
    require(seen.contains(Tile(x: 4, y: 8)), "Interior exit reachable")
    for item in RoomVisit.lootTiles { require(seen.contains { $0.distance(to: item) == 1 }, "All belongings reachable") }

    var theft = Motel()
    _ = theft.checkIn(guestID: 10, roomID: 0)
    let legalCash = theft.cash
    require(theft.enter(0) && theft.visit?.sneaking == true, "Occupied rooms start a stealth visit")
    require(!theft.nextDay() && !theft.expand(), "No managing the motel during a break-in")
    require(!theft.steal(), "Cannot steal belongings remotely")
    theft.move(dx: 1, dy: 0)
    theft.move(dx: 0, dy: -1)
    require(theft.visit?.nearbyLoot == 1, "Actual movement reaches the watch")
    require(theft.steal(), "Player can steal nearby belongings")
    require(!theft.steal(), "Belongings can only be taken once")
    require(theft.cash == legalCash, "Loot is not banked while inside")
    theft.leave()
    require(theft.visit != nil, "Cannot teleport to the exit")
    theft.move(dx: 0, dy: 1)
    theft.move(dx: -1, dy: 0)
    theft.move(dx: 0, dy: 1)
    require(theft.visit == nil && theft.cash == legalCash + 70, "Escaping banks the stolen item")
    _ = theft.enter(0)
    theft.move(dx: 1, dy: 0)
    theft.move(dx: 0, dy: -1)
    require(!theft.steal(), "Re-entering does not duplicate a stolen item")

    var checkpoint = Game()
    checkpoint.coins = 545
    checkpoint.wakeUp()
    _ = checkpoint.motel!.checkIn(guestID: 10, roomID: 0)
    let defaults = UserDefaults(suiteName: "LittleHaven.MotelTests")!
    checkpoint.save(to: defaults)
    let savedData = defaults.data(forKey: "littlehaven.save.v1")
    checkpoint.motel!.cash += 123
    _ = checkpoint.motel!.enter(0)
    checkpoint.save(to: defaults)
    require(defaults.data(forKey: "littlehaven.save.v1") == savedData, "Sneaking cannot overwrite checkpoint")
    checkpoint.motel!.visit!.alert = 98
    checkpoint.motel!.tick()
    require(checkpoint.motel!.caught, "Full suspicion triggers game over")
    let frozen = checkpoint.motel!.visit!.player
    checkpoint.motel!.move(dx: -1, dy: 0)
    checkpoint.motel!.leave()
    checkpoint.save(to: defaults)
    require(checkpoint.motel!.visit!.player == frozen, "Caught players cannot move or escape")
    require(defaults.data(forKey: "littlehaven.save.v1") == savedData, "Game over cannot overwrite checkpoint")
    let restored = Game.load(from: defaults)
    require(restored.motel?.cash == 260 && restored.motel?.occupancy == 1 && restored.motel?.visit == nil && restored.motel?.caught == false, "Restore returns to the exact safe checkpoint")

    var seenByGuest = Motel()
    _ = seenByGuest.checkIn(guestID: 10, roomID: 0)
    _ = seenByGuest.enter(0)
    seenByGuest.visit!.player = Tile(x: 5, y: 3)
    seenByGuest.tick()
    require(seenByGuest.caught, "Getting too close to the guest triggers game over")

    // Legacy save format has no motel field: players keep their prologue progress.
    let legacy = #"{"player":{"x":15,"y":7},"coins":45,"gifts":[0,1,2,3,4,5,6],"ownsHouse":true,"inside":false,"facing":0,"steps":10}"#
    defaults.set(Data(legacy.utf8), forKey: "littlehaven.save.v1")
    var migrated = Game.load(from: defaults)
    require(migrated.readyToWake && migrated.gifts.count == 7, "Old cottage owners migrate into wake-up scene")
    migrated.wakeUp()
    migrated.save(to: defaults)
    require(Game.load(from: defaults).motel?.rooms.count == 3, "Motel saves round trip")
    defaults.removePersistentDomain(forName: "LittleHaven.MotelTests")
    print("PASS: motel economy, occupancy, customization, expansion, interior paths, theft, detection, checkpoint rollback, legacy saves")
}
motelRules()

func worldRules() {
    // Every physical entrance and construction plot must connect to the grounds.
    var seen: Set<Tile> = [MotelGrounds.officeDoor]
    var frontier = Array(seen)
    var index = 0
    while index < frontier.count {
        let tile = frontier[index]; index += 1
        for (dx, dy) in [(0,1),(1,0),(-1,0),(0,-1)] {
            let next = Tile(x: tile.x + dx, y: tile.y + dy)
            if !MotelGrounds.blocked(next), seen.insert(next).inserted { frontier.append(next) }
        }
    }
    for room in 0..<9 { require(seen.contains(MotelGrounds.roomDoor(room)), "Every room plot needs a walkable entrance") }
    require(seen.contains(MotelGrounds.gate), "Road gate reachable")
    require(seen.contains { $0.distance(to: MotelGrounds.sign) == 1 }, "Build sign approachable")
    for guest in Motel.arrivals(day: 1, count: 10) { require(seen.contains(MotelGrounds.guestTile(guest.id)), "Guest waiting points reachable") }

    var walk = Motel()
    walk.initializeWorld()
    require(walk.worldState.place == .office, "Start the shift inside the office")
    require(!walk.chargeGuest(10, roomID: 0), "Cannot charge customers remotely")
    require(!walk.collectTools(), "Cannot collect cleaning tools remotely")
    walk.moveActor(dx: 0, dy: 1)
    require(walk.worldState.place == .grounds && walk.actorTile == Tile(x: 6, y: 10), "Office door leads onto the actual grounds")
    walk.moveActor(dx: -1, dy: 0)
    walk.moveActor(dx: 0, dy: 1)
    require(walk.nearbyAction == .guest(10), "Walk beside the waiting guest to talk")
    require(!walk.chargeGuest(11, roomID: 0), "Cannot charge a different guest through the nearby interaction")
    require(walk.chargeGuest(10, roomID: 0) && walk.cash == 260, "Nearby payment assigns the room and charges exactly once")
    require(!walk.guestPresent(in: 0) && walk.worldState.travellers.count == 1, "Guest must walk to the room before appearing inside")
    for _ in 0..<150 {
        walk.tickWorld()
        for actor in walk.worldState.travellers { require(!MotelGrounds.blocked(actor.player), "Guests cannot walk through buildings or water") }
        if walk.worldState.travellers.isEmpty { break }
    }
    require(walk.worldState.travellers.isEmpty && walk.guestPresent(in: 0), "Guest pathfinding reaches the assigned room")
    walk.moveActor(dx: 1, dy: 0)
    require(walk.actorTile == Tile(x: 5, y: 11), "Cannot walk through a waiting customer")
    walk.moveActor(dx: 0, dy: -1)
    walk.moveActor(dx: 1, dy: -1)
    require(walk.worldState.place == .office, "Diagonal movement can reach an unobstructed doorway")
    walk.world!.player = Tile(x: 4, y: 5)
    walk.moveActor(dx: 0, dy: -1)
    require(walk.actorTile == Tile(x: 4, y: 5) && walk.atSavePoint, "Office desk has collision and a nearby save point")
    walk.world!.player = Tile(x: 2, y: 5)
    require(walk.collectTools() && walk.worldState.hasCleaningKit, "Cleaning kit is collected at the actual closet")

    var service = Motel()
    service.initializeWorld()
    service.rooms[0].dirty = true
    require(!service.cleanNearbyTask(), "Cannot clean a room from the office")
    service.world!.place = .grounds
    service.world!.player = Tile(x: 16, y: 9)
    require(service.useEntrance() && service.visit?.roomID == 0, "Walk through a room's own entrance")
    service.visit!.player = Tile(x: 3, y: 3)
    require(service.cleaningTarget == 0 && !service.cleanNearbyTask(), "Cleaning requires supplies")
    service.world!.hasCleaningKit = true
    require(service.cleanNearbyTask() && service.rooms[0].dirty, "Making the bed does not remotely clean the whole room")
    require(!service.cleanNearbyTask(), "Finished cleaning tasks cannot be repeated")
    service.moveActor(dx: 1, dy: 0)
    service.moveActor(dx: 0, dy: 1)
    service.moveActor(dx: 0, dy: 1)
    require(service.cleaningTarget == 2 && service.cleanNearbyTask(), "Walk to the actual spill to mop it")
    service.moveActor(dx: -1, dy: 0)
    service.moveActor(dx: 0, dy: 1)
    require(service.cleaningTarget == 1 && service.cleanNearbyTask(), "Walk to the trash to collect it")
    require(!service.rooms[0].dirty && service.rooms[0].cleanedTasks?.count == 3, "Only all three physical tasks make a room rentable")
    require(!service.paintNearby(2), "Cannot repaint from across the room")
    service.visit!.player = Tile(x: 6, y: 2)
    require(service.paintNearby(2) && service.rooms[0].theme == 2 && service.cash == 155, "Paint cabinet changes the room for its stated cost")
    require(!service.paintNearby(2), "No duplicate paint charges")
    service.visit!.player = Tile(x: 3, y: 3)
    require(service.furnishNearby() && service.rooms[0].furniture == 1 && service.cash == 65, "Bed interaction upgrades furnishings")
    service.visit!.player = Tile(x: 4, y: 7)
    require(service.useEntrance() && service.visit == nil && service.actorTile == Tile(x: 16, y: 9), "Leaving a room returns to that room on the grounds")
    service.world!.place = .office
    service.world!.player = Tile(x: 6, y: 5)
    require(service.paintNearby(1) && service.officeTheme == 1, "Office paint has its own physical cabinet")

    var build = Motel()
    build.initializeWorld()
    build.cash = 600
    require(!build.buildNearby(), "No remote construction menu")
    build.world!.place = .grounds
    build.world!.player = Tile(x: 12, y: 27)
    require(build.buildNearby() && build.rooms.count == 4 && build.cash == 350, "Construction sign expands the physical motel")
    build.world!.player = Tile(x: 3, y: 17)
    build.moveActor(dx: -1, dy: 1)
    require(build.actorTile == Tile(x: 3, y: 17), "Diagonal movement cannot cut pool corners")
    build.world!.player = Tile(x: 2, y: 19)
    build.moveActor(dx: 1, dy: 0)
    require(build.actorTile == Tile(x: 2, y: 19), "Pool water blocks movement")

    var morning = Motel()
    morning.initializeWorld()
    _ = morning.checkIn(guestID: 10, roomID: 0)
    require(!morning.restAtBed(), "Next day requires walking to the bed")
    morning.world!.player = Tile(x: 2, y: 3)
    require(morning.restAtBed() && morning.day == 2 && morning.rooms[0].dirty, "Sleeping advances stays and creates physical room work")
    require(morning.worldState.travellers.count == 1, "Checked-out guests walk toward the exit")

    let defaults = UserDefaults(suiteName: "LittleHaven.WorldTests")!
    var checkpoint = Game()
    checkpoint.coins = 545
    checkpoint.wakeUp()
    checkpoint.motel = service
    checkpoint.save(to: defaults)
    let saved = Game.load(from: defaults)
    require(saved.motel?.world?.hasCleaningKit == true && saved.motel?.rooms[0].theme == 2 && saved.motel?.rooms[0].cleanedTasks?.count == 3, "Tools, room work and position persist in checkpoints")
    var legacy = Game()
    legacy.coins = 545
    legacy.wakeUp()
    legacy.motel!.cash = 333
    legacy.motel!.world = nil
    legacy.save(to: defaults)
    var migrated = Game.load(from: defaults).motel!
    migrated.initializeWorld()
    require(migrated.cash == 333 && migrated.rooms.count == 3 && migrated.worldState.place == .office, "Existing motel saves keep their business and gain a walkable office")
    defaults.removePersistentDomain(forName: "LittleHaven.WorldTests")
    print("PASS: grounds and entrance reachability, physical payments, guest paths, collisions, hands-on cleaning, object customization, construction, sleep, world checkpoints")
}
worldRules()

var crossingDoor = Motel()
crossingDoor.initializeWorld()
crossingDoor.world!.place = .grounds
crossingDoor.world!.player = Tile(x: 15, y: 8)
crossingDoor.moveActor(dx: 1, dy: 0)
require(crossingDoor.visit == nil, "Walking along a room frontage must not enter the room")
crossingDoor.moveActor(dx: 0, dy: 1)
crossingDoor.moveActor(dx: 0, dy: -1)
require(crossingDoor.visit?.roomID == 0, "Walking into a vacant room door enters it")
print("PASS: directional room entrances")

// Shared engine maps preserve collision, portals and event triggers.
require(RPGMaps.grounds.blocked(Tile(x: 3,y: 18)), "Engine map blocks pool water")
require(!RPGMaps.grounds.canStep(from: Tile(x: 3,y: 17),dx: -1,dy: 1), "Engine prevents diagonal corner cutting")
require(RPGMaps.office.events(at: Tile(x: 2,y: 5),trigger: .action).first?.id == "tools", "Engine dispatches adjacent object events")
require(RPGMaps.office.events(at: Tile(x: 4,y: 8),trigger: .playerTouch).first?.destination == "grounds", "Engine defines linked map transfer")
let mapRoundTrip = try! JSONDecoder().decode(RPGMapDefinition.self, from: JSONEncoder().encode(RPGMaps.grounds))
require(mapRoundTrip.events.count == 11 && mapRoundTrip.blocked(Tile(x: 14,y: 4)), "Map database serializes events and collision")
print("PASS: RPG map collision, events, transfers and map serialization")
