import Foundation

struct MotelGuest: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let nights: Int
    let color: UInt32
    let story: String
    var category: GuestKind?
    var kind: GuestKind { category ?? GuestKind.allCases[(Motel.guestNames.firstIndex(of:name) ?? max(0,id)%10) % GuestKind.allCases.count] }
    var appearanceSeed:Int {Motel.appearanceSeed(name:name,id:id)}
}
struct MotelRoom: Codable, Identifiable {
    let id: Int
    var theme = 0
    var furniture = 0
    var guest: MotelGuest?
    var nightsLeft = 0
    var dirty = false
    var stolen: Set<Int> = []
    var cleanedTasks: Set<Int>?
    var hospitality: GuestRoomState?
    var health: GuestRoomState { hospitality ?? GuestRoomState() }
    var number: Int { (id / 9 + 1) * 100 + id % 9 + 1 }
    init(id: Int) { self.id = id; self.theme = id % 4 }
    var available: Bool { guest == nil && !dirty && health.cleanliness >= 60 && health.faults.isEmpty }
}
struct RoomVisit: Codable {
    let roomID: Int
    let sneaking: Bool
    var player = Tile(x: 4, y: 7)
    var facing = 3
    var alert = 0
    var ticks = 0
    var loot: Set<Int> = []
    var pocket = 0
    var guestTile: Tile {
        [Tile(x: 6, y: 3), Tile(x: 6, y: 4), Tile(x: 5, y: 4), Tile(x: 5, y: 3)][(ticks / 3) % 4]
    }
    static let lootTiles = [Tile(x: 2, y: 3), Tile(x: 6, y: 6), Tile(x: 2, y: 6)]
    static let lootNames = ["Suitcase", "Watch", "Camera"]
    static let lootValues = [45, 70, 95]
    static let lootNoise = [16, 24, 32]
    var nearbyLoot: Int? { Self.lootTiles.indices.first { player.distance(to: Self.lootTiles[$0]) <= 1 } }
    static func blocked(_ tile: Tile) -> Bool {
        RPGMaps.room.blocked(tile)
    }
}
struct Motel: Codable {
    static let goal = 9
    static let guestNames = ["Robin", "Sasha", "Ellis", "Alex", "Morgan", "Casey", "Jamie", "Blair", "Drew", "Quinn"]
    static func appearanceSeed(name:String,id:Int)->Int {100+(guestNames.firstIndex(of:name) ?? id)}
    static let themeNames = ["Sage", "Sunset", "Ocean", "Plum"]
    static let themeColors: [UInt32] = [0x91B7A1, 0xD99B7E, 0x82AFC1, 0xAE95B9]
    var day = 1
    var cash = 180
    var rooms = (0..<3).map { MotelRoom(id: $0) }
    var officeTheme = 0
    var officeLevel = 0
    var waiting = Motel.arrivals(day: 1, count: 4)
    var visit: RoomVisit?
    var caught = false
    var lastEvent = "Three rooms. One desk. A fresh start."
    var guestsServed = 0
    var totalStolen = 0
    var world: MotelWorldState?
    var operations: MotelOperations?
    var home: FamilyHome?
    var household: FamilyHome { home ?? FamilyHome() }
    var expansionCost: Int { 250 + (rooms.count - 3) * 150 }
    var occupancy: Int { rooms.filter { $0.guest != nil }.count }
    var goalReached: Bool { rooms.count >= expansionCapacity }
    var canSave: Bool { visit == nil && !caught }
    func rate(for room: MotelRoom) -> Int {
        let base=80 + room.furniture * 30 + officeLevel * 15
        return operationsState.simulation == nil ? base : managementRate(room,base:base)
    }
    static func arrivals(day: Int, count: Int) -> [MotelGuest] {
        let names = Self.guestNames
        let stories = ["Passing through on a road trip.", "In town for the weekend market.", "Needs a quiet place to write.", "Visiting an old friend.", "Taking the scenic route home."]
        return (0..<count).map { index in
            let key = day * 10 + index
            return MotelGuest(id: key, name: names[index % names.count],
                              nights: index % 3 == 1 ? 2 : 1,
                              color: [UInt32(0xD99B7E), 0x82AFC1, 0xAE95B9, 0xD6BD71][index % 4],
                              story: stories[(day + index) % stories.count])
        }
    }
    @discardableResult mutating func checkIn(guestID: Int, roomID: Int) -> Bool {
        guard !caught, (visit == nil || managementEnabled && operationsState.workers.contains(where:{$0.role == .clerk && $0.active})), let guestIndex = waiting.firstIndex(where: { $0.id == guestID }),
              let roomIndex = rooms.firstIndex(where: { $0.id == roomID }),
              rooms[roomIndex].available else { return false }
        let candidate=waiting[guestIndex]
        guard mayCheckIn(candidate,room:rooms[roomIndex]) else { return false }
        let guest = waiting.remove(at: guestIndex)
        let payment = bookingQuote(guest,room:rooms[roomIndex])
        rooms[roomIndex].guest = guest
        rooms[roomIndex].nightsLeft = operationsState.simulation == nil ? guest.nights : (bookingPlan(guest,room:rooms[roomIndex]) == .weekly ? 7 : guest.nights)
        rooms[roomIndex].stolen = []
        cash += payment
        repayBusinessDebt()
        guestsServed += 1
        if isAtReception {playVisual("checkin",target:OfficeReception.computer)}
        registerContract(guest,room:rooms[roomIndex],payment:payment)
        prepareChaosClock()
        lastEvent = "\(guest.name) checked into room \(rooms[roomIndex].number). +\(payment) coins."
        return true
    }
    @discardableResult mutating func clean(_ roomID: Int) -> Bool {
        guard canSave, let index = rooms.firstIndex(where: { $0.id == roomID }),
              rooms[index].guest == nil, rooms[index].dirty else { return false }
        guard useCleaningStock(full:true) else { return false }
        rooms[index].dirty = false
        if operationsState.simulation != nil { var health=rooms[index].health; health.cleanliness=100; health.faults.remove(.mattress); rooms[index].hospitality=health }
        playVisual("mop")
        rooms[index].cleanedTasks = Set(MotelGrounds.cleaningTiles.indices)
        lastEvent = "Room \(rooms[index].number) is ready. A little elbow grease costs nothing."
        return true
    }
    @discardableResult mutating func decorate(roomID: Int?, theme: Int) -> Bool {
        guard canSave, Self.themeNames.indices.contains(theme) else { return false }
        if let roomID {
            guard let index = rooms.firstIndex(where: { $0.id == roomID }),
                  rooms[index].guest == nil, rooms[index].theme != theme, cash >= 25 else { return false }
            cash -= 25
            rooms[index].theme = theme
        } else {
            guard officeTheme != theme, cash >= 25 else { return false }
            cash -= 25
            officeTheme = theme
        }
        lastEvent = "Fresh \(Self.themeNames[theme].lowercased()) paint. -25 coins."
        return true
    }
    @discardableResult mutating func upgrade(roomID: Int?) -> Bool {
        guard canSave else { return false }
        if let roomID {
            guard let index = rooms.firstIndex(where: { $0.id == roomID }),
                  rooms[index].guest == nil, rooms[index].furniture < 2 else { return false }
            let price = (rooms[index].furniture + 1) * 90
            guard cash >= price else { return false }
            cash -= price
            rooms[index].furniture += 1
            lastEvent = "Room \(rooms[index].number) upgraded. Its nightly rate increased by 30."
        } else {
            let price = (officeLevel + 1) * 120
            guard officeLevel < 2, cash >= price else { return false }
            cash -= price
            officeLevel += 1
            lastEvent = "Office upgraded. All nightly rates increased by 15."
        }
        return true
    }
    @discardableResult mutating func expand() -> Bool {
        guard canSave, !goalReached, cash >= expansionCost else { return false }
        cash -= expansionCost
        rooms.append(MotelRoom(id: rooms.count))
        lastEvent = managementEnabled && goalReached ? "Capacity reached. Buy land or add an upper floor on the management board." : goalReached ? "Nine rooms! You built Brainstorm Haven into a thriving Airb&b. Keep running it as long as you like." : "Room \(rooms.last!.number) is built and ready for its first guest."
        return true
    }
    @discardableResult mutating func nextDay() -> Bool {
        guard !caught, (visit == nil || managementEnabled), business.police == nil else { return false }
        day += 1
        let beforeWages=cash
        payStaffForDay()
        logMoney(cash-beforeWages,category:"Wages",note:"Day and night shift payroll")
        var departures = 0
        for index in rooms.indices where rooms[index].guest != nil {
            rooms[index].nightsLeft -= 1
            if rooms[index].nightsLeft == 0 {
                recordCheckoutReview(rooms[index])
                rooms[index].guest = nil
                rooms[index].dirty = true
                rooms[index].cleanedTasks = []
                rooms[index].stolen = []
                departures += 1
            }
        }
        waiting = Self.arrivals(day: day, count: max(1,min(rooms.count + 1 + officeLevel, 10) - bookingPenalty))
        finishSimulationDay()
        if let oldVisit=visit,oldVisit.sneaking,rooms.first(where:{$0.id==oldVisit.roomID})?.guest==nil {
            var empty=RoomVisit(roomID:oldVisit.roomID,sneaking:false)
            empty.player=oldVisit.player;empty.facing=oldVisit.facing;empty.pocket=oldVisit.pocket;empty.loot=oldVisit.loot
            visit=empty
        }
        lastEvent = "Day \(day): \(departures) checkouts. Clean the empty rooms and welcome new arrivals."
        return true
    }
    @discardableResult mutating func enter(_ roomID: Int) -> Bool {
        guard !isRidingBike else{return false}
        guard canSave, let room = rooms.first(where: { $0.id == roomID }) else { return false }
        visit = RoomVisit(roomID: roomID, sneaking: room.guest != nil)
        return true
    }
    mutating func tick() {
        guard !caught, var roomVisit = visit, roomVisit.sneaking else { return }
        roomVisit.ticks += 1
        roomVisit.alert = min(100, roomVisit.alert + 3)
        visit = roomVisit
        detect()
    }
    mutating func move(dx: Int, dy: Int) {
        guard !caught, var roomVisit = visit, abs(dx) <= 1, abs(dy) <= 1, dx != 0 || dy != 0 else { return }
        roomVisit.facing = dy > 0 ? 0 : dx < 0 ? 1 : dx > 0 ? 2 : 3
        let next = Tile(x: roomVisit.player.x + dx, y: roomVisit.player.y + dy)
        guard !RoomVisit.blocked(next) else { visit = roomVisit; return }
        if dx != 0 && dy != 0 {
            guard !RoomVisit.blocked(Tile(x: roomVisit.player.x + dx, y: roomVisit.player.y)),
                  !RoomVisit.blocked(Tile(x: roomVisit.player.x, y: roomVisit.player.y + dy)) else { visit = roomVisit; return }
        }
        if next == Tile(x: 4, y: 8) { leave(); return }
        roomVisit.player = next
        if roomVisit.sneaking { roomVisit.alert = min(100, roomVisit.alert + 3) }
        visit = roomVisit
        detect()
    }
    @discardableResult mutating func steal() -> Bool {
        guard !caught, var roomVisit = visit, roomVisit.sneaking,
              let item = roomVisit.nearbyLoot,
              let room = rooms.first(where: { $0.id == roomVisit.roomID }),
              !room.stolen.contains(item), !roomVisit.loot.contains(item) else { return false }
        playVisual("steal-\(item)",target:RoomVisit.lootTiles[item])
        if managementEnabled {var s=simulation;s.criminal += 1;s.heat += 5;simulation=s}
        roomVisit.loot.insert(item)
        roomVisit.pocket += RoomVisit.lootValues[item]
        roomVisit.alert = min(100, roomVisit.alert + RoomVisit.lootNoise[item])
        visit = roomVisit
        detect()
        return !caught
    }
    private mutating func detect() {
        guard let roomVisit = visit, roomVisit.sneaking else { return }
        if roomVisit.alert >= 100 || (guestPresent(in: roomVisit.roomID) && roomVisit.player.distance(to: roomVisit.guestTile) <= 1) {
            caught = true
            lastEvent = "The guest caught you inside their room. Your Airb&b story ends here."
        }
    }
    mutating func leave() {
        guard !caught, let roomVisit = visit else { return }
        guard roomVisit.player.distance(to: Tile(x: 4, y: 8)) <= 1 else { return }
        if let index = rooms.firstIndex(where: { $0.id == roomVisit.roomID }) {
            rooms[index].stolen.formUnion(roomVisit.loot)
        }
        var belongings=household
        belongings.stolen += roomVisit.loot.sorted()
        home=belongings
        totalStolen += roomVisit.pocket

        lastEvent = roomVisit.pocket > 0 ? "You slipped out with \(roomVisit.pocket) coins worth of belongings. Visit the pawn shop to sell them." : "Back outside. The desk is waiting."
        visit = nil
        if world != nil {
            let door = groundRoomDoor(roomVisit.roomID)
            world!.place = .grounds
            world!.player = Tile(x: door.x, y: door.y + 1)
            world!.facing = 0
        }
    }
}
