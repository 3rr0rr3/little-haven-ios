import Foundation

enum MotelPlace: String, Codable { case office, grounds }
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
    var guestPositions: [Int:Tile]?
}
enum MotelAction: Hashable {
    case none, office, room(Int), guest(Int), construction, desk, save, rest, tools
    case paint(Int?), furniture(Int?), clean(Int), loot(Int), exit, incident
}
enum MotelGrounds {
    static let width = 40
    static let height = 38
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
        [Tile(x:2,y:12),Tile(x:11,y:32),Tile(x:35,y:25),Tile(x:12,y:3)]
            .max { $0.distance(to:danger) < $1.distance(to:danger) } ?? tile
    }
    static func blocked(_ tile: Tile) -> Bool {
        RPGMaps.grounds.blocked(tile)
    }
    static func nextStep(from start: Tile, to target: Tile, avoiding: Set<Tile>) -> Tile? {
        if start == target { return nil }
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
    static let desk = Tile(x: 4, y: 4)
    static let bed = Tile(x: 2, y: 2)
    static let tools = Tile(x: 1, y: 5)
    static let paint = Tile(x: 7, y: 5)
    static let logbook = Tile(x: 6, y: 2)
    static func officeBlocked(_ tile: Tile) -> Bool {
        RPGMaps.office.blocked(tile)
    }
    static let cleaningTiles = [Tile(x: 3, y: 2), Tile(x: 2, y: 6), Tile(x: 5, y: 5)]
    static let cleaningNames = ["Make bed", "Collect trash", "Mop spill"]
    static let roomPaint = Tile(x: 7, y: 2)
}

extension Motel {
    func waitingTile(_ id:Int) -> Tile { worldState.guestPositions?[id] ?? MotelGrounds.guestTile(id) }
    var worldState: MotelWorldState { world ?? MotelWorldState() }
    var actorTile: Tile { visit?.player ?? worldState.player }
    var actorFacing: Int { visit?.facing ?? worldState.facing }
    var mapName: String {
        if let visit, let room = rooms.first(where: { $0.id == visit.roomID }) { return "ROOM \(room.number)" }
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
        if let visit {
            if player.distance(to: Tile(x: 4, y: 8)) <= 1 { return .exit }
            if visit.sneaking {
                if let item = visit.nearbyLoot, !visit.loot.contains(item),
                   let room = rooms.first(where: { $0.id == visit.roomID }), !room.stolen.contains(item) { return .loot(item) }
                return .none
            }
            if let target = cleaningTarget { return .clean(target) }
            if player.distance(to: MotelGrounds.roomPaint) <= 1 { return .paint(visit.roomID) }
            if player.distance(to: Tile(x: 3, y: 2)) <= 1 { return .furniture(visit.roomID) }
            return .none
        }
        if isAtReception {
            if player.distance(to:OfficeReception.door) <= 1 { return .exit }
            if player.distance(to:Tile(x:1,y:7)) <= 1 { return .tools }
            if player.distance(to:Tile(x:1,y:9)) <= 1 { return .paint(nil) }
            if player.distance(to:Tile(x:1,y:2)) <= 1 { return .rest }
            if player.distance(to:OfficeReception.clerk) <= 1 { return .desk }
            if player.distance(to:Tile(x:5,y:4)) <= 1 { return .save }
            return .none
        }
        if nearbyIncident { return .incident }
        if let guest = waiting.first(where: { player.distance(to: waitingTile($0.id)) <= 1 }) { return .guest(guest.id) }
        if player.distance(to: MotelGrounds.officeDoor) <= 1 { return .office }
        for room in rooms where room.id / 9 == viewingFloor && player.distance(to: MotelGrounds.roomDoor(room.id)) <= 1 { return .room(room.id) }
        if !goalReached && (player.distance(to: MotelGrounds.sign) <= 1 || player.distance(to: MotelGrounds.roomDoor(rooms.count)) <= 1) { return .construction }
        return .none
    }
    mutating func initializeWorld() {
        assignRoomColors()
        if world == nil { world = MotelWorldState() }
        if world!.reception == nil { world!.reception = OfficeReception() }
    }
    mutating func moveActor(dx: Int, dy: Int) {
        guard !caught, abs(dx) <= 1, abs(dy) <= 1, dx != 0 || dy != 0 else { return }
        initializeWorld()
        if visit != nil { move(dx: dx, dy: dy); return }
        var state = worldState
        state.facing = dy > 0 ? 0 : dx < 0 ? 1 : dx > 0 ? 2 : 3
        let next = Tile(x: state.player.x + dx, y: state.player.y + dy)
        if state.place == .office {
            guard !MotelGrounds.officeBlocked(next) else { world = state; return }
            if dx != 0 && dy != 0 {
                guard !MotelGrounds.officeBlocked(Tile(x: state.player.x + dx, y: state.player.y)),
                      !MotelGrounds.officeBlocked(Tile(x: state.player.x, y: state.player.y + dy)) else { world = state; return }
            }
            if next == OfficeReception.door || next == Tile(x:7,y:14) {
                state.place = .grounds; state.player = Tile(x: 6, y: 10)
            } else { state.player = next }
            world = state
            return
        }
        let occupied = Set(waiting.map { waitingTile($0.id) } + state.travellers.map(\.player))
        guard !MotelGrounds.blocked(next), !occupied.contains(next) else { world = state; return }
        if dx != 0 && dy != 0 {
            for tile in [Tile(x: state.player.x + dx, y: state.player.y), Tile(x: state.player.x, y: state.player.y + dy)] {
                guard !MotelGrounds.blocked(tile), !occupied.contains(tile) else { world = state; return }
            }
        }
        if next == MotelGrounds.officeDoor && dy < 0 {
            state.place = .office; state.player = OfficeReception.clerk
            world = state; return
        }
        state.player = next
        world = state
        if dy < 0, let room = rooms.first(where: { $0.id / 9 == viewingFloor && MotelGrounds.roomDoor($0.id) == next && $0.guest == nil }) { _ = enter(room.id) }
    }
    @discardableResult mutating func useEntrance() -> Bool {
        initializeWorld()
        switch nearbyAction {
        case .office:
            world!.place = .office; world!.player = OfficeReception.clerk; return true
        case .room(let id): return enter(id)
        case .exit:
            if visit != nil { leave() }
            else { world!.place = .grounds; world!.player = Tile(x: 6, y: 10) }
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
        world!.travellers.append(MotelWalker(id: guest.id, name: guest.name, color: guest.color, roomID: roomID, player: start, previous: start, destination: MotelGrounds.roomDoor(roomID)))
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
            let start = MotelGrounds.roomDoor(room.id)
            return MotelWalker(id: guest.id, name: guest.name, color: guest.color, roomID: room.id, player: start, previous: start, destination: MotelGrounds.gate)
        }
        guard nextDay() else { return false }
        initializeWorld()
        world!.travellers = departures.filter { $0.name != business.police?.guest }
        world!.reception = OfficeReception()
        world!.place = .office; world!.player = OfficeReception.clerk
        return true
    }
    var atSavePoint: Bool { nearbyAction == .desk || nearbyAction == .save }
    func guestPresent(in roomID: Int) -> Bool {
        guard let guest = rooms.first(where: { $0.id == roomID })?.guest else { return false }
        if let incident = operationsState.incident, incident.kind != .fire {
            let participants = [incident.guest ?? rooms.compactMap(\.guest).first, incident.kind == .fight ? (incident.otherGuest ?? rooms.compactMap(\.guest).dropFirst().first) : nil].compactMap { $0 }
            if participants.contains(where: { $0.id == guest.id }) { return false }
        }
        if reception.visitor?.guest.id == guest.id { return false }
        return !worldState.travellers.contains { $0.id == guest.id && $0.destination == MotelGrounds.roomDoor(roomID) }
    }
    mutating func tickWorld() {
        guard !caught else { return }
        initializeWorld()
        var state = worldState
        state.tick += 1
        var positions = state.guestPositions ?? [:]
        positions = positions.filter { id,_ in waiting.contains { $0.id == id } }
        for guest in waiting {
            let current = positions[guest.id] ?? MotelGrounds.guestTile(guest.id)
            let target: Tile
            if let danger = operationsState.incident?.kind.tile, current.distance(to:danger) < 12 || positions[guest.id] != nil {
                target = MotelGrounds.refuge(from:current,danger:danger)
            } else { target = MotelGrounds.guestTile(guest.id) }
            positions[guest.id] = MotelGrounds.nextStep(from:current,to:target,avoiding:Set(positions.filter { $0.key != guest.id }.map(\.value))) ?? current
        }
        state.guestPositions = positions
        var occupied = Set(waiting.map { positions[$0.id] ?? MotelGrounds.guestTile($0.id) } + state.travellers.map(\.player))
        if state.place == .grounds && visit == nil { occupied.insert(state.player) }
        for index in state.travellers.indices {
            var walker = state.travellers[index]
            occupied.remove(walker.player)
            walker.previous = walker.player
            let danger = operationsState.incident?.kind.tile
            let target = danger.map { MotelGrounds.refuge(from:walker.player,danger:$0) } ?? walker.destination
            if let step = MotelGrounds.nextStep(from: walker.player, to: target, avoiding: occupied) { walker.player = step }
            occupied.insert(walker.player)
            state.travellers[index] = walker
        }
        if operationsState.incident == nil { state.travellers.removeAll { $0.player == $0.destination } }
        world = state
    }
}
