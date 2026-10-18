import Foundation

enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case cleaner, maintenance, security, valet
    var id: String { rawValue }
    var title: String { switch self { case .cleaner: return "Housekeeper"; case .maintenance: return "Groundskeeper"; case .security: return "Security guard"; case .valet: return "Car wash attendant" } }
    var name: String { switch self { case .cleaner: return "Luna"; case .maintenance: return "Mateo"; case .security: return "Riley"; case .valet: return "Diego" } }
    var hireCost: Int { switch self { case .cleaner: return 100; case .maintenance: return 140; case .security: return 160; case .valet: return 120 } }
    var wage: Int { switch self { case .cleaner: return 15; case .maintenance: return 20; case .security: return 25; case .valet: return 18 } }
    var duty: String { switch self { case .cleaner: return "Walks to vacant dirty rooms and cleans them."; case .maintenance: return "Responds to fires and pool accidents."; case .security: return "Breaks up fights outside the office."; case .valet: return "Walks to parked guest cars, scrubs and rinses them. Each car earns 35 coins once per day." } }
    var home: Tile { self == .valet ? Tile(x:15,y:32) : Tile(x:11,y:self == .cleaner ? 10 : self == .maintenance ? 11 : 12) }
    var color: UInt32 { switch self { case .cleaner: return 0xB4A1C5; case .maintenance: return 0xD8AC66; case .security: return 0x718DA9; case .valet: return 0x5DA6B0 } }
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
    var serviceDays: [String:Int]?
    var actionLabel: String?
    var actionUntil: Int?
    var visual: HotelVisual?
    var visualSerial: Int?
    var cars: [HotelCar]?
    var washIncome: Int?
    var weatherOverride: HotelWeather?

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
        let incident = state.incident!
        state.visualSerial = (state.visualSerial ?? 0) + 1
        state.visual = HotelVisual(id:state.visualSerial!,kind:incident.kind == .fire ? "extinguish" : incident.kind == .pool ? "rescue" : "calm",origin:actorTile,target:incident.kind.tile,map:"grounds")
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
        tickParking(&state)
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
            } else if worker.role == .valet, let car = state.cars?.first(where: { $0.arrival >= 8 && $0.washedDay != day }) {
                worker.roomID = car.id
                target = HotelCar.approach(car.slot)
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
            } else if worker.role == .valet, let carID = worker.roomID,
                      let carIndex = state.cars?.firstIndex(where: { $0.id == carID }) {
                worker.progress += 1
                state.cars![carIndex].washProgress = worker.progress
                if worker.progress >= 10 {
                    state.cars![carIndex].washedDay = day
                    state.cars![carIndex].washProgress = 0
                    state.washIncome = (state.washIncome ?? 0) + 35
                    cash += 35
                    worker.progress = 0; worker.roomID = nil
                    lastEvent = "Diego washed a guest car. +35 coins."
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


enum HotelService: String, CaseIterable {
    case breakfast, laundry, repair, garden, luggage
    var title: String { switch self {
    case .breakfast: return "Serve breakfast"
    case .laundry: return "Wash fresh towels"
    case .repair: return "Repair pool pump"
    case .garden: return "Water the garden"
    case .luggage: return "Deliver luggage"
    } }
    var tile: Tile { switch self {
    case .breakfast: return Tile(x:10,y:15)
    case .laundry: return Tile(x:10,y:25)
    case .repair: return Tile(x:10,y:22)
    case .garden: return Tile(x:3,y:28)
    case .luggage: return Tile(x:8,y:11)
    } }
    var symbol: String { switch self {
    case .breakfast: return "?"
    case .laundry: return "�"
    case .repair: return "?"
    case .garden: return "?"
    case .luggage: return "?"
    } }
    var reward: Int { self == .luggage ? 18 : self == .breakfast ? 24 : 12 }
}
extension Motel {
    var nearbyService: HotelService? {
        guard canSave, visit == nil, worldState.place == .grounds else { return nil }
        return HotelService.allCases.first { actorTile.distance(to:$0.tile) <= 1 }
    }
    func serviceAvailable(_ service: HotelService) -> Bool {
        (operationsState.serviceDays?[service.rawValue] != day) &&
        (!(service == .breakfast || service == .luggage) || occupancy > 0)
    }
    @discardableResult mutating func performService(_ service: HotelService) -> Bool {
        guard nearbyService == service, serviceAvailable(service), !caught else { return false }
        var state = operationsState
        var days = state.serviceDays ?? [:]
        days[service.rawValue] = day
        state.serviceDays = days
        state.actionLabel = service.rawValue
        state.actionUntil = state.tick + 3
        operations = state
        cash += service.reward
        playVisual(service.rawValue, target:service.tile)
        lastEvent = "\(service.title) completed! +\(service.reward) coins. Available again tomorrow."
        return true
    }
}

enum HotelWeather: String, Codable, CaseIterable {
    case sunny, rain, storm, wind, snow
    var title: String { switch self {
    case .sunny: return "SUNNY"; case .rain: return "RAIN"; case .storm: return "THUNDERSTORM"
    case .wind: return "WIND"; case .snow: return "SNOW"
    } }
}
struct HotelVisual: Codable {
    let id: Int
    let kind: String
    let origin: Tile
    let target: Tile
    let map: String
}
struct HotelCar: Codable, Identifiable {
    let id: Int
    let slot: Int
    let color: UInt32
    var arrival = 0
    var washedDay = 0
    var washProgress = 0
    static func tile(_ slot: Int) -> Tile { Tile(x:18 + slot * 8,y:30) }
    static func approach(_ slot: Int) -> Tile { Tile(x:18 + slot * 8,y:32) }
}
extension Motel {
    var weather: HotelWeather {
        operationsState.weatherOverride ?? HotelWeather.allCases[((day-1) + operationsState.tick / 75) % HotelWeather.allCases.count]
    }
    var visualMap: String { visit.map { "room-\($0.roomID)" } ?? worldState.place.rawValue }
    mutating func playVisual(_ kind: String, target: Tile? = nil) {
        var state = operationsState
        state.visualSerial = (state.visualSerial ?? 0) + 1
        state.visual = HotelVisual(id:state.visualSerial!,kind:kind,origin:actorTile,target:target ?? actorTile,map:visualMap)
        operations = state
    }
    mutating func tickParking(_ state: inout MotelOperations) {
        let guests = rooms.compactMap(\.guest) + waiting
        let valid = Set(guests.map(\.id))
        var cars = state.cars ?? []
        cars.removeAll { !valid.contains($0.id) }
        for guest in guests where !cars.contains(where: { $0.id == guest.id }) {
            guard let slot = (0..<3).first(where: { slot in !cars.contains { $0.slot == slot } }) else { break }
            cars.append(HotelCar(id:guest.id,slot:slot,color:guest.color))
        }
        for i in cars.indices { cars[i].arrival = min(8,cars[i].arrival + 1) }
        state.cars = cars
    }
    var nearbyCar: HotelCar? {
        guard canSave, worldState.place == .grounds else { return nil }
        return operationsState.cars?.first { $0.arrival >= 8 && $0.washedDay != day && actorTile.distance(to:HotelCar.approach($0.slot)) <= 1 }
    }
    @discardableResult mutating func washNearbyCar() -> Bool {
        guard let car = nearbyCar else { return false }
        var state = operationsState
        guard let i = state.cars?.firstIndex(where: { $0.id == car.id }) else { return false }
        state.cars![i].washedDay = day; state.cars![i].washProgress = 0
        state.washIncome = (state.washIncome ?? 0) + 35
        cash += 35; operations = state
        playVisual("carwash",target:HotelCar.tile(car.slot))
        lastEvent = "Car scrubbed and rinsed. +35 coins."
        return true
    }
}
