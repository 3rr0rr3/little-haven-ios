import Foundation
Motel.randomizeGuestArrivals = false
func measure(_ name: String, _ action: () -> Int) {
    let start = Date().timeIntervalSinceReferenceDate
    let checksum = action()
    let ms = (Date().timeIntervalSinceReferenceDate - start) * 1000
    print("\(name) \(ms) \(checksum)")
}
var hotel = Motel(); hotel.initializeWorld()
hotel.waiting = Motel.arrivals(day: 8, count: 12, randomize: false)
hotel.world!.place = .grounds
hotel.operations!.nextIncidentTick = 100000
measure("waitingLookups") {
    var sum = 0
    for _ in 0..<1000 { for tile in hotel.waitingGuestTargets.values { sum += tile.x + tile.y } }
    return sum
}
measure("worldTicks") {
    for _ in 0..<240 { hotel.tickWorld() }
    return hotel.worldState.tick
}
hotel.world!.structureOffsets = ["office": Tile(x: 1, y: 0)]
measure("creativeCollision") {
    var sum = 0
    for index in 0..<1000 { if hotel.groundBlocked(Tile(x: 2 + index % 35, y: 11 + index % 20)) { sum += 1 } }
    return sum
}
measure("routes") {
    var sum = 0
    for _ in 0..<100 {
        for target in [Tile(x:10,y:24),Tile(x:44,y:22),Tile(x:63,y:38)] {
            if let step = MotelGrounds.nextStep(from: Tile(x:10,y:16), to:target, avoiding:[]) { if !MotelGrounds.blocked(step) { sum += 1 } }
        }
    }
    return sum
}
