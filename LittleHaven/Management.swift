import Foundation

enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case cleaner, maintenance, security
    var id: String { rawValue }
    var title: String { switch self { case .cleaner: return "Housekeeper"; case .maintenance: return "Groundskeeper"; case .security: return "Security guard" } }
    var name: String { switch self { case .cleaner: return "Luna"; case .maintenance: return "Mateo"; case .security: return "Riley" } }
    var hireCost: Int { switch self { case .cleaner: return 100; case .maintenance: return 140; case .security: return 160 } }
    var wage: Int { switch self { case .cleaner: return 15; case .maintenance: return 20; case .security: return 25 } }
    var duty: String { switch self { case .cleaner: return "Walks to vacant dirty rooms and cleans them."; case .maintenance: return "Responds to fires and pool accidents."; case .security: return "Breaks up fights outside the office." } }
    var home: Tile { Tile(x:11,y:self == .cleaner ? 10 : self == .maintenance ? 11 : 12) }
    var color: UInt32 { switch self { case .cleaner: return 0xB4A1C5; case .maintenance: return 0xD8AC66; case .security: return 0x718DA9 } }
}
struct MotelWorker: Codable, Identifiable {
    let role: StaffRole
    var tile = Tile(x:6,y:10)
    var roomID: Int?
    var progress = 0
    var active = true
    var id: String { role.rawValue }
}
struct GuestReview: Codable, Identifiable {
    let id: String
    let guest: String
    let day: Int
    let room: Int
    let stars: Int
    let text: String
}
enum ChaosKind: String, Codable, CaseIterable {
    case fire, pool, fight
    var title: String { switch self { case .fire: return "Fire in the courtyard!"; case .pool: return "Guest in the pool!"; case .fight: return "A fight outside!" } }
    var detail: String { switch self { case .fire: return "A trash bin is burning by the parking area. Go outside and put it out before it spreads."; case .pool: return "A guest fell into the pool and needs help getting out. Reach the south pool edge and help them."; case .fight: return "Two guests are arguing and shoving outside reception. Go over and calm them down." } }
    var action: String { switch self { case .fire: return "Put out the fire"; case .pool: return "Help the guest out"; case .fight: return "Break up the fight" } }
    var tile: Tile { switch self { case .fire: return Tile(x:16,y:28); case .pool: return Tile(x:6,y:21); case .fight: return Tile(x:11,y:13) } }
    var approach: Tile { switch self { case .fire: return Tile(x:16,y:29); case .pool: return Tile(x:6,y:23); case .fight: return Tile(x:11,y:14) } }
    var responder: StaffRole { self == .fight ? .security : .maintenance }
}
struct MotelIncident: Codable {
    let kind: ChaosKind
    var elapsed = 0
    var staffProgress = 0
    let limit = 90
    var remaining: Int { max(0,limit-elapsed) }
}
struct MotelOperations: Codable {
    var tick = 0
    var nextIncidentTick = 45
    var incidentsStarted = 0
    var incidentsResolved = 0
    var incidentsMissed = 0
    var incident: MotelIncident?
    var workers: [MotelWorker] = []
    var reviews: [GuestReview] = []
    var guestPenalties: [Int:Int] = [:]
}
extension Motel {
    var operationsState: MotelOperations { operations ?? MotelOperations() }
    var reviewAverage: Double? {
        let reviews = operationsState.reviews
        return reviews.isEmpty ? nil : Double(reviews.reduce(0) { $0 + $1.stars }) / Double(reviews.count)
    }
    var nearbyIncident: Bool {
        guard visit == nil, worldState.place == .grounds, let incident = operationsState.incident else { return false }
        return actorTile.distance(to:incident.kind.approach) <= 1
    }
    mutating func prepareChaosClock() {
        var state = operationsState
        if occupancy == 1 && state.incidentsStarted == 0 { state.nextIncidentTick = state.tick + 40 }
        operations = state
    }
    @discardableResult mutating func hire(_ role: StaffRole) -> Bool {
        guard isAtReception, canSave, cash >= role.hireCost, !operationsState.workers.contains(where: { $0.role == role }) else { return false }
        var state = operationsState
        cash -= role.hireCost
        state.workers.append(MotelWorker(role:role,tile:role.home))
        operations = state
        lastEvent = "\(role.name) joined as your \(role.title.lowercased()). First shift included; \(role.wage) coins each morning."
        return true
    }
    mutating func payStaffForDay() {
        var state = operationsState
        if state.incident != nil {
            for room in rooms { if let guest = room.guest { state.guestPenalties[guest.id,default:0] += 2 } }
            cash = max(0,cash-40)
            state.incidentsMissed += 1
            state.incident = nil
            state.nextIncidentTick = state.tick + 60
        }
        for i in state.workers.indices {
            let wage = state.workers[i].role.wage
            state.workers[i].active = cash >= wage
            state.workers[i].roomID = nil
            state.workers[i].progress = 0
            if state.workers[i].active { cash -= wage }
        }
        operations = state
    }
    mutating func recordCheckoutReview(_ room: MotelRoom) {
        guard let guest = room.guest else { return }
        var state = operationsState
        let id = "\(day)-\(guest.id)"
        guard !state.reviews.contains(where: { $0.id == id }) else { return }
        let penalty = state.guestPenalties.removeValue(forKey:guest.id) ?? 0
        let theft = room.stolen.isEmpty ? 0 : 3
        let stars = max(1,min(5,4 + min(1,room.furniture) - penalty - theft))
        let text: String
        if theft > 0 { text = "My belongings disappeared. I cannot recommend this motel." }
        else if penalty > 0 { text = "The trouble outside was not handled in time. It spoiled my stay." }
        else if stars == 5 { text = "Lovely upgraded room and a peaceful stay. I would come back!" }
        else { text = "A clean room and a friendly welcome. Good value for the night." }
        state.reviews.insert(GuestReview(id:id,guest:guest.name,day:day,room:room.number,stars:stars,text:text),at:0)
        state.reviews = Array(state.reviews.prefix(30))
        operations = state
    }
    @discardableResult mutating func upgradeFromDesk(_ roomID: Int) -> Bool {
        guard isAtReception else { return false }
        return upgrade(roomID:roomID)
    }
    @discardableResult mutating func resolveNearbyIncident() -> Bool {
        guard nearbyIncident, !caught else { return false }
        var state = operationsState
        state.incident = nil
        state.incidentsResolved += 1
        state.nextIncidentTick = state.tick + 60
        operations = state
        lastEvent = "You handled the emergency. Guests can relax again."
        return true
    }
    mutating func tickManagement() {
        guard !caught else { return }
        var state = operationsState
        state.tick += 1
        if state.incident == nil && occupancy > 0 && state.tick >= state.nextIncidentTick {
            let kind = ChaosKind.allCases[state.incidentsStarted % ChaosKind.allCases.count]
            state.incidentsStarted += 1
            state.incident = MotelIncident(kind:kind)
            lastEvent = kind.title + " Check the grounds or send a trained employee."
        }
        if var incident = state.incident {
            incident.elapsed += 1
            state.incident = incident
            if incident.elapsed >= incident.limit {
                for room in rooms { if let guest = room.guest { state.guestPenalties[guest.id,default:0] += 2 } }
                cash = max(0,cash-40)
                state.incidentsMissed += 1
                state.incident = nil
                state.nextIncidentTick = state.tick + 60
                lastEvent = "The incident was handled too late. -40 coins in repairs; guests may leave bad reviews."
            }
        }
        var occupied = Set(waiting.filter { $0.id != reception.visitor?.guest.id }.map { MotelGrounds.guestTile($0.id) } + worldState.travellers.map(\.player))
        if !isAtReception && visit == nil { occupied.insert(actorTile) }
        for index in state.workers.indices where state.workers[index].active {
            var worker = state.workers[index]
            let target: Tile
            let responding = state.incident?.kind.responder == worker.role
            if responding, let incident = state.incident {
                worker.roomID = nil
                target = incident.kind.approach
            } else if worker.role == .cleaner, let room = rooms.first(where: { $0.dirty && $0.guest == nil }) {
                if worker.roomID != room.id { worker.progress = 0 }
                worker.roomID = room.id
                target = MotelGrounds.roomDoor(room.id)
            } else {
                worker.roomID = nil
                worker.progress = 0
                target = worker.role.home
            }
            if worker.tile.distance(to:target) > (responding ? 1 : 0) {
                if let next = MotelGrounds.nextStep(from:worker.tile,to:target,avoiding:occupied) { worker.tile = next }
            } else if responding {
                state.incident!.staffProgress += 1
                if state.incident!.staffProgress >= 8 {
                    state.incident = nil
                    state.incidentsResolved += 1
                    state.nextIncidentTick = state.tick + 60
                    lastEvent = "\(worker.role.name) handled the emergency. Your guests are safe."
                }
            } else if let roomID = worker.roomID, let roomIndex = rooms.firstIndex(where: { $0.id == roomID }) {
                worker.progress += 1
                if worker.progress >= 15 {
                    rooms[roomIndex].dirty = false
                    rooms[roomIndex].cleanedTasks = Set(MotelGrounds.cleaningTiles.indices)
                    worker.roomID = nil
                    worker.progress = 0
                    lastEvent = "\(worker.role.name) cleaned room \(rooms[roomIndex].number). It is ready to rent."
                }
            }
            state.workers[index] = worker
            occupied.insert(worker.tile)
        }
        operations = state
    }
}
