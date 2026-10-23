import Foundation

enum MotelPlace: String, Codable { case office, grounds, house, shop, basement }
struct MotelWalker: Codable, Identifiable {
    let id: Int
    let name: String
    let color: UInt32
    let roomID: Int
    var player: Tile
    var previous: Tile
    let destination: Tile
    var appearanceSeed:Int {Motel.appearanceSeed(name:name,id:id)}
}
struct MotelWorldState: Codable {
    var place: MotelPlace = .office
    var player = Tile(x: 4, y: 3)
    var facing = 0
    var hasCleaningKit = false
    var travellers: [MotelWalker] = []
    var tick = 0
    var reception: OfficeReception?
    var shop: NeighborhoodShop?
    var beachSeat:Int?
    var barDrink:BarDrink?
    var barOrders:Int?
    var guestPositions: [Int:Tile]?
    var guestPrevious: [Int:Tile]?
    var witnessPositions: [Int:Tile]?
    var neighborPositions:[Int:Tile]?
    var neighborPrevious:[Int:Tile]?
    var neighborStops:[Int:Int]?
    var townPositions:[Int:Tile]?
    var townPrevious:[Int:Tile]?
    var townDestinations:[Int:Int]?
    var fishMeal:FishMeal?
    var claimedBikes:[HotelCar]?
    var ridingBike:Int?
    var bikeParking:[Int:Tile]?
    var structureOffsets:[String:Tile]?
    var corrals:[Int:CorralCare]?
    var pets: [String: PetCompanion]?
    var guestFavour: GuestFavour?
    var guestFavourDays: [Int:Int]?
    var guestGreetingDays: [Int:Int]?
    var brokenGuestPromises: Set<Int>?
}
enum MotelAction: Hashable {
    case basement, corral(Int), computer, pet(String), home, homeDecor, shop(NeighborhoodShop)
    case none, office, room(Int), guest(Int), construction, desk, save, rest, tools
    case paint(Int?), furniture(Int?), clean(Int), loot(Int), exit, incident
}
private final class GroundsRoutes: @unchecked Sendable {
    private let lock = NSLock()
    private var fields: [Tile: [Int]] = [:]
    func distances(to target: Tile) -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        if let field = fields[target] { return field }
        var field = Array(repeating: -1, count: MotelGrounds.width * MotelGrounds.height)
        var queue = [target], cursor = 0
        field[target.y * MotelGrounds.width + target.x] = 0
        while cursor < queue.count {
            let tile = queue[cursor]; cursor += 1
            let distance = field[tile.y * MotelGrounds.width + tile.x] + 1
            for (dx, dy) in [(0,1),(1,0),(-1,0),(0,-1)] {
                let next = Tile(x: tile.x + dx, y: tile.y + dy)
                guard !MotelGrounds.blocked(next) else { continue }
                let index = next.y * MotelGrounds.width + next.x
                guard field[index] == -1 else { continue }
                field[index] = distance; queue.append(next)
            }
        }
        // Bound memory even when visitors choose many different destinations.
        if fields.count >= 32 { fields.removeAll(keepingCapacity: true) }
        fields[target] = field
        return field
    }
}
private let groundsRoutes = GroundsRoutes()

enum MotelGrounds {
    static let width = 72
    static let height = 64
    static let officeDoor = Tile(x: 6, y: 9)
    static let sign = Tile(x: 12, y: 26)
    static let gate = Tile(x: 6, y: 35)
    static func roomOrigin(_ id: Int) -> Tile { Tile(x: 14 + (id % 3) * 8, y: 4 + ((id % 9) / 3) * 9) }
    static func roomDoor(_ id: Int) -> Tile {
        let origin = roomOrigin(id)
        return Tile(x: origin.x + 2, y: origin.y + 4)
    }
    static func guestTile(_ id: Int) -> Tile { Tile(x: 4 + (id % 5) * 2, y: 11 + ((id % 10) / 5) * 2) }
    static func refuge(from tile: Tile, danger: Tile) -> Tile {
        [Tile(x:2,y:12),Tile(x:11,y:32),Tile(x:36,y:27),Tile(x:12,y:3)]
            .max { $0.distance(to:danger) < $1.distance(to:danger) } ?? tile
    }
    static func escapeStep(from start:Tile,danger:Tile,avoiding:Set<Tile>) -> Tile? {
        let clearance=min(12,start.distance(to:danger))
        var unsafe=avoiding
        for y in 1..<height-1 { for x in 1..<width-1 {
            let tile=Tile(x:x,y:y)
            if tile.distance(to:danger)<clearance { unsafe.insert(tile) }
        }}
        return nextStep(from:start,to:refuge(from:start,danger:danger),avoiding:unsafe)
    }
    // Immutable terrain is shared by player movement and every NPC route search.
    static let walkableTiles: Set<Tile> = {
        var tiles:Set<Tile>=[]
        for y in 0..<height { for x in 0..<width {
            let tile=Tile(x:x,y:y)
            if !RPGMaps.grounds.blocked(tile) { tiles.insert(tile) }
        }}
        return tiles
    }()
    static func blocked(_ tile: Tile) -> Bool { !walkableTiles.contains(tile) }
    static func nearestWalkable(to point:Tile)->Tile {
        walkableTiles.min {a,b in
            let da=a.distance(to:point),db=b.distance(to:point)
            return da != db ? da<db : a.y != b.y ? a.y<b.y : a.x<b.x
        } ?? gate
    }
    static func nextStep(from start: Tile, to target: Tile, avoiding: Set<Tile>) -> Tile? {
        if start == target || blocked(target) { return nil }
        if avoiding.contains(target) {
            // Keep approaching a busy destination, but never scan the entire
            // map for a path that cannot finish on its occupied final tile.
            return [(0,1),(1,0),(-1,0),(0,-1)].map { Tile(x:start.x+$0.0,y:start.y+$0.1) }.first {
                !blocked($0) && !avoiding.contains($0) && $0.distance(to:target)<start.distance(to:target)
            }
        }
        // Reuse static distance fields, but verify the entire preferred path
        // against moving actors before taking it. Otherwise retain dynamic BFS.
        if !blocked(start) {
            let field = groundsRoutes.distances(to: target)
            var cursor = start
            var first: Tile?
            while cursor != target {
                let distance = field[cursor.y * width + cursor.x]
                guard distance > 0 else { break }
                let candidates = [(0,1),(1,0),(-1,0),(0,-1)].map {
                    Tile(x: cursor.x + $0.0, y: cursor.y + $0.1)
                }
                guard let next = candidates.first(where: {
                    !blocked($0) && field[$0.y * width + $0.x] == distance - 1
                }), !avoiding.contains(next) else { break }
                if first == nil { first = next }
                cursor = next
            }
            if cursor == target { return first }
        }
        var queue = [start]
        var seen: Set<Tile> = [start]
        var parents: [Tile: Tile] = [:]
        var cursor = 0
        while cursor < queue.count {
            let tile = queue[cursor]
            cursor += 1
            for (dx, dy) in [(0,1),(1,0),(-1,0),(0,-1)] {
                let next = Tile(x: tile.x + dx, y: tile.y + dy)
                guard !blocked(next), !avoiding.contains(next), seen.insert(next).inserted else { continue }
                parents[next] = tile
                if next == target {
                    var step = next
                    while let parent = parents[step], parent != start { step = parent }
                    return step
                }
                queue.append(next)
            }
        }
        return nil
    }
    static func staffStep(from start:Tile,to target:Tile,avoiding:Set<Tile>)->Tile? {
        if !avoiding.contains(target) {return nextStep(from:start,to:target,avoiding:avoiding)}
        let approaches=[Tile(x:target.x-1,y:target.y),Tile(x:target.x+1,y:target.y),Tile(x:target.x,y:target.y-1),Tile(x:target.x,y:target.y+1)]
            .filter {!blocked($0) && !avoiding.contains($0)}.sorted {$0.distance(to:start)<$1.distance(to:start)}
        for approach in approaches {
            if approach == start {return nil}
            if let step=nextStep(from:start,to:approach,avoiding:avoiding) {return step}
        }
        return nil
    }
    static let desk = Tile(x: 4, y: 4)
    static let bed = Tile(x: 2, y: 2)
    static let tools = Tile(x: 1, y: 5)
    static let paint = Tile(x: 7, y: 5)
    static let logbook = Tile(x: 6, y: 2)
    static func officeBlocked(_ tile: Tile) -> Bool {
        RPGMaps.office.blocked(tile)
    }
    static let cleaningTiles = [Tile(x: 3, y: 3), Tile(x: 2, y: 6), Tile(x: 5, y: 5)]
    static let cleaningNames = ["Make bed", "Collect trash", "Mop spill"]
    static let roomPaint = Tile(x: 7, y: 2)
}

extension Motel {
    func waitingTile(_ id:Int) -> Tile { worldState.guestPositions?[id] ?? groundGuestTile(id) }
    var worldState: MotelWorldState { world ?? MotelWorldState() }
    var actorTile: Tile { visit?.player ?? worldState.player }
    var actorFacing: Int { visit?.facing ?? worldState.facing }
    var mapName: String {
        if let visit, let room = rooms.first(where: { $0.id == visit.roomID }) { return "ROOM \(room.number)" }
        if let shop=currentShop {return shop.title.uppercased()}
        if isAtBasement {return "BASEMENT SANCTUARY"}
        if isAtHome { return "FAMILY HOME" }
        if worldState.place == .grounds && BeachLayout.contains(actorTile) {return "SUNSET COVE BEACH"}
        return worldState.place == .office ? "YOUR OFFICE" : "Airb&b GROUNDS"
    }
    var cleaningTarget: Int? {
        guard let visit, !visit.sneaking, let room = rooms.first(where: { $0.id == visit.roomID }), room.dirty else { return nil }
        return MotelGrounds.cleaningTiles.indices.first {
            !(room.cleanedTasks ?? []).contains($0) && visit.player.distance(to: MotelGrounds.cleaningTiles[$0]) <= 1
        }
    }
    var nearbyAction: MotelAction {
        if caught { return .none }
        let player = actorTile
        let petAction: MotelAction = visiblePets.first(where: {player.distance(to:$0.value.tile)<=1}).map { .pet($0.key) } ?? .none
        if let visit {
            if player.distance(to: Tile(x: 4, y: 8)) <= 1 { return .exit }
            if visit.sneaking {
                if let item = visit.nearbyLoot, !visit.loot.contains(item),
                   let room = rooms.first(where: { $0.id == visit.roomID }), !room.stolen.contains(item) { return .loot(item) }
                return petAction
            }
            if let target = cleaningTarget { return .clean(target) }
            if player.distance(to: MotelGrounds.roomPaint) <= 1 { return .paint(visit.roomID) }
            if player.distance(to: Tile(x: 3, y: 2)) <= 1 { return .furniture(visit.roomID) }
            return petAction
        }
        if let shop=currentShop {
            if player.distance(to:ShopLayout.exit)<=1 {return .exit}
            if player.distance(to:ShopLayout.counter)<=1 {return .shop(shop)}
            return petAction
        }
        if isAtBasement {
            if player.distance(to:BasementLayout.stairs)<=1 {return .exit}
            if let id=nearbyCorral {return .corral(id)}
            return petAction
        }
        if isAtHome {
            if player.distance(to:BasementLayout.homeStairs)<=1 {return .basement}
            if player.distance(to:FamilyHome.exit) <= 1 { return .exit }
            if player.distance(to:FamilyHome.workbench) <= 1 { return .homeDecor }
        }
        if isAtHome { return petAction }
        if isAtReception {
            if player.distance(to:OfficeReception.door) <= 1 { return .exit }
            if player.distance(to:Tile(x:1,y:7)) <= 1 { return .tools }
            if player.distance(to:Tile(x:1,y:9)) <= 1 { return .paint(nil) }
            if player.distance(to:Tile(x:1,y:2)) <= 1 { return .rest }
            if player.distance(to:OfficeReception.computer) <= 1 { return .computer }
            if player.distance(to:OfficeReception.clerk) <= 1 { return .desk }
            if player.distance(to:Tile(x:5,y:4)) <= 1 { return .save }
            return petAction
        }
        if player.distance(to:groundTile(FamilyHome.door)) <= 1 { return .home }
        for shop in NeighborhoodShop.allCases where player.distance(to:groundTile(shop.door)) <= 1 { return .shop(shop) }
        if nearbyIncident { return .incident }
        if let guest = waiting.first(where: { $0.id != reception.visitor?.guest.id && player.distance(to: waitingTile($0.id)) <= 1 }) { return .guest(guest.id) }
        if player.distance(to: groundTile(MotelGrounds.officeDoor)) <= 1 { return .office }
        for room in rooms where room.id / 9 == viewingFloor && player.distance(to: groundRoomDoor(room.id)) <= 1 { return .room(room.id) }
        if !goalReached && (player.distance(to: MotelGrounds.sign) <= 1 || player.distance(to: groundRoomDoor(rooms.count)) <= 1) { return .construction }
        return petAction
    }
    mutating func initializeWorld() {
        assignRoomColors()
        if Self.randomizeGuestArrivals { prepareStoryArrivals() }
        if world == nil { world = MotelWorldState() }
        if Self.randomizeGuestArrivals { initializeHavenLife() }
        if world!.reception == nil { world!.reception = OfficeReception() }
        if world!.place == .office,world!.player.x == 9,MotelGrounds.officeBlocked(world!.player) { world!.player.x=8 }

    }
    mutating func reconcileInteriorSpawn() {
        initializeWorld()
        var homeState=household
        let moved=homeState.placed.filter{$0.tile.distance(to:BasementLayout.homeStairs)<=1}
        if !moved.isEmpty {
            homeState.storage.append(contentsOf:moved.map(\.kind))
            homeState.placed.removeAll{$0.tile.distance(to:BasementLayout.homeStairs)<=1}
            home=homeState
        }
        // Relocated buildings must not strand people from an older checkpoint.
        if var people=world!.townPositions {
            for (id,tile) in people where groundBlocked(tile) {people[id]=groundNearestWalkable(to:tile)}
            world!.townPositions=people;world!.townPrevious=people
        }
        for index in world!.travellers.indices where groundBlocked(world!.travellers[index].player) {
            let safe=groundNearestWalkable(to:world!.travellers[index].player)
            world!.travellers[index].player=safe;world!.travellers[index].previous=safe
        }
        if visit == nil && world!.place == .grounds && groundBlocked(world!.player) {
            world!.player=groundNearestWalkable(to:world!.player)
        }
        if let roomVisit=visit,RoomVisit.blocked(roomVisit.player) {visit!.player=Tile(x:4,y:7)}
        if isAtReception && MotelGrounds.officeBlocked(world!.player) {world!.player=OfficeReception.clerk}
        if world!.ridingBike != nil && (visit != nil || world!.place != .grounds) {world!.ridingBike=nil}
        if isAtBasement && BasementLayout.blocked(world!.player) {world!.player=BasementLayout.arrival}
        if isAtHome && homeBlocked(world!.player) {world!.player=Tile(x:7,y:12)}
        if let seat=world!.beachSeat,(!BeachLayout.lounges.indices.contains(seat) || world!.place != .grounds || actorTile.distance(to:BeachLayout.approach(seat))>1) {world!.beachSeat=nil}
        if isAtShop && shopBlocked(world!.player) {world!.player=ShopLayout.arrival}
        for (id,saved) in worldState.pets ?? [:] {
            var pet=saved
            if pet.map == "basement" && BasementLayout.blocked(pet.tile) {pet.tile=BasementLayout.arrival}
            else if pet.map == "grounds" && groundBlocked(pet.tile) {pet.tile=groundNearestWalkable(to:pet.tile)}
            else if pet.map == "house" && homeBlocked(pet.tile) {pet.tile=id == "chichu" ? OfficeReception.chichu : OfficeReception.chichi}
            else if pet.map == "office" && RPGMaps.office.blocked(pet.tile) {pet.tile=Tile(x:8,y:id == "chichu" ? 8 : 9)}
            else if pet.map.hasPrefix("shop-") && ((pet.map == "shop-bar" || pet.map == "shop-fish") ? BarLayout.blocked(pet.tile) : ShopLayout.blocked(pet.tile)) {pet.tile=Tile(x:id == "chichu" ? 6 : 8,y:12)}
            world!.pets?[id]=pet
        }
    }
    mutating func moveActor(dx: Int, dy: Int) {
        guard !caught, !policeRequiresDecision, abs(dx) <= 1, abs(dy) <= 1, dx != 0 || dy != 0 else { return }
        initializeWorld()
        world!.beachSeat=nil
        if visit != nil { move(dx: dx, dy: dy); return }
        var state = worldState
        state.facing = dy > 0 ? 0 : dx < 0 ? 1 : dx > 0 ? 2 : 3
        let next = Tile(x: state.player.x + dx, y: state.player.y + dy)
        if state.place == .basement {
            guard !BasementLayout.blocked(next) else{world=state;return}
            if dx != 0 && dy != 0 {
                guard !BasementLayout.blocked(Tile(x:state.player.x+dx,y:state.player.y)),!BasementLayout.blocked(Tile(x:state.player.x,y:state.player.y+dy)) else{world=state;return}
            }
            state.player=next;world=state;return
        }
        if state.place == .shop {
            guard !shopBlocked(next) else {world=state;return}
            if dx != 0 && dy != 0 {
                guard !shopBlocked(Tile(x:state.player.x+dx,y:state.player.y)),!shopBlocked(Tile(x:state.player.x,y:state.player.y+dy)) else {world=state;return}
            }
            state.player=next;world=state
            if next == ShopLayout.exit {_=leaveShop()}
            return
        }
        if state.place == .house {
            if dx != 0 && dy != 0 {
                guard !homeBlocked(Tile(x:state.player.x+dx,y:state.player.y)),!homeBlocked(Tile(x:state.player.x,y:state.player.y+dy)) else {world=state;return}
            }
            if next == FamilyHome.exit { state.place = .grounds; state.player=Tile(x:groundTile(FamilyHome.door).x,y:groundTile(FamilyHome.door).y+1) }
            else if !homeBlocked(next) {state.player=next}
            world=state;return
        }
        if state.place == .office {
            guard !MotelGrounds.officeBlocked(next) else { world = state; return }
            if dx != 0 && dy != 0 {
                guard !MotelGrounds.officeBlocked(Tile(x: state.player.x + dx, y: state.player.y)),
                      !MotelGrounds.officeBlocked(Tile(x: state.player.x, y: state.player.y + dy)) else { world = state; return }
            }
            if next == OfficeReception.door || next == Tile(x:7,y:14) {
                state.place = .grounds; state.player = groundTile(Tile(x: 6, y: 10))
            } else { state.player = next }
            world = state
            return
        }
        let occupied = Set(waiting.filter{$0.id != reception.visitor?.guest.id}.map { waitingTile($0.id) } + state.travellers.map(\.player))
        guard !groundBlocked(next), !bikeBlocks(next), !occupied.contains(next) else { world = state; return }
        if dx != 0 && dy != 0 {
            for tile in [Tile(x: state.player.x + dx, y: state.player.y), Tile(x: state.player.x, y: state.player.y + dy)] {
                guard !groundBlocked(tile), !bikeBlocks(tile), !occupied.contains(tile) else { world = state; return }
            }
        }
        if isRidingBike && next == groundTile(MotelGrounds.officeDoor) {world=state;return}
        if next == groundTile(MotelGrounds.officeDoor) && dy < 0 {
            state.place = .office; state.player = OfficeReception.clerk
            world = state; return
        }
        state.player = next
        world = state
        if !isRidingBike,dy < 0, let room = rooms.first(where: { $0.id / 9 == viewingFloor && groundRoomDoor($0.id) == next && $0.guest == nil }) { _ = enter(room.id) }
    }
    @discardableResult mutating func useEntrance() -> Bool {
        guard !isRidingBike else{lastEvent="Dismount your bike before entering.";return false}
        initializeWorld()
        switch nearbyAction {
        case .basement:return enterBasement()
        case .home:
            world!.place = .house; world!.player=Tile(x:7,y:12);return true
        case .office:
            world!.place = .office; world!.player = OfficeReception.clerk; return true
        case .shop(let shop): return enterShop(shop)
        case .room(let id): return enter(id)
        case .exit:
            if isAtBasement {return leaveBasement()}
            if isAtShop {return leaveShop()}
            if visit != nil { leave() }
            else { let atHome=isAtHome; world!.place = .grounds; world!.player = atHome ? Tile(x:groundTile(FamilyHome.door).x,y:groundTile(FamilyHome.door).y+1) : groundTile(Tile(x:6,y:10)) }
            return true
        default: return false
        }
    }
    @discardableResult mutating func chargeGuest(_ guestID: Int, roomID: Int) -> Bool {
        guard nearbyAction == .guest(guestID), reception.visitor?.guest.id != guestID else { return false }
        guard let guest = waiting.first(where: { $0.id == guestID }) else { return false }
        guard checkIn(guestID: guestID, roomID: roomID) else { return false }
        initializeWorld()
        let start = waitingTile(guest.id)
        let destination=groundRoomDoor(roomID)
        world!.travellers.append(MotelWalker(id: guest.id, name: guest.name, color: guest.color, roomID: roomID, player: start, previous: start, destination: destination))
        return true
    }
    @discardableResult mutating func collectTools() -> Bool {
        guard nearbyAction == .tools else { return false }
        initializeWorld()
        world!.hasCleaningKit = true
        lastEvent = "Mop, bin bags and fresh sheets collected. Find a dirty room."
        return true
    }
    @discardableResult mutating func cleanNearbyTask() -> Bool {
        guard !caught, worldState.hasCleaningKit, let target = cleaningTarget, let visit,
              let index = rooms.firstIndex(where: { $0.id == visit.roomID }) else { return false }
        guard useCleaningStock(full:false) else { return false }
        var tasks = rooms[index].cleanedTasks ?? []
        guard tasks.insert(target).inserted else { return false }
        rooms[index].cleanedTasks = tasks
        if operationsState.simulation != nil { var health=rooms[index].health; health.cleanliness=tasks.count == 3 ? 100 : min(95,health.cleanliness+30); if tasks.count==3 {health.faults.remove(.mattress)}; rooms[index].hospitality=health }
        playVisual(target == 0 ? "bed" : target == 1 ? "trash" : "mop",target:MotelGrounds.cleaningTiles[target])
        if tasks.count == MotelGrounds.cleaningTiles.count {
            rooms[index].dirty = false
            lastEvent = "Room \(rooms[index].number) is spotless and ready for a guest."
        } else { lastEvent = "\(MotelGrounds.cleaningNames[target]) done. \(3 - tasks.count) tasks left in room \(rooms[index].number)." }
        return true
    }
    @discardableResult mutating func paintNearby(_ theme: Int) -> Bool {
        if isAtReception { return decorate(roomID: nil, theme: theme) }
        guard case .paint(let roomID) = nearbyAction else { return false }
        if let roomID {
            guard let index = rooms.firstIndex(where: { $0.id == roomID }), rooms[index].guest == nil,
                  Self.themeNames.indices.contains(theme), rooms[index].theme != theme, cash >= 25 else { return false }
            rooms[index].theme = theme; cash -= 25
            lastEvent = "Room \(rooms[index].number) repainted \(Self.themeNames[theme].lowercased())."
            return true
        }
        return decorate(roomID: nil, theme: theme)
    }
    @discardableResult mutating func furnishNearby() -> Bool {
        switch nearbyAction {
        case .desk: return upgrade(roomID: nil)
        case .furniture(let roomID):
            guard let roomID, let index = rooms.firstIndex(where: { $0.id == roomID }),
                  rooms[index].guest == nil, rooms[index].furniture < 2,
                  cash >= (rooms[index].furniture + 1) * 90 else { return false }
            cash -= (rooms[index].furniture + 1) * 90
            rooms[index].furniture += 1
            lastEvent = "New furnishings installed in room \(rooms[index].number)."
            return true
        default: return false
        }
    }
    @discardableResult mutating func buildNearby() -> Bool {
        guard nearbyAction == .construction else { return false }
        return expand()
    }
    @discardableResult mutating func restAtBed() -> Bool {
        guard business.police == nil, isAtReception || nearbyAction == .rest else { return false }
        if managementEnabled && !isNight {lastEvent="Rest opens at 20:00. Advance time from the management board.";return false}
        let departures = rooms.compactMap { room -> MotelWalker? in
            guard let guest = room.guest, room.nightsLeft == 1 else { return nil }
            let start = groundRoomDoor(room.id)
            return MotelWalker(id: guest.id, name: guest.name, color: guest.color, roomID: room.id, player: start, previous: start, destination: MotelGrounds.gate)
        }
        guard nextDay() else { return false }
        initializeWorld()
        world!.travellers = departures.filter { $0.name != business.police?.guest }
        world!.reception = OfficeReception()
        world!.place = .office; world!.player = OfficeReception.clerk
        return true
    }
    var atSavePoint: Bool { isAtBasement || isAtHome || nearbyAction == .desk || nearbyAction == .save }
    func guestPresent(in roomID: Int) -> Bool {
        guard let guest = rooms.first(where: { $0.id == roomID })?.guest else { return false }
        if let incident = operationsState.incident, incident.kind != .fire {
            let participants = [incident.guest ?? rooms.compactMap(\.guest).first, incident.kind == .fight ? (incident.otherGuest ?? rooms.compactMap(\.guest).dropFirst().first) : nil].compactMap { $0 }
            if participants.contains(where: { $0.id == guest.id }) { return false }
        }
        if reception.visitor?.guest.id == guest.id { return false }
        return !worldState.travellers.contains { $0.id == guest.id && $0.destination == groundRoomDoor(roomID) }
    }
    mutating func tickWorld() {
        guard !caught else { return }
        initializeWorld()
        var state = worldState
        state.tick += 1
        let outdoorGuests=waiting.filter{$0.id != reception.visitor?.guest.id}
        let waitingDestinations=waitingGuestTargets
        var positions=(state.guestPositions ?? [:]).filter{id,_ in outdoorGuests.contains{$0.id == id}}
        var guestPrevious:[Int:Tile]=[:]
        let entrance=groundTile(Tile(x:6,y:10))
        var reserved=Set(state.travellers.map(\.player)+[entrance,groundTile(MotelGrounds.officeDoor)])
        if state.place == .grounds && visit == nil {reserved.insert(state.player)}
        for guest in outdoorGuests {
            let target=waitingDestinations[guest.id] ?? groundGuestTile(guest.id)
            let saved=positions[guest.id] ?? target
            let current=groundBlocked(saved) ? groundNearestWalkable(to:saved) : saved
            guestPrevious[guest.id]=current
            let occupied=Set(positions.filter{$0.key != guest.id}.map(\.value)).union(reserved)
            if let danger=operationsState.incident?.tile {
                positions[guest.id]=groundEscapeStep(from:current,danger:danger,avoiding:occupied) ?? current
            } else {
                positions[guest.id]=groundNextStep(from:current,to:target,avoiding:occupied) ?? current
            }
        }
        state.guestPositions=positions;state.guestPrevious=guestPrevious
        var travellerIDs=Set<Int>()
        state.travellers=state.travellers.filter{travellerIDs.insert($0.id).inserted}
        let witnesses=simulation.issues.filter { [HotelIssueKind.adultVisitor,.drugDeal,.cult,.celebrity].contains($0.kind) }
        var witnessPositions=(state.witnessPositions ?? [:]).filter { id,_ in witnesses.contains { $0.id == id } }
        for witness in witnesses {
            let origin=Tile(x:8+witness.id%3,y:14)
            let current=witnessPositions[witness.id] ?? origin
            if let danger=operationsState.incident?.tile {
                witnessPositions[witness.id]=groundEscapeStep(from:current,danger:danger,avoiding:Set(positions.values)) ?? current
            } else { witnessPositions[witness.id]=groundNextStep(from:current,to:origin,avoiding:Set(positions.values)) ?? current }
        }
        state.witnessPositions=witnessPositions
        var occupied = Set(positions.values).union(state.travellers.map(\.player))
        if state.place == .grounds && visit == nil { occupied.insert(state.player) }
        for index in state.travellers.indices {
            var walker = state.travellers[index]
            occupied.remove(walker.player)
            walker.previous = walker.player
            let danger = operationsState.incident?.tile
            let target = danger.map { MotelGrounds.refuge(from:walker.player,danger:$0) } ?? walker.destination
            let next:Tile?
            if let danger { next=groundEscapeStep(from:walker.player,danger:danger,avoiding:occupied) }
            else { next=groundNextStep(from:walker.player,to:target,avoiding:occupied) }
            if let step=next { walker.player=step }
            occupied.insert(walker.player)
            state.travellers[index] = walker
        }
        if operationsState.incident == nil { state.travellers.removeAll { $0.player == $0.destination } }
        if state.tick%2 == 0 {
            var neighbors=state.neighborPositions ?? [:]
            var neighborPrevious=neighbors
            var stops=state.neighborStops ?? [:]
            for id in 0..<ResidentialLayout.doors.count {
                let route=ResidentialLayout.route(id).map{groundNearestWalkable(to:groundTile($0))}
                let current=neighbors[id] ?? route[0]
                neighborPrevious[id]=current
                var target=stops[id] ?? 1
                if current == route[target] {target=(target+1)%route.count}
                let occupied=Set(neighbors.filter{$0.key != id}.map(\.value)).union(state.place == .grounds ? [state.player] : [])
                neighbors[id]=groundNextStep(from:current,to:route[target],avoiding:occupied) ?? current
                stops[id]=target
            }
            state.neighborPositions=neighbors;state.neighborPrevious=neighborPrevious;state.neighborStops=stops
        }
        var townspeople=state.townPositions ?? [:]
        var previous=townspeople
        var destinations=state.townDestinations ?? [:]
        let stops=[Tile(x:43,y:16),Tile(x:54,y:16),Tile(x:65,y:17),Tile(x:68,y:32),Tile(x:51,y:33),Tile(x:38,y:33),Tile(x:38,y:16),Tile(x:48,y:42),Tile(x:52,y:54)].map{groundNearestWalkable(to:groundTile($0))}
        for id in 0..<7 {
            let current=townspeople[id] ?? stops[id]
            previous[id]=current
            var destination=destinations[id] ?? (id+1)%stops.count
            if current == stops[destination] {destination=(destination+1)%stops.count}
            let occupied=Set(townspeople.filter{$0.key != id}.map(\.value)).union(state.place == .grounds ? [state.player] : [])
            if let danger=operationsState.incident?.tile,current.distance(to:danger)<12 {
                townspeople[id]=groundEscapeStep(from:current,danger:danger,avoiding:occupied) ?? current
            } else {townspeople[id]=groundNextStep(from:current,to:stops[destination],avoiding:occupied) ?? current}
            destinations[id]=destination
        }
        state.townPositions=townspeople;state.townPrevious=previous;state.townDestinations=destinations
        world = state
    }
}
