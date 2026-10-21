import Foundation

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
    static let landscapeTrees = [Tile(x:2,y:2),Tile(x:12,y:2),Tile(x:21,y:2),Tile(x:29,y:2),Tile(x:37,y:2),Tile(x:2,y:16),Tile(x:2,y:24),Tile(x:2,y:30),Tile(x:9,y:30),Tile(x:3,y:33),Tile(x:10,y:33),Tile(x:37,y:10),Tile(x:37,y:19),Tile(x:37,y:28)]
    static let landscapeBenches = [Tile(x:3,y:16),Tile(x:8,y:16),Tile(x:3,y:25),Tile(x:8,y:25)]
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
        obstacles: [RPGRegion(x: 2,y: 4,width: 5,height: 2),RPGRegion(x:10,y:7,width:3,height:2),RPGRegion(x:11,y:2,width:2,height:3),RPGRegion(x:2,y:11,width:2,height:2),RPGRegion(x:13,y:10,width:1,height:1)],
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
        var obstacles = [RPGRegion(x: 3,y: 3,width: 8,height: 6),RPGRegion(x: 3,y: 18,width: 7,height: 5),RPGRegion(x: 12,y: 26,width: 1,height: 1)]
        for tile in landscapeTrees + landscapeBenches {
            obstacles.append(RPGRegion(x:tile.x,y:tile.y,width:1,height:1))
        }
        for (x,y,w) in [(44,21,1),(49,21,1),(59,21,1),(69,21,1),(45,32,1),(60,32,1),(46,38,2),(58,38,2),(65,38,2),(48,38,1),(60,38,1),(67,38,1),(12,15,1)] {
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
        for x in [17,25,33] { obstacles.append(RPGRegion(x: x,y: 30,width: 3,height: 2)) }
        obstacles.append(RPGRegion(x:51,y:9,width:7,height:5))
        for shop in NeighborhoodShop.allCases {obstacles.append(RPGRegion(x:shop.door.x-3,y:23,width:7,height:6))}
        return RPGMapDefinition(id: "grounds",width: MotelGrounds.width,height: MotelGrounds.height,walkable: RPGRegion(x: 1,y: 1,width: MotelGrounds.width-2,height: MotelGrounds.height-2),obstacles: obstacles,events: events)
    }()
}
