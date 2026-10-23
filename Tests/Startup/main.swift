import Foundation
import Darwin
setbuf(stdout,nil)
Motel.randomizeGuestArrivals = true
for attempt in 0..<20 {
    print("PRODUCTION STARTUP \(attempt): wake")
    var game=Game();game.coins=545;game.wakeUp()
    print("PRODUCTION STARTUP \(attempt): reconcile")
    game.motel!.reconcileInteriorSpawn()
    print("PRODUCTION STARTUP \(attempt): management")
    game.motel!.enableManagement()
    print("PRODUCTION STARTUP \(attempt): tick")
    for _ in 0..<20 {game.motel!.tickWorld()}
    print("PRODUCTION STARTUP \(attempt): save")
    let data=try JSONEncoder().encode(game)
    let restored=try JSONDecoder().decode(Game.self,from:data)
    precondition(restored.motel?.managementEnabled == true)
}
print("PASS: production initialization, normal guests, first ticks and save round trip")
