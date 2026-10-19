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
    require(decor.rooms[1].theme == 1, "Room themes stay independent")
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
    require(theft.visit == nil && theft.cash == legalCash && theft.household.stolen == [1], "Escaping carries the stolen item without paying cash")
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
    require(walk.receptionTools(), "Tap the office closet to collect tools from the desk")
    _ = walk.leaveReception()
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
    require(walk.actorTile == Tile(x:4,y:5), "Office desk collision blocks movement without teleporting the player")
    walk.world!.player = Tile(x: 2, y: 5)
    require(walk.receptionTools() && walk.worldState.hasCleaningKit, "Cleaning kit is collected at the actual closet")

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
    require(morning.isAtReception, "Sleep is available by tapping the office bed")
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
require(RPGMaps.office.events(at: Tile(x: 1,y: 7),trigger: .action).contains { $0.id == "tools" }, "Engine dispatches adjacent object events")
require(RPGMaps.office.events(at: Tile(x: 7,y: 13),trigger: .action).first?.destination == "grounds", "Engine defines linked map transfer")
let mapRoundTrip = try! JSONDecoder().decode(RPGMapDefinition.self, from: JSONEncoder().encode(RPGMaps.grounds))
require(mapRoundTrip.events.count == 11 && mapRoundTrip.blocked(Tile(x: 14,y: 4)), "Map database serializes events and collision")
print("PASS: RPG map collision, events, transfers and map serialization")

func receptionRules() {
    var motel = Motel()
    motel.initializeWorld()
    for direction in [Tile(x:0,y:1),Tile(x:1,y:0),Tile(x:-1,y:0)] { motel.moveActor(dx:direction.x,dy:direction.y) }
    require(motel.actorTile == OfficeReception.clerk && motel.isAtReception, "Walking around office desk respects collision")
    motel.moveActor(dx:1,dy:0)
    require(motel.actorTile == Tile(x:5,y:3), "Player walks inside office")
    motel.initializeWorld(); motel.tickReception()
    require(motel.actorTile == Tile(x:5,y:3), "Office initialization and guest ticks never reset player position")
    motel.moveActor(dx:-1,dy:0)
    require(!motel.acceptReceptionGuest(roomID:0) && !motel.declineReceptionGuest(), "Clients cannot be decided before arriving")
    let familyStart = motel.reception.hildarelys
    for _ in 0..<12 { motel.tickReception() }
    require(motel.receptionGuest?.id == 10 && motel.reception.visitor?.tile == Tile(x:4,y:6), "Client walks from door to front of desk")
    require(motel.acceptReceptionGuest(roomID:0) && motel.cash == 260, "Accepting charges the correct room price once")
    require(!motel.acceptReceptionGuest(roomID:1) && motel.cash == 260, "Double acceptance cannot charge twice")
    require(!motel.guestPresent(in:0), "Accepted visitor is not teleported into room while leaving reception")
    for _ in 0..<11 { motel.tickReception() }
    require(motel.worldState.travellers.contains { $0.id == 10 && $0.destination == MotelGrounds.roomDoor(0) }, "Accepted client leaves office and walks to assigned room")
    for _ in 0..<12 { motel.tickReception() }
    require(motel.receptionGuest?.id == 11, "Next client arrives after first leaves")
    let before = motel.cash
    require(motel.declineReceptionGuest() && motel.cash == before && !motel.waiting.contains { $0.id == 11 }, "Declining removes client without payment or occupancy")
    for _ in 0..<11 { motel.tickReception() }
    require(motel.worldState.travellers.contains { $0.id == 11 && $0.destination == MotelGrounds.gate }, "Declined client walks toward road")
    for _ in 0..<4 { motel.tickReception() }
    require(motel.reception.hildarelys != familyStart, "Hildarelys walks around the office")
    require(motel.leaveReception() && motel.actorTile == Tile(x:6,y:10), "Tapping office door resumes free movement outside")
    let position = motel.actorTile
    motel.moveActor(dx:1,dy:0)
    require(motel.actorTile != position, "Grounds retain free walking")
    require(!motel.receptionTools() && !motel.declineReceptionGuest(), "Office actions cannot run remotely")
    let data = try! JSONEncoder().encode(motel)
    var saved = try! JSONDecoder().decode(Motel.self,from:data)
    saved.initializeWorld()
    require(saved.cash == motel.cash && saved.reception.visitor?.guest.id == motel.reception.visitor?.guest.id, "Reception queue persists in save data")
    print("PASS: static clerk, guest arrival, acceptance, decline, no double charge, departures, family movement, door exit and reception persistence")
}
receptionRules()
func managementRules() {
    var good = Motel()
    good.initializeWorld(); good.cash = 1000
    require(good.upgradeFromDesk(0) && good.rooms[0].furniture == 1, "Desk upgrade changes room tier")
    require(good.checkIn(guestID:10,roomID:0), "Upgraded room can be rented")
    require(good.nextDay() && good.operationsState.reviews.first?.stars == 5, "Happy checkout produces a five star review")
    require(good.operationsState.reviews.count == 1, "Review is created once per checkout")
    var bad = Motel()
    bad.initializeWorld(); _ = bad.checkIn(guestID:10,roomID:0)
    bad.operations!.incident = MotelIncident(kind:.fire,elapsed:89)
    bad.tickManagement()
    require(bad.operationsState.incidentsMissed == 1 && bad.business.deaths == 1 && bad.rooms[0].guest == nil, "Ignoring an emergency affects staying guests")
    _ = bad.nextDay()
    require(bad.operationsState.reviews.first?.stars == 1, "Unresolved chaos creates a bad checkout review")
    var theft = Motel()
    _ = theft.checkIn(guestID:10,roomID:0); theft.rooms[0].stolen = [0]
    _ = theft.nextDay()
    require(theft.operationsState.reviews.first?.stars == 1, "Stolen belongings lead to a one star review")
    var staff = Motel()
    staff.initializeWorld(); staff.cash = 1000
    for role in StaffRole.allCases { require(staff.hire(role), "Each staff role can be hired") }
    require(staff.cash == 350 && !staff.hire(.cleaner), "Hiring charges once and prevents duplicate employees")
    staff.rooms[0].dirty = true
    for _ in 0..<80 { staff.tickManagement() }
    require(!staff.rooms[0].dirty && staff.rooms[0].cleanedTasks?.count == 3, "Housekeeper walks to and cleans a vacant room")
    for kind in ChaosKind.allCases {
        staff.operations!.incident = MotelIncident(kind:kind)
        let index = staff.operations!.workers.firstIndex { $0.role == kind.responder }!
        staff.operations!.workers[index].tile = kind.approach
        for _ in 0..<8 { staff.tickManagement() }
        require(staff.operationsState.incident == nil, "Matching employee handles each emergency")
    }
    staff.cash = 5; _ = staff.nextDay()
    require(staff.cash == 5 && staff.operationsState.workers.allSatisfy { !$0.active }, "Insufficient wages put workers off duty without debt")
    staff.cash = 100; _ = staff.nextDay()
    require(staff.cash == 0 && staff.operationsState.workers.allSatisfy { $0.active }, "Paying wages restores the next shift")
    var manual = Motel()
    manual.initializeWorld(); _ = manual.checkIn(guestID:10,roomID:0)
    for _ in 0..<40 { manual.tickManagement() }
    require(manual.operationsState.incident?.kind == .fire && !manual.resolveNearbyIncident(), "Incidents occur during a shift and require a physical response")
    _ = manual.leaveReception()
    manual.world!.player = ChaosKind.fire.approach
    require(manual.nearbyAction == .incident && manual.resolveNearbyIncident(), "Walking to the scene allows manual intervention")
    require(!manual.resolveNearbyIncident(), "Resolved incidents cannot be claimed twice")
    let data = try! JSONEncoder().encode(staff)
    let saved = try! JSONDecoder().decode(Motel.self,from:data)
    require(saved.operationsState.workers.count == 5 && saved.operationsState.incidentsResolved == 3, "Staff and incident outcomes survive save/load")
    var legacy = Motel(); legacy.operations = nil
    let old = try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(legacy))
    require(old.operationsState.workers.isEmpty && old.operationsState.reviews.isEmpty, "Old motel saves migrate with no invented employees or ratings")
    print("PASS: good and bad checkout reviews, theft reviews, hiring costs, wages, autonomous cleaning, all staff emergency responses, manual intervention, persistence and migration")
}
managementRules()

func expandedHotelRules() {
    var hotel = Motel()
    hotel.initializeWorld()
    hotel.world!.place = .grounds
    hotel.world!.player = MotelGrounds.gate
    require(!hotel.performService(.garden), "Cannot complete service remotely")
    for service in HotelService.allCases {
        require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:service.tile,avoiding:[]) != nil, "All service stations must remain reachable")
    }
    for id in 0..<9 {
        require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:MotelGrounds.roomDoor(id),avoiding:[]) != nil, "Landscaping must not block guest rooms")
    }
    for kind in ChaosKind.allCases {
        require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:kind.approach,avoiding:[]) != nil, "Emergency routes must stay accessible")
    }
    hotel.world!.player = HotelService.breakfast.tile
    require(!hotel.performService(.breakfast), "Breakfast requires guests")
    hotel.world!.player = HotelService.garden.tile
    let balance = hotel.cash
    require(hotel.performService(.garden), "Nearby gardening succeeds")
    require(hotel.cash == balance + HotelService.garden.reward, "Service pays exact reward")
    require(!hotel.performService(.garden), "Same-day repeated reward is rejected")
    let data = try! JSONEncoder().encode(hotel)
    var loaded = try! JSONDecoder().decode(Motel.self,from:data)
    require(!loaded.performService(.garden), "Daily reward guard survives reload")
    loaded.day += 1
    require(loaded.performService(.garden), "Service becomes available next day")
    require((loaded.operationsState.actionUntil ?? 0) > loaded.operationsState.tick, "Service starts visible animation")
    print("PASS: service proximity, guest requirements, rewards, daily limits, persistence, and landscape routes")
}
expandedHotelRules()

func policeRules() {
    for kind in ChaosKind.allCases {
        var m = Motel(); m.initializeWorld(); _ = m.checkIn(guestID:10,roomID:0)
        m.operations!.incident = MotelIncident(kind:kind,elapsed:89)
        m.tickManagement()
        require(m.business.deaths == 1 && m.business.police?.cause == kind, "Each neglected emergency can kill a guest and dispatch police")
        require(m.occupancy == 0 && m.rooms[0].dirty && m.operationsState.reviews.first?.stars == 1, "Fatality removes guest and damages safety rating")
        require(!m.nextDay() && !m.payPoliceFine(), "Cannot sleep past police or pay before arrival")
        for _ in 0..<100 { m.tickManagement() }
        require(m.business.police?.arrived == true, "Officer walks from road to reception")
        m.operations!.consequences!.police!.acceptsBribe = false
        m.cash = 1000
        require(m.tryPoliceBribe() && m.cash == 920 && m.business.police?.fine == 350, "Refused bribe costs money and increases fine")
        require(!m.tryPoliceBribe(), "Cannot repeat a rejected bribe")
        require(m.payPoliceFine() && m.cash == 570 && m.business.police == nil, "Fine clears once")
        require(!m.payPoliceFine(), "Cannot pay twice")
        require(m.nextDay() && m.waiting.count == 1, "Reputation damage reduces daily bookings")
    }
    var accepted = Motel(); accepted.initializeWorld(); accepted.cash = 500
    accepted.operations!.consequences = BusinessConsequences(deaths:2,police:PoliceCase(number:2,guest:"Robin",cause:.fire,arrived:true,acceptsBribe:true))
    require(accepted.tryPoliceBribe() && accepted.cash == 420 && accepted.business.bribesAccepted == 1 && accepted.business.police == nil, "Accepted bribe clears fine but leaves reputation damage")
    var debt = Motel(); debt.initializeWorld(); debt.cash = 20
    debt.operations!.consequences = BusinessConsequences(police:PoliceCase(number:1,guest:"Sasha",cause:.pool,arrived:true))
    require(debt.payPoliceFine() && debt.cash == 0 && debt.business.debt == 180, "Unfunded fine creates debt without blocking play")
    _ = debt.checkIn(guestID:10,roomID:0)
    require(debt.cash == 0 && debt.business.debt == 100, "Room payments repay fine debt")
    let data = try! JSONEncoder().encode(debt)
    let loaded = try! JSONDecoder().decode(Motel.self,from:data)
    require(loaded.business.debt == 100, "Legal consequences persist")
    var colors = Motel(); colors.initializeWorld()
    require(Set(colors.rooms.map(\.theme)).count == 3, "Starting rooms have different colors")
    colors.rooms[1].theme = 0; colors.initializeWorld()
    require(colors.rooms[1].theme == 0, "Player repainting survives migration")
    _ = colors.leaveReception(); colors.cash = 500
    require(colors.hire(.cleaner), "Hiring is available outside the office")
    print("PASS: fatalities, police arrival, fine debt, accepted and rejected bribes, booking penalties, persisted consequences, room colors and accessible hiring")
}
policeRules()

func parkingAndAnimationRules() {
    var hotel=Motel(); hotel.initializeWorld()
    hotel.world!.place = .grounds; hotel.world!.player=MotelGrounds.gate
    hotel.operations = MotelOperations()
    for _ in 0..<8 { hotel.tickManagement() }
    require(hotel.operationsState.cars?.count == 3,"Three occupied parking bays are created")
    require(!hotel.washNearbyCar(),"Cannot collect car wash income remotely")
    for slot in 0..<3 {
        require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:HotelCar.approach(slot),avoiding:[]) != nil,"Every parking bay is reachable")
    }
    hotel.world!.player=HotelCar.approach(0)
    let money=hotel.cash
    require(hotel.washNearbyCar() && hotel.cash == money+35,"Nearby car wash earns 35 coins")
    require(!hotel.washNearbyCar(),"Cannot wash the same car repeatedly in one day")
    require(hotel.operationsState.visual?.kind == "carwash","Washing records a specific animation")
    let copy=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(hotel))
    require(copy.operationsState.cars?.first?.washedDay == hotel.day,"Clean cars survive save and reload")
    var worker=Motel(); worker.initializeWorld(); worker.cash=1000
    require(worker.hire(.valet),"Car wash attendant can be hired")
    for _ in 0..<80 { worker.tickManagement() }
    require(worker.operationsState.washIncome == 105,"Attendant walks to and washes all three cars")
    let earned=worker.cash
    for _ in 0..<30 { worker.tickManagement() }
    require(worker.cash == earned,"Attendant cannot farm the same cars")
    for mode in HotelWeather.allCases {
        worker.operations!.weatherOverride=mode
        require(worker.weather == mode,"Every weather mode is available and persisted")
    }
    var old=Motel(); old.operations=MotelOperations()
    let legacy=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(old))
    require(legacy.operationsState.cars == nil && legacy.operationsState.visual == nil,"Old saves need no car or animation fields")
    var cleaner=Motel(); cleaner.initializeWorld(); cleaner.rooms[0].dirty=true
    cleaner.world!.hasCleaningKit=true; _ = cleaner.enter(0)
    cleaner.visit!.player=Tile(x:3,y:3)
    require(cleaner.cleanNearbyTask() && cleaner.operationsState.visual?.kind == "bed","Bed cleaning uses a sheet animation")
    var thief=Motel(); thief.initializeWorld(); _ = thief.checkIn(guestID:10,roomID:0); _ = thief.enter(0)
    thief.visit!.player=Tile(x:3,y:3)
    require(thief.steal() && thief.operationsState.visual?.kind == "steal-0","Stolen suitcase records its source and destination")
    for kind in ChaosKind.allCases {
        var rescue=Motel(); rescue.initializeWorld(); rescue.world!.place = .grounds
        rescue.world!.player=kind.approach; rescue.operations=MotelOperations()
        rescue.operations!.incident=MotelIncident(kind:kind)
        require(rescue.resolveNearbyIncident(),"Each emergency can be resolved")
        require(rescue.operationsState.visual?.target == kind.tile,"Emergency resolution animation stays at the incident")
    }
    print("PASS: parking, walking attendant, car wash income, persistence, climate and action animation events")
}
parkingAndAnimationRules()


func expandedManagementRules() {
    func make()->Motel {
        var hotel=Motel();hotel.initializeWorld();hotel.enableManagement();hotel.cash=20000
        return hotel
    }
    let returning1=Motel.arrivals(day:1,count:10)
    let returning2=Motel.arrivals(day:2,count:10)
    require(Set(returning1.map(\.name)).count==10,"Arrivals have distinct recurring identities")
    require(zip(returning1,returning2).allSatisfy{pair in pair.0.name==pair.1.name && pair.0.kind==pair.1.kind && pair.0.appearanceSeed==pair.1.appearanceSeed},"Returning characters keep their identity, type and appearance")
    var hotel=make()
    require(hotel.simulation.hour==8 && !hotel.isNight,"Management opens in daytime")
    let oldSnapshot=hotel.simulation.stock
    hotel.enableManagement()
    require(hotel.simulation.stock==oldSnapshot,"Migration cannot duplicate supplies")
    require(hotel.expansionCapacity==6,"Base property has six-room capacity")
    let price=hotel.rate(for:hotel.rooms[0])
    require(hotel.checkIn(guestID:10,roomID:0),"Daytime normal traveler checks in")
    require(hotel.simulation.stock["towels"]==11 && hotel.simulation.stock["toiletries"]==11,"Check-in consumes guest supplies")
    require(hotel.simulation.contracts[10]?.paid==price,"Actual booking payment is recorded")
    let clean=hotel.rooms[0].health.cleanliness
    hotel.advanceHotelHour()
    require(hotel.simulation.hour==9 && hotel.rooms[0].health.cleanliness<clean,"Time progresses and rooms deteriorate")
    var hourly=make();var state=hourly.simulation;state.plan = .hourly;hourly.simulation=state
    let hourlyPayment=hourly.bookingQuote(hourly.waiting[0],room:hourly.rooms[0])
    require(hourlyPayment==40 && hourly.checkIn(guestID:10,roomID:0),"Two-hour contract charges hourly pricing")
    hourly.advanceHotelHour();hourly.advanceHotelHour()
    require(hourly.rooms[0].guest==nil && hourly.rooms[0].dirty,"Hourly guest automatically checks out")
    var weekly=make()
    let resident=weekly.waiting.first{$0.kind == .resident}!
    require(weekly.checkIn(guestID:resident.id,roomID:0),"Weekly resident checks in")
    require(weekly.rooms[0].nightsLeft==7 && weekly.simulation.contracts[resident.id]?.plan == .weekly,"Weekly discount and stay duration are real")
    var rates=make();let standard=rates.rate(for:rates.rooms[0])
    rates.setPrices(.premium,plan:.nightly)
    require(rates.rate(for:rates.rooms[0])>standard,"Pricing policy changes charged rates")
    var renovation=make()
    require(!renovation.changeRoomKind(0,kind:.suite),"Suite reputation gate is enforced")
    var rep=renovation.simulation;rep.reputation=75;renovation.simulation=rep
    require(renovation.changeRoomKind(0,kind:.suite),"Suites unlock at reputation 60")
    require(renovation.buyRoomUpgrade(0,upgrade:.bed),"Meaningful bed upgrade installs")
    require(!renovation.buyRoomUpgrade(0,upgrade:.bed),"Upgrade cannot be purchased twice")
    require(renovation.rate(for:renovation.rooms[0])>standard+100,"Suite and bed affect real room prices")
    var dirty=make();var h=dirty.rooms[0].health;h.cleanliness=20;h.faults=[.pipe,.roaches];dirty.rooms[0].hospitality=h;dirty.rooms[0].dirty=true
    require(!dirty.rooms[0].available,"Damaged dirty rooms cannot be assigned")
    require(dirty.managerClean(0) && !dirty.rooms[0].available,"Cleaning alone does not repair a leaking infested room")
    require(dirty.repairRoom(0) && dirty.rooms[0].available,"Parts or pest treatment restores bookable rooms")
    var stock=dirty.simulation;stock.stock["detergent"]=0;dirty.simulation=stock
    let before=dirty.cash
    require(!dirty.managerClean(0) && dirty.cash==before,"Out-of-stock cleaning does not grant work or charge money")
    require(dirty.buyStock(.detergent) && dirty.simulation.stock["detergent"]==5,"Inventory purchases add real stock")
    require(MiniGameTiming.isHit(elapsed:0.8) && !MiniGameTiming.isHit(elapsed:0) && !MiniGameTiming.isHit(elapsed:1.5),"Cleaning and repair timing windows are meaningful")
    var night=make();var ns=night.simulation;ns.hour=22;ns.absoluteHour=22;night.simulation=ns
    require(night.isNight && !night.checkIn(guestID:10,roomID:0),"Normal check-in closes at night")
    night.toggleShadyOffers()
    require(night.checkIn(guestID:10,roomID:0) && night.simulation.heat>0,"Optional off-books night rentals have consequences")
    var identity=make()
    let privateGuest=identity.waiting.first{$0.kind == .suspicious}!
    require(!identity.checkIn(guestID:privateGuest.id,roomID:0),"Private cash guests need verified identity")
    identity.verifyGuest(privateGuest.id);let ethics=identity.simulation.ethical;identity.verifyGuest(privateGuest.id)
    require(identity.simulation.ethical==ethics,"Repeated identity checks cannot farm story points")
    require(identity.checkIn(guestID:privateGuest.id,roomID:0),"Verified private guest can book")
    var bills=make();bills.cash=1000
    require(bills.nextDay() && bills.cash==941,"Rent and utilities are charged each morning")
    bills.cash=0;_=bills.nextDay()
    require(bills.simulation.billDebt>0,"Unpaid bills persist as debt")
    require(bills.emergencyLoan() && bills.cash==200 && bills.simulation.loanDebt==240,"Emergency credit has an explicit repayment cost")
    require(bills.repayBills() && bills.cash==0,"Debt repayment spends available cash")
    var staff=make()
    require(staff.hire(.clerk),"Front-desk clerk can be hired")
    for _ in 0..<12 {staff.tickManagement()}
    require(staff.occupancy>=1 && staff.guestsServed>=1,"Clerk really assigns rooms and takes payment")
    staff.scheduleNight(.clerk)
    require(staff.scheduledWage(.clerk)==33,"Night coverage costs fifty percent more")
    let speed=staff.simulation.profiles[StaffRole.clerk.rawValue]!.speed
    require(staff.trainStaff(.clerk) && staff.simulation.profiles[StaffRole.clerk.rawValue]!.speed>speed,"Training improves employee stats")
    var quitting=make();_=quitting.hire(.cleaner);quitting.cash=0;_=quitting.nextDay();_=quitting.nextDay()
    require(!quitting.operationsState.workers.contains{$0.role == .cleaner},"Staff can quit after two unpaid shifts")
    var events=make();_=events.checkIn(guestID:10,roomID:0)
    for kind in HotelIssueKind.allCases {
        events.injectIssue(kind,roomID:0)
        let issue=events.simulation.issues.last!
        require(events.respondToIssue(issue.id,choice:0),"Every listed issue has a safe response")
        require(!events.simulation.issues.contains{$0.id==issue.id},"Handled issues close exactly once")
        require(!events.respondToIssue(issue.id,choice:0),"Closed events cannot pay twice")
    }
    events.injectIssue(.drugDeal,roomID:0);let deal=events.simulation.issues.last!.id
    require(!events.respondToIssue(deal,choice:1),"Shady choices are optional and disabled by default")
    events.toggleShadyOffers();let money=events.cash
    require(events.respondToIssue(deal,choice:1) && events.cash==money+90 && events.simulation.criminal>0,"Fictional criminal route changes money and story")
    events.injectIssue(.noise,roomID:0);let reputation=events.simulation.reputation
    for _ in 0..<3 {events.advanceHotelHour()}
    require(events.simulation.reputation<reputation,"Ignored complaints damage future reputation")
    var attention=make();var heat=attention.simulation;heat.heat=40;attention.simulation=heat;attention.advanceHotelHour()
    require(attention.business.police?.reason != nil && attention.business.deaths==0,"Noise and criminal attention summon a nonfatal police citation")
    var utilities=make();var us=utilities.simulation;us.powerOut=true;us.waterOut=true;utilities.simulation=us
    require(!utilities.checkIn(guestID:10,roomID:0),"Utility failures stop new bookings")
    require(utilities.restoreUtilities() && !utilities.simulation.powerOut && !utilities.simulation.waterOut,"Utilities can always be repaired from the operations board")
    var growth=make();var gs=growth.simulation;gs.reputation=75;growth.simulation=gs
    require(growth.installFacility(.adjacentLot) && growth.expansionCapacity==9,"Buying land expands capacity")
    require(growth.installFacility(.upperFloor) && growth.expansionCapacity==18,"Upper floor expands to eighteen rooms")
    for _ in 0..<7 {require(growth.expand(),"Rooms can be built beyond the original nine")}
    growth.world!.place = .grounds
    require(growth.setViewingFloor(1) && growth.rooms[9].number==201,"Upper-floor room numbers and access are distinct")
    require(MotelGrounds.roomDoor(9)==MotelGrounds.roomDoor(0),"Floors share the existing walkable footprint")
    require(growth.installFacility(.parking),"Parking expansion installs")
    growth.waiting=Motel.arrivals(day:3,count:10)
    for _ in 0..<8 {growth.tickManagement()}
    require(growth.operationsState.cars?.count==6,"Expanded parking creates six physical guest cars")
    for slot in 0..<6 {require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:HotelCar.approach(slot),avoiding:[]) != nil,"Expanded parking remains reachable")}
    require(growth.installFacility(.cameras) && growth.installFacility(.nightVision),"CCTV and night vision unlock")
    growth.toggleNightVision();require(growth.simulation.nightVision,"Night vision is a saved mode")
    require(growth.installFacility(.restaurant) && growth.installFacility(.pool),"Restaurant and staffed pool are real upgrades")
    var local=make();local.day=11;_=local.nextDay()
    require(local.simulation.economy == .heatwave && local.weather == .sunny,"Local heatwaves affect the climate and AC events")
    local.day=8;_=local.nextDay()
    require(local.simulation.economy == .factoryClosure && local.waiting.allSatisfy{$0.kind == .resident},"Factory closure changes the guest economy")
    var noShow=make();var reservations=noShow.simulation
    reservations.reservations=[HotelReservation(id:999,guest:Motel.arrivals(day:4,count:1)[0],arrivalHour:9,noShow:true)]
    noShow.simulation=reservations;let feeMoney=noShow.cash;noShow.advanceHotelHour()
    require(noShow.simulation.noShows==1 && noShow.cash==feeMoney+10,"No-shows collect the disclosed fee")
    var story=make();story.day=14
    for (ethical,greedy,criminal,cult,title) in [(10,0,0,0,"A haven worth returning to"),(0,10,0,0,"Profit at any price"),(0,0,10,0,"Highway underworld"),(0,0,0,10,"Sanctuary of the strange")] {
        var s=story.simulation;s.ethical=ethical;s.greedy=greedy;s.criminal=criminal;s.cultFriendly=cult;story.simulation=s;story.claimStoryEnding()
        require(story.simulation.endings.contains(title),"Every management story path can reach its ending")
    }
    let data=try! JSONEncoder().encode(growth)
    let saved=try! JSONDecoder().decode(Motel.self,from:data)
    require(saved.simulation.facilities.contains(.upperFloor) && saved.rooms[9].number==201 && saved.simulation.nightVision,"Expansion, room state and camera mode survive reload")
    var legacy=Motel();legacy.operations=nil
    var migrated=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(legacy));migrated.enableManagement()
    require(migrated.managementEnabled && migrated.rooms.allSatisfy{$0.hospitality != nil},"Old saves migrate to the management simulation")
    print("PASS: day/night, room types and wear, contracts, pricing, inventory, bills, staff, complaints, guests, demand, expansion, cameras, minigames, story endings and migration")
}
expandedManagementRules()

func reactiveGuestsAndStaffPosts() {
    var motel=Motel(); motel.initializeWorld(); motel.cash=5000; motel.waiting=[]
    for role in StaffRole.allCases { require(motel.hire(role),"Hire staff for lounge test") }
    for _ in 0..<90 { motel.tickManagement() }
    require(motel.operationsState.workers.allSatisfy { $0.tile == $0.role.home },"Idle employees return to their own work posts")
    let cleaner=motel.operationsState.workers.firstIndex { $0.role == .cleaner }!
    motel.rooms[0].dirty=true
    for _ in 0..<90 { motel.tickManagement() }
    require(!motel.rooms[0].dirty,"Employees leave their work posts when work appears")
    require(motel.operationsState.workers[cleaner].tile == StaffRole.cleaner.home,"Cleaner returns to housekeeping after work")
    var emergency=Motel(); emergency.initializeWorld()
    let guest=emergency.waiting[0]
    _=emergency.checkIn(guestID:guest.id,roomID:0)
    emergency.operations!.incident=MotelIncident(kind:.pool,guest:guest)
    require(!emergency.guestPresent(in:0),"Guest in pool is absent from their room")
    let bystander=emergency.waiting[0]
    let before=emergency.waitingTile(bystander.id)
    for _ in 0..<10 { emergency.tickWorld() }
    let after=emergency.waitingTile(bystander.id)
    require(after != before && after.distance(to:ChaosKind.pool.tile)>before.distance(to:ChaosKind.pool.tile),"Bystanders run away from danger")
    let saved=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(emergency))
    require(saved.operationsState.incident?.guest?.appearanceSeed == guest.appearanceSeed && saved.operationsState.incident?.guest?.color == guest.color,"Pool event preserves guest identity through checkpoints")
    emergency.operations!.incident=nil
    for _ in 0..<90 { emergency.tickWorld() }
    require(emergency.waitingTile(bystander.id) == MotelGrounds.guestTile(bystander.id),"Guests return after the emergency")
    print("PASS: individual staff posts, return to work, evacuation, recovery and emergency guest identity")
}
reactiveGuestsAndStaffPosts()

func continuousStaffAndFamilyRoomRules() {
    var officeSeen:Set<Tile>=[OfficeReception.clerk],queue=[OfficeReception.clerk],cursor=0
    while cursor<queue.count {
        let tile=queue[cursor];cursor += 1
        for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
            let next=Tile(x:tile.x+dx,y:tile.y+dy)
            if !MotelGrounds.officeBlocked(next),officeSeen.insert(next).inserted {queue.append(next)}
        }
    }
    for tile in OfficeReception.hildarelysRoute+[OfficeReception.samhil,OfficeReception.chichu,OfficeReception.chichi] {
        require(tile.x>=10 && officeSeen.contains(tile),"Family and cats stay in a reachable separate office room")
    }
    require(!MotelGrounds.officeBlocked(Tile(x:9,y:4)) && !MotelGrounds.officeBlocked(Tile(x:9,y:7)),"Office is restored without family partitions")
    var blocked=Motel();blocked.initializeWorld();blocked.cash=1000;blocked.waiting=[]
    blocked.world!.place = .grounds;blocked.world!.player=MotelGrounds.roomDoor(0)
    blocked.rooms[0].dirty=true;_=blocked.hire(.cleaner)
    for frame in 0..<360 {blocked.tickManagement(advanceClock:frame%MotelCadence.businessSteps==0)}
    require(!blocked.rooms[0].dirty,"Cleaner can work when the player occupies the room doorway")
    var fast=Motel();fast.initializeWorld();fast.cash=1000;fast.waiting=[];_=fast.hire(.security)
    fast.operations!.workers[0].tile=Tile(x:20,y:34)
    fast.operations!.incident=MotelIncident(kind:.fight)
    let oldClock=fast.operationsState.tick
    var moved=0
    for _ in 0..<8 {
        let before=fast.operationsState.workers[0].tile
        fast.tickManagement(advanceClock:false)
        if fast.operationsState.workers[0].tile != before {moved += 1}
    }
    require(moved==8,"Staff run on every motion update, without the old business-clock pauses")
    require(fast.operationsState.tick==oldClock && fast.operationsState.incident?.elapsed==0 && fast.operationsState.incident?.staffProgress==0,"Fast movement never speeds up incidents or paid work")
    var business=Motel();business.initializeWorld();business.enableManagement();business.cash=5000
    _=business.checkIn(guestID:10,roomID:2);business.waiting=[]
    business.rooms[0].dirty=true
    var health=business.rooms[1].health;health.faults=[.pipe];business.rooms[1].hospitality=health
    business.injectIssue(.noise,roomID:2)
    business.operations!.nextIncidentTick=10000
    for role in [StaffRole.cleaner,.maintenance,.security,.valet] {require(business.hire(role),"Hire workers for real job dispatch")}
    for frame in 0..<360 {business.tickManagement(advanceClock:frame%MotelCadence.businessSteps==0)}
    require(!business.rooms[0].dirty,"Housekeeping completes actual room work")
    require(business.rooms[1].health.faults.isEmpty,"Maintenance reaches and repairs the actual room")
    require(!business.simulation.issues.contains{$0.kind == .noise},"Security reaches and handles complaints")
    require((business.operationsState.washIncome ?? 0)>=35,"Valet reaches cars and earns wash income")
    var tired=Motel();tired.initializeWorld();tired.enableManagement();tired.cash=5000;_=tired.hire(.clerk)
    var profile=tired.simulation;profile.profiles[StaffRole.clerk.rawValue]!.fatigue=90;tired.simulation=profile
    for _ in 0..<24 {tired.tickManagement()}
    require(tired.guestsServed>0,"A tired clerk slows down without becoming permanently unable to work")
    print("PASS: reachable family room, separate posts, continuous staff navigation, occupied doorways, independent clocks and real staff job completion")
}
continuousStaffAndFamilyRoomRules()

func familyHomeAndNeighborhoodRules() {
    var motel=Motel();motel.initializeWorld();motel.cash=3000;motel.waiting=[]
    motel.world!.place = .grounds
    for door in [FamilyHome.door]+NeighborhoodShop.allCases.map(\.door) {
        require(!MotelGrounds.blocked(door),"Every neighborhood entrance is walkable")
        require(MotelGrounds.nextStep(from:MotelGrounds.officeDoor,to:door,avoiding:[]) != nil,"Office connects to the house and every shop")
    }
    motel.world!.player=NeighborhoodShop.furniture.door
    require(motel.nearbyAction == .shop(.furniture),"Furniture shop has a physical interaction")
    let initial=motel.cash
    require(motel.buyHomeObject(.plant) && motel.cash == initial-30 && motel.household.storage == [.plant],"Furniture is paid from business profits and delivered to storage")
    motel.cash=0;require(!motel.buyHomeObject(.table),"Cannot buy furniture without money");motel.cash=initial-30
    motel.world!.player=FamilyHome.door
    require(motel.useEntrance() && motel.isAtHome,"Enter the separate family house")
    let hildarelys=motel.reception.hildarelys
    for _ in 0..<2 {motel.tickReception()}
    require(motel.reception.hildarelys != hildarelys,"Family animations continue at home")
    require(!motel.placeHomeObject(.plant,at:OfficeReception.samhil),"Furniture cannot cover the family")
    require(motel.placeHomeObject(.plant,at:Tile(x:6,y:8)),"Purchased furniture can be placed on an open home tile")
    require(motel.homeBlocked(Tile(x:6,y:8)),"Placed furniture affects movement")
    require(motel.storeHomeObject(motel.household.placed[0].id) && motel.placeHomeObject(.plant,at:Tile(x:8,y:8)),"Furniture can be stored and moved")
    require(motel.homeBlocked(Tile(x:2,y:3)),"Unrenovated west room is locked")
    let beforeUpgrade=motel.cash
    require(motel.upgradeHome() && motel.cash == beforeUpgrade-250 && !motel.homeBlocked(Tile(x:2,y:3)) && motel.household.capacity == 10,"Home upgrade charges profits, opens a room and increases furnishing space")
    require(motel.finishHome(wall:true,color:2) && motel.finishHome(wall:false,color:3),"Wall and floor customization")
    motel.world!.place = .grounds;motel.world!.player=NeighborhoodShop.clothing.door
    let beforeOutfit=motel.cash
    require(motel.wearOutfit(2) && motel.cash == beforeOutfit-80 && motel.household.outfit == 2,"Clothing purchases equip a persistent outfit")
    require(motel.wearOutfit(0) && motel.wearOutfit(2) && motel.cash == beforeOutfit-80,"Owned outfits are free to wear again")
    var state=motel.household;state.stolen=[1,2];motel.home=state
    let beforeSale=motel.cash
    require(!motel.sellBelonging(1),"Belongings cannot be sold away from the pawn shop")
    motel.world!.player=NeighborhoodShop.pawn.door
    require(motel.sellBelonging(1) && motel.cash == beforeSale+70 && motel.household.stolen == [2],"Explicit pawn sale pays only for the chosen carried item")
    require(!motel.sellBelonging(1) && motel.cash == beforeSale+70,"Cannot sell an item twice")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(motel))
    require(restored.household.placed.count == 1 && restored.household.level == 1 && restored.household.outfit == 2 && restored.household.stolen == [2] && restored.household.floor == 3,"Checkpoint preserves home, decorations, clothes and unsold inventory")
    for tile in Motel.chaosLocations {
        require(!MotelGrounds.blocked(tile) && !MotelGrounds.blocked(Tile(x:tile.x+1,y:tile.y)) && !MotelGrounds.blocked(Tile(x:tile.x,y:tile.y+1)),"Every varied emergency location supports both fighters and responders")
        var incident=MotelIncident(kind:.fight);incident.location=tile
        require(incident.tile == tile && incident.approach == Tile(x:tile.x,y:tile.y+1),"Emergency actors and staff share the incident location")
    }
    var pool=MotelIncident(kind:.pool);pool.location=Tile(x:55,y:30)
    require(pool.tile == ChaosKind.pool.tile && pool.approach == ChaosKind.pool.approach,"Only pool incidents remain fixed")
    for _ in 0..<3 {motel.tickWorld()}
    let pedestrians=motel.worldState.townPositions
    for _ in 0..<8 {motel.tickWorld()}
    require(motel.worldState.townPositions?.count == 7 && motel.worldState.townPositions != pedestrians,"Neighborhood NPCs keep walking even without hotel arrivals")
    print("PASS: open neighborhood, physical shops, separate animated family home, upgrades, decoration placement, clothing, explicit pawn sales and saved belongings")
}
familyHomeAndNeighborhoodRules()
