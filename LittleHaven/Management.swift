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
struct PoliceCase: Codable {
    let number: Int
    let guest: String
    let cause: ChaosKind
    var tile = MotelGrounds.gate
    var arrived = false
    var fine = 200
    var bribeTried = false
    var acceptsBribe = Bool.random()
    var message = ""
}
struct BusinessConsequences: Codable {
    var deaths = 0
    var reputationLoss = 0
    var finesPaid = 0
    var bribesAccepted = 0
    var bribesRejected = 0
    var debt = 0
    var police: PoliceCase?
}
struct MotelOperations: Codable {
    var consequences: BusinessConsequences?
    var colorsAssigned: Bool?
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
        if occupancy == 1 && state.incidentsStarted == 0 { state.nextIncidentTick = state.tick + 25 }
        operations = state
    }
    @discardableResult mutating func hire(_ role: StaffRole) -> Bool {
        guard canSave, cash >= role.hireCost, !operationsState.workers.contains(where: { $0.role == role }) else { return false }
        var state = operationsState
        cash -= role.hireCost
        state.workers.append(MotelWorker(role:role,tile:role.home))
        operations = state
        lastEvent = "\(role.name) joined as your \(role.title.lowercased()). First shift included; \(role.wage) coins each morning."
        return true
    }
    mutating func payStaffForDay() {
        var state = operationsState
        if state.incident != nil { failIncident(&state) }
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
        if theft > 0 { text = "My belongings disappeared. I cannot recommend this Airb&b." }
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
        state.nextIncidentTick = state.tick + 30
        operations = state
        lastEvent = "You handled the emergency. Guests can relax again."
        return true
    }
    mutating func tickManagement() {
        guard !caught else { return }
        var state = operationsState
        state.tick += 1
        if state.incident == nil && state.consequences?.police == nil && occupancy > 0 && state.tick >= state.nextIncidentTick {
            let kind = ChaosKind.allCases[state.incidentsStarted % ChaosKind.allCases.count]
            state.incidentsStarted += 1
            state.incident = MotelIncident(kind:kind)
            lastEvent = kind.title + " Check the grounds or send a trained employee."
        }
        if var incident = state.incident {
            incident.elapsed += 1
            state.incident = incident
            if incident.elapsed >= incident.limit {
                failIncident(&state)
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
                    state.nextIncidentTick = state.tick + 30
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
        if var police = state.consequences?.police {
            if police.tile == Tile(x:6,y:10) { police.arrived = true }
            else if let next = MotelGrounds.nextStep(from:police.tile,to:Tile(x:6,y:10),avoiding:[]) { police.tile = next }
            state.consequences!.police = police
        }
        operations = state
    }
}

extension Motel {
    var business: BusinessConsequences { operationsState.consequences ?? BusinessConsequences() }
    var bookingPenalty: Int { min(4,business.reputationLoss / 2) }
    mutating func assignRoomColors() {
        var state = operationsState
        guard state.colorsAssigned != true else { return }
        for i in rooms.indices where rooms[i].theme == 0 { rooms[i].theme = rooms[i].id % Self.themeColors.count }
        state.colorsAssigned = true
        operations = state
    }
    private mutating func failIncident(_ state: inout MotelOperations) {
        guard let incident = state.incident else { return }
        for room in rooms { if let guest = room.guest { state.guestPenalties[guest.id,default:0] += 2 } }
        cash = max(0,cash-40)
        state.incidentsMissed += 1
        state.incident = nil
        state.nextIncidentTick = state.tick + 30
        guard let index = rooms.firstIndex(where: { $0.guest != nil }), let guest = rooms[index].guest else {
            lastEvent = "The emergency caused damage. Repairs cost 40 coins."
            return
        }
        var consequences = state.consequences ?? BusinessConsequences()
        consequences.deaths += 1
        consequences.reputationLoss += 4
        consequences.police = PoliceCase(number:consequences.deaths,guest:guest.name,cause:incident.kind)
        state.consequences = consequences
        state.guestPenalties.removeValue(forKey:guest.id)
        state.reviews.insert(GuestReview(id:"fatal-\(consequences.deaths)",guest:"Concerned guest",day:day,room:rooms[index].number,stars:1,text:"A guest died during an ignored emergency. This Airb&b needs to take safety seriously."),at:0)
        state.reviews = Array(state.reviews.prefix(30))
        rooms[index].guest = nil; rooms[index].nightsLeft = 0
        rooms[index].dirty = true; rooms[index].cleanedTasks = []; rooms[index].stolen = []
        world?.travellers.removeAll { $0.id == guest.id }
        if world?.reception?.visitor?.guest.id == guest.id { world?.reception?.visitor = nil }
        lastEvent = "\(guest.name) died in the \(incident.kind.rawValue) emergency. Police are coming. Reputation fell and future bookings will drop."
    }
    @discardableResult mutating func payPoliceFine() -> Bool {
        var state = operationsState
        guard var consequences = state.consequences, let police = consequences.police, police.arrived else { return false }
        let paid = min(cash,police.fine)
        cash -= paid
        consequences.finesPaid += paid
        consequences.debt += police.fine-paid
        consequences.police = nil
        state.consequences = consequences; operations = state
        lastEvent = consequences.debt > 0 ? "Fine recorded. \(consequences.debt) coins remain due; future room payments repay the balance." : "Fine paid. The officer leaves. The safety record still affects bookings."
        return true
    }
    @discardableResult mutating func tryPoliceBribe() -> Bool {
        var state = operationsState
        guard var consequences = state.consequences, var police = consequences.police,
              police.arrived, !police.bribeTried, cash >= 80 else { return false }
        cash -= 80
        police.bribeTried = true
        // Decide once at dispatch and persist the outcome across save reloads.
        if police.acceptsBribe {
            consequences.bribesAccepted += 1
            consequences.reputationLoss += 1
            consequences.police = nil
            lastEvent = "The officer took 80 coins and closed the fine. Rumors about the payoff hurt your reputation."
        } else {
            consequences.bribesRejected += 1
            consequences.reputationLoss += 2
            police.fine += 150
            police.message = "Bribery refused. Your fine is now \(police.fine) coins. The attempted payoff is on your record."
            consequences.police = police
            lastEvent = police.message
        }
        state.consequences = consequences; operations = state
        return true
    }
    mutating func repayBusinessDebt() {
        var state = operationsState
        guard var consequences = state.consequences, consequences.debt > 0 else { return }
        let payment = min(cash,consequences.debt)
        cash -= payment; consequences.debt -= payment; consequences.finesPaid += payment
        state.consequences = consequences; operations = state
    }
}
