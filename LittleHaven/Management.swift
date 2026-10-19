import Foundation

enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case cleaner, maintenance, security, valet, clerk
    var id: String { rawValue }
    var title: String { switch self { case .cleaner: return "Housekeeper"; case .maintenance: return "Groundskeeper"; case .security: return "Security guard"; case .valet: return "Car wash attendant"; case .clerk: return "Front-desk clerk" } }
    var name: String { switch self { case .cleaner: return "Luna"; case .maintenance: return "Mateo"; case .security: return "Riley"; case .valet: return "Diego"; case .clerk: return "Nora" } }
    var hireCost: Int { switch self { case .cleaner: return 100; case .maintenance: return 140; case .security: return 160; case .valet: return 120; case .clerk: return 130 } }
    var wage: Int { switch self { case .cleaner: return 15; case .maintenance: return 20; case .security: return 25; case .valet: return 18; case .clerk: return 22 } }
    var duty: String { switch self { case .cleaner: return "Walks to vacant dirty rooms and cleans them."; case .maintenance: return "Responds to fires and pool accidents."; case .security: return "Breaks up fights outside the office."; case .valet: return "Walks to parked guest cars, scrubs and rinses them. Each car earns 35 coins once per day."; case .clerk: return "Handles daytime arrivals, assigns suitable rooms and collects payments while you work outside." } }
    var home: Tile { self == .clerk ? Tile(x:6,y:10) : self == .valet ? Tile(x:15,y:32) : Tile(x:11,y:self == .cleaner ? 10 : self == .maintenance ? 11 : 12) }
    var color: UInt32 { switch self { case .cleaner: return 0xB4A1C5; case .maintenance: return 0xD8AC66; case .security: return 0x718DA9; case .valet: return 0x5DA6B0; case .clerk: return 0xD0B777 } }
    var breakTile: Tile { Tile(x:24 + (Self.allCases.firstIndex(of:self) ?? 0)*2,y:26) }
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
    var guest: MotelGuest?
    var otherGuest: MotelGuest?
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
    var reason:String?
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
    var simulation: HotelSimulation?

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
        if state.simulation != nil {state.simulation!.profiles[role.rawValue]=StaffProfile.make(role)}
        operations = state
        lastEvent = "\(role.name) joined as your \(role.title.lowercased()). First shift included; \(role.wage) coins each morning."
        return true
    }
    mutating func payStaffForDay() {
        var state = operationsState
        if state.incident != nil { failIncident(&state) }
        for i in state.workers.indices {
            let wage = scheduledWage(state.workers[i].role)
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
        let baseStars = max(1,min(5,4 + min(1,room.furniture) - penalty - theft))
        let stars = managementEnabled ? max(1,min(5,baseStars - room.health.faults.count - (room.health.cleanliness < 60 ? 2 : 0) + (room.health.upgrades.contains(.bed) ? 1 : 0))) : baseStars
        let text: String
        if theft > 0 { text = "My belongings disappeared. I cannot recommend this Airb&b." }
        else if penalty > 0 { text = "The trouble outside was not handled in time. It spoiled my stay." }
        else if managementEnabled && !room.health.faults.isEmpty {text="Maintenance and pest problems interrupted my stay."}
        else if managementEnabled && room.health.cleanliness<60 {text="The room needed cleaning. I would expect better hygiene."}
        else if stars == 5 { text = "Lovely upgraded room and a peaceful stay. I would come back!" }
        else { text = "A clean room and a friendly welcome. Good value for the night." }
        state.reviews.insert(GuestReview(id:id,guest:guest.name,day:day,room:room.number,stars:stars,text:text),at:0)
        state.reviews = Array(state.reviews.prefix(30))
        if var sim=state.simulation { sim.reputation=max(0,min(100,sim.reputation+stars-3)); state.simulation=sim }
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
            let guests = rooms.compactMap(\.guest)
            state.incident = MotelIncident(kind:kind,guest:guests.first,otherGuest:guests.dropFirst().first)
            lastEvent = kind.title + " Check the grounds or send a trained employee."
        }
        if var incident = state.incident {
            incident.elapsed += 1
            state.incident = incident
            if incident.elapsed >= incident.limit {
                failIncident(&state)
            }
        }
        var occupied = Set(waiting.filter { $0.id != reception.visitor?.guest.id }.map { waitingTile($0.id) } + worldState.travellers.map(\.player))
        if !isAtReception && visit == nil { occupied.insert(actorTile) }
        for index in state.workers.indices {
            var worker = state.workers[index]
            let offShift = !worker.active || (state.simulation != nil && isNight && !(state.simulation!.profiles[worker.role.rawValue]?.nightShift ?? false))
            if !offShift && state.simulation != nil && !workerCanWork(worker, tick:state.tick) { continue }
            let target: Tile
            let responding = !offShift && state.incident?.kind.responder == worker.role
            if let incident=state.incident,!responding {
                worker.roomID = nil; worker.progress = 0
                target = MotelGrounds.refuge(from:worker.tile,danger:incident.kind.tile)
            } else if offShift {
                worker.roomID = nil; worker.progress = 0
                target = worker.role.breakTile
            } else if responding, let incident = state.incident {
                worker.roomID = nil
                target = incident.kind.approach
            } else if worker.role == .valet, let car = state.cars?.first(where: { $0.arrival >= 8 && $0.washedDay != day }) {
                if worker.roomID != car.id { worker.progress = 0 }
                worker.roomID = car.id
                target = HotelCar.approach(car.slot)
            } else if worker.role == .cleaner, let room = rooms.first(where: { $0.dirty && $0.guest == nil }) {
                if worker.roomID != room.id { worker.progress = 0 }
                worker.roomID = room.id
                target = MotelGrounds.roomDoor(room.id)
            } else if worker.role == .clerk && (!waiting.isEmpty || reception.visitor != nil) {
                worker.roomID = nil; worker.progress = 0
                target = worker.role.home
            } else {
                worker.roomID = nil
                worker.progress = 0
                target = worker.role.breakTile
            }
            if worker.tile.distance(to:target) > (responding ? 1 : 0) {
                if let next = MotelGrounds.nextStep(from:worker.tile,to:target,avoiding:occupied) { worker.tile = next }
            } else if responding {
                state.incident!.staffProgress += 1
                if state.incident!.staffProgress >= (state.simulation == nil ? 8 : max(4,12-workerSkill(worker.role)/12)) {
                    state.incident = nil
                    state.incidentsResolved += 1
                    state.nextIncidentTick = state.tick + 30
                    lastEvent = "\(worker.role.name) handled the emergency. Your guests are safe."
                }
            } else if worker.role == .valet, let carID = worker.roomID,
                      let carIndex = state.cars?.firstIndex(where: { $0.id == carID }) {
                if state.simulation?.waterOut == true {continue}
                worker.progress += 1
                state.cars![carIndex].washProgress = worker.progress
                if worker.progress >= 10 {
                    if state.simulation != nil {guard state.simulation!.stock["detergent",default:0]>0 else{continue};state.simulation!.stock["detergent",default:0] -= 1}
                    state.cars![carIndex].washedDay = day
                    state.cars![carIndex].washProgress = 0
                    state.washIncome = (state.washIncome ?? 0) + 35
                    cash += 35
                    worker.progress = 0; worker.roomID = nil
                    lastEvent = "Diego washed a guest car. +35 coins."
                }
            } else if let roomID = worker.roomID, let roomIndex = rooms.firstIndex(where: { $0.id == roomID }) {
                worker.progress += 1
                if worker.progress >= (state.simulation == nil ? 15 : max(6,20-workerSkill(worker.role)/10)) {
                    if state.simulation != nil {
                        guard state.simulation!.stock[Supply.detergent.rawValue,default:0] >= 3,
                              state.simulation!.stock[Supply.towels.rawValue,default:0] >= 1 else { continue }
                        state.simulation!.stock[Supply.detergent.rawValue,default:0] -= 3
                        state.simulation!.stock[Supply.towels.rawValue,default:0] -= 1
                        var health=rooms[roomIndex].health; health.cleanliness=100; rooms[roomIndex].hospitality=health
                    }
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
        if operationsState.simulation != nil { tickSimulation() }
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
    case .laundry: return "?"
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
        logMoney(service.reward,category:"Service",note:service.title)
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
    static func tile(_ slot: Int) -> Tile { Tile(x:18 + (slot % 3) * 8,y:30 + (slot / 3) * 3) }
    static func approach(_ slot: Int) -> Tile { Tile(x:18 + (slot % 3) * 8,y:32 + (slot / 3) * 3) }
}
extension Motel {
    var weather: HotelWeather {
        if operationsState.simulation?.economy == .heatwave {return .sunny}
        return operationsState.weatherOverride ?? HotelWeather.allCases[((day-1) + operationsState.tick / 75) % HotelWeather.allCases.count]
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
            guard let slot = (0..<(state.simulation?.facilities.contains(.parking) == true ? 6 : 3)).first(where: { slot in !cars.contains { $0.slot == slot } }) else { break }
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
        if managementEnabled && (simulation.waterOut || simulation.stock["detergent",default:0]<1) {lastEvent="Need running water and detergent.";return false}
        var state = operationsState
        guard let i = state.cars?.firstIndex(where: { $0.id == car.id }) else { return false }
        if state.simulation != nil {state.simulation!.stock["detergent",default:0] -= 1}
        state.cars![i].washedDay = day; state.cars![i].washProgress = 0
        state.washIncome = (state.washIncome ?? 0) + 35
        cash += 35; operations = state
        playVisual("carwash",target:HotelCar.tile(car.slot))
        lastEvent = "Car scrubbed and rinsed. +35 coins."
        return true
    }
}


// Management simulation. Optional outer state migrates pre-9.0 checkpoints.
enum RoomKind:String,Codable,CaseIterable,Identifiable {
    case basic,deluxe,suite,hourly
    var id:String { rawValue }
    var title:String { self == .hourly ? "By the hour" : rawValue.capitalized }
    var cost:Int { switch self { case .basic:return 0; case .deluxe:return 180; case .suite:return 350; case .hourly:return 90 } }
    var premium:Int { switch self { case .basic:return 0; case .deluxe:return 45; case .suite:return 100; case .hourly:return 0 } }
}
enum RoomFault:String,Codable,CaseIterable,Identifiable {
    case ac,mattress,pipe,light,bedbugs,roaches
    var id:String { rawValue }
    var title:String { switch self {
    case .ac:return "Broken AC"; case .mattress:return "Stained mattress"; case .pipe:return "Leaking pipe"
    case .light:return "Burnt-out light"; case .bedbugs:return "Bedbugs"; case .roaches:return "Cockroaches"
    } }
}
enum RoomUpgrade:String,Codable,CaseIterable,Identifiable {
    case bed,soundproof,fridge,locks,camera
    var id:String { rawValue }
    var title:String { switch self { case .bed:return "Better bed"; case .soundproof:return "Soundproofing"; case .fridge:return "Mini-fridge"; case .locks:return "Strong locks"; case .camera:return "Door camera" } }
    var cost:Int { switch self { case .bed:return 90; case .soundproof:return 120; case .fridge:return 100; case .locks:return 80; case .camera:return 140 } }
    var benefit:String { switch self { case .bed:return "+15 nightly, comfort complaints reduced"; case .soundproof:return "Blocks party noise complaints"; case .fridge:return "Consumes snacks for 10/night extra income"; case .locks:return "Reduces room damage and theft risk"; case .camera:return "Corridor monitoring; reduces security risk" } }
}
struct GuestRoomState:Codable {
    var kind:RoomKind = .basic
    var cleanliness=100
    var condition=100
    var faults:Set<RoomFault>=[]
    var upgrades:Set<RoomUpgrade>=[]
}
enum GuestKind:String,Codable,CaseIterable {
    case traveler,party,suspicious,resident,adultVisitor,dealer,cultist,celebrity
    var title:String { switch self {
    case .traveler:return "Traveler"; case .party:return "Party group"; case .suspicious:return "Private cash guest"
    case .resident:return "Long-term resident"; case .adultVisitor:return "Adult sex worker"; case .dealer:return "Suspicious dealmaker"
    case .cultist:return "Cult visitor"; case .celebrity:return "Celebrity in hiding"
    } }
    var preference:String { switch self {
    case .traveler:return "Clean room, reliable Wi-Fi and a fair price."
    case .party:return "Late arrival, snacks and room to celebrate. Soundproofing protects neighbors."
    case .suspicious:return "Privacy and strong locks. Identity must still be verified."
    case .resident:return "Discounted weekly stays, laundry and reliable AC."
    case .adultVisitor:return "Adults-only, discreet lawful hourly stay with hygiene supplies."
    case .dealer:return "May offer an off-books arrangement; security can remove them."
    case .cultist:return "Wants a quiet gathering; ignoring noise can upset other guests."
    case .celebrity:return "High budget, strong security and strict privacy."
    } }
    var budget:Int { switch self { case .resident:return 120; case .traveler:return 180; case .party:return 230; case .celebrity:return 450; default:return 220 } }
}
enum RentalPlan:String,Codable,CaseIterable,Identifiable {
    case nightly,hourly,weekly
    var id:String { rawValue }
}
enum PricePolicy:String,Codable,CaseIterable,Identifiable {
    case budget,standard,surge,premium
    var id:String { rawValue }
    var percent:Int { switch self { case .budget:return 80; case .standard:return 100; case .surge:return 135; case .premium:return 165 } }
}
enum Supply:String,Codable,CaseIterable,Identifiable {
    case toiletries,towels,detergent,snacks,condoms,parts,pesticide
    var id:String { rawValue }
    var title:String { self == .parts ? "Repair parts" : rawValue.capitalized }
    var price:Int { switch self { case .toiletries:return 2; case .towels:return 3; case .detergent:return 2; case .snacks:return 3; case .condoms:return 2; case .parts:return 6; case .pesticide:return 8 } }
}
enum Facility:String,Codable,CaseIterable,Identifiable {
    case adjacentLot,upperFloor,pool,restaurant,parking,wifi,cameras,nightVision
    var id:String { rawValue }
    var title:String { switch self {
    case .adjacentLot:return "Buy adjacent lot"; case .upperFloor:return "Add an upper floor"; case .pool:return "Open staffed pool"
    case .restaurant:return "Patio restaurant"; case .parking:return "Expand to six parking bays"; case .wifi:return "Fiber Wi-Fi"
    case .cameras:return "Security camera network"; case .nightVision:return "Night-vision equipment"
    } }
    var cost:Int { switch self { case .adjacentLot:return 450; case .upperFloor:return 900; case .pool:return 300; case .restaurant:return 500; case .parking:return 250; case .wifi:return 180; case .cameras:return 250; case .nightVision:return 150 } }
    var requiredRep:Int { self == .upperFloor ? 60 : self == .restaurant ? 50 : self == .adjacentLot ? 45 : 0 }
}
enum LocalEconomy:String,Codable,CaseIterable {
    case normal,festival,touristSeason,factoryClosure,heatwave
    var headline:String { switch self {
    case .normal:return "Steady traffic on the highway."
    case .festival:return "LOCAL FESTIVAL: demand and late-night noise are rising."
    case .touristSeason:return "TOURIST SEASON: deluxe rooms and suites are in demand."
    case .factoryClosure:return "FACTORY CLOSES: displaced workers need affordable weekly stays."
    case .heatwave:return "HEATWAVE: AC failures and temperature complaints are more likely."
    } }
}
enum HotelIssueKind:String,Codable,CaseIterable {
    case noise,vandalism,bedbugs,roaches,outage,leak,ac,wifi,privacy,temperature,adultVisitor,drugDeal,cult,celebrity
    var title:String { switch self {
    case .noise:return "Noise complaint"; case .vandalism:return "Room vandalism"; case .bedbugs:return "Bedbug report"
    case .roaches:return "Cockroaches spotted"; case .outage:return "Power outage"; case .leak:return "Water leak"
    case .ac:return "AC failure"; case .wifi:return "Wi-Fi complaint"; case .privacy:return "Privacy complaint"
    case .temperature:return "Room too hot"; case .adultVisitor:return "Unexpected adult visitor"; case .drugDeal:return "Suspicious deal"
    case .cult:return "Cult gathering request"; case .celebrity:return "Celebrity needs protection"
    } }
    var detail:String { switch self {
    case .adultVisitor:return "An adult visitor requests a discreet hourly stay. Verify identity and use the normal legal booking process, or decline."
    case .drugDeal:return "A guest offers money to ignore a suspicious exchange. Security can intervene; taking cash increases police attention."
    case .cult:return "A group asks to meet after dark. An approved quiet gathering earns money; ignored noise hurts reviews."
    case .celebrity:return "A familiar face asks for privacy. Protect them or exploit the visit for cash."
    case .outage:return "Lights and Wi-Fi are down. Use parts to restore power."
    default:return "Respond before the deadline to protect room condition, reviews and reputation."
    } }
    var cost:Int { switch self { case .noise:return 10; case .privacy,.celebrity:return 15; case .wifi:return 20; case .adultVisitor,.cult,.drugDeal:return 0; default:return 12 } }
}
struct HotelIssue:Codable,Identifiable {
    let id:Int
    let kind:HotelIssueKind
    let roomID:Int
    let guestName:String
    let deadline:Int
}
struct HotelContract:Codable {
    let guestID:Int
    let plan:RentalPlan
    let paid:Int
    let checkoutHour:Int
}
struct HotelReservation:Codable,Identifiable {
    let id:Int
    let guest:MotelGuest
    let arrivalHour:Int
    var deposit=10
    var processed=false
    var noShow=false
}
struct StaffProfile:Codable {
    var speed:Int
    var honesty:Int
    var skill:Int
    var loyalty=70
    var fatigue=0
    var unpaid=0
    var nightShift=false
    static func make(_ role:StaffRole)->StaffProfile {
        switch role {
        case .cleaner:return StaffProfile(speed:75,honesty:85,skill:65)
        case .maintenance:return StaffProfile(speed:60,honesty:80,skill:90)
        case .security:return StaffProfile(speed:65,honesty:60,skill:80)
        case .valet:return StaffProfile(speed:80,honesty:75,skill:65)
        case .clerk:return StaffProfile(speed:70,honesty:70,skill:75)
        }
    }
}
struct LedgerLine:Codable,Identifiable {
    let id:Int
    let day:Int
    let hour:Int
    let amount:Int
    let category:String
    let note:String
}
struct HotelSimulation:Codable {
    var hour=8
    var clockTicks=0
    var absoluteHour=8
    var reputation=40
    var prices:PricePolicy = .standard
    var plan:RentalPlan = .nightly
    var stock:[String:Int]=["toiletries":12,"towels":12,"detergent":24,"snacks":8,"condoms":6,"parts":8,"pesticide":4]
    var contracts:[Int:HotelContract]=[:]
    var reservations:[HotelReservation]=[]
    var profiles:[String:StaffProfile]=[:]
    var issues:[HotelIssue]=[]
    var ledger:[LedgerLine]=[]
    var serial=0
    var billDebt=0
    var loanDebt=0
    var facilities:Set<Facility>=[]
    var floor=0
    var economy:LocalEconomy = .normal
    var relationships:[String:Int]=[:]
    var visits:[String:Int]=[:]
    var checkedIDs:Set<Int>=[]
    var ethical=0
    var greedy=0
    var criminal=0
    var cultFriendly=0
    var heat=0
    var shadyOffers=false
    var nightVision=false
    var powerOut=false
    var waterOut=false
    var endings:[String]=[]
    var news="A new chapter: your first rent and utility bill arrives tomorrow."
    var accountedWashIncome=0
    var noShows=0
    var complaintsHandled=0
}
extension Motel {
    var simulation:HotelSimulation {
        get { operationsState.simulation ?? HotelSimulation() }
        set { var state=operationsState; state.simulation=newValue; operations=state }
    }
    var managementEnabled:Bool { operationsState.simulation != nil }
    var isNight:Bool { managementEnabled && (simulation.hour >= 20 || simulation.hour < 7) }
    var clockLabel:String { managementEnabled ? String(format:"%02d:00 %@",simulation.hour,isNight ? "NIGHT" : "DAY") : "" }
    var viewingFloor:Int { managementEnabled ? simulation.floor : 0 }
    var expansionCapacity:Int { !managementEnabled ? 9 : simulation.facilities.contains(.upperFloor) ? 18 : simulation.facilities.contains(.adjacentLot) ? 9 : 6 }
    mutating func enableManagement() {
        guard !managementEnabled else { return }
        var s=HotelSimulation()
        s.accountedWashIncome=operationsState.washIncome ?? 0
        for worker in operationsState.workers { s.profiles[worker.role.rawValue]=StaffProfile.make(worker.role) }
        for i in rooms.indices { if rooms[i].hospitality == nil { rooms[i].hospitality=GuestRoomState() } }
        simulation=s
        createReservations()
        lastEvent="Management board ready. Keep rooms clean, restock supplies and prepare for the night shift."
    }
    func managementRate(_ room:MotelRoom,base:Int)->Int {
        let s=simulation
        let upgrades=room.health.upgrades
        var value=base+room.health.kind.premium+(upgrades.contains(.bed) ? 15 : 0)
        if s.facilities.contains(.pool) { value += 8 }
        if s.facilities.contains(.restaurant) { value += 12 }
        value=value*s.prices.percent/100
        if s.economy == .festival || s.economy == .touristSeason { value=value*120/100 }
        if s.reputation >= 70 { value=value*110/100 }
        return max(20,value)
    }
    func bookingPlan(_ guest:MotelGuest,room:MotelRoom)->RentalPlan {
        if !managementEnabled { return .nightly }
        if room.health.kind == .hourly || guest.kind == .adultVisitor { return .hourly }
        if guest.kind == .resident { return .weekly }
        return simulation.plan
    }
    func bookingQuote(_ guest:MotelGuest,room:MotelRoom)->Int {
        let price=rate(for:room)
        switch bookingPlan(guest,room:room) {
        case .nightly:return price*guest.nights
        case .hourly:return max(20,price/4)*2
        case .weekly:return price*7*80/100
        }
    }
    func mayCheckIn(_ guest:MotelGuest,room:MotelRoom)->Bool {
        guard managementEnabled else { return true }
        if isNight && guest.kind != .adultVisitor && !simulation.shadyOffers { return false }
        if simulation.powerOut || simulation.waterOut { return false }
        if (guest.kind == .suspicious || guest.kind == .adultVisitor || guest.kind == .dealer) && !simulation.checkedIDs.contains(guest.id) && !simulation.shadyOffers { return false }
        if simulation.stock[Supply.toiletries.rawValue,default:0] < 1 || simulation.stock[Supply.towels.rawValue,default:0] < 1 { return false }
        return rate(for:room) <= guestBudget(guest)
    }
    func checkInExplanation(_ guest:MotelGuest,room:MotelRoom)->String {
        if !managementEnabled { return "" }
        if simulation.powerOut || simulation.waterOut { return "Restore power/water before assigning a room." }
        if isNight && guest.kind != .adultVisitor && !simulation.shadyOffers { return "Normal check-in is closed for the night. Reopen at 07:00." }
        if [.suspicious,.adultVisitor,.dealer].contains(guest.kind) && !simulation.checkedIDs.contains(guest.id) { return simulation.shadyOffers ? "Unverified off-books rental: raises police attention." : "Verify this guest's ID first." }
        if simulation.stock["toiletries",default:0] < 1 || simulation.stock["towels",default:0] < 1 { return "Restock towels and toiletries first." }
        return rate(for:room) > guestBudget(guest) ? "This guest cannot afford the current rate. Lower your pricing policy." : "Ready for check-in."
    }
    mutating func verifyGuest(_ id:Int) { guard managementEnabled,waiting.contains(where:{$0.id==id}),!simulation.checkedIDs.contains(id) else{return}; var s=simulation;s.checkedIDs.insert(id);s.ethical += 1;simulation=s;lastEvent="Identity verified. Standard booking rules apply." }
    mutating func registerContract(_ guest:MotelGuest,room:MotelRoom,payment:Int) {
        guard managementEnabled else{return}
        var s=simulation
        let plan=bookingPlan(guest,room:room)
        s.contracts[guest.id]=HotelContract(guestID:guest.id,plan:plan,paid:payment,checkoutHour:plan == .hourly ? s.absoluteHour+2 : -1)
        s.stock["toiletries",default:0] -= 1;s.stock["towels",default:0] -= 1
        if plan == .hourly { if s.stock["condoms",default:0] > 0 {s.stock["condoms",default:0] -= 1} else {s.reputation=max(0,s.reputation-1)} }
        s.visits[guest.name,default:0] += 1
        s.greedy += s.prices == .premium ? 1 : 0
        if s.shadyOffers && (isNight || [.suspicious,.adultVisitor,.dealer].contains(guest.kind) && !s.checkedIDs.contains(guest.id)) {s.criminal += 2;s.heat += 12}
        s.serial += 1;s.ledger.insert(LedgerLine(id:s.serial,day:day,hour:s.hour,amount:payment,category:"Booking",note:"\(guest.name), room \(room.number), \(plan.rawValue)"),at:0)
        simulation=s
    }
    mutating func setPrices(_ policy:PricePolicy,plan:RentalPlan) { guard managementEnabled else{return};var s=simulation;s.prices=policy;s.plan=plan;simulation=s;lastEvent="Rates changed. Guests compare prices against their budgets." }
    mutating func logMoney(_ amount:Int,category:String,note:String) {
        guard managementEnabled else{return};var s=simulation;s.serial += 1
        s.ledger.insert(LedgerLine(id:s.serial,day:day,hour:s.hour,amount:amount,category:category,note:note),at:0)
        s.ledger=Array(s.ledger.prefix(100));simulation=s
    }
    @discardableResult mutating func buyStock(_ item:Supply,count:Int=5)->Bool {
        guard managementEnabled,count>0,count<=100,cash>=item.price*count else{return false}
        cash -= item.price*count;var s=simulation;s.stock[item.rawValue,default:0] += count;simulation=s
        logMoney(-item.price*count,category:"Supplies",note:"\(count) \(item.title)");lastEvent="Supplies delivered: \(item.title) +\(count).";return true
    }
    @discardableResult mutating func useCleaningStock(full:Bool)->Bool {
        guard managementEnabled else{return true};var s=simulation
        let amount=full ? 3 : 1
        guard s.stock["detergent",default:0]>=amount, !full || s.stock["towels",default:0]>=1 else {lastEvent="Out of cleaning supplies. Restock on the management board.";return false}
        s.stock["detergent",default:0] -= amount
        if full {s.stock["towels",default:0] -= 1};simulation=s;return true
    }
    @discardableResult mutating func changeRoomKind(_ id:Int,kind:RoomKind)->Bool {
        guard managementEnabled,let i=rooms.firstIndex(where:{$0.id==id}),rooms[i].guest==nil,rooms[i].health.kind != kind,cash>=kind.cost,
              kind != .suite || simulation.reputation>=60 else{return false}
        cash -= kind.cost;var h=rooms[i].health;h.kind=kind;rooms[i].hospitality=h
        logMoney(-kind.cost,category:"Renovation",note:"Room \(rooms[i].number): \(kind.title)");playVisual("build");return true
    }
    @discardableResult mutating func buyRoomUpgrade(_ id:Int,upgrade:RoomUpgrade)->Bool {
        guard managementEnabled,let i=rooms.firstIndex(where:{$0.id==id}),rooms[i].guest==nil,!rooms[i].health.upgrades.contains(upgrade),cash>=upgrade.cost else{return false}
        cash -= upgrade.cost;var h=rooms[i].health;h.upgrades.insert(upgrade);rooms[i].hospitality=h
        logMoney(-upgrade.cost,category:"Upgrade",note:"Room \(rooms[i].number): \(upgrade.title)");playVisual("build");return true
    }
    @discardableResult mutating func managerClean(_ id:Int)->Bool {
        guard managementEnabled,let i=rooms.firstIndex(where:{$0.id==id}),useCleaningStock(full:true) else{return false}
        var h=rooms[i].health;h.cleanliness=100;h.faults.remove(.mattress);rooms[i].hospitality=h
        rooms[i].dirty=false;rooms[i].cleanedTasks=Set(MotelGrounds.cleaningTiles.indices)
        playVisual("mop");lastEvent="Room \(rooms[i].number) cleaned and linen refreshed.";return true
    }
    @discardableResult mutating func repairRoom(_ id:Int)->Bool {
        guard managementEnabled,let i=rooms.firstIndex(where:{$0.id==id}) else{return false}
        var s=simulation;var h=rooms[i].health
        let pests=h.faults.contains(.bedbugs)||h.faults.contains(.roaches)
        let item=pests ? Supply.pesticide : .parts
        guard s.stock[item.rawValue,default:0]>=2,cash>=15 else{lastEvent="Need 2 \(item.title) and 15 coins.";return false}
        s.stock[item.rawValue,default:0] -= 2;simulation=s;cash -= 15;h.condition=100;h.faults=[];rooms[i].hospitality=h
        logMoney(-15,category:"Repair",note:"Room \(rooms[i].number)");playVisual("repair");lastEvent="Room repaired, inspected and pest-treated.";return true
    }
    @discardableResult mutating func installFacility(_ facility:Facility)->Bool {
        guard managementEnabled,!simulation.facilities.contains(facility),cash>=facility.cost,simulation.reputation>=facility.requiredRep,
              facility != .upperFloor || simulation.facilities.contains(.adjacentLot),
              facility != .nightVision || simulation.facilities.contains(.cameras) else{return false}
        cash -= facility.cost;var s=simulation;s.facilities.insert(facility);simulation=s
        logMoney(-facility.cost,category:"Expansion",note:facility.title);playVisual("build");lastEvent=facility.title+" completed.";return true
    }
    @discardableResult mutating func setViewingFloor(_ floor:Int)->Bool {
        guard managementEnabled,visit==nil,worldState.place == .grounds,(floor==0 || floor==1 && simulation.facilities.contains(.upperFloor)) else{return false}
        var s=simulation;s.floor=floor;simulation=s;lastEvent="Viewing floor \(floor+1). Room doors lead to this floor.";return true
    }
    func scheduledWage(_ role:StaffRole)->Int {
        guard managementEnabled else{return role.wage}
        return (simulation.profiles[role.rawValue]?.nightShift ?? false) ? role.wage*3/2 : role.wage
    }
    func workerCanWork(_ worker:MotelWorker,tick:Int)->Bool {
        let profile=simulation.profiles[worker.role.rawValue] ?? StaffProfile.make(worker.role)
        if profile.loyalty<=0 {return false}
        if isNight && !profile.nightShift {return false}
        if profile.fatigue>=75 && tick%3==0 {return false}
        return tick % max(1,4-profile.speed/30)==0
    }
    mutating func scheduleNight(_ role:StaffRole) { guard managementEnabled else{return};var s=simulation;var p=s.profiles[role.rawValue] ?? StaffProfile.make(role);p.nightShift.toggle();s.profiles[role.rawValue]=p;simulation=s;lastEvent="Shift schedule updated. Night shifts cost 50% more." }
    @discardableResult mutating func trainStaff(_ role:StaffRole)->Bool {
        guard managementEnabled,cash>=25,operationsState.workers.contains(where:{$0.role==role}) else{return false}
        cash -= 25;var s=simulation;var p=s.profiles[role.rawValue] ?? StaffProfile.make(role)
        p.speed=min(95,p.speed+5);p.skill=min(95,p.skill+5);p.honesty=min(95,p.honesty+5);p.loyalty=min(100,p.loyalty+8);p.fatigue=max(0,p.fatigue-20)
        s.profiles[role.rawValue]=p;simulation=s;logMoney(-25,category:"Training",note:role.name);return true
    }
    mutating func dismissStaff(_ role:StaffRole) { guard managementEnabled else{return};var state=operationsState;state.workers.removeAll{$0.role==role};state.simulation?.profiles.removeValue(forKey:role.rawValue);operations=state;lastEvent=role.name+" left the team." }
    mutating func createReservations() {
        guard managementEnabled else{return};var s=simulation
        let samples=Motel.arrivals(day:day+5,count:2)
        let guests=samples.enumerated().map { i,g in MotelGuest(id:100000+day*10+i,name:g.name,nights:g.nights,color:g.color,story:"Reserved arrival.",category:.traveler) }
        for (i,guest) in guests.enumerated() {s.serial += 1;s.reservations.append(HotelReservation(id:s.serial,guest:guest,arrivalHour:(day-1)*24+12+i*4,noShow:(day+i)%3==0))}
        simulation=s
    }
    @discardableResult mutating func checkoutGuest(_ roomID:Int)->Bool {
        guard let i=rooms.firstIndex(where:{$0.id==roomID}),let guest=rooms[i].guest else{return false}
        recordCheckoutReview(rooms[i])
        if managementEnabled {
            var s=simulation
            let quality=rooms[i].health.cleanliness-rooms[i].health.faults.count*15
            s.reputation=max(0,min(100,s.reputation+(quality>=65 ? 2 : -4)))
            s.relationships[guest.name,default:0] += quality>=65 ? 1 : -1
            s.contracts.removeValue(forKey:guest.id);simulation=s
        }
        rooms[i].guest=nil;rooms[i].nightsLeft=0;rooms[i].dirty=true;rooms[i].cleanedTasks=[]
        var h=rooms[i].health;h.cleanliness=max(0,h.cleanliness-25);rooms[i].hospitality=h
        lastEvent="Room \(rooms[i].number) checked out. Inspect and clean before reassigning.";return true
    }
    mutating func tickSimulation() {
        guard managementEnabled,!caught else{return};var s=simulation;s.clockTicks += 1
        let washIncome=operationsState.washIncome ?? 0
        if washIncome>s.accountedWashIncome {s.serial += 1;s.ledger.insert(LedgerLine(id:s.serial,day:day,hour:s.hour,amount:washIncome-s.accountedWashIncome,category:"Car wash",note:"Guest vehicle service"),at:0);s.accountedWashIncome=washIncome}
        let advance=s.clockTicks>=20
        if advance {s.clockTicks=0}
        simulation=s
        if advance {advanceHotelHour()}
        if operationsState.tick%6==0,let worker=operationsState.workers.first(where:{$0.role == .clerk && $0.active}),workerCanWork(worker,tick:operationsState.tick),!isNight,let guest=waiting.first {
            verifyGuest(guest.id)
            if let room=rooms.first(where:{$0.available && mayCheckIn(guest,room:$0)}) {_=managerAssignGuest(guest.id,roomID:room.id)}
        }
        if operationsState.tick%10==0,let worker=operationsState.workers.first(where:{$0.role == .clerk && $0.active}),workerCanWork(worker,tick:operationsState.tick),
           let issue=simulation.issues.first(where:{[HotelIssueKind.privacy,.wifi,.celebrity,.adultVisitor].contains($0.kind)}) {_=respondToIssue(issue.id,choice:0)}
        if operationsState.tick%12==0,operationsState.workers.contains(where:{$0.active && $0.role == .maintenance && workerCanWork($0,tick:operationsState.tick)}),
           let room=rooms.first(where:{!$0.health.faults.isEmpty}) { _=repairRoom(room.id) }
        if operationsState.tick%15==0,let issue=simulation.issues.first,
           operationsState.workers.contains(where:{$0.active && $0.role == (issue.kind == .noise || issue.kind == .drugDeal ? .security : .maintenance) && workerCanWork($0,tick:operationsState.tick)}) { _=respondToIssue(issue.id,choice:0) }
        if isNight,operationsState.incident==nil {var state=operationsState;state.nextIncidentTick=min(state.nextIncidentTick,state.tick+25);operations=state}
    }
    mutating func advanceHotelHour() {
        guard managementEnabled,!caught else{return}
        if simulation.hour==23 {
            if business.police != nil {lastEvent="Resolve the police case before starting the next business day.";return}
            _=nextDay();return
        }
        var s=simulation;s.hour += 1;s.absoluteHour=(day-1)*24+s.hour
        for i in rooms.indices {
            var h=rooms[i].health
            h.cleanliness=max(0,h.cleanliness-(rooms[i].guest==nil ? 1 : 3))
            if rooms[i].guest != nil {h.condition=max(0,h.condition-1)}
            if h.cleanliness<60 {rooms[i].dirty=true}
            if rooms[i].guest?.kind == .party && !h.upgrades.contains(.soundproof) && s.hour%3==0 {s.reputation=max(0,s.reputation-1)}
            if h.condition<75 && h.faults.isEmpty {
                h.faults.insert(RoomFault.allCases[(day+i+s.hour)%4])
            }
            rooms[i].hospitality=h
        }
        let due=s.contracts.values.filter{$0.plan == .hourly && $0.checkoutHour<=s.absoluteHour}.map(\.guestID)
        let expired=s.issues.filter{$0.deadline<=s.absoluteHour}
        for issue in expired {
            s.reputation=max(0,s.reputation-4);s.relationships[issue.guestName,default:0] -= 1
            if let guestID=rooms.first(where:{$0.id==issue.roomID})?.guest?.id {var state=operationsState;state.guestPenalties[guestID,default:0] += 1;operations=state}
            if issue.kind == .noise || issue.kind == .drugDeal {s.heat += 8}
            s.billDebt += issue.kind == .vandalism ? 40 : 10
        }
        s.issues.removeAll{$0.deadline<=s.absoluteHour}
        for i in s.reservations.indices where !s.reservations[i].processed && s.reservations[i].arrivalHour<=s.absoluteHour {
            s.reservations[i].processed=true
            if s.reservations[i].noShow {s.noShows += 1;cash += s.reservations[i].deposit}
            else {waiting.append(s.reservations[i].guest)}
        }
        // Keep standard arrivals in daytime; special visitors use explicit event choices.
        if s.hour==20 {waiting=[];world?.reception?.visitor=nil;s.news="NIGHT SHIFT: normal check-in closes; security and maintenance risks rise."}
        if s.hour%4==0 || s.hour>=20 && s.hour%2==0 {
            if let guestRoom=rooms.first(where:{$0.guest != nil}),s.issues.count<3 {
                var kinds:[HotelIssueKind]=[.noise,.vandalism,.bedbugs,.roaches,.outage,.leak,.ac,.wifi,.privacy,.temperature,.adultVisitor,.drugDeal,.cult,.celebrity]
                if s.economy == .heatwave {kinds=[.ac,.temperature,.ac,.leak]}
                if weather == .storm {kinds=[.outage,.leak,.wifi]}
                let kind=kinds[(day*3+s.hour/2)%kinds.count]
                if kind != .noise || !guestRoom.health.upgrades.contains(.soundproof) {
                    s.serial += 1;s.issues.append(HotelIssue(id:s.serial,kind:kind,roomID:guestRoom.id,guestName:guestRoom.guest!.name,deadline:s.absoluteHour+3+(guestRoom.health.upgrades.contains(.camera) || s.facilities.contains(.cameras) ? 2 : 0)))
                    if kind == .outage {s.powerOut=true}
                    if kind == .leak {s.waterOut=true}
                    if let i=rooms.firstIndex(where:{$0.id==guestRoom.id}) {
                        var h=rooms[i].health
                        if kind == .ac {h.faults.insert(.ac)}
                        if kind == .leak {h.faults.insert(.pipe)}
                        if kind == .bedbugs {h.faults.insert(.bedbugs)}
                        if kind == .roaches {h.faults.insert(.roaches)}
                        if kind == .vandalism && !h.upgrades.contains(.locks) {h.condition=max(0,h.condition-25);h.faults.insert(.light)}
                        rooms[i].hospitality=h
                    }
                    s.news=kind.title+" - room \(guestRoom.number)"
                }
            }
        }
        simulation=s
        for id in due {if let room=rooms.first(where:{$0.guest?.id==id}) {_=checkoutGuest(room.id)}}
        if simulation.heat>=35 && business.police==nil {
            var state=operationsState;var consequences=state.consequences ?? BusinessConsequences()
            consequences.police=PoliceCase(number:day+simulation.heat,guest:"Night operations",cause:.fight,fine:150+simulation.heat*2,reason:"Repeated noise and suspicious off-books activity brought a business citation. No guest death was reported.")
            state.consequences=consequences;operations=state
            var current=simulation;current.heat=10;simulation=current
            lastEvent="Noise and suspicious activity drew police attention. An officer is coming."
        }
    }
    @discardableResult mutating func respondToIssue(_ id:Int,choice:Int)->Bool {
        guard managementEnabled,let issue=simulation.issues.first(where:{$0.id==id}) else{return false}
        var s=simulation
        if choice==1 {
            guard s.shadyOffers else{return false}
            let income=issue.kind == .drugDeal ? 90 : issue.kind == .celebrity ? 80 : 60
            cash += income;s.heat += issue.kind == .cult ? 4 : 15;s.reputation=max(0,s.reputation-3)
            if issue.kind == .cult {s.cultFriendly += 3}else{s.criminal += 2};s.greedy += 1
            s.issues.removeAll{$0.id==id};simulation=s;logMoney(income,category:"Off-books",note:issue.kind.title)
            playVisual("luggage");lastEvent="Off-books money collected. Reputation and police attention were affected.";return true
        }
        if choice==2 {
            s.issues.removeAll{$0.id==id};s.ethical += 1;s.relationships[issue.guestName,default:0] -= 1;simulation=s
            lastEvent="The request was declined. The visitor leaves.";return true
        }
        guard cash>=issue.kind.cost else{return false}
        let repairKinds:[HotelIssueKind]=[.outage,.leak,.ac,.temperature,.vandalism]
        let pestKinds:[HotelIssueKind]=[.bedbugs,.roaches]
        if repairKinds.contains(issue.kind) {guard s.stock["parts",default:0]>=1 else{return false};s.stock["parts",default:0] -= 1}
        if pestKinds.contains(issue.kind) {guard s.stock["pesticide",default:0]>=2 else{return false};s.stock["pesticide",default:0] -= 2}
        if issue.kind == .adultVisitor {
            s.checkedIDs.insert(issue.roomID+10000);s.ethical += 1
            // A verified visitor pays a legal, recorded service charge.
            cash += 30
        }
        cash -= issue.kind.cost;s.issues.removeAll{$0.id==id};s.ethical += 1
        s.reputation=min(100,s.reputation+(issue.kind == .celebrity ? 6 : 2))
        s.relationships[issue.guestName,default:0] += 1;s.complaintsHandled += 1
        if issue.kind == .cult {s.cultFriendly += 2;cash += 40}
        if issue.kind == .outage {s.powerOut=false};if issue.kind == .leak {s.waterOut=false}
        simulation=s
        if let i=rooms.firstIndex(where:{$0.id==issue.roomID}) {
            var h=rooms[i].health
            if repairKinds.contains(issue.kind) {h.condition=min(100,h.condition+25);h.faults.remove(.ac);h.faults.remove(.pipe);h.faults.remove(.light)}
            if pestKinds.contains(issue.kind) {h.faults.remove(.bedbugs);h.faults.remove(.roaches);h.cleanliness=max(70,h.cleanliness)}
            rooms[i].hospitality=h
        }
        logMoney(-issue.kind.cost,category:"Guest service",note:issue.kind.title)
        playVisual(repairKinds.contains(issue.kind) ? "repair" : pestKinds.contains(issue.kind) ? "mop" : "calm")
        lastEvent="Handled: "+issue.kind.title+". Guest trust improved.";return true
    }
    mutating func finishSimulationDay() {
        guard managementEnabled else{return}
        var s=simulation;s.hour=8;s.absoluteHour=(day-1)*24+8;s.clockTicks=0
        s.economy=LocalEconomy.allCases[(day/3)%LocalEconomy.allCases.count]
        s.news=s.economy.headline
        let rent=30+rooms.count*4
        let utilities=8+rooms.count*3+(s.facilities.contains(.pool) ? 8 : 0)+(s.facilities.contains(.restaurant) ? 10 : 0)
        let due=rent+utilities+s.billDebt
        let payment=min(cash,due);cash -= payment;s.billDebt=due-payment
        if s.billDebt>0 {s.billDebt += max(1,s.billDebt/30)}
        s.serial += 1;s.ledger.insert(LedgerLine(id:s.serial,day:day,hour:8,amount:-payment,category:"Rent & utilities",note:"Rent \(rent), utilities \(utilities), unpaid \(s.billDebt)"),at:0)
        for worker in operationsState.workers {
            var profile=s.profiles[worker.role.rawValue] ?? StaffProfile.make(worker.role)
            if worker.active {profile.unpaid=0;profile.loyalty=min(100,profile.loyalty+2)}
            else {profile.unpaid += 1;profile.loyalty -= 20}
            profile.fatigue=max(0,profile.fatigue+(profile.nightShift ? 20 : -15))
            if profile.nightShift && (day+profile.skill)%7==0 {s.billDebt += 20;profile.loyalty -= 8;s.news=worker.role.name+" had a dangerous night shift. First-aid costs: 20 coins."}
            if profile.honesty<75 && (day+profile.honesty)%5==0 {
                let stolen=min(cash,12);cash -= stolen;s.news=worker.role.name+" was caught pocketing cash. Train or dismiss them.";s.reputation=max(0,s.reputation-1)
            }
            if day%4==0 && profile.fatigue>50 {profile.loyalty -= 10;profile.fatigue=min(100,profile.fatigue+15);s.news=worker.role.name+" caused staff drama. Morale fell and the next shift is slower."}
            if profile.fatigue>=80 {s.news=worker.role.name+" is exhausted and slowing down. Rest or train the team."}
            s.profiles[worker.role.rawValue]=profile
        }
        let quit=operationsState.workers.filter{(s.profiles[$0.role.rawValue]?.unpaid ?? 0)>=2 || (s.profiles[$0.role.rawValue]?.loyalty ?? 70)<=10}.map(\.role)
        if !quit.isEmpty {var state=operationsState;state.workers.removeAll{quit.contains($0.role)};operations=state;s.news="Staff quit after unpaid or unhappy shifts. Hire replacements."}
        for i in rooms.indices {
            var h=rooms[i].health
            if rooms[i].dirty {h.cleanliness=min(40,h.cleanliness)}
            h.condition=max(0,h.condition-3);rooms[i].hospitality=h
            if let guest=rooms[i].guest {
                if h.upgrades.contains(.fridge),s.stock["snacks",default:0]>0 {s.stock["snacks",default:0] -= 1;cash += 10}
                if h.faults.isEmpty && h.cleanliness>=70 {s.reputation=min(100,s.reputation+1);s.relationships[guest.name,default:0] += 1}
                else{s.reputation=max(0,s.reputation-2)}
            }
        }
        var arrivals=max(1,min(10,rooms.count+1+(s.reputation-40)/15-bookingPenalty))
        if s.economy == .festival || s.economy == .touristSeason {arrivals=min(12,arrivals+2)}
        if s.prices == .premium && s.reputation<60 {arrivals=max(1,arrivals-2)}
        waiting=Motel.arrivals(day:day,count:arrivals)
        for i in waiting.indices {
            if s.economy == .factoryClosure {waiting[i].category = .resident}
            else if s.economy == .festival && i%2==1 {waiting[i].category = .party}
            else if waiting[i].kind == .celebrity && s.reputation<60 {waiting[i].category = .traveler}
        }
        if s.facilities.contains(.restaurant) && s.stock["snacks",default:0]>=2 {s.stock["snacks",default:0] -= 2;cash += 35}
        if s.facilities.contains(.pool) {cash += occupancy*5}
        s.reservations.removeAll{$0.processed}
        simulation=s;createReservations()
        if day>=14 || rooms.count>=18 {claimStoryEnding()}
    }
    @discardableResult mutating func repayBills()->Bool {
        guard managementEnabled,cash>0,simulation.billDebt+simulation.loanDebt>0 else{return false}
        var s=simulation;let paid=min(cash,s.billDebt+s.loanDebt);cash -= paid
        let bills=min(paid,s.billDebt);s.billDebt -= bills;s.loanDebt -= paid-bills;simulation=s
        logMoney(-paid,category:"Debt repayment",note:"Outstanding bills and emergency loan");return true
    }
    @discardableResult mutating func emergencyLoan()->Bool {
        guard managementEnabled,simulation.loanDebt<480 else{return false};var s=simulation;s.loanDebt += 240;cash += 200;simulation=s
        logMoney(200,category:"Emergency loan",note:"240 due; outstanding loans capped at 480");return true
    }
    mutating func toggleShadyOffers() {guard managementEnabled else{return};var s=simulation;s.shadyOffers.toggle();simulation=s}
    mutating func toggleNightVision() {guard managementEnabled,simulation.facilities.contains(.nightVision) else{return};var s=simulation;s.nightVision.toggle();simulation=s}
    var storyEnding:String {
        let s=simulation
        if s.billDebt>600 {return "Foreclosed: the bills won"}
        if s.cultFriendly>=s.ethical && s.cultFriendly>s.criminal {return "Sanctuary of the strange"}
        if s.criminal>s.ethical {return "Highway underworld"}
        if s.greedy>s.ethical {return "Profit at any price"}
        return "A haven worth returning to"
    }
    mutating func claimStoryEnding() {
        guard managementEnabled,day>=14 || rooms.count>=18 else{return}
        var s=simulation;let ending=storyEnding
        if !s.endings.contains(ending) {s.endings.append(ending);s.news="STORY ENDING: "+ending}
        simulation=s
    }
}

extension Motel {
    func workerSkill(_ role:StaffRole)->Int { simulation.profiles[role.rawValue]?.skill ?? StaffProfile.make(role).skill }
    @discardableResult mutating func restoreUtilities()->Bool {
        guard managementEnabled,cash>=20,simulation.stock["parts",default:0]>=2 else{return false}
        var s=simulation;s.stock["parts",default:0] -= 2;s.powerOut=false;s.waterOut=false
        s.issues.removeAll{$0.kind == .outage || $0.kind == .leak};simulation=s;cash -= 20
        logMoney(-20,category:"Utilities repair",note:"Power and water restored");playVisual("repair");return true
    }
    @discardableResult mutating func serviceGuest(_ id:Int)->Bool {
        guard managementEnabled,let room=rooms.first(where:{$0.guest?.id==id}),let guest=room.guest,cash>=8 else{return false}
        var s=simulation
        guard s.stock["snacks",default:0]>=1 else{return false}
        let key="guest-service-\(day)-\(id)"
        var state=operationsState
        guard state.serviceDays?[key] == nil else{return false}
        var serviced=state.serviceDays ?? [:];serviced[key]=day;state.serviceDays=serviced;operations=state
        s.stock["snacks",default:0] -= 1;s.relationships[guest.name,default:0] += 1;s.reputation=min(100,s.reputation+1);simulation=s
        cash -= 8;logMoney(-8,category:"Guest care",note:guest.name);playVisual("breakfast");lastEvent=guest.name+" appreciated the personal service.";return true
    }
}

extension Motel {
    @discardableResult mutating func reserveGuest(_ id:Int)->Bool {
        guard managementEnabled,!isNight,let guest=waiting.first(where:{$0.id==id}) else{return false}
        var s=simulation;guard !s.reservations.contains(where:{$0.guest.id==id && !$0.processed}) else{return false}
        s.serial += 1;s.reservations.append(HotelReservation(id:s.serial,guest:guest,arrivalHour:s.absoluteHour+2,noShow:guest.id%4==0))
        simulation=s;waiting.removeAll{$0.id==id};if reception.visitor?.guest.id==id {world?.reception?.visitor=nil};lastEvent=guest.name+" reserved a later arrival. A 10-coin no-show fee applies.";return true
    }
    mutating func injectIssue(_ kind:HotelIssueKind,roomID:Int) {
        guard managementEnabled,let room=rooms.first(where:{$0.id==roomID}) else{return}
        var s=simulation;s.serial += 1
        s.issues.append(HotelIssue(id:s.serial,kind:kind,roomID:roomID,guestName:room.guest?.name ?? "Visitor",deadline:s.absoluteHour+3))
        simulation=s
    }
}

enum MiniGameTiming {
    static func isHit(elapsed:Double)->Bool {
        let phase=max(0,elapsed).truncatingRemainder(dividingBy:1.6)/1.6
        return (0.25...0.75).contains(phase)
    }
}
extension Motel {
    @discardableResult mutating func managerAssignGuest(_ id:Int,roomID:Int)->Bool {
        guard let guest=waiting.first(where:{$0.id==id}) else{return false}
        if isAtReception,reception.visitor?.guest.id==id,reception.visitor?.phase == .waiting {return acceptReceptionGuest(roomID:roomID)}
        guard checkIn(guestID:id,roomID:roomID) else{return false}
        if world != nil {
            if reception.visitor?.guest.id==id {world?.reception?.visitor=nil}
            let start=Tile(x:6,y:10)
            world?.travellers.append(MotelWalker(id:id,name:guest.name,color:guest.color,roomID:roomID,player:start,previous:start,destination:MotelGrounds.roomDoor(roomID)))
        }
        return true
    }
}

extension Motel {
    func guestBudget(_ guest:MotelGuest)->Int {
        guest.kind.budget+simulation.reputation+max(-20,min(50,simulation.relationships[guest.name,default:0]*5))
    }
}
