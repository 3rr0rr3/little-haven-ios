import Foundation

Motel.randomizeGuestArrivals = false
import Darwin
setbuf(stdout,nil)

extension Motel {
    // Older economy/dispatch scenarios begin with an established business.
    mutating func hireEstablishedStaff(_ role:StaffRole)->Bool {
        guestsServed=max(guestsServed,12)
        return hire(role)
    }
}
func hiringMilestoneRules() {
    var business=Motel();business.initializeWorld();business.cash=5000
    require(business.staffStations.isEmpty,"No employee stations before hiring")
    let before=business.cash
    for role in StaffRole.allCases {
        require(!business.hiringUnlocked(role) && !business.hire(role),"Fresh business cannot hire with money alone")
    }
    require(business.cash == before,"Locked hiring never charges")
    for role in StaffRole.allCases {
        business.guestsServed=business.hiringMilestone(role)-1
        require(!business.hiringUnlocked(role),"Role stays locked until its guest milestone")
        business.guestsServed += 1
        require(business.hiringUnlocked(role) && business.hire(role),"Role unlocks and can be hired at its milestone")
        require(business.staffStations.contains(role),"Hiring adds only that worker's station")
    }
    let saved=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(business))
    require(saved.staffStations.count == StaffRole.allCases.count && saved.hiringUnlocked(.clerk),"Milestones and stations survive saves")
    business.guestsServed=0
    require(business.hiringUnlocked(.clerk),"Existing employees are preserved in older saves")
    business.enableManagement()
    business.dismissStaff(.cleaner)
    require(!business.staffStations.contains(.cleaner),"Dismissal removes the employee station")
    print("PASS: unlockable hiring, no-charge locked actions, stations and saved employees")
}
hiringMilestoneRules()


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
    require(walk.worldState.place  == .office, "Start the shift inside the office")
    require(!walk.chargeGuest(10, roomID: 0), "Cannot charge customers remotely")
    require(walk.receptionTools(), "Tap the office closet to collect tools from the desk")
    _ = walk.leaveReception()
    require(walk.worldState.place  == .grounds && walk.actorTile == Tile(x: 6, y: 10), "Office door leads onto the actual grounds")
    let customer=walk.waitingTile(10)
    for _ in 0..<120 {
        if walk.actorTile.distance(to:customer)<=1 {break}
        let occupied=Set(walk.waiting.map{walk.waitingTile($0.id)})
        guard let step=walk.groundNextStep(from:walk.actorTile,to:customer,avoiding:occupied.subtracting([customer])) else{fatalError("Customer waiting spot must be reachable")}
        walk.moveActor(dx:step.x-walk.actorTile.x,dy:step.y-walk.actorTile.y)
    }
    require(walk.nearbyAction  == .guest(10), "Walk beside the waiting guest to talk")
    require(!walk.chargeGuest(11, roomID: 0), "Cannot charge a different guest through the nearby interaction")
    require(walk.chargeGuest(10, roomID: 0) && walk.cash == 260, "Nearby payment assigns the room and charges exactly once")
    require(!walk.guestPresent(in: 0) && walk.worldState.travellers.count == 1, "Guest must walk to the room before appearing inside")
    for _ in 0..<150 {
        walk.tickWorld()
        for actor in walk.worldState.travellers { require(!MotelGrounds.blocked(actor.player), "Guests cannot walk through buildings or water") }
        if walk.worldState.travellers.isEmpty { break }
    }
    require(walk.worldState.travellers.isEmpty && walk.guestPresent(in: 0), "Guest pathfinding reaches the assigned room")
    let waitingCustomer=walk.waitingTile(11)
    let approach=[Tile(x:waitingCustomer.x-1,y:waitingCustomer.y),Tile(x:waitingCustomer.x+1,y:waitingCustomer.y)].first{!walk.groundBlocked($0)}!
    walk.world!.player=approach
    walk.moveActor(dx:waitingCustomer.x-approach.x,dy:waitingCustomer.y-approach.y)
    require(walk.actorTile == approach, "Cannot walk through a waiting customer")
    walk.world!.player=Tile(x:5,y:10)
    walk.moveActor(dx: 1, dy: -1)
    require(walk.worldState.place  == .office, "Diagonal movement can reach an unobstructed doorway")
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
    service.visit!.player = Tile(x: 4, y: 3)
    require(service.cleaningTarget == 0 && !service.cleanNearbyTask(), "Cleaning requires supplies")
    service.world!.hasCleaningKit = true
    require(service.cleanNearbyTask() && service.rooms[0].dirty, "Making the bed does not remotely clean the whole room")
    require(!service.cleanNearbyTask(), "Finished cleaning tasks cannot be repeated")
    service.moveActor(dx: 1, dy: 0)
    service.moveActor(dx: 0, dy: 1)
    service.moveActor(dx: 0, dy: 1)
    require(service.cleaningTarget == 2 && service.cleanNearbyTask(), "Walk to the actual spill to mop it")
    service.moveActor(dx: -1, dy: 0)
    service.moveActor(dx: -1, dy: 0)
    service.moveActor(dx: 0, dy: 1)
    require(service.cleaningTarget == 1 && service.cleanNearbyTask(), "Walk to the trash to collect it")
    require(!service.rooms[0].dirty && service.rooms[0].cleanedTasks?.count == 3, "Only all three physical tasks make a room rentable")
    require(!service.paintNearby(2), "Cannot repaint from across the room")
    service.visit!.player = Tile(x: 7, y: 3)
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
    require(migrated.cash == 333 && migrated.rooms.count == 3 && migrated.worldState.place  == .office, "Existing motel saves keep their business and gain a walkable office")
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
    for _ in 0..<12 { motel.tickReception();motel.tickWorld() }
    require(motel.receptionGuest?.id == 10 && motel.reception.visitor?.tile == Tile(x:4,y:6), "Client walks from door to front of desk")
    require(motel.acceptReceptionGuest(roomID:0) && motel.cash == 260, "Accepting charges the correct room price once")
    require(!motel.acceptReceptionGuest(roomID:1) && motel.cash == 260, "Double acceptance cannot charge twice")
    require(!motel.guestPresent(in:0), "Accepted visitor is not teleported into room while leaving reception")
    for _ in 0..<11 { motel.tickReception();motel.tickWorld() }
    require(motel.worldState.travellers.contains { $0.id == 10 && $0.destination == MotelGrounds.roomDoor(0) }, "Accepted client leaves office and walks to assigned room")
    for _ in 0..<12 { motel.tickReception();motel.tickWorld() }
    require(motel.receptionGuest?.id == 11, "Next client arrives after first leaves")
    let before = motel.cash
    require(motel.declineReceptionGuest() && motel.cash == before && !motel.waiting.contains { $0.id == 11 }, "Declining removes client without payment or occupancy")
    for _ in 0..<11 { motel.tickReception();motel.tickWorld() }
    require(motel.worldState.travellers.contains { $0.id == 11 && $0.destination == MotelGrounds.gate }, "Declined client walks toward road")
    for _ in 0..<4 { motel.tickReception();motel.tickWorld() }
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
    for role in StaffRole.allCases { require(staff.hireEstablishedStaff(role), "Each staff role can be hired") }
    require(staff.cash == 1000-StaffRole.allCases.reduce(0){$0+$1.hireCost} && !staff.hireEstablishedStaff(.cleaner), "Hiring charges once and prevents duplicate employees")
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
    staff.cash = StaffRole.allCases.reduce(0){$0+$1.wage}; _ = staff.nextDay()
    require(staff.cash == 0 && staff.operationsState.workers.allSatisfy { $0.active }, "Paying wages restores the next shift")
    var manual = Motel()
    manual.initializeWorld(); _ = manual.checkIn(guestID:10,roomID:0)
    for _ in 0..<40 { manual.tickManagement() }
    require(manual.operationsState.incident?.kind  == .fire && !manual.resolveNearbyIncident(), "Incidents occur during a shift and require a physical response")
    _ = manual.leaveReception()
    manual.world!.player = manual.operationsState.incident!.approach
    require(manual.nearbyAction  == .incident && manual.resolveNearbyIncident(), "Walking to the scene allows manual intervention")
    require(!manual.resolveNearbyIncident(), "Resolved incidents cannot be claimed twice")
    let data = try! JSONEncoder().encode(staff)
    let saved = try! JSONDecoder().decode(Motel.self,from:data)
    require(saved.operationsState.workers.count == StaffRole.allCases.count && saved.operationsState.incidentsResolved == 3, "Staff and incident outcomes survive save/load")
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
    require(colors.hireEstablishedStaff(.cleaner), "Hiring is available outside the office")
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
    require(worker.hireEstablishedStaff(.valet),"Car wash attendant can be hired")
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
    cleaner.visit!.player=Tile(x:4,y:3)
    require(cleaner.cleanNearbyTask() && cleaner.operationsState.visual?.kind == "bed","Bed cleaning uses a sheet animation")
    var thief=Motel(); thief.initializeWorld(); _ = thief.checkIn(guestID:10,roomID:0); _ = thief.enter(0)
    thief.visit!.player=Tile(x:2,y:4)
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
    let resident=weekly.waiting.first{$0.kind  == .resident}!
    require(weekly.checkIn(guestID:resident.id,roomID:0),"Weekly resident checks in")
    require(weekly.rooms[0].nightsLeft==7 && weekly.simulation.contracts[resident.id]?.plan  == .weekly,"Weekly discount and stay duration are real")
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
    let privateGuest=identity.waiting.first{$0.kind  == .suspicious}!
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
    require(staff.hireEstablishedStaff(.clerk),"Front-desk clerk can be hired")
    for _ in 0..<12 {staff.tickManagement()}
    require(staff.occupancy>=1 && staff.guestsServed>=1,"Clerk really assigns rooms and takes payment")
    staff.scheduleNight(.clerk)
    require(staff.scheduledWage(.clerk)==33,"Night coverage costs fifty percent more")
    let speed=staff.simulation.profiles[StaffRole.clerk.rawValue]!.speed
    require(staff.trainStaff(.clerk) && staff.simulation.profiles[StaffRole.clerk.rawValue]!.speed>speed,"Training improves employee stats")
    var quitting=make();_=quitting.hireEstablishedStaff(.cleaner);quitting.cash=0;_=quitting.nextDay();_=quitting.nextDay()
    require(!quitting.operationsState.workers.contains{$0.role  == .cleaner},"Staff can quit after two unpaid shifts")
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
    require(local.simulation.economy  == .heatwave && local.weather  == .sunny,"Local heatwaves affect the climate and AC events")
    local.day=8;_=local.nextDay()
    require(local.simulation.economy  == .factoryClosure && local.waiting.allSatisfy{$0.kind  == .resident},"Factory closure changes the guest economy")
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
    for role in StaffRole.allCases { require(motel.hireEstablishedStaff(role),"Hire staff for lounge test") }
    for _ in 0..<90 { motel.tickManagement() }
    require(motel.operationsState.workers.allSatisfy { $0.tile == $0.role.home },"Idle employees return to their own work posts")
    let cleaner=motel.operationsState.workers.firstIndex { $0.role  == .cleaner }!
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
    require(emergency.waitingTile(bystander.id) == emergency.groundGuestTile(bystander.id),"Guests return to their spread-out waiting areas after the emergency")
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
    var familyHome=Motel();familyHome.initializeWorld();familyHome.world!.place = .house
    var homeSeen:Set<Tile>=[Tile(x:7,y:12)],homeQueue=[Tile(x:7,y:12)],homeCursor=0
    while homeCursor<homeQueue.count {
        let tile=homeQueue[homeCursor];homeCursor+=1
        for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
            let next=Tile(x:tile.x+dx,y:tile.y+dy)
            if !familyHome.homeBlocked(next),homeSeen.insert(next).inserted {homeQueue.append(next)}
        }
    }
    for tile in OfficeReception.hildarelysRoute {require(homeSeen.contains(tile),"Family walking route stays clear of the TV and decoration")}
    for tile in [OfficeReception.samhil,OfficeReception.chichu,OfficeReception.chichi] {
        require(homeSeen.contains{$0.distance(to:tile)<=1},"Family seating and cat beds remain approachable in their separate home")
    }
    require(!MotelGrounds.officeBlocked(Tile(x:9,y:4)) && !MotelGrounds.officeBlocked(Tile(x:9,y:7)),"Office is restored without family partitions")
    var blocked=Motel();blocked.initializeWorld();blocked.cash=1000;blocked.waiting=[]
    blocked.world!.place = .grounds;blocked.world!.player=MotelGrounds.roomDoor(0)
    blocked.rooms[0].dirty=true;_=blocked.hireEstablishedStaff(.cleaner)
    for frame in 0..<360 {blocked.tickManagement(advanceClock:frame%MotelCadence.businessSteps==0)}
    require(!blocked.rooms[0].dirty,"Cleaner can work when the player occupies the room doorway")
    var fast=Motel();fast.initializeWorld();fast.cash=1000;fast.waiting=[];_=fast.hireEstablishedStaff(.security)
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
    for role in [StaffRole.cleaner,.maintenance,.security,.valet,.repair,.pestControl] {require(business.hireEstablishedStaff(role),"Hire workers for real job dispatch")}
    for frame in 0..<360 {business.tickManagement(advanceClock:frame%MotelCadence.businessSteps==0)}
    require(!business.rooms[0].dirty,"Housekeeping completes actual room work")
    require(business.rooms[1].health.faults.isEmpty,"Maintenance reaches and repairs the actual room")
    require(!business.simulation.issues.contains{$0.kind  == .noise},"Security reaches and handles complaints")
    require((business.operationsState.washIncome ?? 0)>=35,"Valet reaches cars and earns wash income")
    var tired=Motel();tired.initializeWorld();tired.enableManagement();tired.cash=5000;_=tired.hireEstablishedStaff(.clerk)
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
    require(motel.nearbyAction  == .shop(.furniture),"Furniture shop has a physical interaction")
    let initial=motel.cash
    require(!motel.buyHomeObject(.plant),"Shopping requires entering and reaching the counter")
    require(motel.enterShop(.furniture),"Furniture store is a walk-in interior")
    motel.world!.player=ShopLayout.counter
    require(motel.buyHomeObject(.plant) && motel.cash == initial-30 && motel.household.storage == [.plant],"Furniture is paid from business profits and delivered to storage")
    motel.cash=0;require(!motel.buyHomeObject(.table),"Cannot buy furniture without money");motel.cash=initial-30
    motel.world!.player=ShopLayout.exit;_=motel.leaveShop();motel.world!.player=FamilyHome.door
    require(motel.useEntrance() && motel.isAtHome,"Enter the separate family house")
    let hildarelys=motel.reception.hildarelys
    for _ in 0..<2 {motel.tickReception()}
    require(motel.reception.hildarelys != hildarelys,"Family animations continue at home")
    require(!motel.placeHomeObject(.plant,at:OfficeReception.samhil),"Furniture cannot cover the family")
    require(motel.placeHomeObject(.plant,at:Tile(x:6,y:8)),"Purchased furniture can be placed on an open home tile")
    require(motel.homeBlocked(Tile(x:6,y:8)),"Placed furniture affects movement")
    require(motel.storeHomeObject(motel.household.placed[0].id) && motel.placeHomeObject(.plant,at:Tile(x:8,y:8)),"Furniture can be stored and moved")
    require(!motel.homeBlocked(Tile(x:2,y:4)),"The continuous west-room floor is walkable before renovating")
    let beforeUpgrade=motel.cash
    require(motel.upgradeHome() && motel.cash == beforeUpgrade-250 && !motel.homeBlocked(Tile(x:2,y:4)) && motel.household.capacity == 10,"Home upgrade charges profits, improves the home and increases furnishing space")
    require(motel.finishHome(wall:true,color:2) && motel.finishHome(wall:false,color:3),"Wall and floor customization")
    motel.world!.place = .grounds;motel.world!.player=NeighborhoodShop.clothing.door
    require(motel.enterShop(.clothing),"Clothing store can be entered");motel.world!.player=ShopLayout.counter
    let beforeOutfit=motel.cash
    require(motel.wearOutfit(2) && motel.cash == beforeOutfit-80 && motel.household.outfit == 2,"Clothing purchases equip a persistent outfit")
    require(motel.wearOutfit(0) && motel.wearOutfit(2) && motel.cash == beforeOutfit-80,"Owned outfits are free to wear again")
    var state=motel.household;state.stolen=[1,2];motel.home=state
    let beforeSale=motel.cash
    require(!motel.sellBelonging(1),"Belongings cannot be sold away from the pawn shop")
    motel.world!.player=ShopLayout.exit;_=motel.leaveShop();motel.world!.player=NeighborhoodShop.pawn.door
    require(motel.enterShop(.pawn),"Pawn store can be entered");motel.world!.player=ShopLayout.counter
    require(motel.sellBelonging(1) && motel.cash == beforeSale+70 && motel.household.stolen == [2],"Explicit pawn sale pays only for the chosen carried item")
    require(!motel.sellBelonging(1) && motel.cash == beforeSale+70,"Cannot sell an item twice")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(motel))
    require(restored.household.placed.count == 1 && restored.household.level == 1 && restored.household.outfit == 2 && restored.household.stolen == [2] && restored.household.floor == 3,"Checkpoint preserves home, decorations, clothes and unsold inventory")
    for tile in Motel.chaosLocations {
        require(!MotelGrounds.blocked(tile) && !MotelGrounds.blocked(Tile(x:tile.x+1,y:tile.y)) && !MotelGrounds.blocked(Tile(x:tile.x,y:tile.y+1)),"Every varied emergency location supports both fighters and responders")
        var incident=MotelIncident(kind:.fight);incident.location=tile
        require(incident.tile == tile && incident.approach == Tile(x:tile.x,y:tile.y+1),"Emergency actors and staff share the incident location")
    }
    var pool=MotelIncident(kind:.pool)
    require(pool.tile == ChaosKind.pool.tile && pool.approach == ChaosKind.pool.approach,"Default pool incidents use the pool")
    pool.location=Tile(x:55,y:30)
    require(pool.tile == Tile(x:55,y:30) && pool.approach == Tile(x:55,y:32),"Pool emergencies follow a relocated pool")
    for _ in 0..<3 {motel.tickWorld()}
    let pedestrians=motel.worldState.townPositions
    for _ in 0..<8 {motel.tickWorld()}
    require(motel.worldState.townPositions?.count == 7 && motel.worldState.townPositions != pedestrians,"Neighborhood NPCs keep walking even without hotel arrivals")
    print("PASS: open neighborhood, physical shops, separate animated family home, upgrades, decoration placement, clothing, explicit pawn sales and saved belongings")
}
familyHomeAndNeighborhoodRules()

func receptionAndCompanionRules() {
    var motel=Motel()
    motel.initializeWorld()
    require(motel.visiblePets.isEmpty,"Legacy saves keep pets at home, not in reception")
    motel.world!.player=Tile(x:3,y:3)
    require(motel.nearbyAction  == .computer,"The physical PC opens business management")
    motel.world!.place = .house
    motel.world!.player=Tile(x:7,y:8)
    require(motel.nearbyAction != .homeDecor,"Decorating is not offered throughout the house")
    motel.world!.player=Tile(x:4,y:12)
    require(motel.nearbyAction  == .homeDecor && motel.homeBlocked(FamilyHome.workbench),"Workbench is solid and usable from beside it")
    motel.world!.player=Tile(x:9,y:12)
    motel.togglePet("chichu")
    let old=motel.actorTile, oldMap=motel.petMap
    motel.moveActor(dx:-1,dy:0)
    motel.updateCompanions(from:old,map:oldMap)
    require(motel.petState("chichu").tile == old,"Follower retraces a safe player step")
    motel.world!.place = .grounds
    motel.world!.player=Tile(x:54,y:15)
    motel.updateCompanions(from:old,map:oldMap)
    require(motel.petState("chichu").map == "grounds" && !MotelGrounds.blocked(motel.petState("chichu").tile),"Pet follows a map transfer onto walkable ground")
    require(motel.nearbyAction  == .home,"A following pet does not hide the nearby doorway action")
    motel.togglePet("chichu")
    let waiting=motel.petState("chichu").tile
    motel.world!.place = .office
    motel.world!.player=OfficeReception.clerk
    motel.updateCompanions(from:Tile(x:54,y:15),map:"grounds")
    require(motel.petState("chichu").tile == waiting && motel.petState("chichu").map == "grounds", "Stay here preserves the pet's location")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(motel))
    require(restored.petState("chichu").tile == waiting && !restored.petState("chichu").following,"Checkpoint preserves waiting pets")
    require(restored.petState("chichi").map == "house","Unselected pet remains home")
    for tile in Motel.chaosLocations { require(tile.x<39 && tile.y<35,"Emergencies remain inside hotel grounds") }
    var state=motel.operationsState
    var fight=MotelIncident(kind:.fight)
    fight.location=Tile(x:60,y:32)
    state.incident=fight
    motel.operations=state
    motel.tickManagement(advanceClock:false)
    require(motel.operationsState.incident?.tile == Motel.chaosLocations[0],"A saved city fight migrates back to the hotel")
    state=motel.operationsState
    state.incident=nil
    state.consequences=BusinessConsequences()
    var police=PoliceCase(number:1,guest:"Test",cause:.fight)
    police.tile=Tile(x:6,y:11)
    motel.world!.place = .grounds;motel.world!.player=Tile(x:6,y:10)
    state.consequences!.police=police
    motel.operations=state
    motel.tickManagement()
    require(motel.business.police?.arrived == true,"Police arrival registers on the final movement step")
    require(motel.payPoliceFine() && motel.business.police == nil,"The arrived case can be settled")
    print("PASS: physical PC, workbench, pet follow/stay/checkpoints, hotel-only fights and police arrival")
}
receptionAndCompanionRules()

func fluidMovementAndGuestFavourRules() {
    for y in -1...MotelGrounds.height {for x in -1...MotelGrounds.width {
        let tile=Tile(x:x,y:y)
        require(MotelGrounds.blocked(tile)==RPGMaps.grounds.blocked(tile),"Cached terrain exactly preserves collisions")
    }}
    require(MotelGrounds.nextStep(from:Tile(x:43,y:18),to:Tile(x:44,y:18),avoiding:[Tile(x:44,y:18)]) == nil,"Occupied destination waits without searching the entire map")
    require(MotelGrounds.nextStep(from:Tile(x:43,y:18),to:Tile(x:46,y:18),avoiding:[Tile(x:46,y:18)]) == Tile(x:44,y:18),"NPCs still approach busy destinations without freezing far away")
    let started=Date().timeIntervalSinceReferenceDate
    for _ in 0..<30 {_=MotelGrounds.nextStep(from:Tile(x:43,y:16),to:Tile(x:68,y:32),avoiding:[])}
    print("Route benchmark (30 city searches):",Date().timeIntervalSinceReferenceDate-started,"seconds")
    var motel=Motel();motel.initializeWorld();motel.enableManagement()
    motel.rooms[0].guest=Motel.arrivals(day:1,count:1)[0]
    motel.world!.place = .grounds;motel.world!.player=Tile(x:16,y:9)
    let guest=motel.rooms[0].guest!
    require(motel.greetGuest(0),"Guest can discuss their stay from the doorway")
    let relation=motel.simulation.relationships[guest.name]
    require(!motel.greetGuest(0) && motel.simulation.relationships[guest.name]==relation,"Repeated greetings cannot farm trust")
    require(motel.acceptGuestFavour(0),"A guest request can be promised")
    require(!motel.deliverGuestFavour(0),"Supplies must actually be collected")
    let kind=motel.worldState.guestFavour!.kind
    motel.world!.player=kind.source
    let stock=motel.simulation.stock[kind.stockKey]!
    var empty=motel;var sim=empty.simulation;sim.stock[kind.stockKey]=0;empty.simulation=sim
    require(!empty.collectGuestFavour(),"Empty stock cannot produce supplies")
    require(motel.collectGuestFavour() && motel.simulation.stock[kind.stockKey]==stock-1,"Collection consumes one real inventory item")
    require(!motel.collectGuestFavour(),"Supplies cannot be collected twice")
    motel=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(motel))
    require(motel.worldState.guestFavour?.collected==true,"Checkpoint retains a carried delivery")
    motel.world!.player=Tile(x:16,y:9)
    let before=motel.cash
    require(motel.deliverGuestFavour(0) && motel.cash==before+25,"Delivery pays the promised tip")
    require(!motel.deliverGuestFavour(0) && !motel.acceptGuestFavour(0),"Daily requests and tips cannot be farmed")
    var expired=Motel();expired.initializeWorld();expired.enableManagement();expired.cash=100
    expired.rooms[0].guest=guest;expired.world!.place = .grounds;expired.world!.player=Tile(x:16,y:9)
    require(expired.acceptGuestFavour(0),"A separate promise starts")
    expired.operations!.tick=expired.worldState.guestFavour!.deadline
    let reputation=expired.simulation.reputation
    expired.expireGuestFavour();expired.expireGuestFavour()
    require(expired.simulation.reputation==reputation-2 && expired.operationsState.guestPenalties[guest.id]==1,"A missed promise applies consequences exactly once")
    require(!expired.deliverGuestFavour(0),"Late delivery cannot collect a tip")
    require(expired.apologizeGuestFavour(0) && expired.cash==80 && !expired.apologizeGuestFavour(0),"One refund can recover some trust")
    expired.world!.guestFavour=nil // Another conversation must not erase the checkout history.
    expired.recordCheckoutReview(expired.rooms[0])
    require(expired.operationsState.reviews.first?.text.contains("promised")==true,"Checkout review remembers the broken promise")
    var declined=Motel();declined.initializeWorld();declined.rooms[0].guest=guest;declined.world!.place = .grounds;declined.world!.player=Tile(x:16,y:9)
    require(declined.declineGuestFavour(0),"Guest request can be politely declined")
    declined.expireGuestFavour()
    require(declined.operationsState.guestPenalties[guest.id]==nil,"An honest refusal is not a broken promise")
    print("PASS: cached terrain, daily guest conversations, supply delivery, saved requests, stock checks, tips, deadlines, refunds and checkout consequences")
}
fluidMovementAndGuestFavourRules()

func coastAndWalkInStoreRules() {
    var motel=Motel();motel.initializeWorld();motel.cash=1000;motel.world!.place = .grounds
    for shop in NeighborhoodShop.allCases {
        motel.world!.player=shop.door
        require(motel.enterShop(shop) && motel.currentShop==shop,"Each store has its own interior")
        require(!motel.canTrade(shop),"Entrance does not remotely open the checkout")
        var seen:Set<Tile>=[ShopLayout.arrival],queue=[ShopLayout.arrival],cursor=0
        while cursor<queue.count {
            let p=queue[cursor];cursor+=1
            for (dx,dy) in [(0,1),(1,0),(-1,0),(0,-1)] {
                let next=Tile(x:p.x+dx,y:p.y+dy)
                if !motel.shopBlocked(next),seen.insert(next).inserted {queue.append(next)}
            }
        }
        require(seen.contains(ShopLayout.counter) && seen.contains(ShopLayout.exit),"Displays leave a clear route to the counter and door")
        motel.world!.player=ShopLayout.counter
        require(motel.canTrade(shop) && motel.nearbyAction  == .shop(shop),"Counter enables the correct store inventory")
        let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(motel))
        require(restored.currentShop==shop && restored.actorTile==ShopLayout.counter,"Checkpoint retains the active store")
        motel.world!.player=ShopLayout.exit
        require(motel.leaveShop() && motel.actorTile==Tile(x:shop.door.x,y:shop.door.y+1),"Leaving returns to this store's exterior")
    }
    for target in [Tile(x:48,y:42),Tile(x:52,y:54),Tile(x:55,y:60)] {
        require(MotelGrounds.nextStep(from:NeighborhoodShop.clothing.door,to:target,avoiding:[]) != nil,"Town connects to beach walking areas")
    }
    require(MotelGrounds.blocked(Tile(x:65,y:52)),"Deep sea cannot be walked into")
    require(!MotelGrounds.blocked(Tile(x:52,y:54)),"Beach promenade is walkable")
    for tile in BeachLayout.palms+BeachLayout.lounges {require(MotelGrounds.blocked(tile),"Beach furniture and trunks are solid")}
    for y in 0..<MotelGrounds.height {for x in 0..<MotelGrounds.width {
        let tile=Tile(x:x,y:y);require(MotelGrounds.blocked(tile)==RPGMaps.grounds.blocked(tile),"Expanded beach terrain matches cached collision data")
    }}
    motel.world!.place = .house;motel.world!.player=Tile(x:7,y:12)
    require(motel.homeBlocked(Tile(x:2,y:3)) && !motel.homeBlocked(Tile(x:7,y:8)),"Home decoration leaves the living-room aisle clear")
    require(motel.homeBlocked(Tile(x:11,y:3)) && motel.homeBlocked(Tile(x:11,y:10)),"TV console and sofa have solid footprints")
    var pets=Motel();pets.initializeWorld();pets.world!.place = .grounds;pets.world!.player=NeighborhoodShop.furniture.door
    pets.world!.pets=["chichu":PetCompanion(following:true,map:"grounds",tile:Tile(x:46,y:29))]
    let before=pets.actorTile
    require(pets.enterShop(.furniture),"Follower test enters furniture shop")
    pets.updateCompanions(from:before,map:"grounds")
    require(pets.petState("chichu").map=="shop-furniture" && !ShopLayout.blocked(pets.petState("chichu").tile),"Pet follows onto a safe store arrival tile")
    pets.togglePet("chichu");pets.world!.player=ShopLayout.exit;_=pets.leaveShop()
    pets.world!.player=NeighborhoodShop.clothing.door;_=pets.enterShop(.clothing)
    require(pets.visiblePets.isEmpty && pets.petState("chichu").map=="shop-furniture","A waiting pet stays in its own store rather than appearing in every store")
    var legacy=Motel();legacy.initializeWorld();legacy.world!.place = .grounds
    legacy.world!.player=Tile(x:65,y:45)
    legacy.world!.pets=["chichu":PetCompanion(following:true,map:"grounds",tile:Tile(x:64,y:45)),"chichi":PetCompanion(following:false,map:"grounds",tile:Tile(x:66,y:45))]
    let oldPosition=legacy.actorTile
    legacy.reconcileInteriorSpawn();legacy.updateCompanions(from:oldPosition,map:"grounds")
    require(legacy.worldState.place  == .grounds && !MotelGrounds.blocked(legacy.actorTile),"An older seaside save loads onto nearby clear ground")
    require(!MotelGrounds.blocked(legacy.petState("chichu").tile),"A following pet is not left inside new water or decoration")
    require(!MotelGrounds.blocked(legacy.petState("chichi").tile) && !legacy.petState("chichi").following,"A waiting pet also migrates to nearby safe ground without changing its follow setting")
    let safe=legacy.actorTile;legacy.reconcileInteriorSpawn()
    require(legacy.actorTile==safe,"Save migration never relocates an already safe player")
    print("PASS: walk-in shop counters, display collisions, store checkpoints, beach access, water safety, TV/sofa footprints, pet transfers and old-save terrain migration")
}
coastAndWalkInStoreRules()

func barRules() {
    var game=Motel();game.initializeWorld();game.cash=100;game.world!.place = .grounds
    require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:NeighborhoodShop.bar.door,avoiding:[]) != nil,"Bar entrance connects to town")
    require(!game.orderBarDrink(.houseCocktail) && game.cash == 100,"Cannot buy bar drinks from another map")
    game.world!.player=NeighborhoodShop.bar.door;require(game.enterShop(.bar),"Bar can be entered")
    require(!game.orderBarDrink(.citrusSoda),"Drinks require reaching the bartender")
    game.world!.player=ShopLayout.counter
    require(game.orderBarDrink(.citrusSoda) && game.cash == 92 && game.worldState.barOrders == 1,"Bartender charges once and serves requested drink")
    require(game.worldState.barDrink  == .citrusSoda,"Served drink is recorded")
    game.cash=0;require(!game.orderBarDrink(.houseCocktail) && game.cash == 0,"Unaffordable drinks do not overdraw")
    for tile in BarLayout.seats {require(game.shopBlocked(tile),"Seated patrons block their chair tile")}
    game.world!.player=Tile(x:7,y:10);game.moveActor(dx:-1,dy:-1)
    require(game.actorTile==Tile(x:7,y:10),"Cannot cut diagonally through patrons or tables")
    let saved=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(game))
    require(saved.currentShop  == .bar && saved.worldState.barDrink  == .citrusSoda,"Bar and drink order survive checkpoint")
    game.world!.player=ShopLayout.exit;require(game.leaveShop() && game.actorTile == Tile(x:NeighborhoodShop.bar.door.x,y:NeighborhoodShop.bar.door.y+1),"Bar exit returns to its own road")
    print("PASS: bar entry, counter service, prices, patrons, furniture, checkpoints and exit")
}
barRules()

func neighborhoodAndFacilitiesRules() {
    require(NeighborhoodShop.bar.door == Tile(x:57,y:35),"Bar is in the retail district")
    for origin in ResidentialLayout.origins {require(MotelGrounds.blocked(origin),"Neighbor homes have physical walls")}
    for door in ResidentialLayout.doors {require(MotelGrounds.nextStep(from:FamilyHome.door,to:door,avoiding:[]) != nil,"Neighbor porches connect to the player's home")}
    for service in HotelService.allCases {require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:service.tile,avoiding:[]) != nil,"Physical facilities remain reachable")}
    require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:FacilityLayout.supplies,avoiding:[]) != nil,"Guest supply pavilion is reachable")
    require(GuestFavourKind.toiletries.source == FacilityLayout.supplies,"Guest requests collect supplies at the new pavilion")
    require(GuestFavourKind.snacks.source == HotelService.breakfast.tile,"Breakfast requests use the new terrace")
    var game=Motel();game.initializeWorld();game.waiting=[];game.world!.place = .grounds
    for index in BeachLayout.lounges.indices {
        require(!MotelGrounds.blocked(BeachLayout.approach(index)),"Every chair has a safe approach")
        game.world!.player=BeachLayout.approach(index)
        require(game.sitOnBeachChair() && game.isRelaxing,"Beach loungers are interactive")
        let saved=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(game))
        require(saved.isRelaxing && saved.relaxingTile == BeachLayout.lounges[index],"Relaxing persists through saves")
        game.standFromBeachChair();require(!game.isRelaxing,"Player can stand")
        _=game.sitOnBeachChair();game.moveActor(dx:0,dy:1);require(!game.isRelaxing,"Moving exits the chair immediately")
    }
    game.world!.place = .office
    require(!game.sitOnBeachChair(),"Chairs cannot be used remotely")
    game.world!.place = .grounds;game.world!.player=HotelService.repair.tile
    require(game.serviceAvailable(.repair) && game.performService(.repair) && !game.serviceAvailable(.repair),"Repair clears the pump fault")
    for _ in 0..<12 {game.tickWorld()}
    require(game.worldState.neighborPositions?.count == 3,"Residential neighbors live on the map")
    require(game.worldState.neighborPositions!.values.allSatisfy{!MotelGrounds.blocked($0)},"Neighbors use safe routes")
    game.world!.townPositions=[0:Tile(x:57,y:33)]
    game.world!.travellers=[MotelWalker(id:99,name:"Visitor",color:0x91B7A1,roomID:0,player:Tile(x:11,y:4),previous:Tile(x:11,y:4),destination:MotelGrounds.roomDoor(0))]
    game.reconcileInteriorSpawn()
    require(!MotelGrounds.blocked(game.worldState.townPositions![0]!),"Saved townspeople relocate out of the moved bar")
    require(!MotelGrounds.blocked(game.worldState.travellers[0].player),"Saved guests relocate out of new facilities")
    print("PASS: retail relocation, residential access, physical facilities, pump repairs, usable loungers and neighbor routes")
}
neighborhoodAndFacilitiesRules()

func touchAndSidewalkRules() {
    for tile in [Tile(x:12,y:15),Tile(x:12,y:26),Tile(x:9,y:25),Tile(x:10,y:25)] {
        require(!MotelGrounds.blocked(tile),"Removed objects leave no invisible collisions")
    }
    require(MotelGrounds.blocked(Tile(x:66,y:32)),"Relocated bin has matching collision")
    require(StaffRole.cleaner.home == FacilityLayout.laundry,"Hired housekeeper works in the laundry pavilion")
    require(HotelService.laundry.tile == FacilityLayout.laundry,"Laundry service shares the physical pavilion")
    require(GuestFavourKind.toiletries.source == FacilityLayout.supplies,"Guest supplies use the laundry area")
    require(FacilityLayout.supplies.distance(to:FacilityLayout.laundry)<=2,"Laundry and supplies are together")
    for y in 0..<MotelGrounds.height {for x in 0..<MotelGrounds.width {
        let tile=Tile(x:x,y:y)
        if RPGMaps.hotelSidewalk(tile) {require(!MotelGrounds.blocked(tile),"Every hotel sidewalk remains free of fixtures")}
        if FacilityLayout.laundryFootprint.contains(tile) {
            require(!RPGMaps.hotelSidewalk(tile) && x<40,"Laundry footprint stays on grass outside sidewalks and the road")
        }
    }}
    for y in 30...33 {for x in 7...10 {
        require(!MotelGrounds.blocked(Tile(x:x,y:y)),"Old laundry site leaves no invisible furniture collisions")
    }}
    require(!MotelGrounds.blocked(Tile(x:12,y:8)),"Laundry opens between reception and room 101 without occupying row 8")
    require(MotelGrounds.nextStep(from:MotelGrounds.roomDoor(5),to:FacilityLayout.laundry,avoiding:[]) != nil,"Laundry is reachable from the motel room row")
    require(MotelGrounds.nextStep(from:FacilityLayout.laundry,to:FacilityLayout.supplies,avoiding:[]) != nil,"Supplies share the laundry aisle")
    require(ThumbstickInput.direction(dx:0,dy:0) == nil,"A tap never requests movement")
    require(ThumbstickInput.direction(dx:8,dy:6) == nil,"Thumb jitter inside the dead zone stays still")
    require(ThumbstickInput.direction(dx:60,dy:0) == Tile(x:1,y:0),"Drag right steers east")
    require(ThumbstickInput.direction(dx:-60,dy:0) == Tile(x:-1,y:0),"Drag left reverses direction")
    require(ThumbstickInput.direction(dx:0,dy:-60) == Tile(x:0,y:-1),"Screen-up drags walk north")
    require(ThumbstickInput.direction(dx:0,dy:60) == Tile(x:0,y:1),"Screen-down drags walk south")
    require(ThumbstickInput.direction(dx:45,dy:-45) == Tile(x:1,y:-1),"Diagonal thumb steering is supported")
    require(ThumbstickInput.direction(dx:500,dy:0) == ThumbstickInput.direction(dx:60,dy:0),"Long drags keep normal walking speed")
    require(ThumbstickInput.direction(dx:45,dy:30,diagonals:false) == Tile(x:1,y:0),"Prologue uses its cardinal movement rules")
    require(ThumbstickInput.direction(dx:.infinity,dy:0) == nil,"Invalid touch coordinates cannot move the character")
    var game=Motel();game.initializeWorld();game.world!.place = .house;game.world!.player=Tile(x:9,y:9)
    game.moveActor(dx:1,dy:-1)
    require(game.actorTile == Tile(x:9,y:9),"Diagonal steering cannot cut through the sofa corner")
    print("PASS: clear sidewalks, grouped laundry, thumb dead zone, direction changes, diagonal safety and bounded speed")
}
touchAndSidewalkRules()

func referenceCompanionRules() {
    var game=Motel();game.initializeWorld();game.world!.place = .house;game.world!.player=Tile(x:4,y:9)
    require(game.visiblePets.contains{$0.key == "mochi"},"Creature is visible at home in existing saves")
    require(!game.homeBlocked(game.petState("mochi").tile),"Creature starts on an open tile")
    game.togglePet("mochi")
    require(game.petState("mochi").following,"Creature can follow")
    let previous=game.actorTile, map=game.petMap
    game.world!.place = .grounds;game.world!.player=Tile(x:12,y:8)
    game.updateCompanions(from:previous,map:map)
    require(game.petState("mochi").map == "grounds","Creature follows between maps")
    require(!MotelGrounds.blocked(game.petState("mochi").tile),"Creature arrives on a safe tile")
    game.togglePet("mochi")
    let saved=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(game))
    require(!saved.petState("mochi").following && saved.petState("mochi").map == "grounds","Creature stay position persists")
    for y in 10...15 {for x in 36...39 {
        require(!FacilityLayout.obstacles.contains{$0.contains(Tile(x:x,y:y))},"Previous eastern laundry fixtures are removed")
    }}
    require(FacilityLayout.laundryFootprint.x == 11 && FacilityLayout.laundryFootprint.x+FacilityLayout.laundryFootprint.width == 14,"Laundry fits in the office-room gap")
    print("PASS: reference creature follow, transfer, waiting save and compact reception laundry")
}
referenceCompanionRules()

func basementSanctuaryRules() {
    require(BasementLayout.titles.count == 8,"Exactly eight distinct corral residents")
    for id in 0..<8 {
        let p=BasementLayout.pen(id)
        for tick in 0..<40 {
            let creature=BasementLayout.creature(id,tick:tick)
            require(p.contains(creature),"Every creature stays inside its assigned corral")
            require((0..<8).filter{BasementLayout.pen($0).contains(creature)}.count == 1,"Exactly one habitat contains each resident")
        }
        require(!BasementLayout.blocked(BasementLayout.gate(id)),"Every gate has a clear visitor approach")
    }
    var game=Motel();game.initializeWorld();game.world!.place = .house;game.world!.player=Tile(x:2,y:13)
    require(game.nearbyAction  == .basement && game.enterBasement(),"Physical home stairs enter the basement")
    require(game.isAtBasement && game.actorTile == BasementLayout.arrival,"Basement arrival is safe")
    for id in 0..<8 {
        game.world!.player=BasementLayout.gate(id)
        require(game.nearbyCorral == id,"Each corral is individually interactive")
        require(game.careForCorral(id,feed:true),"Feed each resident")
        require(!game.careForCorral(id,feed:true),"Feeding records the day")
        require(game.careForCorral(id,feed:false),"Pet each resident")
        let before=game.actorTile
        game.moveActor(dx:id%2 == 0 ? -1 : 1,dy:0)
        require(game.actorTile == before,"Corral fences block entry")
    }
    game.world!.player=BasementLayout.arrival
    require(!game.careForCorral(0,feed:false),"Cannot interact with a distant animal")
    let saved=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(game))
    require(saved.isAtBasement && saved.corralCare(7).fedDay == game.day && saved.corralCare(7).visits == 1,"Basement location and animal care persist")
    game.togglePet("mochi") // Tuki is upstairs, so remote follow stays disabled.
    require(!game.petState("mochi").following,"Corrals do not alter the home companion")
    require(game.leaveBasement() && game.isAtHome && !game.homeBlocked(game.actorTile),"Upstairs returns to the family home")
    print("PASS: eight enclosed residents, home stairs, feeding, petting, safe movement and saved care")
}
basementSanctuaryRules()

func restaurantAndBikeRules() {
    require(NeighborhoodShop.fish.door.x<NeighborhoodShop.bar.door.x && NeighborhoodShop.fish.door.y == NeighborhoodShop.bar.door.y,"Fish restaurant is directly left of the bar")
    require(MotelGrounds.nextStep(from:MotelGrounds.gate,to:NeighborhoodShop.fish.door,avoiding:[]) != nil,"Restaurant entrance reachable")
    var game=Motel();game.initializeWorld();game.cash=500
    game.world!.place = .grounds;game.world!.player=NeighborhoodShop.fish.door
    require(game.enterShop(.fish),"Enter fish restaurant")
    require(!game.orderFishMeal(.grilledFish),"Cannot order remotely")
    game.world!.player=ShopLayout.counter
    require(game.orderFishMeal(.grilledFish) && game.cash == 482 && game.worldState.fishMeal  == .grilledFish,"Chef serves a paid meal")
    game.world!.place = .grounds;game.world!.shop=nil;game.world!.player=Tile(x:15,y:32)
    require(game.mountNearbyBike() && game.isRidingBike,"Mount a character-sized bicycle")
    game.moveActor(dx:1,dy:0);require(game.actorTile == Tile(x:16,y:32),"Pedal with ordinary movement controls")
    require(!game.enter(0) && !game.enterShop(.fish),"Cannot take bicycle indoors")
    require(game.dismountBike() && !game.isRidingBike && game.nearbyBike != nil,"Dismount and park nearby")
    let loaded=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(game))
    require(loaded.bikeParking[-800] == game.bikeParking[-800],"Parked bicycle persists")
    game.world!.place = .office;game.world!.player=OfficeReception.clerk
    if let guest=game.waiting.first {
        require(game.checkIn(guestID:guest.id,roomID:0),"Attend a reception client")
        require(game.operationsState.visual?.kind == "checkin" && game.operationsState.visual?.target == OfficeReception.computer,"Check-in animation belongs on the desk")
    }
    require(BasementLayout.homeStairs == Tile(x:1,y:13),"Small stairs are tucked in the home corner")
    require(!game.homeBlocked(Tile(x:2,y:13)),"Corner stair approach stays clear")
    print("PASS: restaurant location and ordering, bicycle mounting/movement/parking/save, desk check-in and corner stairs")
}
restaurantAndBikeRules()

func creativeAndSpecialistRules() {
    var game=Motel();game.initializeWorld();game.enableManagement()
    require(!game.hiringUnlocked(.repair) && !game.hiringUnlocked(.pestControl),"Specialists unlock through guest service")
    game.guestsServed=20;game.cash=5000
    require(game.hire(.repair) && game.hire(.pestControl),"Two distinct specialists can be hired")
    require(game.staffStations.contains(.repair) && game.staffStations.contains(.pestControl),"Specialists each receive a physical station")
    require(StaffRole.repair.handles(RoomFault.pipe) && !StaffRole.repair.handles(RoomFault.roaches),"Repair specialist leaves pest work to Iris")
    require(StaffRole.pestControl.handles(RoomFault.bedbugs) && !StaffRole.pestControl.handles(RoomFault.ac),"Pest specialist leaves repairs to Alex")
    var health=game.rooms[0].health;health.faults=[.pipe,.bedbugs];game.rooms[0].hospitality=health
    game.waiting=[];game.operations!.nextIncidentTick=10000
    for i in game.operations!.workers.indices {game.operations!.workers[i].tile=game.groundRoomDoor(0)}
    for frame in 0..<150 {game.tickManagement(advanceClock:frame%6==0)}
    require(game.rooms[0].health.faults.isEmpty,"Alex and Iris complete their actual independent room jobs")
    require(game.operationsState.serviceDays?[HotelService.repair.rawValue] == game.day,"Repair technician also services the physical pool pump")
    require(game.relocateStructure("laundry",to:Tile(x:20,y:30)),"Whole laundry can move away from the sidewalk")
    require(game.groundTile(FacilityLayout.laundry) == Tile(x:21,y:33),"Washer interaction follows the pavilion")
    require(!game.groundBlocked(Tile(x:11,y:4)) && game.groundBlocked(Tile(x:20,y:31)),"Laundry walls move with the artwork")
    require(game.relocateStructure("washer",to:Tile(x:24,y:30)),"Washer moves independently")
    require(game.groundTile(FacilityLayout.laundry) == Tile(x:25,y:32),"Individual appliance keeps its service approach")
    let loaded=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(game))
    require(loaded.groundTile(FacilityLayout.supplies) == game.groundTile(FacilityLayout.supplies),"Creative positions survive save and load")
    let before=game.worldState.structureOffsets
    require(!game.relocateStructure("home",to:Tile(x:14,y:4)),"Overlapping another room is rejected")
    require(game.worldState.structureOffsets == before,"Rejected placement leaves layout unchanged")
    require(game.relocateStructure("shop-fish",to:Tile(x:40,y:55)),"Shop can relocate into another region")
    game.world!.place = .grounds;game.world!.player=game.groundTile(NeighborhoodShop.fish.door)
    require(game.enterShop(.fish),"Relocated shop entrance still works")
    game.world!.player=ShopLayout.exit
    require(game.leaveShop() && game.actorTile == game.groundTile(Tile(x:47,y:36)),"Shop exits return to relocated doorway")
    game.resetCreativeLayout()
    require((game.worldState.structureOffsets ?? [:]).isEmpty && game.groundTile(FacilityLayout.laundry)==FacilityLayout.laundry,"Original layout can be restored")
    var office=Motel();office.initializeWorld()
    require(office.relocateStructure("office",to:Tile(x:23,y:29)),"Reception building can move")
    office.world!.place = .office
    require(office.leaveReception() && office.actorTile==office.groundTile(Tile(x:6,y:10)),"Reception exits follow the moved office")
    require(office.groundNextStep(from:MotelGrounds.gate,to:office.groundTile(MotelGrounds.officeDoor),avoiding:[]) != nil,"Visitors can still route to the reception entrance")
    print("PASS: specialist unlocks, separate duties, movable laundry and appliances, collisions, entrances, rejected overlaps and persistent creative layout")
}
creativeAndSpecialistRules()

func creativeEmergencyAccessRules() {
    var game=Motel();game.initializeWorld();game.world!.place = .grounds
    var state=game.operationsState;state.incident=MotelIncident(kind:.fire);game.operations=state
    require(!game.relocateStructure("room-8",to:Tile(x:16,y:27)),"Cannot place a building over an active emergency")
    game.operations!.incident=nil
    require(game.relocateStructure("room-8",to:Tile(x:16,y:27)),"An unused emergency site is ordinary editable ground")
    require(!game.availableHotelIncidentSites.contains(ChaosKind.fire.tile),"Future emergencies exclude relocated building footprints")
    require(game.checkIn(guestID:10,roomID:0),"Establish an occupied motel")
    game.operations!.nextIncidentTick=0
    game.tickManagement()
    require(game.operationsState.incident?.kind  == .fire,"Emergency scheduling continues in creative layouts")
    let incident=game.operationsState.incident!
    require(!game.groundBlocked(incident.tile) && !game.groundBlocked(incident.approach),"Emergency participants and responders have reachable ground")
    var bikes=Motel();bikes.initializeWorld();bikes.world!.place = .grounds
    var parking=bikes.operationsState
    parking.cars=[HotelCar(id:901,slot:0,color:0xA0B0A0,arrival:8),HotelCar(id:902,slot:1,color:0xB0A090,arrival:8)]
    bikes.operations=parking
    require(bikes.relocateStructure("office",to:Tile(x:15,y:29)),"A building can move into the former bicycle parking area")
    let positions=bikes.parkedBikes.map{bikes.bikeParking[$0.id] ?? HotelCar.tile($0.slot)}
    let entrances=Set(bikes.creativeStructures.flatMap(\.anchors).map{bikes.groundTile($0)})
    require(Set(positions).count==positions.count && positions.allSatisfy{!bikes.groundBlocked($0) && !entrances.contains($0)},"Covered bicycles are parked separately away from entrances")
    print("PASS: creative placement protects active emergencies and keeps future incidents reachable")
}
creativeEmergencyAccessRules()

func responseAndGuestVariationRules() {
    var hotel=Motel();hotel.initializeWorld();hotel.world!.place = .office
    var visitor=OfficeVisitor(guest:hotel.waiting[0]);visitor.phase = .waiting;visitor.pathIndex=OfficeVisitor.path.count-1
    hotel.world!.reception!.visitor=visitor;hotel.world!.player=OfficeReception.clerk
    require(hotel.canTouchInteract(at:visitor.tile),"Receptionist can speak across counter")
    hotel.world!.player=Tile(x:12,y:3)
    require(!hotel.canTouchInteract(at:visitor.tile),"Reception exception does not permit remote guest interaction")
    hotel.world!.place = .house;hotel.world!.player=OfficeReception.clerk
    require(!hotel.canTouchInteract(at:visitor.tile),"Counter exception is limited to reception")
    let batches=(1...20).map{Motel.arrivals(day:$0,count:4,randomize:true)}
    require(Set(batches.map{$0.map(\.name).joined(separator:",")}).count>1,"Daily guest combinations and order vary")
    require(batches.allSatisfy{Set($0.map(\.id)).count==$0.count && Set($0.map(\.name)).count==$0.count},"Each arriving batch has distinct identities")
    require(Set(batches.flatMap{$0}.map(\.id)).count==80,"Guest IDs remain unique across days")
    hotel=Motel();hotel.initializeWorld();hotel.world!.place = .grounds
    for id in 0..<3 {_=hotel.checkIn(guestID:10+id,roomID:id)}
    require(Set(Motel.arrivals(day:3,count:12).map(\.id)).isDisjoint(with:Set(Motel.arrivals(day:4,count:12).map(\.id))),"Busy twelve-guest days cannot overlap guest IDs")
    var victims:[String]=[]
    for _ in 0..<12 {
        hotel.operations!.incident=nil;hotel.operations!.incidentsStarted=1;hotel.operations!.nextIncidentTick=0
        hotel.tickManagement()
        let event=hotel.operationsState.incident!
        require(event.kind  == .pool && event.guest != nil,"Pool selects an actual checked-in guest")
        if let previous=victims.last {require(event.guest!.name != previous,"Pool does not repeatedly choose the same victim when others are available")}
        victims.append(event.guest!.name)
        hotel.world!.player=event.approach
        require(hotel.resolveNearbyIncident(),"Rescue begins at pool")
        let visual=hotel.operationsState.visual!
        require(visual.guest?.id==event.guest?.id && visual.outfit != nil,"Rescue animation retains victim identity and player outfit")
        require(!hotel.resolveNearbyIncident(),"Response cannot award completion twice")
        let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(hotel))
        require(restored.operationsState.lastPoolGuestName==event.guest?.name,"Victim rotation survives checkpoints")
    }
    require(BasementLayout.titles[3]=="Shrek Chichu" && BasementLayout.titles[7]=="Messi Chichu","Sanctuary names updated")
    print("PASS: counter interaction, randomized arrivals, varied pool victims, response identity and creature names")
}
responseAndGuestVariationRules()

func pursuitAndRandomFireRules() {
    var motel=Motel();motel.initializeWorld()
    let cases:[(MotelPlace,NeighborhoodShop?,Int?,Tile)]=[
        (.grounds,nil,nil,Tile(x:35,y:32)),
        (.office,nil,nil,OfficeReception.clerk),
        (.house,nil,nil,Tile(x:7,y:6)),
        (.basement,nil,nil,Tile(x:12,y:7)),
        (.shop,.fish,nil,Tile(x:7,y:10)),
        (.grounds,nil,0,Tile(x:4,y:4))
    ]
    for (place,shop,room,position) in cases {
        motel.world!.place=place;motel.world!.shop=shop;motel.world!.player=position
        motel.visit=room.map{RoomVisit(roomID:$0,sneaking:false,player:position)}
        motel.operations!.consequences=BusinessConsequences(police:PoliceCase(number:1,guest:"Test",cause:.fire,acceptsBribe:false))
        for _ in 0..<260 {
            motel.tickManagement(advanceClock:false)
            if motel.policeRequiresDecision {break}
        }
        let officer=motel.business.police!
        require(officer.arrived && (officer.map ?? "grounds")==motel.petMap && officer.tile.distance(to:motel.actorTile)<=1,"Police physically reach the player in every map")
        let before=motel.actorTile;motel.moveActor(dx:1,dy:0)
        require(motel.actorTile==before,"Cannot walk out of mandatory police conversation")
        motel.cash=1000;require(motel.tryPoliceBribe() && motel.policeRequiresDecision,"Rejected bribe keeps the case open")
        let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(motel))
        require(restored.policeRequiresDecision && restored.business.police!.bribeTried,"Reload cannot dismiss a case or retry a refused bribe")
        require(motel.payPoliceFine() && !motel.policeRequiresDecision,"Payment releases the conversation")
    }
    motel.visit=nil;motel.world!.place = .grounds;motel.world!.player=Tile(x:30,y:32)
    motel.operations!.consequences=BusinessConsequences(police:PoliceCase(number:2,guest:"Test",cause:.fire))
    for _ in 0..<5 {motel.tickManagement(advanceClock:false)}
    motel.world!.place = .house;motel.world!.player=Tile(x:7,y:7)
    for _ in 0..<260 {motel.tickManagement(advanceClock:false);if motel.policeRequiresDecision {break}}
    require(motel.business.police?.map=="house" && motel.policeRequiresDecision,"Pursuit updates when the player changes maps")
    _=motel.payPoliceFine()
    motel.world!.place = .grounds;motel.world!.player=Tile(x:11,y:14)
    motel.rooms[0].guest=Motel.arrivals(day:1,count:1)[0]
    var locations=Set<Tile>(),previous:Tile?
    for _ in 0..<40 {
        motel.operations!.incident=nil;motel.operations!.incidentsStarted=0;motel.operations!.nextIncidentTick=0
        motel.tickManagement()
        let incident=motel.operationsState.incident!
        require(incident.kind  == .fire && incident.tile != previous,"Consecutive fires choose a different location")
        require((2...37).contains(incident.tile.x) && (3...33).contains(incident.tile.y),"Fire stays around the motel")
        require(!motel.groundBlocked(incident.tile) && !motel.groundBlocked(incident.approach),"Fire and response position stay accessible")
        previous=incident.tile;locations.insert(incident.tile)
    }
    require(locations.count>5,"Fires have more than five possible positions")
    print("PASS: police pursuit in six maps, moving targets, mandatory case persistence and varied safe fire locations")
}
pursuitAndRandomFireRules()

func clearReceptionEntranceRules() {
    var hotel=Motel();hotel.initializeWorld()
    hotel.waiting=Motel.arrivals(day:8,count:12,randomize:false)
    hotel.world!.place = .grounds;hotel.world!.player=Tile(x:10,y:11)
    hotel.operations!.nextIncidentTick=10000
    let entrance=hotel.groundTile(Tile(x:6,y:10))
    let targets=hotel.waitingGuestTargets
    require(targets.count==12 && Set(targets.values).count==12,"Every waiting guest has a distinct courtyard destination")
    require(targets.values.allSatisfy{!hotel.groundBlocked($0) && $0.distance(to:entrance)>3 && !RPGMaps.hotelSidewalk($0)},"Waiting areas leave the reception entrance and sidewalks clear")
    hotel.world!.guestPositions=Dictionary(uniqueKeysWithValues:hotel.waiting.map{($0.id,entrance)})
    for _ in 0..<90 {hotel.tickWorld()}
    let positions=hotel.waiting.map{hotel.waitingTile($0.id)}
    require(Set(positions).count==positions.count && positions.allSatisfy{$0.distance(to:entrance)>3},"A legacy entrance crowd separates and leaves the doorway")
    let loaded=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(hotel))
    require(loaded.waitingGuestTargets==targets && loaded.worldState.guestPositions==hotel.worldState.guestPositions,"Spread-out waiting guests survive save and reload")
    var office=Motel();office.initializeWorld()
    let guest=office.waiting.removeFirst()
    var visitor=OfficeVisitor(guest:guest);visitor.phase = .leaving;visitor.pathIndex=1;visitor.roomID=0
    office.world!.reception!.visitor=visitor
    let exit=office.groundTile(Tile(x:6,y:10))
    office.world!.travellers=[MotelWalker(id:999,name:"Leaving",color:0xAABBCC,roomID:-1,player:exit,previous:exit,destination:MotelGrounds.gate)]
    office.tickReception()
    require(office.reception.visitor?.guest.id==guest.id && office.worldState.travellers.count==1,"Guests wait inside until the exterior exit clears")
    office.tickWorld();office.tickReception()
    require(office.reception.visitor==nil && office.worldState.travellers.filter{$0.id==guest.id}.count==1,"One guest exits after the previous guest moves away")
    require(Set(office.worldState.travellers.map(\.player)).count==office.worldState.travellers.count,"Departing guests do not overlap at the exit")
    var inside=Motel();inside.initializeWorld()
    let insideGuest=inside.waiting[0]
    var atDesk=OfficeVisitor(guest:insideGuest);atDesk.phase = .waiting;atDesk.pathIndex=OfficeVisitor.path.count-1
    inside.world!.reception!.visitor=atDesk;inside.world!.place = .grounds
    let oldSpot=inside.waitingTile(insideGuest.id)
    inside.world!.player=Tile(x:oldSpot.x-1,y:oldSpot.y)
    require(inside.nearbyAction != .guest(insideGuest.id),"An indoor client cannot be spoken to at an invisible outdoor spot")
    inside.moveActor(dx:1,dy:0)
    require(inside.actorTile==oldSpot,"An indoor client cannot block outdoor walking")
    require(ChaosKind.pool.responseDuration==9,"Pool rescue uses the previous animation duration")
    print("PASS: distributed waiting areas, clear sidewalks and entrance, legacy crowd migration, saved waiting guests and one-at-a-time office exits")
}
clearReceptionEntranceRules()

func navigationMemoRules() {
    var hotel = Motel(); hotel.initializeWorld()
    hotel.waiting = Motel.arrivals(day: 8, count: 12, randomize: false)
    let original = hotel.waitingGuestTargets
    require(hotel.waitingGuestTargets == original, "Repeated waiting lookup is stable")
    let removed = hotel.waiting.removeFirst().id
    require(hotel.waitingGuestTargets[removed] == nil, "Waiting cache invalidates after guest departure")
    hotel.world!.structureOffsets = ["office": Tile(x: 1, y: 0)]
    require(hotel.groundTile(MotelGrounds.officeDoor).x == MotelGrounds.officeDoor.x + 1, "Layout cache follows creative relocation")
    require(hotel.relocatedGrounds.events.first { $0.id == "office" }?.tile == hotel.groundTile(MotelGrounds.officeDoor), "Relocated map events follow moved office")
    hotel.world!.structureOffsets = nil
    require(hotel.groundTile(MotelGrounds.officeDoor) == MotelGrounds.officeDoor, "Clearing creative layout restores coordinates")
    let start = Tile(x: 10, y: 16), target = Tile(x: 10, y: 24)
    if let step = MotelGrounds.nextStep(from: start, to: target, avoiding: []) {
        require(start.distance(to: step) == 1 && !MotelGrounds.blocked(step), "Cached route takes a legal step")
        let blocked: Set<Tile> = [step]
        if let detour = MotelGrounds.nextStep(from: start, to: target, avoiding: blocked) {
            require(!blocked.contains(detour) && !MotelGrounds.blocked(detour), "Cached routes respect moving blockers")
        }
    }
    print("PASS: navigation memo invalidation and moving obstacle fallback")
}
navigationMemoRules()

func guestStoryRules() {
    func meet(_ id:GuestStoryID, day:Int, hotel:inout Motel)->MotelGuest {
        hotel.day=day;hotel.initializeWorld()
        let guest=MotelGuest(id:600000+day*10+(GuestStoryID.allCases.firstIndex(of:id) ?? 0),
            name:id.name,nights:1,color:id.color,story:id.title,category:.traveler,storyID:id)
        hotel.waiting=[guest];hotel.world!.place = .office;hotel.world!.player=OfficeReception.clerk
        var visitor=OfficeVisitor(guest:guest);visitor.phase = .waiting;visitor.pathIndex=OfficeVisitor.path.count-1
        hotel.world!.reception!.visitor=visitor
        return guest
    }
    var hotel=Motel();hotel.initializeWorld();hotel.cash=500
    hotel.prepareStoryArrivals()
    require(hotel.waiting.first?.storyID  == .musician,"First story arrival introduces Rowan")
    let count=hotel.waiting.count;hotel.prepareStoryArrivals()
    require(hotel.waiting.count==count,"Repeated world initialization cannot duplicate story arrivals")
    let rowan=meet(.musician,day:1,hotel:&hotel)
    require(hotel.chooseGuestStory(rowan,choiceID:1),"A guest can offer a show and room discount at the desk")
    let quote=hotel.bookingQuote(rowan,room:hotel.rooms[0])
    require(quote==hotel.rate(for:hotel.rooms[0])-30,"Room discount changes actual booking price")
    require(!hotel.chooseGuestStory(rowan,choiceID:1),"Story decisions cannot be replayed for rewards")
    require(!hotel.startLanternShow(),"A show cannot be claimed remotely")
    let before=hotel.cash
    require(hotel.checkIn(guestID:rowan.id,roomID:0),"Story guest checks into a real room")
    require(hotel.cash==before+quote,"Discounted amount is collected")
    hotel.world!.place = .shop;hotel.world!.shop = .bar;hotel.world!.player=ShopLayout.counter
    let showCash=hotel.cash
    require(hotel.startLanternShow() && hotel.cash==showCash+60,"Keeping the show promise grants its one-time payout")
    require(!hotel.startLanternShow(),"Repeated show interaction cannot farm money")
    let loaded=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(hotel))
    require(loaded.storyBook.showSucceeded && loaded.storyProgress(.musician).chapter==1,"Story memories and show outcomes survive reload")
    let nextRowan=meet(.musician,day:4,hotel:&hotel)
    require(hotel.chooseGuestStory(nextRowan,choiceID:1),"Returning musician remembers and advances a new chapter")
    let finalRowan=meet(.musician,day:7,hotel:&hotel)
    require(hotel.chooseGuestStory(finalRowan,choiceID:0) && hotel.storyBook.musicPartnership,"Successful show unlocks lasting music partnership")
    let income=hotel.cash;hotel.day=8;hotel.settleGuestStoryDay();hotel.settleGuestStoryDay()
    require(hotel.cash==income+12 && hotel.storyBookingBonus==1,"Recurring music income settles once per day")

    var missed=Motel();missed.initializeWorld();missed.cash=200
    let promised=meet(.musician,day:1,hotel:&missed)
    require(missed.chooseGuestStory(promised,choiceID:1),"A show can be promised")
    missed.day=2;missed.settleGuestStoryDay()
    require(missed.storyProgress(.musician).relationship == -1 && !missed.lanternShowAvailable,"Missing the show reduces trust and removes the show")
    missed.settleGuestStoryDay()
    require(missed.storyProgress(.musician).relationship == -1,"A missed promise is penalized only once")
    var poor=Motel();poor.initializeWorld();poor.cash=0
    let traveler=meet(.traveler,day:1,hotel:&poor)
    require(!poor.chooseGuestStory(traveler,choiceID:0) && poor.storyProgress(.traveler).chapter==0,"Unaffordable choices do not consume the chapter")
    require(poor.chooseGuestStory(traveler,choiceID:1),"A meaningful free choice remains available")
    poor.world!.place = .grounds;poor.world!.player=Tile(x:38,y:32)
    require(!poor.canDiscussStory(traveler),"Story choices require physically meeting the guest")
    for id in [GuestStoryID.reviewer,.traveler] {
        var story=Motel();story.initializeWorld();story.cash=500
        for chapter in 0..<3 {
            let guest=meet(id,day:1+chapter*3,hotel:&story)
            require(story.chooseGuestStory(guest,choiceID:0),"All three chapters can be completed for "+id.name)
        }
        require(story.storyProgress(id).chapter==3 && !story.storyProgress(id).ending.isEmpty,"Completed stories retain their ending")
        require(id  == .reviewer ? story.storyBook.travelFeature : story.storyBook.familyReunited,"Choices unlock a lasting story outcome")
    }
    var damaged=Motel();damaged.initializeWorld();damaged.cash=500
    let reviewer=meet(.reviewer,day:1,hotel:&damaged);_=damaged.chooseGuestStory(reviewer,choiceID:0)
    damaged.rooms[0].guest=reviewer;damaged.rooms[0].dirty=true
    let returnReviewer=meet(.reviewer,day:4,hotel:&damaged);_=damaged.chooseGuestStory(returnReviewer,choiceID:0)
    require(damaged.storyProgress(.reviewer).relationship==0,"Poor room care affects the returning reviewer's trust")
    let third=meet(.reviewer,day:7,hotel:&damaged)
    require(!damaged.chooseGuestStory(third,choiceID:0),"Low trust cannot unlock a positive guide feature")
    var oldJSON=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(Motel())) as! [String:Any]
    oldJSON.removeValue(forKey:"guestStories")
    let oldSave=try! JSONDecoder().decode(Motel.self,from:JSONSerialization.data(withJSONObject:oldJSON))
    require(oldSave.guestStories == nil,"Older saves load without story data")
    print("PASS: branching returning guests, real discounts, show promises, repeated reward prevention, persistent endings, care consequences and old saves")
}
guestStoryRules()

func connectedHavenLifeRules() {
    func base()->Motel {
        var hotel=Motel();hotel.initializeWorld();hotel.enableManagement();hotel.initializeHavenLife()
        hotel.cash=5000;hotel.operations!.nextIncidentTick=100000
        return hotel
    }
    func standByNeighbor(_ id:Int,_ hotel:inout Motel) {
        hotel.visit=nil;hotel.world!.place = .grounds
        hotel.world!.neighborPositions=[id:hotel.groundTile(ResidentialLayout.doors[id])]
        hotel.world!.player=hotel.groundTile(ResidentialLayout.doors[id])
    }
    var neighbors=base();standByNeighbor(0,&neighbors)
    require(neighbors.neighborAction(0,choice:0) && !neighbors.neighborAction(0,choice:0),"Neighbor chat improves friendship once daily")
    require(neighbors.neighborAction(0,choice:1),"A physical neighbor can offer an errand")
    require(!neighbors.collectNeighborParcels(),"Parcels cannot be collected remotely")
    neighbors.world!.place = .shop;neighbors.world!.shop = .furniture;neighbors.world!.player=ShopLayout.counter
    require(neighbors.collectNeighborParcels() && !neighbors.collectNeighborParcels(),"Otis hands over each parcel once")
    standByNeighbor(0,&neighbors);let coins=neighbors.cash
    require(neighbors.neighborAction(0,choice:2) && neighbors.cash==coins+20,"Delivering a real parcel earns a favor reward")
    require(!neighbors.neighborAction(0,choice:2),"Delivered parcels cannot be redeemed again")
    require(neighbors.neighborAction(0,choice:3),"Friends can be invited home")
    neighbors.world!.place = .house;neighbors.world!.player=neighbors.homeNeighborTile(0)
    require(neighbors.homeNeighborIDs==[0] && neighbors.welcomeHomeNeighbor(0),"Invited neighbors physically visit and can be welcomed")
    require(!neighbors.welcomeHomeNeighbor(0),"Home visit friendship cannot be farmed")
    var identity=base()
    require(!identity.chooseHavenIdentity(.boutique),"Boutique direction requires reputation and furniture")
    require(identity.chooseHavenIdentity(.lively),"A motel can choose a lively identity")
    identity.attractHavenGuests()
    require(identity.waiting.contains{$0.kind  == .party},"Identity changes the real guest mix")
    require(!identity.chooseHavenIdentity(.peaceful),"Identity choices have a daily cooldown")
    var employees=base();employees.guestsServed=20;_=employees.hire(.cleaner);_=employees.hire(.security)
    for day in 2...4 {employees.day=day;employees.settleHavenDay()}
    require(employees.haven.employees[StaffRole.security.rawValue]?.requestDay==4,"Experienced staff ask for a raise")
    let wage=employees.scheduledWage(.security)
    require(employees.supportHavenEmployee(.security,choice:1) && employees.scheduledWage(.security)==wage+2,"Accepted raises affect actual payroll")
    require(!employees.supportHavenEmployee(.security,choice:1),"Raise requests cannot be accepted twice")
    let fatigue=employees.simulation.profiles[StaffRole.security.rawValue]!.fatigue
    require(employees.supportHavenEmployee(.security,choice:0) && employees.simulation.profiles[StaffRole.security.rawValue]!.fatigue<=fatigue,"Paid breaks support staff")
    require(!employees.supportHavenEmployee(.security,choice:0),"Paid breaks have a daily cooldown")
    employees.day=5;employees.settleHavenDay()
    require(employees.haven.employees[StaffRole.security.rawValue]!.level==2,"Employees level up after four shifts")
    var creatures=base()
    for id in 0..<8 {
        creatures.world!.place = .basement;creatures.world!.player=BasementLayout.gate(id)
        require(creatures.startCreatureAdventure(id),"Each corral offers a unique quest")
        require(!creatures.finishCreatureAdventure(id),"A quest cannot be completed without its keepsake")
        creatures.world!.place = .grounds;creatures.world!.player=creatures.adventureTile(id)
        require(creatures.collectAdventureFind(),"Each keepsake can be found at its physical site")
        creatures.world!.place = .basement;creatures.world!.player=BasementLayout.gate(id)
        require(creatures.finishCreatureAdventure(id) && !creatures.finishCreatureAdventure(id),"Each corral ability unlocks once")
    }
    let snacks=creatures.simulation.stock["snacks",default:0]
    creatures.day=2;creatures.settleHavenDay()
    require(creatures.simulation.stock["snacks",default:0]==snacks+2,"Shrek's unlocked ability supplies real snacks")
    let after=creatures.simulation.stock;creatures.settleHavenDay()
    require(creatures.simulation.stock==after,"Creature morning rewards settle once daily")
    creatures.world!.place = .grounds;creatures.world!.player=Tile(x:45,y:17)
    creatures.world!.pets=["mochi":PetCompanion(following:true,map:"grounds",tile:Tile(x:44,y:17))]
    let pouch=creatures.cash
    require(creatures.exploreWithPet() && creatures.cash==pouch+12 && !creatures.exploreWithPet(),"Following pets find a bounded daily discovery")
    for activity in HavenActivity.allCases {
        var hotel=base();hotel.day=activity.weekday
        hotel.world!.place = .grounds;hotel.world!.player=hotel.groundNearestWalkable(to:hotel.groundTile(activity.location))
        require(hotel.startHavenActivity(),"Each weekly activity is playable on its calendar day")
        require(!hotel.startHavenActivity(),"Entry costs cannot be charged twice")
        for _ in 0..<3 {require(hotel.playHavenActivity(choice:0),"Activity rounds advance at the physical location")}
        require(hotel.haven.activity?.finished==true && !hotel.playHavenActivity(choice:0),"Activity prizes cannot be replayed")
    }
    var neglect=base();var health=neglect.rooms[0].health;health.faults=[.pipe];neglect.rooms[0].hospitality=health
    neglect.day=2;neglect.settleHavenDay();let debt=neglect.simulation.billDebt
    neglect.day=3;neglect.settleHavenDay()
    require(neglect.simulation.billDebt==debt+15 && neglect.haven.cancellations==1,"Ignored damage adds real bills and cancels a booking")
    require(neglect.repairRoom(0),"Damage can be repaired using normal tools and stock")
    neglect.day=4;neglect.settleHavenDay()
    require(neglect.haven.neglectedDays[0]==0,"Repairing a room stops its neglect chain")
    var promises=base();standByNeighbor(1,&promises);_=promises.neighborAction(1,choice:1)
    promises.day=4;promises.settleHavenDay()
    require(!promises.neighborState(1).favorPending && promises.neighborState(1).friendship == -2,"Overdue neighbor promises have lasting consequences")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(creatures))
    require(restored.haven.adventures.count==8 && restored.haven.petFindDays==creatures.haven.petFindDays,"All creature quests and rewards survive reloading")
    var object=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(base())) as! [String:Any]
    object.removeValue(forKey:"havenLife")
    require((try! JSONDecoder().decode(Motel.self,from:JSONSerialization.data(withJSONObject:object))).havenLife==nil,"Older saves remain compatible with Haven life")
    print("PASS: neighbor friendships and visits, identity guest mix, employee pay and growth, eight creature quests, pet discoveries, four weekly games, damage bills, cancellations and saved consequences")
}
connectedHavenLifeRules()


func resortExpansionRules() {
    func base()->Motel {
        var m=Motel();m.waiting=[];m.initializeWorld();m.enableManagement();m.initializeHavenLife();m.initializeExpansion();m.cash=10000
        m.operations!.nextIncidentTick=100000
        return m
    }
    var hotel=base()
    let couple=MotelGuest(id:300,name:"Avery",nights:2,color:0x91B7A1,story:"A getaway",category:.traveler)
    let family=MotelGuest(id:301,name:"Reese",nights:2,color:0xD99B7E,story:"Family holiday",category:.traveler)
    let business=MotelGuest(id:302,name:"Parker",nights:2,color:0x82AFC1,story:"Work trip",category:.traveler)
    let quote=hotel.bookingQuote(couple,room:hotel.rooms[0])
    require(hotel.designHavenRoom(0,.cozy),"Vacant rooms can be designed")
    require(hotel.bookingQuote(couple,room:hotel.rooms[0])==quote+16,"Room suitability changes the actual two-night payment")
    require(hotel.roomMatch(couple,hotel.rooms[0])>hotel.roomMatch(family,hotel.rooms[0]),"Different trip types value different room designs")
    hotel.waiting=[couple,family,business]
    require(hotel.checkIn(guestID:couple.id,roomID:0),"Designed room can be booked")
    require(!hotel.designHavenRoom(0,.family),"Occupied rooms cannot be rearranged")
    require(hotel.expansion.satisfaction[couple.id]==65 && hotel.expansion.daily["welcome"]==1,"Guest satisfaction and daily goals use actual check-in")
    hotel.rooms[1].guest=family;hotel.rooms[1].nightsLeft=2
    hotel.world!.place = .grounds;hotel.world!.player=hotel.groundTile(HotelService.breakfast.tile)
    let snacks=hotel.simulation.stock["snacks",default:0],cash=hotel.cash
    require(hotel.cookHavenBreakfast() && hotel.simulation.stock["snacks"]==snacks-3 && hotel.cash==cash-6,"Breakfast consumes real ingredients and cash")
    require(hotel.serveHavenBreakfast() && hotel.serveHavenBreakfast() && !hotel.serveHavenBreakfast(),"Each staying guest receives only one breakfast")
    require(hotel.expansion.buffet==1 && hotel.expansion.meals.count==2,"Breakfast stock and guest queue remain consistent")
    require(hotel.claimHavenGoal("breakfast") && !hotel.claimHavenGoal("breakfast"),"Optional goal rewards cannot be replayed")
    var sim=hotel.simulation;sim.hour=12;sim.absoluteHour=12;hotel.simulation=sim
    hotel.settleExpansionHour()
    require(hotel.expansion.buffet==0 && !hotel.cookHavenBreakfast(),"Fresh food expires at noon and service closes")
    hotel.day=2;hotel.refreshExpansionDay()
    require(hotel.expansion.daily.isEmpty && hotel.expansion.claimedGoals.isEmpty && hotel.expansion.meals.isEmpty,"Daily reset preserves permanent progress but clears the rush")

    var routine=base();routine.rooms[0].guest=couple;routine.rooms[0].nightsLeft=2
    var s=routine.simulation;s.hour=14;routine.simulation=s
    for _ in 0..<6 {routine.tickWorld()}
    require(routine.expansion.routines[couple.id] != nil && !routine.guestPresent(in:0),"A guest outside must not also appear in their room")
    require(!routine.groundBlocked(routine.routineDestination(couple,room:routine.rooms[0])),"Guest routines route to a real walkable destination")
    let savedRoutine=routine.expansion.routines[couple.id]!
    require(savedRoutine.tile != savedRoutine.previous,"Guest routine uses movement rather than teleporting")
    var unhappy=routine.expansion;unhappy.satisfaction[couple.id]=20;routine.havenExpansion=unhappy
    require(routine.guestRoutine(couple) == .complaint,"Unhappy guests change their behavior and seek help")
    unhappy.satisfaction[couple.id]=70;routine.havenExpansion=unhappy
    routine.operations!.weatherOverride = .rain
    require(routine.guestRoutine(couple) == .shelter,"Rain moves routines to shelter")
    routine.operations!.weatherOverride = .sunny
    var night=routine.simulation;night.hour=22;routine.simulation=night
    var e=routine.expansion;e.routines[couple.id]=HavenRoutineGuest(tile:routine.groundRoomDoor(0),previous:routine.groundRoomDoor(0),activity:.room);routine.havenExpansion=e
    routine.tickHavenRoutines()
    require(routine.expansion.routines[couple.id]==nil && routine.guestPresent(in:0),"Returning guests reappear indoors only after reaching their door")

    var storm=base();storm.day=7;storm.refreshExpansionDay();var noon=storm.simulation;noon.hour=12;noon.absoluteHour=156;storm.simulation=noon
    var prepared=storm
    require(prepared.prepareHavenWeather() && !prepared.prepareHavenWeather(),"Weather preparation costs resources once per day")
    storm.settleExpansionHour();prepared.settleExpansionHour()
    require(storm.rooms[0].health.faults.contains(.pipe) && !prepared.rooms[0].health.faults.contains(.pipe),"Preparation prevents actual storm damage")
    let condition=storm.rooms[0].health.condition;storm.settleExpansionHour()
    require(storm.rooms[0].health.condition==condition,"Hourly weather settlement is idempotent")

    var journey=base()
    require(!journey.advanceJourney() && !journey.journeyAllows(.pool),"New permits require achievements")
    journey.guestsServed=5;var rep=journey.simulation;rep.reputation=50;journey.simulation=rep
    require(journey.advanceJourney() && journey.journeyAllows(.pool) && !journey.journeyAllows(.restaurant),"First milestone unlocks the pool but not later permits")
    require(!journey.advanceJourney(),"Milestone money cannot be farmed")

    var collector=base();collector.world!.place = .grounds
    collector.world!.player=collector.groundNearestWalkable(to:collector.groundTile(Tile(x:57,y:50)))
    require(collector.findHavenDiscovery("shell-pearl") && !collector.findHavenDiscovery("shell-pearl"),"A physical shell becomes a permanent collection entry")
    collector.world!.player=Tile(x:6,y:10)
    require(!collector.findHavenDiscovery("shell-coral"),"Journal hints cannot collect distant objects")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(hotel))
    require(restored.expansion.designs[0] == .cozy && restored.expansion.tier==hotel.expansion.tier,"Design and progression survive saving")
    let collection=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(collector))
    require(collection.expansion.discoveries.contains("shell-pearl"),"Discoveries survive saving")
    var object=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(hotel)) as! [String:Any]
    object.removeValue(forKey:"havenExpansion")
    require((try! JSONDecoder().decode(Motel.self,from:JSONSerialization.data(withJSONObject:object))).havenExpansion==nil,"Older checkpoints load without expansion state")
    print("PASS: routines and room presence, room-aware bookings, breakfast inventory and queue, weather prevention, milestone gates, discoveries, optional goals and old saves")
}
resortExpansionRules()


func beachWardrobeRules() {
    var hotel=Motel();hotel.initializeWorld();hotel.world!.place = .grounds
    require(hotel.guestUsesBeachwear(at:Tile(x:54,y:49)),"Guests switch to beach clothing on dry sand")
    require(!hotel.guestUsesBeachwear(at:Tile(x:54,y:37)),"Guests return to normal clothing away from the beach")
    require(!hotel.guestUsesBeachwear(at:Tile(x:65,y:49)),"Deep water is not a clothing changing location")
    hotel.world!.place = .office
    require(!hotel.guestUsesBeachwear(at:Tile(x:54,y:49)),"Interior guests keep their regular clothing")
    hotel.world!.place = .grounds;hotel.visit=RoomVisit(roomID:0,sneaking:false)
    require(!hotel.guestUsesBeachwear(at:Tile(x:54,y:49)),"Room visits never inherit an outdoor outfit")
    print("PASS: beach clothing boundaries and return to everyday outfits")
}
beachWardrobeRules()


func kitchenGardenRules() {
    func base()->Motel {
        var m=Motel();m.waiting=[];m.initializeWorld();m.enableManagement();m.initializeExpansion();m.initializeKitchenGarden();m.cash=10000
        m.world!.place = .grounds;m.world!.player=Tile(x:2,y:17);m.operations!.nextIncidentTick=100000;m.operations!.weatherOverride = .sunny
        return m
    }
    func grow(_ crop:GardenCrop,_ hotel:inout Motel) {
        hotel.world!.place = .grounds;hotel.world!.player=hotel.gardenTile(0)
        require(hotel.plantKitchenCrop(0,crop:crop),"Seeds plant at the actual plot")
        for _ in 0..<crop.days {
            require(hotel.waterKitchenPlot(0),"Each growing day accepts one watering")
            require(!hotel.waterKitchenPlot(0),"Watering cannot be repeated for extra growth")
            require(hotel.nextDay(),"Rest advances the garden through the real motel day transition")
        }
        require(hotel.plotReady(0) && hotel.harvestKitchenPlot(0),"Watered crops become harvestable")
        require(!hotel.harvestKitchenPlot(0),"A harvested plot cannot pay out twice")
    }
    var hotel=base()
    let cash=hotel.cash
    hotel.world!.player=Tile(x:12,y:16)
    require(!hotel.plantKitchenCrop(0,crop:.basil) && hotel.cash==cash,"Seeds cannot be planted remotely")
    hotel.world!.player=hotel.gardenTile(0)
    require(hotel.plantKitchenCrop(0,crop:.basil),"Starter crop plants")
    require(!hotel.harvestKitchenPlot(0),"Fresh seeds do not produce instant ingredients")
    require(hotel.nextDay() && hotel.kitchenPlot(0).growth==0,"Dry soil pauses growth safely")
    require(hotel.waterKitchenPlot(0) && hotel.nextDay() && hotel.harvestKitchenPlot(0),"Watering restarts growth")
    let ingredients=hotel.kitchen.pantry
    hotel.settleGardenMorning()
    require(hotel.kitchen.pantry==ingredients,"Morning settlement does not duplicate harvests")
    grow(.tomato,&hotel);grow(.carrot,&hotel)
    require(hotel.kitchen.unlocked.contains(GardenRecipe.salad.rawValue),"Harvesting tomatoes and carrots unlocks salad")
    grow(.pepper,&hotel);grow(.basil,&hotel)
    require(hotel.kitchen.unlocked.contains(GardenRecipe.roast.rawValue),"Pepper harvesting and experience unlock roasted vegetables")
    hotel.world!.player=hotel.groundTile(HotelService.breakfast.tile)
    let basil=hotel.kitchen.pantry["basil",default:0],snacks=hotel.simulation.stock["snacks",default:0]
    require(hotel.cookGardenRecipe(.herbToast),"A starter dish cooks at the physical kitchen")
    require(hotel.kitchen.pantry["basil"]==basil-1 && hotel.simulation.stock["snacks"]==snacks-1 && hotel.kitchen.plates["herbToast"]==2,"Cooking atomically consumes ingredients and creates two portions")
    require(hotel.cookGardenRecipe(.herbToast) && hotel.cookGardenRecipe(.herbToast),"Experience uses real cooking")
    require(hotel.kitchen.unlocked.contains(GardenRecipe.stew.rawValue),"Three batches and the required harvests unlock stew")
    var outage=hotel.simulation;outage.powerOut=true;hotel.simulation=outage
    let pantry=hotel.kitchen.pantry
    require(!hotel.cookGardenRecipe(.roast) && hotel.kitchen.pantry==pantry,"Hot dishes stop during outages without consuming ingredients")
    require(hotel.cookGardenRecipe(.salad),"A cold salad remains available during a power outage")
    outage=hotel.simulation;outage.waterOut=true;hotel.simulation=outage
    require(!hotel.cookGardenRecipe(.salad),"Food preparation still requires running water")
    outage.powerOut=false;outage.waterOut=false;hotel.simulation=outage
    let guest=MotelGuest(id:901,name:"Garden guest",nights:2,color:0x91B7A1,story:"Fresh food",category:.traveler)
    hotel.rooms[0].guest=guest;hotel.rooms[0].nightsLeft=2
    let payment=hotel.cash,portions=hotel.kitchen.plates["herbToast",default:0]
    require(hotel.serveGardenDish(.herbToast,guestID:guest.id),"Garden meals serve a real staying guest")
    require(hotel.cash==payment+18 && hotel.kitchen.plates["herbToast"]==portions-1 && hotel.expansion.meals.contains(guest.id),"Serving pays money, consumes a portion and fulfills breakfast")
    require(!hotel.serveGardenDish(.salad,guestID:guest.id) && !hotel.serveGardenDish(.herbToast,guestID:999),"Meals cannot be farmed or sold to nonexistent guests")
    var rain=base();rain.operations!.weatherOverride = .rain
    require(rain.plantKitchenCrop(0,crop:.basil) && !rain.waterKitchenPlot(0) && rain.nextDay() && rain.plotReady(0),"Rain waters crops naturally")
    var moved=base();_=moved.plantKitchenCrop(0,crop:.basil)
    moved.world!.structureOffsets=["kitchen-plot-0":Tile(x:8,y:0)]
    require(moved.gardenTile(0)==Tile(x:10,y:18) && moved.kitchenPlot(0).crop == .basil,"Creative relocation moves the plot without losing its crop")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(hotel))
    require(restored.kitchen.unlocked==hotel.kitchen.unlocked && restored.kitchen.pantry==hotel.kitchen.pantry && restored.kitchen.servedDay==hotel.kitchen.servedDay,"Recipes, ingredients and serving limits survive reloading")
    var object=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(hotel)) as! [String:Any]
    object.removeValue(forKey:"kitchenGarden")
    require((try! JSONDecoder().decode(Motel.self,from:JSONSerialization.data(withJSONObject:object))).kitchenGarden==nil,"Older saves load without garden state")
    for night in [false,true] {for vision in [false,true] {
        require(Motel.ambientOpacity(night:night,nightVision:vision,powerOut:true)==Motel.ambientOpacity(night:night,nightVision:vision,powerOut:false),"Outages never dim the full map")
    }}
    print("PASS: growing and rain, real overnight progress, recipe unlocks, ingredient accounting, guest meal rewards, creative plot relocation, old saves and outage visibility")
}
kitchenGardenRules()


func occasionRules() {
    func base()->Motel {
        var m=Motel();m.initializeWorld();m.enableManagement();m.initializeExpansion();m.initializeKitchenGarden()
        m.havenOccasions=HavenOccasions();m.world!.place = .office;m.cash=1000
        var state=m.simulation;state.reputation=80;m.simulation=state
        m.rooms[0].guest=MotelGuest(id:601,name:"Celebrating guest",nights:3,color:0x91B7A1,story:"Birthday",category:.traveler);m.rooms[0].nightsLeft=3
        return m
    }
    var m=base();let before=m.cash
    require(m.requestHavenInspection(),"A prepared motel can book an inspection")
    require(m.cash==before+40 && m.occasions.inspectionScore>=75,"Passing inspections charge their fee and pay the award")
    require(!m.requestHavenInspection(),"Inspection rewards cannot be repeated within seven days")
    var poor=base();for i in poor.rooms.indices {poor.rooms[i].dirty=true;var h=poor.rooms[i].health;h.condition=0;poor.rooms[i].hospitality=h}
    require(poor.requestHavenInspection() && poor.occasions.award=="Improvements required","Neglected rooms fail inspection")
    var weakService=base();var service=weakService.simulation;service.reputation=20;weakService.simulation=service
    require(weakService.requestHavenInspection() && weakService.occasions.inspectionScore>=75 && !weakService.inspectionHasAward && weakService.rivalAppeal==weakService.inspectionTotal,"A failed minimum check never awards a rivalry bonus even with a high overall score")
    require(m.rivalCampaign(cooperate:false) && !m.rivalCampaign(cooperate:false),"One campaign per week")
    require(m.rivalCampaign(cooperate:true) && !m.rivalCampaign(cooperate:true),"One partnership per week")
    m.day=8;let weekly=m.cash;m.settleOccasionMorning()
    require(m.cash>=weekly+45 && m.occasions.rivalWeek==1,"A weekly partnership pays its promised referral reward")
    let settled=m.cash;m.settleOccasionMorning();require(m.cash==settled,"Weekly prizes cannot be replayed")
    m=base();require(m.acceptCelebration() && !m.acceptCelebration(),"Only one celebration may be booked")
    require(!m.hostCelebration(),"Unprepared celebrations cannot be hosted")
    require(m.prepareCelebration(0) && !m.prepareCelebration(0),"Decorations are charged once")
    require(m.prepareCelebration(2),"Solo owners can prepare hosting")
    m.world!.place = .grounds;m.world!.player=m.groundTile(HotelService.breakfast.tile)
    require(!m.prepareCelebration(1),"Catering requires real cooked portions")
    var k=m.kitchen;k.plates["herbToast"]=4;m.kitchenGarden=k
    let portions=m.occasions.celebration!.kind.portions
    require(m.prepareCelebration(1) && m.kitchen.plates["herbToast"]==4-portions,"Catering consumes the required portions")
    m.world!.place = .office;let fee=m.occasions.celebration!.kind.fee,payment=m.cash
    require(m.hostCelebration() && m.cash==payment+fee && !m.hostCelebration(),"A finished celebration pays exactly once")
    m.settleOccasionEvening();require(m.occasions.missed==0,"Completed celebrations do not cause disappointment")
    var missed=base();_=missed.acceptCelebration();missed.settleOccasionEvening()
    require(missed.occasions.missed==1 && missed.expansion.satisfaction[601]==35,"A missed promise reduces guest satisfaction")
    missed.settleOccasionEvening();require(missed.occasions.missed==1,"Missed promises settle only once")
    var away=base();away.world!.place = .grounds;require(!away.requestHavenInspection() && !away.acceptCelebration() && !away.rivalCampaign(cooperate:true),"Bookings require the physical reception office")
    let saved=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(m))
    require(saved.occasions.celebrations==1 && saved.occasions.inspectionDay==m.occasions.inspectionDay,"Occasion progress survives reloading")
    var object=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(m)) as! [String:Any];object.removeValue(forKey:"havenOccasions")
    require((try! JSONDecoder().decode(Motel.self,from:JSONSerialization.data(withJSONObject:object))).havenOccasions==nil,"Pre-occasion saves remain compatible")
    print("PASS: inspections, weekly rivalry and cooperation, celebrations, real catering, once-only rewards, missed promises and old saves")
}
occasionRules()

func firstChapterStartupRules() {
    let previous=Motel.randomizeGuestArrivals
    defer {Motel.randomizeGuestArrivals=previous}
    Motel.randomizeGuestArrivals=true
    for _ in 0..<20 {
        var game=Game();game.coins=545;game.wakeUp()
        game.motel!.reconcileInteriorSpawn();game.motel!.enableManagement()
        for _ in 0..<20 {game.motel!.tickWorld()}
        require(game.motel!.world != nil && game.motel!.managementEnabled,"First chapter prepares the real office and management")
        let restored=try! JSONDecoder().decode(Game.self,from:JSONEncoder().encode(game))
        require(restored.motel?.managementEnabled == true,"First chapter checkpoint survives restoring")
    }
    func scale(_ w:Double,_ h:Double,_ indoor:Bool=true)->Double? {
        RPGViewport.cameraScale(mapWidth:240,mapHeight:240,viewportWidth:w,viewportHeight:h,columns:14,interior:indoor)
    }
    require(scale(390,0)==nil && scale(0,844)==nil,"A collapsed transition view must not create an infinite camera scale")
    require(scale(390,0,false)==nil && scale(0,844,false)==nil,"Outdoor transitions also wait for a real viewport")
    require(scale(.nan,844)==nil && scale(390,.infinity)==nil && scale(390,-1)==nil,"Invalid viewport dimensions are rejected")
    require(scale(390,844)==240.0/390.0 && scale(390,844,false)==224.0/390.0,"Ready camera layouts keep the existing indoor and outdoor zoom")
    print("PASS: production first-chapter startup, normal guests, initial ticks, checkpoint restoration and finite transition camera")
}
firstChapterStartupRules()

func cartoonIdentityRules() {
    let variants=Array(0..<7)+Array(100..<124)+Array(180..<185)+Array(200..<209)+Array(220..<240)+Array(310..<317)+Array(461..<466)+Array(520..<526)+Array(530..<532)+Array(560..<566)+Array(610..<616)+[700]
    let faces=variants.map{NPCDesign(variant:$0).fingerprint}
    require(Set(faces).count==variants.count,"Every ordinary guest, neighbor, worker, keeper, diner and police design is distinct")
    require(Set((0..<1024).map{NPCDesign(variant:$0).fingerprint}).count==1024,"The native character system does not cycle through four repeated faces")
    for variant in variants {
        require(NPCDesign(variant:variant)==NPCDesign(variant:variant),"A person keeps the same appearance across maps and reloads")
    }
    let previous=Motel.randomizeGuestArrivals
    defer {Motel.randomizeGuestArrivals=previous}
    Motel.randomizeGuestArrivals=false
    let capped=Motel.arrivals(day:1,count:1000,randomize:false)
    require(capped.count==Motel.guestNames.count && Set(capped.map(\.name)).count==capped.count,"A large arrival request never creates duplicate people")
    require(Motel.arrivals(day:1,count:4,excluding:Set(Motel.guestNames)).isEmpty,"An exhausted identity pool creates no clones")
    var m=Motel();m.cash=10000
    for i in 0..<3 {m.rooms[i].guest=Motel.arrivals(day:1,count:3,randomize:false)[i];m.rooms[i].nightsLeft=3}
    require(m.nextDay(),"Advance a day while guests stay in occupied rooms")
    let residents=Set(m.rooms.compactMap{$0.guest?.name})
    require(residents.isDisjoint(with:Set(m.waiting.map(\.name))),"A checked-in person cannot appear again in the arrival queue")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(m))
    require(restored.rooms.compactMap{$0.guest?.appearanceSeed}==m.rooms.compactMap{$0.guest?.appearanceSeed},"Existing guest appearance identities survive saving without a new schema")
    print("PASS: unique cartoon NPC designs, stable appearance identities, no cloned guest arrivals and unchanged checkpoint schema")
}
cartoonIdentityRules()


func homeRoamingAndRearBathroomRules() {
    var home=Motel();home.initializeWorld();home.waiting=[];home.world!.place = .house;home.world!.player=Tile(x:7,y:12)
    var paths:[String:Set<Tile>]=["chichu":[],"chichi":[]]
    home.home=FamilyHome();home.home!.placed=[PlacedHomeObject(id:99,kind:.table,tile:Tile(x:8,y:10))]
    for _ in 0..<120 {
        home.tickWorld()
        for id in ["chichu","chichi"] {
            let tile=home.petState(id).tile;paths[id]!.insert(tile)
            require(!home.homeBlocked(tile),"Roaming cats avoid real home furniture")
            require(tile != FamilyHome.exit && tile != BasementLayout.homeStairs,"Cats do not leave through either stair or doorway")
        }
        require(home.petState("chichu").tile != home.petState("chichi").tile,"Roaming cats reserve separate floor positions")
    }
    require(paths.values.allSatisfy{$0.count>5},"Both cats explore the home instead of staying on their beds")
    home.togglePet("chichu");let follower=home.petState("chichu").tile
    for _ in 0..<12 {home.tickWorld()}
    require(home.petState("chichu").tile==follower,"A follower does not independently roam")
    home.togglePet("chichu");let waiting=home.petState("chichu").tile
    for _ in 0..<16 {home.tickWorld()}
    require(home.petState("chichu").tile==waiting && home.petState("chichu").stay==true,"Explicit Stay here pauses home roaming")
    let oldPet=Data(#"{"following":false,"map":"house","tile":{"x":10,"y":12}}"#.utf8)
    let legacy=try! JSONDecoder().decode(PetCompanion.self,from:oldPet)
    require(legacy.tile==OfficeReception.chichu && legacy.stay==nil,"Old pet saves load without new roaming fields")
    let restored=try! JSONDecoder().decode(Motel.self,from:JSONEncoder().encode(home))
    require(restored.petState("chichu").stay==true && restored.petState("chichu").tile==waiting,"Stay and roaming positions survive a checkpoint")
    home.world!.place = .grounds;let away=home.petState("chichi").tile
    for _ in 0..<8 {home.tickWorld()}
    require(home.petState("chichi").tile==away && home.petState("chichi").map=="house","House cats do not appear or roam on other maps")
    home.world!.place = .house;home.world!.player=home.reception.hildarelys
    let before=home.reception.hildarelys;for _ in 0..<6 {home.tickReception()}
    require(home.reception.hildarelys==before,"Hildarelys pauses nearby for a reliable conversation target")
    require(RoomVisit.blocked(Tile(x:6,y:3)) && RoomVisit.blocked(Tile(x:7,y:3)),"Rear shower and privacy screen have matching solid tiles")
    require(!RoomVisit.blocked(Tile(x:5,y:3)),"The rear bathroom doorway stays open")
    for tick in 0..<12 {var visit=RoomVisit(roomID:0,sneaking:true);visit.ticks=tick;require(!RoomVisit.blocked(visit.guestTile),"Guest patrol stays out of bathroom fixtures")}
    var oldRoom=Motel();oldRoom.initializeWorld();oldRoom.visit=RoomVisit(roomID:0,sneaking:false);oldRoom.visit!.player=Tile(x:7,y:3)
    oldRoom.world!.pets=["chichu":PetCompanion(map:"room-0",tile:Tile(x:7,y:3))]
    oldRoom.reconcileInteriorSpawn()
    require(!RoomVisit.blocked(oldRoom.actorTile) && !RoomVisit.blocked(oldRoom.petState("chichu").tile),"Old room saves relocate players and pets out of the new washroom fixtures")
    print("PASS: home roaming, furniture avoidance, stay/follow commands, legacy pet saves and rear bathroom migration")
}
homeRoamingAndRearBathroomRules()
