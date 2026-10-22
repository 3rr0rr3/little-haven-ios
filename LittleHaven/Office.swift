import Foundation

struct PetCompanion: Codable {
    var following = false
    var map = "house"
    var tile: Tile
}

extension Motel {
    func companionName(_ id:String)->String {id == "mochi" ? "Tuki" : id.capitalized}
    var petMap: String { visit.map { "room-\($0.roomID)" } ?? (currentShop.map {"shop-"+$0.rawValue} ?? worldState.place.rawValue) }
    func petState(_ id: String) -> PetCompanion {
        worldState.pets?[id] ?? PetCompanion(tile: id == "mochi" ? Tile(x:4,y:8) : id == "chichu" ? OfficeReception.chichu : OfficeReception.chichi)
    }
    var visiblePets: [(key: String, value: PetCompanion)] {
        ["chichu", "chichi", "mochi"].map { (key:$0,value:petState($0)) }.filter { $0.value.map == petMap }
    }
    mutating func togglePet(_ id: String) {
        guard ["chichu", "chichi", "mochi"].contains(id), petState(id).map == petMap else { return }
        initializeWorld()
        var pet=petState(id)
        pet.following.toggle()
        if world!.pets == nil { world!.pets=[:] }
        world!.pets![id]=pet
        lastEvent=companionName(id) + (pet.following ? " will follow you." : " will wait here.")
    }
    // Followers retrace the player's safe steps. Transfers place them on a safe
    // arrival tile; waiting pets retain their map and position in checkpoints.
    mutating func updateCompanions(from previous: Tile, map previousMap: String) {
        guard previous != actorTile || previousMap != petMap else { return }
        initializeWorld()
        var trail=previous
        var arrivals: Set<Tile> = []
        for id in ["chichu", "chichi", "mochi"] {
            var pet=petState(id)
            guard pet.following else { continue }
            let old=pet.tile
            let trailBlocked:Bool
            if visit != nil {trailBlocked=RPGMaps.room.blocked(trail)}
            else if isAtBasement {trailBlocked=BasementLayout.blocked(trail)}
            else if isAtHome {trailBlocked=homeBlocked(trail)}
            else if isAtShop {trailBlocked=shopBlocked(trail)}
            else if isAtReception {trailBlocked=RPGMaps.office.blocked(trail)}
            else {trailBlocked=MotelGrounds.blocked(trail)}
            if pet.map != petMap || previousMap != petMap || trailBlocked {
                let nearby=[Tile(x:actorTile.x-1,y:actorTile.y),Tile(x:actorTile.x+1,y:actorTile.y),Tile(x:actorTile.x,y:actorTile.y-1)]
                pet.tile=nearby.first { tile in
                    guard !arrivals.contains(tile) else { return false }
                    if visit != nil { return !RPGMaps.room.blocked(tile) }
                    if isAtShop {return !shopBlocked(tile) && tile != ShopLayout.exit}
                    if isAtBasement {return !BasementLayout.blocked(tile) && tile != BasementLayout.stairs}
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
    static let hildarelysRoute = [Tile(x: 6,y: 3),Tile(x: 7,y: 3),Tile(x: 8,y: 3),Tile(x: 8,y: 4),Tile(x: 7,y: 4),Tile(x: 6,y: 4)]
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


struct CorralCare:Codable {
    var fedDay = -1
    var visits = 0
}
enum BasementLayout {
    static let width=25,height=27
    static let homeStairs=Tile(x:7,y:6)
    static let stairs=Tile(x:12,y:25)
    static let arrival=Tile(x:12,y:24)
    static let titles=["Wizard Chichu","Two-tail fox","Blue Chichu","Ogre Chichu","Shark Chichu","Mighty Chichu","Fang Chichu","Football Chichu"]
    static func pen(_ id:Int)->RPGRegion {RPGRegion(x:id%2 == 0 ? 2 : 15,y:3+(id/2)*5,width:8,height:4)}
    static func gate(_ id:Int)->Tile {let p=pen(id);return Tile(x:id%2 == 0 ? 10 : 14,y:p.y+2)}
    static func creature(_ id:Int,tick:Int)->Tile {
        let p=pen(id),route=[Tile(x:p.x+3,y:p.y+2),Tile(x:p.x+4,y:p.y+2),Tile(x:p.x+4,y:p.y+1),Tile(x:p.x+3,y:p.y+1)]
        return route[(tick/5+id)%route.count]
    }
    static func blocked(_ tile:Tile)->Bool {
        tile.x<1 || tile.x>23 || tile.y<2 || tile.y>25 || (0..<8).contains{pen($0).contains(tile)}
    }
}
extension Motel {
    var isAtBasement:Bool {visit == nil && worldState.place == .basement}
    var nearbyCorral:Int? {
        guard isAtBasement else{return nil}
        return (0..<8).first{actorTile.distance(to:BasementLayout.gate($0))<=1}
    }
    func corralCare(_ id:Int)->CorralCare {worldState.corrals?[id] ?? CorralCare()}
    @discardableResult mutating func enterBasement()->Bool {
        guard isAtHome,actorTile.distance(to:BasementLayout.homeStairs)<=1 else{return false}
        initializeWorld();world!.place = .basement;world!.player=BasementLayout.arrival
        lastEvent="Welcome to your creature sanctuary. Eight corrals, eight friends."
        return true
    }
    @discardableResult mutating func leaveBasement()->Bool {
        guard isAtBasement,actorTile.distance(to:BasementLayout.stairs)<=1 else{return false}
        world!.place = .house;world!.player=Tile(x:7,y:7)
        return true
    }
    @discardableResult mutating func careForCorral(_ id:Int,feed:Bool)->Bool {
        guard (0..<8).contains(id),isAtBasement,actorTile.distance(to:BasementLayout.gate(id))<=1 else{return false}
        initializeWorld();var care=corralCare(id)
        if feed {
            guard care.fedDay != day else{lastEvent=BasementLayout.titles[id]+" already ate today.";return false}
            care.fedDay=day
        } else {care.visits+=1}
        if world!.corrals == nil {world!.corrals=[:]}
        world!.corrals![id]=care
        lastEvent=BasementLayout.titles[id]+(feed ? " enjoys a fresh meal." : " comes to the fence for attention.")
        return true
    }
}
