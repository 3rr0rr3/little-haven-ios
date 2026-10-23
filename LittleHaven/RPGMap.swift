import Foundation

// SwiftUI may briefly provide a zero-height viewport while replacing a screen.
// Never send an infinite or NaN scale/position into the SpriteKit camera.
enum RPGViewport {
    static func cameraScale(mapWidth:Double,mapHeight:Double,viewportWidth:Double,viewportHeight:Double,columns:Double,interior:Bool)->Double? {
        let values=[mapWidth,mapHeight,viewportWidth,viewportHeight,columns]
        guard values.allSatisfy({$0.isFinite && $0>0}) else{return nil}
        let scale=interior ? max(mapWidth/viewportWidth,mapHeight/viewportHeight) : 16*columns/viewportWidth
        guard scale.isFinite,scale>0,(viewportWidth*scale).isFinite,(viewportHeight*scale).isFinite else{return nil}
        return scale
    }
}

private final class GroundsMemo<Key: Equatable, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var entry: (Key, Value)?
    func value(for key: Key, build: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        if let entry, entry.0 == key { return entry.1 }
        let result = build()
        entry = (key, result)
        return result
    }
}
private struct GroundsLayoutKey: Equatable {
    let offsets: [String: Tile]
    let stations: [String]
}
private struct WaitingLayoutKey: Equatable {
    let layout: GroundsLayoutKey
    let rooms: [Int]
    let guests: [Int]
}
private let groundsMapMemo = GroundsMemo<GroundsLayoutKey, RPGMapDefinition>()
private let waitingTargetsMemo = GroundsMemo<WaitingLayoutKey, [Int: Tile]>()


// Engine-neutral map database, shared by movement, events and pathfinding.
// Coordinates are top-left tile coordinates, matching RPG Maker conventions.
struct RPGRegion: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    func contains(_ tile: Tile) -> Bool {
        tile.x >= x && tile.y >= y && tile.x < x + width && tile.y < y + height
    }
}
struct RPGMapEvent: Codable {
    enum Trigger: String, Codable { case action, playerTouch }
    let id: String
    let tile: Tile
    let trigger: Trigger
    var destination: String? = nil
    var arrival: Tile? = nil
}
struct RPGMapDefinition: Codable {
    let id: String
    let width: Int
    let height: Int
    let walkable: RPGRegion
    var obstacles: [RPGRegion] = []
    var passages: Set<Tile> = []
    var events: [RPGMapEvent] = []

    func blocked(_ tile: Tile, occupied: Set<Tile> = []) -> Bool {
        guard tile.x >= 0, tile.y >= 0, tile.x < width, tile.y < height else { return true }
        if occupied.contains(tile) { return true }
        if passages.contains(tile) { return false }
        return !walkable.contains(tile) || obstacles.contains { $0.contains(tile) }
    }
    func canStep(from: Tile, dx: Int, dy: Int, occupied: Set<Tile> = []) -> Bool {
        guard abs(dx) <= 1, abs(dy) <= 1, dx != 0 || dy != 0 else { return false }
        let target = Tile(x: from.x + dx, y: from.y + dy)
        guard !blocked(target, occupied: occupied) else { return false }
        return dx == 0 || dy == 0 || (!blocked(Tile(x: from.x + dx, y: from.y), occupied: occupied) && !blocked(Tile(x: from.x, y: from.y + dy), occupied: occupied))
    }
    func events(at tile: Tile, trigger: RPGMapEvent.Trigger) -> [RPGMapEvent] {
        events.filter { $0.trigger == trigger && (trigger == .action ? tile.distance(to: $0.tile) <= 1 : tile == $0.tile) }
    }
}
enum RPGMaps {
    static func hotelSidewalk(_ tile:Tile)->Bool {
        let x=tile.x,y=tile.y
        return ((11...38).contains(x) && [8,9,17,18,26,27,33,34].contains(y)) ||
            ((11...12).contains(x) && (8...34).contains(y)) ||
            ((3...10).contains(x) && (9...15).contains(y)) ||
            ((5...7).contains(x) && (23...35).contains(y))
    }
    static let landscapeTrees = [Tile(x:45,y:1),Tile(x:54,y:1),Tile(x:59,y:2),Tile(x:69,y:3),Tile(x:69,y:7),Tile(x:45,y:12),Tile(x:48,y:15),Tile(x:60,y:14),Tile(x:69,y:16),Tile(x:65,y:1),Tile(x:70,y:12),Tile(x:2,y:2),Tile(x:12,y:2),Tile(x:21,y:2),Tile(x:29,y:2),Tile(x:37,y:2),Tile(x:2,y:16),Tile(x:2,y:24),Tile(x:3,y:33),Tile(x:37,y:6),Tile(x:37,y:19),Tile(x:37,y:28)]
    static let landscapeBenches = [Tile(x:8,y:16),Tile(x:3,y:25),Tile(x:8,y:25)]
    static let town = RPGMapDefinition(id: "town", width: 20, height: 23,
        walkable: RPGRegion(x: 1, y: 1, width: 18, height: 21),
        obstacles: [RPGRegion(x: 2,y: 3,width: 4,height: 4), RPGRegion(x: 13,y: 3,width: 5,height: 4), RPGRegion(x: 2,y: 11,width: 4,height: 3), RPGRegion(x: 14,y: 13,width: 4,height: 3)],
        events: [RPGMapEvent(id: "cottage-door", tile: Tile(x: 15,y: 7), trigger: .action, destination: "cottage", arrival: Tile(x: 4,y: 6))])
    static let cottage = RPGMapDefinition(id: "cottage", width: 9, height: 9,
        walkable: RPGRegion(x: 1,y: 2,width: 7,height: 6),
        obstacles: [RPGRegion(x: 1,y: 2,width: 2,height: 2),RPGRegion(x: 6,y: 2,width: 1,height: 1)],
        passages: [Tile(x: 4,y: 8)], events: [RPGMapEvent(id: "exit",tile: Tile(x: 4,y: 8),trigger: .playerTouch,destination: "town",arrival: Tile(x: 15,y: 7))])
    static let office = RPGMapDefinition(id: "office", width: 15,height: 15,
        walkable: RPGRegion(x: 1,y: 2,width: 13,height: 12),
        obstacles: [RPGRegion(x: 2,y: 4,width: 5,height: 2),RPGRegion(x:10,y:6,width:3,height:3),RPGRegion(x:11,y:10,width:2,height:3),RPGRegion(x:11,y:3,width:2,height:2),RPGRegion(x:2,y:11,width:2,height:2),RPGRegion(x:13,y:13,width:1,height:1)],
        passages: [Tile(x: 7,y: 14)], events: [
            RPGMapEvent(id: "exit",tile: Tile(x: 7,y: 13),trigger: .action,destination: "grounds",arrival: Tile(x: 6,y: 10)),
            RPGMapEvent(id: "desk",tile: Tile(x: 4,y: 3),trigger: .action),
            RPGMapEvent(id: "tools",tile: Tile(x: 1,y: 7),trigger: .action),
            RPGMapEvent(id: "paint",tile: Tile(x: 1,y: 9),trigger: .action),
            RPGMapEvent(id: "save",tile: Tile(x: 5,y: 4),trigger: .action),
            RPGMapEvent(id: "rest",tile: Tile(x: 1,y: 2),trigger: .action)])
    static let room = RPGMapDefinition(id: "room",width: 9,height: 9,
        walkable: RPGRegion(x: 1,y: 2,width: 7,height: 6),
        obstacles: [RPGRegion(x: 2,y: 2,width: 2,height: 2),RPGRegion(x: 5,y: 2,width: 3,height: 1),RPGRegion(x: 2,y: 3,width: 1,height: 1),RPGRegion(x: 6,y: 6,width: 1,height: 1),RPGRegion(x: 2,y: 6,width: 1,height: 1)],
        passages: [Tile(x: 4,y: 8)], events: [RPGMapEvent(id: "exit",tile: Tile(x: 4,y: 8),trigger: .playerTouch,destination: "grounds")])
    static let grounds: RPGMapDefinition = {
        var obstacles = [RPGRegion(x: 3,y: 3,width: 8,height: 6),RPGRegion(x: 3,y: 18,width: 7,height: 5)]
        for tile in landscapeTrees + landscapeBenches {
            obstacles.append(RPGRegion(x:tile.x,y:tile.y,width:1,height:1))
        }
        for (x,y,w) in [(44,21,1),(49,21,1),(59,21,1),(69,21,1),(44,38,1),(66,32,1),(46,38,2),(58,38,2),(65,38,2),(48,38,1),(60,38,1),(67,38,1)] {
            obstacles.append(RPGRegion(x:x,y:y,width:w,height:1))
        }
        var events = [RPGMapEvent(id: "office",tile: Tile(x: 6,y: 9),trigger: .action,destination: "office",arrival: Tile(x: 4,y: 7)),RPGMapEvent(id: "construction",tile: Tile(x: 12,y: 26),trigger: .action)]
        for id in 0..<9 {
            let x = 14 + id % 3 * 8, y = 4 + id / 3 * 9
            obstacles.append(RPGRegion(x: x,y: y,width: 6,height: 4))
            events.append(RPGMapEvent(id: "room-\(id)",tile: Tile(x: x+2,y: y+4),trigger: .action,destination: "room-\(id)",arrival: Tile(x: 4,y: 7)))
        }
        obstacles.append(RPGRegion(x:1,y:40,width:38,height:MotelGrounds.height-40))
        for row in 42..<MotelGrounds.height {
            obstacles.append(RPGRegion(x:BeachLayout.shoreline(row),y:row,width:MotelGrounds.width-BeachLayout.shoreline(row),height:1))
        }
        for tile in BeachLayout.palms {obstacles.append(RPGRegion(x:tile.x,y:tile.y,width:1,height:1))}
        for tile in BeachLayout.lounges {obstacles.append(RPGRegion(x:tile.x,y:tile.y,width:1,height:2))}
        obstacles.append(RPGRegion(x:51,y:9,width:7,height:5))
        for shop in NeighborhoodShop.allCases {
            let height=(shop == .bar || shop == .fish) ? 4 : 6
            obstacles.append(RPGRegion(x:shop.door.x-3,y:shop.door.y-height,width:7,height:height))
        }
        for origin in ResidentialLayout.origins {obstacles.append(RPGRegion(x:origin.x,y:origin.y,width:7,height:5))}
        obstacles.append(contentsOf:FacilityLayout.obstacles)
        return RPGMapDefinition(id: "grounds",width: MotelGrounds.width,height: MotelGrounds.height,walkable: RPGRegion(x: 1,y: 1,width: MotelGrounds.width-2,height: MotelGrounds.height-2),obstacles: obstacles,events: events)
    }()
}

// Finger displacement uses screen points, independent of camera zoom or movement.
enum ThumbstickInput {
    static func direction(dx:Double,dy:Double,diagonals:Bool=true)->Tile? {
        guard dx.isFinite,dy.isFinite,hypot(dx,dy)>=12 else{return nil}
        if !diagonals {
            return abs(dx)>abs(dy) ? Tile(x:dx>0 ? 1 : -1,y:0) : Tile(x:0,y:dy>0 ? 1 : -1)
        }
        let x=abs(dx)>abs(dy)*0.45 ? (dx>0 ? 1 : -1) : 0
        let y=abs(dy)>abs(dx)*0.45 ? (dy>0 ? 1 : -1) : 0
        return Tile(x:x,y:y)
    }
}

// Saved offsets retain stable object IDs; original map coordinates remain migration-safe.
struct CreativeStructure:Identifiable {
    let id:String
    let title:String
    let footprint:RPGRegion
    let art:RPGRegion
    var anchors:[Tile]=[]
    var parent:String?=nil
}
enum CreativeCatalog {
    static let parentIDs:[String:String]=["washer":"laundry","supplies":"laundry","folding":"laundry","station-maintenance":"pump"]
    static let objects:[CreativeStructure] = {
        var result:[CreativeStructure]=[]
        func add(_ id:String,_ title:String,_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ anchors:[Tile]=[],_ art:RPGRegion?=nil,_ parent:String?=nil) {
            result.append(CreativeStructure(id:id,title:title,footprint:RPGRegion(x:x,y:y,width:w,height:h),
                art:art ?? RPGRegion(x:x*16-4,y:y*16-12,width:w*16+8,height:h*16+24),anchors:anchors,parent:parent))
        }
        var officeAnchors=[MotelGrounds.officeDoor,Tile(x:6,y:10),Tile(x:8,y:11)]
        for id in 0..<10 {officeAnchors.append(MotelGrounds.guestTile(id))}
        add("office","Reception office",3,3,8,6,officeAnchors,RPGRegion(x:46,y:40,width:130,height:120))
        for id in 0..<9 {
            let o=MotelGrounds.roomOrigin(id)
            add("room-\(id)","Motel room \(101+id)",o.x,o.y,6,4,[MotelGrounds.roomDoor(id)])
        }
        add("home","Family home",51,9,7,5,[FamilyHome.door,Tile(x:54,y:15)])
        for shop in NeighborhoodShop.allCases {
            let h=(shop == .bar || shop == .fish) ? 4 : 6
            add("shop-"+shop.id,shop.title,shop.door.x-3,shop.door.y-h,7,h,[shop.door,Tile(x:shop.door.x,y:shop.door.y+1)])
        }
        for (id,o) in ResidentialLayout.origins.enumerated() {
            add("neighbor-\(id)","Neighbor home \(id+1)",o.x,o.y,7,5,[ResidentialLayout.doors[id]])
        }
        add("laundry","Laundry pavilion",11,3,3,5,[],RPGRegion(x:176,y:48,width:48,height:82))
        add("washer","Washing machine",11,4,1,2,[FacilityLayout.laundry],RPGRegion(x:178,y:66,width:15,height:30),"laundry")
        add("supplies","Guest-supply shelves",12,4,2,2,[FacilityLayout.supplies],RPGRegion(x:195,y:66,width:27,height:30),"laundry")
        add("folding","Laundry folding counter",11,6,1,2,[],RPGRegion(x:178,y:99,width:14,height:29),"laundry")
        add("pool","Swimming pool",3,18,7,5,[ChaosKind.pool.tile,ChaosKind.pool.approach],RPGRegion(x:46,y:277,width:118,height:99))
        add("pump","Pool pump",10,21,1,2,[HotelService.repair.tile],RPGRegion(x:153,y:337,width:24,height:33))
        add("breakfast","Breakfast counter",2,26,3,2,[HotelService.breakfast.tile],RPGRegion(x:28,y:393,width:57,height:42))
        add("breakfast-table","Breakfast dining table",2,29,3,2,[],RPGRegion(x:31,y:454,width:49,height:36))
        for (id,t) in RPGMaps.landscapeTrees.enumerated() {
            add("tree-\(id)","Tree \(id+1)",t.x,t.y,1,1,[],RPGRegion(x:t.x*16-10,y:t.y*16-20,width:36,height:44))
        }
        for (id,t) in RPGMaps.landscapeBenches.enumerated() {
            add("bench-\(id)","Garden bench \(id+1)",t.x,t.y,1,1,[],RPGRegion(x:t.x*16,y:t.y*16,width:17,height:18))
        }
        for (id,t) in BeachLayout.lounges.enumerated() {
            add("chair-\(id)","Beach chair and parasol \(id+1)",t.x,t.y,1,2,[BeachLayout.approach(id)],RPGRegion(x:t.x*16-4,y:t.y*16-17,width:49,height:54))
        }
        for (id,t) in BeachLayout.palms.enumerated() {
            add("palm-\(id)","Beach palm \(id+1)",t.x,t.y,1,1,[],RPGRegion(x:t.x*16-18,y:t.y*16-42,width:52,height:64))
        }
        for (id,xy) in [(44,21),(49,21),(59,21),(69,21)].enumerated() {
            add("planter-\(id)","Street planter \(id+1)",xy.0,xy.1,1,1,[],RPGRegion(x:xy.0*16-2,y:xy.1*16-5,width:23,height:26))
        }
        for (id,xy) in [(43,21),(52,21),(62,21),(69,32)].enumerated() {
            add("lamp-\(id)","Street lamp \(id+1)",xy.0,xy.1,1,1,[],RPGRegion(x:xy.0*16,y:xy.1*16-24,width:15,height:40))
        }
        for (id,xy) in [(44,38),(66,32)].enumerated() {
            add("bin-\(id)","Recycling bin \(id+1)",xy.0,xy.1,1,1,[],RPGRegion(x:xy.0*16+1,y:xy.1*16,width:15,height:17))
        }
        for (id,xy) in [(46,38),(58,38),(65,38)].enumerated() {
            add("town-bench-\(id)","Town bench \(id+1)",xy.0,xy.1,2,1,[],RPGRegion(x:xy.0*16,y:xy.1*16,width:24,height:18))
        }
        for col in [14,22,30] {for row in [10,19,28] {
            add("flowers-\(col)-\(row)","Flower box",col,row,2,1,[],RPGRegion(x:col*16,y:row*16-3,width:29,height:13))
        }}
        for (id,tile) in Motel.gardenPlots.enumerated() {
            add("kitchen-plot-\(id)","Kitchen garden plot \(id+1)",tile.x,tile.y,1,1,[],RPGRegion(x:tile.x*16,y:tile.y*16-8,width:16,height:24))
        }
        add("garden-table","Garden table",4,16,3,1,[HotelService.garden.tile],RPGRegion(x:63,y:251,width:42,height:16))
        add("luggage","Luggage trolley",8,11,1,1,[],RPGRegion(x:128,y:176,width:24,height:28))
        add("motel-sign","Motel sign",1,32,4,1,[],RPGRegion(x:14,y:504,width:64,height:28))
        return result
    }()
}
extension Motel {
    var creativeStructures:[CreativeStructure] {
        let stations=staffStations.filter{$0 != .cleaner && $0 != .clerk}.map {role in
            let t=role.home
            return CreativeStructure(id:"station-"+role.rawValue,title:role.station.capitalized,
                footprint:RPGRegion(x:t.x,y:t.y,width:1,height:1),
                art:RPGRegion(x:t.x*16-8,y:t.y*16-15,width:41,height:39),anchors:[t],parent:role == .maintenance ? "pump" : nil)
        }
        return CreativeCatalog.objects+stations
    }
    func creativeOffset(_ id:String)->Tile {
        if id=="station-clerk" {return creativeOffset("office")}
        let own=worldState.structureOffsets?[id] ?? Tile(x:0,y:0)
        guard let parent=CreativeCatalog.parentIDs[id] else{return own}
        let inherited=worldState.structureOffsets?[parent] ?? Tile(x:0,y:0)
        return Tile(x:own.x+inherited.x,y:own.y+inherited.y)
    }
    func groundTile(_ source:Tile)->Tile {
        guard !(worldState.structureOffsets ?? [:]).isEmpty else { return source }
        let objects=creativeStructures
        guard let object=objects.first(where:{$0.anchors.contains(source)}) ??
            objects.first(where:{$0.parent != nil && $0.footprint.contains(source)}) ??
            objects.first(where:{$0.footprint.contains(source)}) else{return source}
        let d=creativeOffset(object.id)
        return Tile(x:source.x+d.x,y:source.y+d.y)
    }
    func staffHome(_ role:StaffRole)->Tile {
        if role == .cleaner || role == .clerk {return groundTile(role.home)}
        let d=creativeOffset("station-"+role.rawValue)
        return Tile(x:role.home.x+d.x,y:role.home.y+d.y)
    }
    /// Waiting guests use separate courtyard spots, with the office entrance kept clear.
    private var groundsLayoutKey: GroundsLayoutKey {
        GroundsLayoutKey(offsets: worldState.structureOffsets ?? [:], stations: staffStations.map(\.rawValue))
    }
    var waitingGuestTargets:[Int:Tile] {
        let key = WaitingLayoutKey(layout: groundsLayoutKey, rooms: rooms.map(\.id),
            guests: waiting.filter { $0.id != reception.visitor?.guest.id }.map(\.id))
        return waitingTargetsMemo.value(for: key) { buildWaitingGuestTargets() }
    }
    private func buildWaitingGuestTargets() -> [Int: Tile] {
        let map=relocatedGrounds,entrance=groundTile(Tile(x:6,y:10))
        let preferred=[Tile(x:10,y:16),Tile(x:10,y:24),Tile(x:10,y:29),
            Tile(x:13,y:11),Tile(x:21,y:11),Tile(x:29,y:11),Tile(x:37,y:11),
            Tile(x:21,y:20),Tile(x:29,y:20),Tile(x:37,y:20),
            Tile(x:21,y:29),Tile(x:29,y:29),Tile(x:36,y:31),Tile(x:2,y:29)]
        let fallback=(11...32).filter{$0%3 == 2}.flatMap{y in
            (2...37).filter{$0%3 == 2}.map{x in Tile(x:x,y:y)}
        }
        let doors=rooms.map{groundRoomDoor($0.id)}
        var seen=Set<Tile>()
        let sites=(preferred+fallback).filter{tile in
            seen.insert(tile).inserted && !map.blocked(tile) &&
            tile.distance(to:entrance)>3 && !RPGMaps.hotelSidewalk(tile) &&
            !doors.contains{$0.distance(to:tile)<=1}
        }
        var assigned:[Int:Tile]=[:],used=[Tile]()
        for guest in waiting where guest.id != reception.visitor?.guest.id {
            guard !sites.isEmpty else{break}
            let index=abs(guest.id%sites.count)
            let ordered=Array(sites[index...])+Array(sites[..<index])
            if let tile=ordered.first(where:{candidate in !used.contains{$0.distance(to:candidate)<3}}) ??
                ordered.first(where:{!used.contains($0)}) {
                assigned[guest.id]=tile;used.append(tile)
            }
        }
        return assigned
    }
    func groundGuestTile(_ id:Int)->Tile {
        waitingGuestTargets[id] ?? groundNearestWalkable(to:Tile(x:10,y:16))
    }
    func groundRoomDoor(_ id:Int)->Tile {groundTile(MotelGrounds.roomDoor(id))}
    var relocatedGrounds:RPGMapDefinition {
        guard !(worldState.structureOffsets ?? [:]).isEmpty else{return RPGMaps.grounds}
        return groundsMapMemo.value(for: groundsLayoutKey) { buildRelocatedGrounds() }
    }
    private func buildRelocatedGrounds() -> RPGMapDefinition {
        var map=RPGMaps.grounds
        let objects=creativeStructures
        map.obstacles=map.obstacles.flatMap {r->[RPGRegion] in
            // Split the original laundry's west wall into its movable machines and counter.
            if r.x==11 && r.y==4 && r.width==1 && r.height==4 {
                return ["washer","folding"].compactMap {id in
                    guard let object=objects.first(where:{$0.id==id}) else{return nil}
                    let d=creativeOffset(id),f=object.footprint
                    return RPGRegion(x:f.x+d.x,y:f.y+d.y,width:f.width,height:f.height)
                }
            }
            let origin=Tile(x:r.x,y:r.y)
            guard let owner=objects.first(where:{$0.parent != nil && $0.footprint.contains(origin)}) ??
                    objects.first(where:{$0.footprint.contains(origin) && $0.footprint.contains(Tile(x:r.x+r.width-1,y:r.y+r.height-1))}) else{return [r]}
            let d=creativeOffset(owner.id)
            return [RPGRegion(x:r.x+d.x,y:r.y+d.y,width:r.width,height:r.height)]
        }
        map.events=map.events.map {e in RPGMapEvent(id:e.id,tile:groundTile(e.tile),trigger:e.trigger,destination:e.destination,arrival:e.arrival)}
        return map
    }
    func groundBlocked(_ tile:Tile)->Bool {relocatedGrounds.blocked(tile)}
    func groundNearestWalkable(to point:Tile)->Tile {
        let map=relocatedGrounds
        for radius in 0..<max(map.width,map.height) {
            for y in max(1,point.y-radius)...min(map.height-2,max(1,point.y+radius)) {
                for x in max(1,point.x-radius)...min(map.width-2,max(1,point.x+radius)) {
                    let t=Tile(x:x,y:y)
                    if !map.blocked(t) {return t}
                }
            }
        }
        return MotelGrounds.gate
    }
    func groundNextStep(from start:Tile,to target:Tile,avoiding:Set<Tile>)->Tile? {
        if (worldState.structureOffsets ?? [:]).isEmpty {return MotelGrounds.nextStep(from:start,to:target,avoiding:avoiding)}
        let map=relocatedGrounds
        guard start != target,!map.blocked(target) else{return nil}
        let neighbors:[(Int,Int)]=[(0,1),(1,0),(-1,0),(0,-1)]
        if avoiding.contains(target) {
            return neighbors.map{Tile(x:start.x+$0.0,y:start.y+$0.1)}.first{
                !map.blocked($0) && !avoiding.contains($0) && $0.distance(to:target)<start.distance(to:target)
            }
        }
        var queue=[start],seen:Set<Tile>=[start],parents:[Tile:Tile]=[:],cursor=0
        while cursor<queue.count {
            let current=queue[cursor];cursor += 1
            for (dx,dy) in neighbors {
                let next=Tile(x:current.x+dx,y:current.y+dy)
                guard !map.blocked(next),!avoiding.contains(next),seen.insert(next).inserted else{continue}
                parents[next]=current
                if next==target {
                    var step=next
                    while let parent=parents[step],parent != start {step=parent}
                    return step
                }
                queue.append(next)
            }
        }
        return nil
    }
    func groundStaffStep(from start:Tile,to target:Tile,avoiding:Set<Tile>)->Tile? {
        if (worldState.structureOffsets ?? [:]).isEmpty {return MotelGrounds.staffStep(from:start,to:target,avoiding:avoiding)}
        if !avoiding.contains(target) {return groundNextStep(from:start,to:target,avoiding:avoiding)}
        for (dx,dy) in [(0,1),(1,0),(-1,0),(0,-1)] {
            let approach=Tile(x:target.x+dx,y:target.y+dy)
            if !groundBlocked(approach),!avoiding.contains(approach),let next=groundNextStep(from:start,to:approach,avoiding:avoiding) {return next}
        }
        return nil
    }
    func groundEscapeStep(from start:Tile,danger:Tile,avoiding:Set<Tile>)->Tile? {
        if (worldState.structureOffsets ?? [:]).isEmpty {return MotelGrounds.escapeStep(from:start,danger:danger,avoiding:avoiding)}
        let map=relocatedGrounds
        let safe=[Tile(x:2,y:12),Tile(x:11,y:32),Tile(x:36,y:27),Tile(x:12,y:3)].filter{!map.blocked($0)}.max{$0.distance(to:danger)<$1.distance(to:danger)} ?? groundNearestWalkable(to:MotelGrounds.gate)
        var unsafe=avoiding
        let clearance=min(12,start.distance(to:danger))
        for y in 1..<map.height-1 {for x in 1..<map.width-1 {
            let tile=Tile(x:x,y:y)
            if tile.distance(to:danger)<clearance {unsafe.insert(tile)}
        }}
        return groundNextStep(from:start,to:safe,avoiding:unsafe)
    }
    @discardableResult mutating func relocateStructure(_ id:String,to origin:Tile)->Bool {
        guard let object=creativeStructures.first(where:{$0.id==id}) else{return false}
        initializeWorld()
        let old=worldState.structureOffsets ?? [:]
        let inherited=object.parent.map{creativeOffset($0)} ?? Tile(x:0,y:0)
        let d=Tile(x:origin.x-object.footprint.x-inherited.x,y:origin.y-object.footprint.y-inherited.y)
        world!.structureOffsets=old;world!.structureOffsets![id]=d
        let map=relocatedGrounds
        let moved=creativeStructures.filter{$0.id==id || $0.parent==id}
        let movedIDs=Set(moved.map(\.id))
        for item in moved {
            let offset=creativeOffset(item.id),f=item.footprint
            for y in f.y+offset.y..<f.y+offset.y+f.height {for x in f.x+offset.x..<f.x+offset.x+f.width {
                let tile=Tile(x:x,y:y)
                if x<1 || y<1 || x>=map.width-1 || y>=map.height-1 ||
                    (y>=42 && x>=BeachLayout.shoreline(y)) || (x<40 && y>=40) ||
                    creativeStructures.contains(where:{other in
                        guard !movedIDs.contains(other.id),other.id != object.parent else{return false}
                        let od=creativeOffset(other.id),o=other.footprint
                        return RPGRegion(x:o.x+od.x,y:o.y+od.y,width:o.width,height:o.height).contains(tile)
                    }) {
                    world!.structureOffsets=old;lastEvent="Choose open ground without another structure or the sea.";return false
                }
            }}
        }
        if let incident=operationsState.incident,incident.kind != .pool,
           map.blocked(incident.tile) || map.blocked(incident.approach) {
            world!.structureOffsets=old;lastEvent="Keep the active emergency area clear.";return false
        }
        // Every entrance and service approach must remain accessible after placement.
        for anchor in creativeStructures.flatMap(\.anchors) where !RPGMaps.grounds.blocked(anchor) && map.blocked(groundTile(anchor)) {
            world!.structureOffsets=old;lastEvent="Leave the doors and service approaches clear.";return false
        }
        // Preserve travellers' destination identities, including guests already en route.
        for i in world!.travellers.indices {
            let walker=world!.travellers[i]
            let target=walker.destination == MotelGrounds.gate ? MotelGrounds.gate : groundRoomDoor(walker.roomID)
            world!.travellers[i]=MotelWalker(id:walker.id,name:walker.name,color:walker.color,roomID:walker.roomID,player:walker.player,previous:walker.player,destination:target)
        }
        for i in world!.travellers.indices where map.blocked(world!.travellers[i].player) {
            let safe=groundNearestWalkable(to:world!.travellers[i].player)
            world!.travellers[i].player=safe;world!.travellers[i].previous=safe
        }
        for key in ["guests","neighbors","town","witnesses"] {
            var people=key=="guests" ? worldState.guestPositions ?? [:] : key=="neighbors" ? worldState.neighborPositions ?? [:] : key=="town" ? worldState.townPositions ?? [:] : worldState.witnessPositions ?? [:]
            for (person,tile) in people where map.blocked(tile) {people[person]=groundNearestWalkable(to:tile)}
            switch key {
            case "guests":world!.guestPositions=people
            case "neighbors":world!.neighborPositions=people;world!.neighborPrevious=people
            case "town":world!.townPositions=people;world!.townPrevious=people
            default:world!.witnessPositions=people
            }
        }
        var parking=bikeParking
        let entrances=Set(creativeStructures.flatMap(\.anchors).map(groundTile))
        var reserved=Set(parkedBikes.map{parking[$0.id] ?? HotelCar.tile($0.slot)})
        for bike in parkedBikes {
            let position=parking[bike.id] ?? HotelCar.tile(bike.slot)
            if map.blocked(position) || entrances.contains(position) {
                reserved.remove(position)
                var safe:Tile?
                for y in 1..<map.height-1 {for x in 1..<map.width-1 {
                    let candidate=Tile(x:x,y:y)
                    guard !map.blocked(candidate),!reserved.contains(candidate),!entrances.contains(candidate) else{continue}
                    if safe == nil || candidate.distance(to:position)<safe!.distance(to:position) {safe=candidate}
                }}
                if let safe {parking[bike.id]=safe;reserved.insert(safe)}
            }
        }
        world!.bikeParking=parking
        for (petID,var pet) in worldState.pets ?? [:] where pet.map=="grounds" && map.blocked(pet.tile) {
            pet.tile=groundNearestWalkable(to:pet.tile);world!.pets?[petID]=pet
        }
        var ops=operationsState
        for i in ops.workers.indices where map.blocked(ops.workers[i].tile) {
            ops.workers[i].tile=groundNearestWalkable(to:ops.workers[i].tile);ops.workers[i].previous=ops.workers[i].tile
        }
        if id=="pool",ops.incident?.kind == .pool {ops.incident!.location=groundTile(ChaosKind.pool.tile)}
        operations=ops
        if world!.place == .grounds && map.blocked(world!.player) {world!.player=groundNearestWalkable(to:world!.player)}
        world!.beachSeat=nil
        lastEvent=object.title+" moved. Doors and routes updated."
        return true
    }
    mutating func resetCreativeLayout() {
        initializeWorld();world!.structureOffsets=nil
        for i in world!.travellers.indices {
            let walker=world!.travellers[i]
            let target=walker.destination == MotelGrounds.gate ? MotelGrounds.gate : groundRoomDoor(walker.roomID)
            world!.travellers[i]=MotelWalker(id:walker.id,name:walker.name,color:walker.color,roomID:walker.roomID,player:walker.player,previous:walker.player,destination:target)
        }
        var ops=operationsState
        if ops.incident?.kind == .pool {ops.incident!.location=ChaosKind.pool.tile}
        for i in ops.workers.indices where groundBlocked(ops.workers[i].tile) {
            ops.workers[i].tile=groundNearestWalkable(to:ops.workers[i].tile);ops.workers[i].previous=ops.workers[i].tile
        }
        operations=ops;reconcileInteriorSpawn()
        lastEvent="Original map layout restored."
    }
}
