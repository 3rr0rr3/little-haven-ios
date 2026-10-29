import Foundation

struct PetCompanion: Codable {
    var following = false
    var map = "house"
    var tile: Tile
    var previous:Tile?
    var facing:Int?
    var stay:Bool?
    var homeStop:Int?
}

extension Motel {
    func companionName(_ id:String)->String {id == "mochi" ? "Tuki" : id.capitalized}
    var petMap: String { visit.map { "room-\($0.roomID)" } ?? (currentShop.map {"shop-"+$0.rawValue} ?? (currentBedroom?.map ?? worldState.place.rawValue)) }
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
        pet.stay = !pet.following
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
            else if let bedroom=currentBedroom {trailBlocked=bedroom.blocked(trail)}
            else if isAtHome {trailBlocked=homeBlocked(trail)}
            else if isAtShop {trailBlocked=shopBlocked(trail)}
            else if isAtReception {trailBlocked=RPGMaps.office.blocked(trail)}
            else {trailBlocked=groundBlocked(trail)}
            if pet.map != petMap || previousMap != petMap || trailBlocked {
                let nearby=[Tile(x:actorTile.x-1,y:actorTile.y),Tile(x:actorTile.x+1,y:actorTile.y),Tile(x:actorTile.x,y:actorTile.y-1)]
                pet.tile=nearby.first { tile in
                    guard !arrivals.contains(tile) else { return false }
                    if visit != nil { return !RPGMaps.room.blocked(tile) }
                    if isAtShop {return !shopBlocked(tile) && tile != ShopLayout.exit}
                    if isAtBasement {return !BasementLayout.blocked(tile) && tile != BasementLayout.stairs}
                    if let bedroom=currentBedroom {return !bedroom.blocked(tile) && tile != HomeBedroom.exit}
                    if isAtHome { return !homeBlocked(tile) && tile != FamilyHome.exit }
                    if isAtReception { return !RPGMaps.office.blocked(tile) && tile != OfficeReception.door }
                    return !groundBlocked(tile)
                } ?? actorTile
                arrivals.insert(pet.tile)
            } else {
                pet.tile=trail
            }
            pet.previous=old
            pet.facing=pet.tile.x<old.x ? 1 : pet.tile.x>old.x ? 2 : pet.tile.y<old.y ? 3 : 0
            pet.map=petMap
            if world!.pets == nil { world!.pets=[:] }
            world!.pets![id]=pet
            trail=old
        }
    }
    /// Home cats wander on the existing simulation cadence; no extra UI timer.
    mutating func tickHomeCats() {
        guard isAtHome,currentBedroom == nil,worldState.tick%4==0 else{return}
        let route=[Tile(x:10,y:12),Tile(x:8,y:10),Tile(x:6,y:7),Tile(x:8,y:4),Tile(x:10,y:7),Tile(x:12,y:12)]
        for (index,id) in ["chichu","chichi"].enumerated() {
            var pet=petState(id)
            guard pet.map=="house",!pet.following,pet.stay != true else{continue}
            var stop=abs(pet.homeStop ?? index*3)%route.count
            if pet.tile==route[stop] {stop=(stop+1)%route.count}
            let reserved=Set(visiblePets.filter{$0.key != id}.map{$0.value.tile}+[actorTile,reception.hildarelys,FamilyHome.exit,BasementLayout.homeStairs])
            var queue=[pet.tile],seen:Set<Tile>=[pet.tile],parents:[Tile:Tile]=[:],cursor=0
            var found:Tile?
            while cursor<queue.count {
                let current=queue[cursor];cursor+=1
                if current==route[stop] {found=current;break}
                for (dx,dy) in [(0,-1),(1,0),(0,1),(-1,0)] {
                    let next=Tile(x:current.x+dx,y:current.y+dy)
                    if !homeBlocked(next),!reserved.contains(next),seen.insert(next).inserted {parents[next]=current;queue.append(next)}
                }
            }
            pet.previous=pet.tile;pet.homeStop=stop
            if var step=found,step != pet.tile {
                while let previous=parents[step],previous != pet.tile {step=previous}
                let old=pet.tile;pet.tile=step
                pet.facing=step.x<old.x ? 1 : step.x>old.x ? 2 : step.y<old.y ? 3 : 0
            } else if found==nil {pet.homeStop=(stop+1)%route.count}
            if world!.pets==nil {world!.pets=[:]}
            world!.pets![id]=pet
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
        if !isAtHome || actorTile.distance(to:office.hildarelys)>2 {office.tick += 1}
        if var visitor = office.visitor {
            switch visitor.phase {
            case .entering:
                visitor.pathIndex += 1
                if visitor.pathIndex >= OfficeVisitor.path.count-1 { visitor.phase = .waiting }
            case .waiting: break
            case .leaving:
                visitor.pathIndex -= 1
                if visitor.pathIndex <= 0 {
                    let start = groundTile(Tile(x: 6,y: 10))
                    let destination = visitor.roomID.map { groundRoomDoor($0) } ?? MotelGrounds.gate
                    let exitOccupied=worldState.travellers.contains{$0.player == start} ||
                        (worldState.place == .grounds && visit == nil && actorTile == start)
                    if exitOccupied {
                        visitor.pathIndex=0;office.visitor=visitor;world!.reception=office;return
                    }
                    world!.travellers.removeAll{$0.id == visitor.guest.id}
                    world!.guestPositions?.removeValue(forKey:visitor.guest.id)
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
        world!.player = groundTile(Tile(x: 6,y: 10))
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
    static let width=25,height=37
    static let homeStairs=Tile(x:1,y:13)
    static let stairs=Tile(x:12,y:35)
    static let arrival=Tile(x:12,y:34)
    static let titles=["Wizard Chichu","Two-tail fox","Blue Chichu","Shrek Chichu","Shark Chichu","Mighty Chichu","Fang Chichu","Messi Chichu","Kawai Tom","Inferno Cat","cosmic cat","Juan the horse"]
    static var residents:Range<Int> {titles.indices}
    static func pen(_ id:Int)->RPGRegion {RPGRegion(x:id%2 == 0 ? 2 : 15,y:3+(id/2)*5,width:8,height:4)}
    static func gate(_ id:Int)->Tile {let p=pen(id);return Tile(x:id%2 == 0 ? 10 : 14,y:p.y+2)}
    static func creature(_ id:Int,tick:Int)->Tile {
        let p=pen(id),route=[Tile(x:p.x+3,y:p.y+2),Tile(x:p.x+4,y:p.y+2),Tile(x:p.x+4,y:p.y+1),Tile(x:p.x+3,y:p.y+1)]
        return route[(tick/5+id)%route.count]
    }
    static func blocked(_ tile:Tile)->Bool {
        tile.x<1 || tile.x>23 || tile.y<2 || tile.y>height-2 || residents.contains{pen($0).contains(tile)}
    }
}
extension Motel {
    var isAtBasement:Bool {visit == nil && worldState.place == .basement}
    var nearbyCorral:Int? {
        guard isAtBasement else{return nil}
        return BasementLayout.residents.first{actorTile.distance(to:BasementLayout.gate($0))<=1}
    }
    func corralCare(_ id:Int)->CorralCare {worldState.corrals?[id] ?? CorralCare()}
    @discardableResult mutating func enterBasement()->Bool {
        guard isAtHome,currentBedroom == nil,actorTile.distance(to:BasementLayout.homeStairs)<=1 else{return false}
        initializeWorld();world!.place = .basement;world!.player=BasementLayout.arrival
        lastEvent="Welcome to your creature sanctuary. Twelve corrals, twelve friends."
        return true
    }
    @discardableResult mutating func leaveBasement()->Bool {
        guard isAtBasement,actorTile.distance(to:BasementLayout.stairs)<=1 else{return false}
        world!.place = .house;world!.player=Tile(x:2,y:13)
        return true
    }
    @discardableResult mutating func careForCorral(_ id:Int,feed:Bool)->Bool {
        guard BasementLayout.residents.contains(id),isAtBasement,actorTile.distance(to:BasementLayout.gate(id))<=1 else{return false}
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

extension Motel {
    /// The visitor and receptionist can speak across the solid counter.
    func canTouchInteract(at target:Tile)->Bool {
        if actorTile.distance(to:target)<=2 {return true}
        guard isAtReception,let visitor=reception.visitor,visitor.phase == .waiting,
              visitor.tile == target else{return false}
        return (2...6).contains(actorTile.x) && actorTile.y == 3
    }
}

// An optional room field keeps every existing home checkpoint decodable.
enum HomeBedroom:String,Codable,CaseIterable,Hashable {
    case samhil,parents,bathroom
    var title:String {switch self {case .samhil:return "Samhil's bedroom";case .parents:return "Your & Hildarelys's bedroom";case .bathroom:return "Bathroom"}}
    var map:String {"home-bedroom-"+rawValue}
    var door:Tile {self == .bathroom ? Tile(x:4,y:2) : Tile(x:self == .samhil ? 5 : 8,y:2)}
    var homeApproach:Tile {Tile(x:door.x,y:3)}
    static let exit=Tile(x:7,y:13)
    static let arrival=Tile(x:7,y:12)
    init?(map:String) {
        guard map.hasPrefix("home-bedroom-") else{return nil}
        self.init(rawValue:String(map.dropFirst(13)))
    }
    func blocked(_ tile:Tile)->Bool {
        if tile.x<1 || tile.x>13 || tile.y<2 || tile.y>13 {return true}
        if self == .bathroom {
            return RPGRegion(x:2,y:3,width:2,height:2).contains(tile) || RPGRegion(x:9,y:3,width:4,height:4).contains(tile) || RPGRegion(x:2,y:8,width:2,height:2).contains(tile)
        }
        let bedWidth=self == .samhil ? 2 : 4
        return RPGRegion(x:2,y:3,width:bedWidth,height:4).contains(tile) ||
            RPGRegion(x:10,y:3,width:3,height:3).contains(tile) ||
            RPGRegion(x:10,y:7,width:3,height:2).contains(tile) ||
            RPGRegion(x:2,y:10,width:2,height:2).contains(tile) || tile == Tile(x:12,y:11)
    }
}
extension Motel {
    var currentBedroom:HomeBedroom? {isAtHome ? worldState.homeBedroom : nil}
    @discardableResult mutating func enterBedroom(_ bedroom:HomeBedroom)->Bool {
        guard isAtHome,currentBedroom == nil,!policeRequiresDecision,actorTile.distance(to:bedroom.door)<=1 else{return false}
        initializeWorld();world!.homeBedroom=bedroom;world!.player=HomeBedroom.arrival;world!.facing=3
        return true
    }
    @discardableResult mutating func leaveBedroom()->Bool {
        guard let bedroom=currentBedroom,!policeRequiresDecision,actorTile.distance(to:HomeBedroom.exit)<=1 else{return false}
        world!.homeBedroom=nil;world!.player=bedroom.homeApproach;world!.facing=0
        return true
    }
}

// Menu-only navigation data. These values do not move actors or alter checkpoints.
enum HavenMapFilter:String,CaseIterable,Identifiable {
    case all="All",rooms="Rooms",shops="Shops",family="Family",tasks="Tasks"
    var id:String {rawValue}
}
struct HavenMapPin:Identifiable {
    let id:String
    let title:String
    let detail:String
    let tile:Tile
    let symbol:String
    let group:HavenMapFilter
}
extension Motel {
    var navigationGroundTile:Tile {
        if let visit {return groundRoomDoor(visit.roomID)}
        if let shop=currentShop {return groundTile(shop.door)}
        if isAtHome || isAtBasement {return groundTile(FamilyHome.door)}
        return isAtReception ? groundTile(MotelGrounds.officeDoor) : actorTile
    }
    var navigationPins:[HavenMapPin] {
        var pins=[HavenMapPin(id:"office",title:"Reception",detail:"Computer, check-in and supplies",tile:groundTile(MotelGrounds.officeDoor),symbol:"desktopcomputer",group:.all),
                  HavenMapPin(id:"beach",title:"Sunset Cove",detail:"Beach, palms and loungers",tile:Tile(x:48,y:44),symbol:"beach.umbrella.fill",group:.all)]
        for room in rooms where room.id/9==viewingFloor {
            pins.append(HavenMapPin(id:"room-\(room.id)",title:"Room \(room.number)",detail:room.guest?.name ?? (room.available ? "Ready for guests" : "Needs care"),tile:groundRoomDoor(room.id),symbol:"bed.double.fill",group:.rooms))
            if room.dirty || !room.health.faults.isEmpty {
                pins.append(HavenMapPin(id:"care-\(room.id)",title:"Care for room \(room.number)",detail:room.dirty ? "Cleaning needed" : room.health.faults.map(\.title).sorted().joined(separator:", "),tile:groundRoomDoor(room.id),symbol:"wrench.and.screwdriver.fill",group:.tasks))
            }
        }
        for shop in NeighborhoodShop.allCases {
            pins.append(HavenMapPin(id:"shop-"+shop.rawValue,title:shop.title,detail:shop.keeperName+" · "+shop.detail,tile:groundTile(shop.door),symbol:shop == .bar ? "wineglass.fill" : shop == .fish ? "fish.fill" : "bag.fill",group:.shops))
        }
        pins.append(HavenMapPin(id:"home",title:"Family home",detail:"Hildarelys, Samhil, pets and bedrooms",tile:groundTile(FamilyHome.door),symbol:"house.fill",group:.family))
        for id in ResidentialLayout.doors.indices {
            pins.append(HavenMapPin(id:"neighbor-\(id)",title:ResidentialLayout.names[id],detail:"Neighbor's home",tile:groundTile(ResidentialLayout.doors[id]),symbol:"person.fill",group:.family))
        }
        if let incident=operationsState.incident {
            pins.append(HavenMapPin(id:"incident",title:incident.kind.title,detail:"Emergency · \(incident.remaining) seconds left",tile:incident.tile,symbol:incident.kind == .fire ? "flame.fill" : incident.kind == .pool ? "figure.pool.swim" : "exclamationmark.shield.fill",group:.tasks))
        }
        for issue in simulation.issues {
            if let room=rooms.first(where:{$0.id==issue.roomID}) {
                pins.append(HavenMapPin(id:"issue-\(issue.id)",title:issue.kind.title,detail:"Room \(room.number) · \(max(0,issue.deadline-simulation.absoluteHour)) hours left",tile:groundRoomDoor(room.id),symbol:"exclamationmark.bubble.fill",group:.tasks))
            }
        }
        if let favour=worldState.guestFavour,favour.status == .pending,let room=rooms.first(where:{$0.guest?.id==favour.guestID}) {
            pins.append(HavenMapPin(id:"guest-favour",title:"Guest delivery",detail:room.guest?.name ?? "Guest request",tile:groundRoomDoor(room.id),symbol:"shippingbox.fill",group:.tasks))
        }
        if let hosting=experiences.hosting,!hosting.completed {
            pins.append(HavenMapPin(id:"seasonal-host",title:hosting.kind.title,detail:hosting.stage==0 ? "Decorate at "+hosting.kind.place : hosting.stage==1 ? "Bring 3 snacks" : "Welcome your guests",tile:groundNearestWalkable(to:groundTile(hosting.kind.location)),symbol:"party.popper.fill",group:.tasks))
        }
        return pins
    }
    func navigationDirection(to destination:Tile)->String {
        let from=navigationGroundTile,dx=destination.x-from.x,dy=destination.y-from.y
        if dx==0 && dy==0 {return "You are here"}
        let vertical=dy<0 ? "north" : dy>0 ? "south" : ""
        let horizontal=dx<0 ? "west" : dx>0 ? "east" : ""
        return "Head "+vertical+horizontal+" · \(from.distance(to:destination)) tiles away"
    }
    func actionTitle(_ action:MotelAction)->String {
        switch action {
        case .personal(let care):return care.title
        case .none:return "Walk closer to interact"
        case .bedroom(let room):return "Enter "+room.title
        case .family(let name):return "Talk to "+name.capitalized
        case .pet(let id):return "Talk to "+companionName(id)
        case .basement:return "Enter creature sanctuary"
        case .corral(let id):return "Visit "+BasementLayout.titles[id]
        case .computer:return "Use reception computer"
        case .home:return "Enter family home"
        case .homeDecor:return "Use home workbench"
        case .shop(let shop):return shop == .pawn ? "Trade at Shady Corner" : isAtShop ? "Browse "+shop.title : "Enter "+shop.title
        case .office:return "Enter reception"
        case .room(let id):return "Enter room \(rooms.first(where:{$0.id==id})?.number ?? 101+id)"
        case .guest(let id):return "Talk to "+(waiting.first(where:{$0.id==id})?.name ?? "guest")
        case .construction:return "Build room \(101+rooms.count)"
        case .desk:return "Use front desk"
        case .save:return "Save checkpoint"
        case .rest:return "Sleep until morning"
        case .tools:return "Take cleaning tools"
        case .paint:return "Choose paint"
        case .furniture:return "Upgrade furnishings"
        case .clean:return worldState.hasCleaningKit ? "Hold to clean" : "Get a cleaning kit first"
        case .loot(let id):return "Take "+RoomVisit.lootNames[id]
        case .exit:return currentBedroom != nil ? "Return to living room" : isAtBasement ? "Return upstairs" : isAtHome ? "Leave home" : isAtShop ? "Leave shop" : visit != nil ? "Leave room" : "Leave office"
        case .incident:return operationsState.incident?.kind.action ?? "Respond to emergency"
        }
    }
    var contextActions:[MotelAction] {
        var result:[MotelAction]=[]
        func add(_ action:MotelAction) {if action != .none,!result.contains(action) {if case .clean = action {return};result.append(action)}}
        add(nearbyAction)
        for pet in visiblePets where actorTile.distance(to:pet.value.tile)<=2 {add(.pet(pet.key))}
        if let care=nearbyPersonalCare {add(.personal(care))}
        if currentBedroom != nil {return result}
        if isAtHome {
            if actorTile.distance(to:reception.hildarelys)<=2 {add(.family("hildarelys"))}
            if actorTile.distance(to:OfficeReception.samhil)<=2 {add(.family("samhil"))}
            for room in HomeBedroom.allCases where actorTile.distance(to:room.door)<=1 {add(.bedroom(room))}
            if actorTile.distance(to:BasementLayout.homeStairs)<=1 {add(.basement)}
            if actorTile.distance(to:FamilyHome.workbench)<=1 {add(.homeDecor)}
            if actorTile.distance(to:FamilyHome.exit)<=1 {add(.exit)}
        } else if isAtReception {
            let objects:[(Tile,MotelAction)]=[(OfficeReception.computer,.computer),(OfficeReception.clerk,.desk),(OfficeReception.door,.exit),(Tile(x:1,y:7),.tools),(Tile(x:1,y:9),.paint(nil)),(Tile(x:1,y:2),.rest),(Tile(x:5,y:4),.save)]
            for (tile,action) in objects where actorTile.distance(to:tile)<=1 {add(action)}
        } else if worldState.place == .grounds,visit==nil {
            if actorTile.distance(to:groundTile(FamilyHome.door))<=1 {add(.home)}
            for shop in NeighborhoodShop.allCases where actorTile.distance(to:groundTile(shop.door))<=1 {add(.shop(shop))}
            if actorTile.distance(to:groundTile(MotelGrounds.officeDoor))<=1 {add(.office)}
            for room in rooms where room.id/9==viewingFloor && actorTile.distance(to:groundRoomDoor(room.id))<=1 {add(.room(room.id))}
        }
        return result
    }
    var emergencyDispatchReason:String? {
        guard let incident=operationsState.incident else{return "No active emergency"}
        guard let worker=operationsState.workers.first(where:{$0.role==incident.kind.responder}) else{return "Hire a "+incident.kind.responder.title.lowercased()+" to send help"}
        return worker.active ? nil : worker.role.name+" is off duty; check wages in Staff"
    }
    @discardableResult mutating func dispatchEmergencyResponder()->Bool {
        guard !policeRequiresDecision,emergencyDispatchReason==nil,let incident=operationsState.incident,
              let index=operationsState.workers.firstIndex(where:{$0.role==incident.kind.responder && $0.active}) else{return false}
        var state=operationsState
        state.workers[index].roomID=nil
        state.workers[index].status="Responding to "+incident.kind.rawValue+" emergency"
        operations=state
        lastEvent=incident.kind.responder.name+" is heading to the emergency. Watch their progress on the grounds."
        return true
    }
    func facilityLockReason(_ facility:Facility)->String? {
        if simulation.facilities.contains(facility) {return "Already operational"}
        if !journeyAllows(facility) {return "Reach the "+Self.journeyNames[facilityJourneyTier(facility)]+" milestone in Haven life"}
        if simulation.reputation<facility.requiredRep {return "Requires reputation \(facility.requiredRep); current \(simulation.reputation)"}
        if facility == .upperFloor && !simulation.facilities.contains(.adjacentLot) {return "Buy the adjacent lot first"}
        if facility == .nightVision && !simulation.facilities.contains(.cameras) {return "Install the camera network first"}
        return nil
    }
}
