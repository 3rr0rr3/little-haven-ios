import Foundation

struct PetCompanion: Codable {
    var following = false
    var map = "house"
    var tile: Tile
}

extension Motel {
    var petMap: String { visit.map { "room-\($0.roomID)" } ?? worldState.place.rawValue }
    func petState(_ id: String) -> PetCompanion {
        worldState.pets?[id] ?? PetCompanion(tile: id == "chichu" ? OfficeReception.chichu : OfficeReception.chichi)
    }
    var visiblePets: [(key: String, value: PetCompanion)] {
        ["chichu", "chichi"].map { (key:$0,value:petState($0)) }.filter { $0.value.map == petMap }
    }
    mutating func togglePet(_ id: String) {
        guard ["chichu", "chichi"].contains(id), petState(id).map == petMap else { return }
        initializeWorld()
        var pet=petState(id)
        pet.following.toggle()
        if world!.pets == nil { world!.pets=[:] }
        world!.pets![id]=pet
        lastEvent=id.capitalized + (pet.following ? " will follow you." : " will wait here.")
    }
    // Followers retrace the player's safe steps. Transfers place them on a safe
    // arrival tile; waiting pets retain their map and position in checkpoints.
    mutating func updateCompanions(from previous: Tile, map previousMap: String) {
        guard previous != actorTile || previousMap != petMap else { return }
        initializeWorld()
        var trail=previous
        var arrivals: Set<Tile> = []
        for id in ["chichu", "chichi"] {
            var pet=petState(id)
            guard pet.following else { continue }
            let old=pet.tile
            if pet.map != petMap || previousMap != petMap {
                let nearby=[Tile(x:actorTile.x-1,y:actorTile.y),Tile(x:actorTile.x+1,y:actorTile.y),Tile(x:actorTile.x,y:actorTile.y-1)]
                pet.tile=nearby.first { tile in
                    guard !arrivals.contains(tile) else { return false }
                    if visit != nil { return !RPGMaps.room.blocked(tile) }
                    if isAtHome { return !homeBlocked(tile) && tile != FamilyHome.exit }
                    if isAtReception { return !RPGMaps.office.blocked(tile) && tile != OfficeReception.door }
                    return !MotelGrounds.blocked(tile)
                } ?? actorTile
                arrivals.insert(pet.tile)
            } else {
                pet.tile=trail
            }
            pet.map=petMap
            if world!.pets == nil { world!.pets=[:] }
            world!.pets![id]=pet
            trail=old
        }
    }
}

struct OfficeVisitor: Codable {
    enum Phase: String, Codable { case entering, waiting, leaving }
    let guest: MotelGuest
    var phase: Phase = .entering
    var pathIndex = 0
    var roomID: Int?
    static let path: [Tile] = (6...13).reversed().map { Tile(x: 7, y: $0) } + [Tile(x: 6,y: 6),Tile(x: 5,y: 6),Tile(x: 4,y: 6)]
    var tile: Tile { Self.path[max(0,min(Self.path.count-1,pathIndex))] }
}
struct OfficeReception: Codable {
    var tick = 0
    var visitor: OfficeVisitor?
    static let computer = Tile(x:3,y:4)
    static let clerk = Tile(x: 4,y: 3)
    static let door = Tile(x: 7,y: 13)
    static let samhil = Tile(x:11,y:9)
    static let chichu = Tile(x:10,y:12)
    static let chichi = Tile(x:12,y:12)
    static let hildarelysRoute = [Tile(x: 10,y: 3),Tile(x: 11,y: 3),Tile(x: 12,y: 3),Tile(x: 12,y: 4),Tile(x: 11,y: 4),Tile(x: 10,y: 4)]
    var hildarelys: Tile { Self.hildarelysRoute[(tick / 2) % Self.hildarelysRoute.count] }
}
extension Motel {
    var isAtReception: Bool { visit == nil && worldState.place == .office }
    var reception: OfficeReception { worldState.reception ?? OfficeReception() }
    var receptionGuest: MotelGuest? { reception.visitor?.phase == .waiting ? reception.visitor?.guest : nil }
    mutating func tickReception() {
        guard !caught else { return }
        initializeWorld()
        var office = reception
        office.tick += 1
        if var visitor = office.visitor {
            switch visitor.phase {
            case .entering:
                visitor.pathIndex += 1
                if visitor.pathIndex >= OfficeVisitor.path.count-1 { visitor.phase = .waiting }
            case .waiting: break
            case .leaving:
                visitor.pathIndex -= 1
                if visitor.pathIndex <= 0 {
                    let start = Tile(x: 6,y: 10)
                    let destination = visitor.roomID.map { MotelGrounds.roomDoor($0) } ?? MotelGrounds.gate
                    world!.travellers.append(MotelWalker(id: visitor.guest.id,name: visitor.guest.name,color: visitor.guest.color,roomID: visitor.roomID ?? -1,player: start,previous: start,destination: destination))
                    office.visitor = nil
                    world!.reception = office
                    return
                }
            }
            office.visitor = visitor
        } else if isAtReception, (!managementEnabled || !isNight), let guest = waiting.first {
            office.visitor = OfficeVisitor(guest: guest)
        }
        world!.reception = office
    }
    @discardableResult mutating func acceptReceptionGuest(roomID: Int) -> Bool {
        guard isAtReception, var visitor = reception.visitor, visitor.phase == .waiting,
              checkIn(guestID: visitor.guest.id, roomID: roomID) else { return false }
        visitor.phase = .leaving
        visitor.roomID = roomID
        world!.reception!.visitor = visitor
        return true
    }
    @discardableResult mutating func declineReceptionGuest() -> Bool {
        guard isAtReception, var visitor = reception.visitor, visitor.phase == .waiting else { return false }
        waiting.removeAll { $0.id == visitor.guest.id }
        visitor.phase = .leaving
        world!.reception!.visitor = visitor
        lastEvent = "You politely declined \(visitor.guest.name). They head back to the road."
        return true
    }
    @discardableResult mutating func leaveReception() -> Bool {
        guard isAtReception, !caught else { return false }
        initializeWorld()
        world!.place = .grounds
        world!.player = Tile(x: 6,y: 10)
        return true
    }
    @discardableResult mutating func receptionTools() -> Bool {
        guard isAtReception, !caught else { return false }
        initializeWorld()
        world!.hasCleaningKit = true
        lastEvent = "Cleaning kit ready: mop, fresh sheets and bin bags."
        return true
    }
}
