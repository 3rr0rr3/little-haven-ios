import Foundation

struct MotelGuest: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let nights: Int
    let color: UInt32
    let story: String
    var category: GuestKind?
    var storyID: GuestStoryID?
    var kind: GuestKind { category ?? GuestKind.allCases[(Motel.guestNames.firstIndex(of:name) ?? max(0,id)%10) % GuestKind.allCases.count] }
    var appearanceSeed:Int {storyID?.appearance ?? Motel.appearanceSeed(name:name,id:id)}
}
struct MotelRoom: Codable, Identifiable {
    let id: Int
    var theme = 0
    var furniture = 0
    var guest: MotelGuest?
    var nightsLeft = 0
    var dirty = false
    var stolen: Set<Int> = []
    var cleanedTasks: Set<Int>?
    var hospitality: GuestRoomState?
    var health: GuestRoomState { hospitality ?? GuestRoomState() }
    var number: Int { (id / 9 + 1) * 100 + id % 9 + 1 }
    init(id: Int) { self.id = id; self.theme = id % 4 }
    var available: Bool { guest == nil && !dirty && health.cleanliness >= 60 && health.faults.isEmpty }
}
struct RoomVisit: Codable {
    let roomID: Int
    let sneaking: Bool
    var player = Tile(x: 4, y: 7)
    var facing = 3
    var alert = 0
    var ticks = 0
    var loot: Set<Int> = []
    var pocket = 0
    var guestTile: Tile {
        [Tile(x: 6, y: 3), Tile(x: 6, y: 4), Tile(x: 5, y: 4), Tile(x: 5, y: 3)][(ticks / 3) % 4]
    }
    static let lootTiles = [Tile(x: 2, y: 3), Tile(x: 6, y: 6), Tile(x: 2, y: 6)]
    static let lootNames = ["Suitcase", "Watch", "Camera"]
    static let lootValues = [45, 70, 95]
    static let lootNoise = [16, 24, 32]
    var nearbyLoot: Int? { Self.lootTiles.indices.first { player.distance(to: Self.lootTiles[$0]) <= 1 } }
    static func blocked(_ tile: Tile) -> Bool {
        RPGMaps.room.blocked(tile)
    }
}
struct Motel: Codable {
    static let goal = 9
    static let guestNames = ["Robin", "Sasha", "Ellis", "Alex", "Morgan", "Casey", "Jamie", "Blair", "Drew", "Quinn", "Camila", "Mateo", "Luna", "Diego", "Amara", "Noah", "Valentina", "Leo", "Zoe", "Hugo", "Isabel", "Finn", "Lucia", "Oscar"]
    static func appearanceSeed(name:String,id:Int)->Int {100+(guestNames.firstIndex(of:name) ?? id)}
    static let themeNames = ["Sage", "Sunset", "Ocean", "Plum"]
    static let themeColors: [UInt32] = [0x91B7A1, 0xD99B7E, 0x82AFC1, 0xAE95B9]
    var day = 1
    var cash = 180
    var rooms = (0..<3).map { MotelRoom(id: $0) }
    var officeTheme = 0
    var officeLevel = 0
    var waiting = Motel.arrivals(day: 1, count: 4)
    var visit: RoomVisit?
    var caught = false
    var lastEvent = "Three rooms. One desk. A fresh start."
    var guestsServed = 0
    var totalStolen = 0
    var world: MotelWorldState?
    var operations: MotelOperations?
    var home: FamilyHome?
    var guestStories: GuestStoryBook?
    var havenLife: HavenLife?
    var havenExpansion:HavenExpansion?
    var household: FamilyHome { home ?? FamilyHome() }
    var expansionCost: Int { 250 + (rooms.count - 3) * 150 }
    var occupancy: Int { rooms.filter { $0.guest != nil }.count }
    var goalReached: Bool { rooms.count >= expansionCapacity }
    var canSave: Bool { visit == nil && !caught }
    func rate(for room: MotelRoom) -> Int {
        let base=80 + room.furniture * 30 + officeLevel * 15
        return operationsState.simulation == nil ? base : managementRate(room,base:base)
    }
    static var randomizeGuestArrivals = true
    static func arrivals(day: Int, count: Int, randomize:Bool? = nil) -> [MotelGuest] {
        let randomize=randomize ?? randomizeGuestArrivals
        let names = randomize ? Self.guestNames.shuffled() : Self.guestNames
        let stories = ["Passing through on a road trip.", "In town for the weekend market.", "Needs a quiet place to write.", "Visiting an old friend.", "Taking the scenic route home."]
        return (0..<count).map { index in
            let key = day == 1 ? 10 + index : day * 100 + index
            let identity=Self.guestNames.firstIndex(of:names[index % names.count]) ?? index
            return MotelGuest(id: key, name: names[index % names.count],
                              nights: randomize ? Int.random(in:1...3) : (index % 3 == 1 ? 2 : 1),
                              color: [UInt32(0xD99B7E), 0x82AFC1, 0xAE95B9, 0xD6BD71][identity % 4],
                              story: stories[randomize ? Int.random(in:0..<stories.count) : (day + index) % stories.count])
        }
    }
    @discardableResult mutating func checkIn(guestID: Int, roomID: Int) -> Bool {
        guard !caught, (visit == nil || managementEnabled && operationsState.workers.contains(where:{$0.role == .clerk && $0.active})), let guestIndex = waiting.firstIndex(where: { $0.id == guestID }),
              let roomIndex = rooms.firstIndex(where: { $0.id == roomID }),
              rooms[roomIndex].available else { return false }
        let candidate=waiting[guestIndex]
        guard mayCheckIn(candidate,room:rooms[roomIndex]) else { return false }
        let guest = waiting.remove(at: guestIndex)
        let payment = bookingQuote(guest,room:rooms[roomIndex])
        rooms[roomIndex].guest = guest
        rooms[roomIndex].nightsLeft = operationsState.simulation == nil ? guest.nights : (bookingPlan(guest,room:rooms[roomIndex]) == .weekly ? 7 : guest.nights)
        rooms[roomIndex].stolen = []
        cash += payment
        repayBusinessDebt()
        guestsServed += 1
        if isAtReception {playVisual("checkin",target:OfficeReception.computer)}
        registerContract(guest,room:rooms[roomIndex],payment:payment)
        welcomeRoutineGuest(guest,room:rooms[roomIndex])
        prepareChaosClock()
        lastEvent = "\(guest.name) checked into room \(rooms[roomIndex].number). +\(payment) coins."
        return true
    }
    @discardableResult mutating func clean(_ roomID: Int) -> Bool {
        guard canSave, let index = rooms.firstIndex(where: { $0.id == roomID }),
              rooms[index].guest == nil, rooms[index].dirty else { return false }
        guard useCleaningStock(full:true) else { return false }
        rooms[index].dirty = false
        if operationsState.simulation != nil { var health=rooms[index].health; health.cleanliness=100; health.faults.remove(.mattress); rooms[index].hospitality=health }
        countHavenGoal("clean")
        playVisual("mop")
        rooms[index].cleanedTasks = Set(MotelGrounds.cleaningTiles.indices)
        lastEvent = "Room \(rooms[index].number) is ready. A little elbow grease costs nothing."
        return true
    }
    @discardableResult mutating func decorate(roomID: Int?, theme: Int) -> Bool {
        guard canSave, Self.themeNames.indices.contains(theme) else { return false }
        if let roomID {
            guard let index = rooms.firstIndex(where: { $0.id == roomID }),
                  rooms[index].guest == nil, rooms[index].theme != theme, cash >= 25 else { return false }
            cash -= 25
            rooms[index].theme = theme
        } else {
            guard officeTheme != theme, cash >= 25 else { return false }
            cash -= 25
            officeTheme = theme
        }
        lastEvent = "Fresh \(Self.themeNames[theme].lowercased()) paint. -25 coins."
        return true
    }
    @discardableResult mutating func upgrade(roomID: Int?) -> Bool {
        guard canSave else { return false }
        if let roomID {
            guard let index = rooms.firstIndex(where: { $0.id == roomID }),
                  rooms[index].guest == nil, rooms[index].furniture < 2 else { return false }
            let price = (rooms[index].furniture + 1) * 90
            guard cash >= price else { return false }
            cash -= price
            rooms[index].furniture += 1
            lastEvent = "Room \(rooms[index].number) upgraded. Its nightly rate increased by 30."
        } else {
            let price = (officeLevel + 1) * 120
            guard officeLevel < 2, cash >= price else { return false }
            cash -= price
            officeLevel += 1
            lastEvent = "Office upgraded. All nightly rates increased by 15."
        }
        return true
    }
    @discardableResult mutating func expand() -> Bool {
        guard canSave, !goalReached, cash >= expansionCost else { return false }
        cash -= expansionCost
        rooms.append(MotelRoom(id: rooms.count))
        lastEvent = managementEnabled && goalReached ? "Capacity reached. Buy land or add an upper floor on the management board." : goalReached ? "Nine rooms! You built Brainstorm Haven into a thriving Airb&b. Keep running it as long as you like." : "Room \(rooms.last!.number) is built and ready for its first guest."
        return true
    }
    @discardableResult mutating func nextDay() -> Bool {
        guard !caught, (visit == nil || managementEnabled), business.police == nil else { return false }
        day += 1
        let beforeWages=cash
        payStaffForDay()
        logMoney(cash-beforeWages,category:"Wages",note:"Day and night shift payroll")
        var departures = 0
        for index in rooms.indices where rooms[index].guest != nil {
            rooms[index].nightsLeft -= 1
            if rooms[index].nightsLeft == 0 {
                recordCheckoutReview(rooms[index])
                rooms[index].guest = nil
                rooms[index].dirty = true
                rooms[index].cleanedTasks = []
                rooms[index].stolen = []
                departures += 1
            }
        }
        waiting = Self.arrivals(day: day, count: max(1,min(rooms.count + 1 + officeLevel, 10) - bookingPenalty))
        finishSimulationDay()
        if guestStories != nil { settleGuestStoryDay() }
        if Self.randomizeGuestArrivals || guestStories != nil { prepareStoryArrivals() }
        settleHavenDay()
        attractHavenGuests()
        refreshExpansionDay()
        if let oldVisit=visit,oldVisit.sneaking,rooms.first(where:{$0.id==oldVisit.roomID})?.guest==nil {
            var empty=RoomVisit(roomID:oldVisit.roomID,sneaking:false)
            empty.player=oldVisit.player;empty.facing=oldVisit.facing;empty.pocket=oldVisit.pocket;empty.loot=oldVisit.loot
            visit=empty
        }
        lastEvent = "Day \(day): \(departures) checkouts. Clean the empty rooms and welcome new arrivals."
        return true
    }
    @discardableResult mutating func enter(_ roomID: Int) -> Bool {
        guard !isRidingBike else{return false}
        guard canSave, let room = rooms.first(where: { $0.id == roomID }) else { return false }
        visit = RoomVisit(roomID: roomID, sneaking: room.guest != nil)
        return true
    }
    mutating func tick() {
        guard !caught, var roomVisit = visit, roomVisit.sneaking else { return }
        roomVisit.ticks += 1
        roomVisit.alert = min(100, roomVisit.alert + 3)
        visit = roomVisit
        detect()
    }
    mutating func move(dx: Int, dy: Int) {
        guard !caught, var roomVisit = visit, abs(dx) <= 1, abs(dy) <= 1, dx != 0 || dy != 0 else { return }
        roomVisit.facing = dy > 0 ? 0 : dx < 0 ? 1 : dx > 0 ? 2 : 3
        let next = Tile(x: roomVisit.player.x + dx, y: roomVisit.player.y + dy)
        guard !RoomVisit.blocked(next) else { visit = roomVisit; return }
        if dx != 0 && dy != 0 {
            guard !RoomVisit.blocked(Tile(x: roomVisit.player.x + dx, y: roomVisit.player.y)),
                  !RoomVisit.blocked(Tile(x: roomVisit.player.x, y: roomVisit.player.y + dy)) else { visit = roomVisit; return }
        }
        if next == Tile(x: 4, y: 8) { leave(); return }
        roomVisit.player = next
        if roomVisit.sneaking { roomVisit.alert = min(100, roomVisit.alert + 3) }
        visit = roomVisit
        detect()
    }
    @discardableResult mutating func steal() -> Bool {
        guard !caught, var roomVisit = visit, roomVisit.sneaking,
              let item = roomVisit.nearbyLoot,
              let room = rooms.first(where: { $0.id == roomVisit.roomID }),
              !room.stolen.contains(item), !roomVisit.loot.contains(item) else { return false }
        playVisual("steal-\(item)",target:RoomVisit.lootTiles[item])
        if managementEnabled {var s=simulation;s.criminal += 1;s.heat += 5;simulation=s}
        roomVisit.loot.insert(item)
        roomVisit.pocket += RoomVisit.lootValues[item]
        roomVisit.alert = min(100, roomVisit.alert + RoomVisit.lootNoise[item])
        visit = roomVisit
        detect()
        return !caught
    }
    private mutating func detect() {
        guard let roomVisit = visit, roomVisit.sneaking else { return }
        if roomVisit.alert >= 100 || (guestPresent(in: roomVisit.roomID) && roomVisit.player.distance(to: roomVisit.guestTile) <= 1) {
            caught = true
            lastEvent = "The guest caught you inside their room. Your Airb&b story ends here."
        }
    }
    mutating func leave() {
        guard !caught, let roomVisit = visit else { return }
        guard roomVisit.player.distance(to: Tile(x: 4, y: 8)) <= 1 else { return }
        if let index = rooms.firstIndex(where: { $0.id == roomVisit.roomID }) {
            rooms[index].stolen.formUnion(roomVisit.loot)
        }
        var belongings=household
        belongings.stolen += roomVisit.loot.sorted()
        home=belongings
        totalStolen += roomVisit.pocket

        lastEvent = roomVisit.pocket > 0 ? "You slipped out with \(roomVisit.pocket) coins worth of belongings. Visit the pawn shop to sell them." : "Back outside. The desk is waiting."
        visit = nil
        if world != nil {
            let door = groundRoomDoor(roomVisit.roomID)
            world!.place = .grounds
            world!.player = Tile(x: door.x, y: door.y + 1)
            world!.facing = 0
        }
    }
}

enum GuestStoryID: String, Codable, CaseIterable, Identifiable {
    case musician, reviewer, traveler
    var id: String { rawValue }
    var name: String { switch self { case .musician: return "Rowan"; case .reviewer: return "Celeste"; case .traveler: return "Emilia" } }
    var title: String { switch self { case .musician: return "A room and a song"; case .reviewer: return "An honest review"; case .traveler: return "The long way home" } }
    var color: UInt32 { switch self { case .musician: return 0xB57D68; case .reviewer: return 0x8774A9; case .traveler: return 0x719D8D } }
    var appearance: Int { 180 + (Self.allCases.firstIndex(of: self) ?? 0) }
}
struct GuestStoryProgress: Codable {
    var chapter = 0
    var nextVisitDay = 1
    var answeredGuestID: Int?
    var discountGuestID: Int?
    var relationship = 0
    var memories: [String] = []
    var ending = ""
}
struct GuestStoryBook: Codable {
    var progress: [String: GuestStoryProgress] = [:]
    var scheduledDay = 0
    var showDay: Int?
    var performedDay: Int?
    var showSucceeded = false
    var musicPartnership = false
    var travelFeature = false
    var familyReunited = false
    var dailyIncomeDay = 0
}
struct GuestStoryChoice: Identifiable {
    let id: Int
    let title: String
    let consequence: String
    var cost = 0
}
extension Motel {
    var storyBook: GuestStoryBook { guestStories ?? GuestStoryBook() }
    func storyProgress(_ id: GuestStoryID) -> GuestStoryProgress {
        storyBook.progress[id.rawValue] ?? GuestStoryProgress()
    }
    var storyGuests: [MotelGuest] { waiting + rooms.compactMap(\.guest) }
    func storyGuest(_ id: GuestStoryID) -> MotelGuest? { storyGuests.first { $0.storyID == id } }
    func canDiscussStory(_ guest: MotelGuest) -> Bool {
        guard !caught, visit == nil, let id = guest.storyID,
              storyGuests.contains(where: { $0.id == guest.id }) else { return false }
        let atDesk = isAtReception && receptionGuest?.id == guest.id
        let atDoor = nearbyHospitalityRoom?.guest?.id == guest.id
        let progress = storyProgress(id)
        return (atDesk || atDoor) && progress.chapter < 3 &&
            progress.answeredGuestID != guest.id && day >= progress.nextVisitDay
    }
    var storyBookingBonus: Int { (storyBook.musicPartnership ? 1 : 0) + (storyBook.travelFeature ? 1 : 0) }
    mutating func prepareStoryArrivals() {
        var book = storyBook
        guard book.scheduledDay != day else { return }
        book.scheduledDay = day
        let stories = GuestStoryID.allCases
        let start = max(0, day - 1) % stories.count
        for offset in 0..<stories.count {
            let id = stories[(start + offset) % stories.count]
            let progress = book.progress[id.rawValue] ?? GuestStoryProgress()
            guard (progress.chapter < 3 || progress.relationship >= 3), day >= progress.nextVisitDay, storyGuest(id) == nil else { continue }
            let guest = MotelGuest(id: 500000 + day * 10 + offset, name: id.name, nights: 1,
                color: id.color, story: id.title + ". I'd like to talk when you have a moment.",
                category: .traveler, storyID: id)
            waiting.insert(guest, at: 0)
            if progress.chapter >= 3 { var returning=progress;returning.nextVisitDay=day+7;book.progress[id.rawValue]=returning }
            break
        }
        // Story rewards add visitors; keep the ordinary randomized guest mix.
        let extra = min(2, storyBookingBonus)
        if extra > 0 {
            let targetCount = min(Self.guestNames.count, waiting.count + extra)
            let additions = Self.arrivals(day: day, count: targetCount)
            for guest in additions where !waiting.contains(where: { $0.id == guest.id }) {
                waiting.append(guest)
                if waiting.count >= targetCount { break }
            }
        }
        guestStories = book
    }
    func guestStoryText(_ id: GuestStoryID) -> String {
        let progress = storyProgress(id)
        if progress.chapter >= 3 { return progress.ending }
        switch (id, progress.chapter) {
        case (.musician, 0): return "My van broke down on the way to a gig. Could you take 30 coins off my room? Or I could play a set at the Lantern Bar today in exchange for a room discount."
        case (.musician, 1):
            return storyBook.showSucceeded
                ? "You kept your word. People actually listened to my songs! I'm back with a new set. Shall we make the Lantern a regular stop?"
                : "I remember our first visit. I am back with new songs. Would you like to try a show, or would you prefer a quieter motel?"
        case (.musician, _): return storyBook.showSucceeded
            ? "That little stage helped me find my confidence. I can bring musicians here regularly, if you'd like to invest in the evenings."
            : "I'm heading onward. Before I go, would you like a quiet farewell set or should we leave things here?"
        case (.reviewer, 0): return "I'm writing a travel guide. I won't promise you a perfect score. Would you welcome an honest inspection, pay to polish the room, or rather I stay as an ordinary guest?"
        case (.reviewer, 1): return progress.relationship > 0
            ? "You gave me an honest welcome. The guide needs a place with character. May I photograph the motel, or would you prefer to protect your guests' privacy?"
            : "I wasn't sure what to make of our first meeting. Can we try again with an honest inspection?"
        case (.reviewer, _): return "The article is ready. A public feature will bring more travelers, while a small private recommendation keeps things quieter. Which suits your haven?"
        case (.traveler, 0): return "I came to find my sister after years apart. I know she used to visit this coast. Could you help with travel costs, listen to my story, or give me some space?"
        case (.traveler, 1): return progress.relationship > 0
            ? "I found her address. I'm nervous about reaching out. Could you help me write a letter, arrange a meeting, or let me decide in my own time?"
            : "I haven't reached out yet. Perhaps we could start by talking over a meal?"
        case (.traveler, _): return "She answered. She wants to meet. Could we celebrate here, share a simple meal, or keep this a private family moment?"
        }
    }
    func guestStoryChoices(_ id: GuestStoryID) -> [GuestStoryChoice] {
        let chapter = storyProgress(id).chapter
        guard chapter < 3 else { return [] }
        switch (id, chapter) {
        case (.musician, 0): return [
            .init(id:0,title:"Offer a 30-coin room discount",consequence:"+2 trust. Discount applies once to this booking."),
            .init(id:1,title:"Trade a discount for a bar show",consequence:"+1 trust. Visit Jules today and start the show. Miss it: -2 trust."),
            .init(id:2,title:"Keep the normal room rate",consequence:"No extra cost. Rowan remembers your decision.")]
        case (.musician, 1): return [
            .init(id:0,title:"Book another set tonight",consequence:"Pay 20 for promotion. Start the show at the bar today.",cost:20),
            .init(id:1,title:"Offer a quiet place to rehearse",consequence:"+2 trust. No show to organize."),
            .init(id:2,title:"Keep our relationship strictly business",consequence:"-1 trust. No new promise.")]
        case (.musician, _): return [
            .init(id:0,title:"Fund regular Lantern music nights",consequence:"Requires a successful show. Pay 60; +12 coins per day and one extra daily arrival.",cost:60),
            .init(id:1,title:"Stay friends without a business deal",consequence:"+2 trust. A personal friendship."),
            .init(id:2,title:"Say goodbye and wish Rowan well",consequence:"Close the story without an investment.")]
        case (.reviewer, 0): return [
            .init(id:0,title:"Welcome an honest inspection",consequence:"+2 trust. Good room care matters on the return visit."),
            .init(id:1,title:"Prepare a welcome basket",consequence:"Pay 20; +1 trust. No guaranteed perfect review.",cost:20),
            .init(id:2,title:"Ask for an ordinary private stay",consequence:"No cost. Your privacy is respected.")]
        case (.reviewer, 1): return [
            .init(id:0,title:"Invite a respectful photo visit",consequence:"+2 trust if occupied rooms are clean and fault-free; otherwise -2."),
            .init(id:1,title:"Protect guest privacy",consequence:"+1 trust. No photography."),
            .init(id:2,title:"Ask for a guaranteed perfect review",consequence:"-3 trust. Celeste refuses to sell her opinion.")]
        case (.reviewer, _): return [
            .init(id:0,title:"Publish the honest travel feature",consequence:"Requires 3 trust. +1 daily arrival and +3 reputation."),
            .init(id:1,title:"Keep it a personal recommendation",consequence:"+2 trust. Quiet word of mouth."),
            .init(id:2,title:"Decline publicity",consequence:"Close the story and keep the motel private.")]
        case (.traveler, 0): return [
            .init(id:0,title:"Help with travel costs",consequence:"Pay 25; +2 trust.",cost:25),
            .init(id:1,title:"Listen and share local advice",consequence:"+1 trust. No money needed."),
            .init(id:2,title:"Give Emilia space",consequence:"No cost. She can try again on a later visit.")]
        case (.traveler, 1): return [
            .init(id:0,title:"Help write an honest letter",consequence:"+2 trust. Emilia reaches out."),
            .init(id:1,title:"Arrange a welcoming meal",consequence:"Pay 20; +3 trust.",cost:20),
            .init(id:2,title:"Let Emilia take her time",consequence:"+1 trust. No pressure.")]
        case (.traveler, _): return [
            .init(id:0,title:"Host a family celebration",consequence:"Requires 3 trust. Pay 30; receive a 70-coin thank-you and +2 reputation.",cost:30),
            .init(id:1,title:"Share a simple meal",consequence:"+2 trust. A quiet reunion."),
            .init(id:2,title:"Respect their private meeting",consequence:"+1 trust. The family keeps in touch.")]
        }
    }
    func storyChoiceEnabled(_ guest: MotelGuest, choice: GuestStoryChoice) -> Bool {
        guard canDiscussStory(guest), cash >= choice.cost, let id = guest.storyID else { return false }
        if storyProgress(id).chapter == 2 && choice.id == 0 {
            if id == .musician { return storyBook.showSucceeded }
            if id == .reviewer || id == .traveler { return storyProgress(id).relationship >= 3 }
        }
        return true
    }
    @discardableResult mutating func chooseGuestStory(_ guest: MotelGuest, choiceID: Int) -> Bool {
        guard let id = guest.storyID, let choice = guestStoryChoices(id).first(where: { $0.id == choiceID }),
              storyChoiceEnabled(guest, choice: choice) else { return false }
        var book = storyBook, progress = storyProgress(id)
        let chapter = progress.chapter
        cash -= choice.cost
        if choice.cost > 0 { logMoney(-choice.cost, category:"Guest stories", note:id.name + ": " + choice.title) }
        var trust = 0, result = ""
        switch (id, chapter, choiceID) {
        case (.musician, 0, 0), (.musician, 0, 1):
            trust = choiceID == 0 ? 2 : 1
            if rooms.contains(where: { $0.guest?.id == guest.id }) {
                cash += 30; logMoney(30,category:"Guest stories",note:"Rowan's room refund")
            } else { progress.discountGuestID = guest.id }
            if choiceID == 1 { book.showDay = day; book.performedDay = nil }
            result = choiceID == 1 ? "Rowan will meet you at the Lantern Bar today. Talk to Jules and start the set before resting." : "Rowan appreciates the 30-coin help and will remember it."
        case (.musician, 0, _): result = "Rowan pays the normal rate. No show was promised."
        case (.musician, 1, 0): trust=1;book.showDay=day;book.performedDay=nil;result="Tonight's show is booked. Visit Jules at the Lantern Bar before resting."
        case (.musician, 1, 1): trust=2;result="Rowan finds a quiet place to rehearse and feels welcome."
        case (.musician, 1, _): trust = -1;result="Rowan understands that you want to keep this a business relationship."
        case (.musician, _, 0): trust=3;book.musicPartnership=true;result="Lantern music nights begin: +12 coins and an extra traveler each day."
        case (.musician, _, 1): trust=2;result="Rowan leaves as a friend. Your kindness matters more than a contract."
        case (.musician, _, _): result="Rowan heads down the coast with a story to tell."
        case (.reviewer, 0, 0): trust=2;result="Celeste appreciates your honesty and plans to return."
        case (.reviewer, 0, 1): trust=1;result="Celeste enjoys the basket, but the review will still be honest."
        case (.reviewer, 0, _): result="Celeste respects your request for a private stay."
        case (.reviewer, 1, 0):
            let caredFor = rooms.filter { $0.guest != nil }.allSatisfy { !$0.dirty && $0.health.cleanliness >= 70 && $0.health.faults.isEmpty }
            trust = caredFor ? 2 : -2
            result = caredFor ? "The rooms are cared for. Celeste's photographs capture a welcoming motel." : "Maintenance problems spoil the visit. Celeste notices that the rooms need care."
        case (.reviewer, 1, 1): trust=1;result="Celeste leaves her camera packed and respects your guests' privacy."
        case (.reviewer, 1, _): trust = -3;result="Celeste refuses the offer. Buying praise has damaged her trust."
        case (.reviewer, _, 0): trust=2;book.travelFeature=true;var s=simulation;s.reputation=min(100,s.reputation+3);simulation=s;result="The travel feature is published. One extra traveler arrives each day."
        case (.reviewer, _, 1): trust=2;result="Celeste recommends the motel privately to friends."
        case (.reviewer, _, _): result="The article leaves your motel unnamed. Celeste respects your choice."
        case (.traveler, 0, 0): trust=2;result="Emilia can continue her search. She promises to come back with news."
        case (.traveler, 0, 1): trust=1;result="Emilia feels heard. Your advice gives her a starting point."
        case (.traveler, 0, _): result="Emilia takes some time to think. The door remains open."
        case (.traveler, 1, 0): trust=2;result="Emilia sends the letter. For the first time, she feels hopeful."
        case (.traveler, 1, 1): trust=3;result="Over a warm meal, Emilia finds the courage to reach out."
        case (.traveler, 1, _): trust=1;result="Emilia appreciates that you didn't rush her."
        case (.traveler, _, 0):
            trust=3;book.familyReunited=true;cash+=70;logMoney(70,category:"Guest stories",note:"Emilia's family thank-you")
            var s=simulation;s.reputation=min(100,s.reputation+2);simulation=s
            result="The sisters reunite at your haven. Their family leaves a 70-coin thank-you."
        case (.traveler, _, 1): trust=2;book.familyReunited=true;result="The sisters share a quiet meal. Emilia calls this place a second home."
        default: trust=1;book.familyReunited=true;result="Emilia and her sister meet in private and promise to stay in touch."
        }
        progress.relationship = max(-10,min(10,progress.relationship+trust))
        progress.chapter += 1; progress.nextVisitDay = day + 3; progress.answeredGuestID = guest.id
        progress.memories.append("Day \(day): " + result)
        if progress.chapter == 3 { progress.ending = result }
        book.progress[id.rawValue] = progress; guestStories = book
        var s=simulation;s.relationships[id.name,default:0]+=trust;simulation=s
        lastEvent = result
        return true
    }
    var lanternShowAvailable: Bool { storyBook.showDay == day && storyBook.performedDay != day }
    @discardableResult mutating func startLanternShow() -> Bool {
        guard !caught, canTrade(.bar), lanternShowAvailable else { return false }
        var book=storyBook
        book.performedDay=day;book.showSucceeded=true
        var progress=book.progress[GuestStoryID.musician.rawValue] ?? GuestStoryProgress()
        progress.relationship=min(10,progress.relationship+2)
        progress.memories.append("Day \(day): You hosted Rowan's Lantern set. +60 coins; +2 trust.")
        book.progress[GuestStoryID.musician.rawValue]=progress;guestStories=book
        cash+=60;logMoney(60,category:"Guest stories",note:"Lantern live music")
        var s=simulation;s.relationships["Rowan",default:0]+=2;simulation=s
        lastEvent="Rowan plays to a cheering Lantern crowd. +60 coins. Rowan will remember that you kept your promise."
        return true
    }
    mutating func settleGuestStoryDay() {
        var book=storyBook
        if let showDay=book.showDay,showDay < day {
            if book.performedDay != showDay {
                var progress=book.progress[GuestStoryID.musician.rawValue] ?? GuestStoryProgress()
                progress.relationship=max(-10,progress.relationship-2)
                progress.memories.append("Day \(showDay): The promised show was missed. -2 trust.")
                book.progress[GuestStoryID.musician.rawValue]=progress
                var s=simulation;s.relationships["Rowan",default:0]-=2;simulation=s
            }
            book.showDay=nil
        }
        if book.dailyIncomeDay != day {
            book.dailyIncomeDay=day
            if book.musicPartnership { cash+=12;logMoney(12,category:"Guest stories",note:"Regular Lantern music nights") }
        }
        guestStories=book
    }
}

enum HavenIdentity:String,Codable,CaseIterable,Identifiable {
    case peaceful, lively, boutique
    var id:String {rawValue}
    var title:String {switch self {case .peaceful:return "Peaceful retreat";case .lively:return "Lively destination";case .boutique:return "Boutique haven"}}
    var detail:String {switch self {
    case .peaceful:return "More long-term residents and quiet travelers. Quiet neighbors appreciate this direction."
    case .lively:return "More party groups. Music and celebrations flourish, but noise can upset neighbors."
    case .boutique:return "More celebrities and travelers. Requires 60 reputation and three furniture upgrades; room care matters."
    }}
}
struct HavenNeighbor:Codable {
    var friendship=0
    var chattedDay=0
    var favorDay=0
    var favorPending=false
    var parcel=false
    var invitedDay=0
    var welcomedDay=0
}
struct HavenEmployee:Codable {
    var experience=0
    var level=1
    var raiseBonus=0
    var requestDay=0
    var decisionDay=0
    var supportDay=0
    var friend:String?
}
struct HavenAdventure:Codable {
    var accepted=false
    var found=false
    var completed=false
}
enum HavenActivity:String,Codable,CaseIterable,Identifiable {
    case market,fishing,food,beachParty
    var id:String {rawValue}
    var title:String {switch self {case .market:return "Neighborhood market";case .fishing:return "Cove fishing contest";case .food:return "Coral Catch special";case .beachParty:return "Sunset beach party"}}
    var weekday:Int {switch self {case .market:return 1;case .fishing:return 3;case .food:return 5;case .beachParty:return 7}}
    var cost:Int {switch self {case .market:return 20;case .fishing:return 10;case .food:return 25;case .beachParty:return 35}}
    var snacks:Int {self == .food ? 3 : self == .beachParty ? 4 : 0}
    var location:Tile {switch self {case .market:return Tile(x:54,y:33);case .fishing:return Tile(x:52,y:48);case .food:return Tile(x:47,y:36);case .beachParty:return Tile(x:61,y:47)}}
    var locationName:String {switch self {case .market:return "the shop plaza";case .fishing:return "the cove shoreline";case .food:return "outside Coral Catch";case .beachParty:return "the east beach"}}
    var rounds:[String] {switch self {
    case .market:return ["Set up your stall","Welcome the first visitors","Finish the market"]
    case .fishing:return ["Choose your first cast","A second chance at a catch","Make your final cast"]
    case .food:return ["Prepare the ingredients","Serve the first guests","Finish the special"]
    case .beachParty:return ["Welcome the beach crowd","Keep the party going","Close the evening"]
    }}
    var options:[[String]] {switch self {
    case .market:return [["Offer fair prices","Charge a premium"],["Share local stories","Push quick sales"],["Trade with neighbors","Sell every last item"]]
    case .fishing:return Array(repeating:["Patient cast","Risk a deep-water cast"],count:3)
    case .food:return [["Prepare carefully","Rush the prep"],["Serve generous plates","Keep portions small"],["Thank the kitchen team","Keep the tips"]]
    case .beachParty:return [["Acoustic welcome","Loud beach music"],["Share food and stories","Sell VIP tickets"],["Clean the beach together","Leave early"]]
    }}
}
struct HavenActivityRun:Codable {
    var day:Int
    var kind:HavenActivity
    var round=0
    var score=0
    var finished=false
}
struct HavenLife:Codable {
    var identity:HavenIdentity = .peaceful
    var identityDay=0
    var neighbors:[Int:HavenNeighbor]=[:]
    var employees:[String:HavenEmployee]=[:]
    var adventures:[Int:HavenAdventure]=[:]
    var petFindDays:[String:Int]=[:]
    var activity:HavenActivityRun?
    var completedActivities:[String]=[]
    var neglectedDays:[Int:Int]=[:]
    var cancellations=0
    var lastSettledDay=0
    var notes:[String]=[]
}
struct HavenWorldProp {
    let id:String
    let tile:Tile
    let kind:Int
}
extension Motel {
    var haven:HavenLife {havenLife ?? HavenLife()}
    mutating func initializeHavenLife() {if havenLife == nil {havenLife=HavenLife()}}
    mutating func havenNote(_ message:String) {
        var state=haven;state.notes.insert("Day \(day): "+message,at:0)
        state.notes=Array(state.notes.prefix(24));havenLife=state;lastEvent=message
    }
    var havenWeekday:Int {max(0,day-1)%7+1}
    var todaysActivity:HavenActivity? {HavenActivity.allCases.first{$0.weekday==havenWeekday}}
    var nearHavenActivity:Bool {
        guard !caught,!isRidingBike,visit==nil,worldState.place == .grounds,let activity=todaysActivity else{return false}
        return actorTile.distance(to:groundNearestWalkable(to:groundTile(activity.location)))<=2
    }
    var nearHavenNeighbor:Int? {
        guard !caught,visit==nil,worldState.place == .grounds else{return nil}
        return (0..<3).first {id in actorTile.distance(to:worldState.neighborPositions?[id] ?? groundTile(ResidentialLayout.doors[id]))<=2}
    }
    func neighborState(_ id:Int)->HavenNeighbor {haven.neighbors[id] ?? HavenNeighbor()}
    @discardableResult mutating func chooseHavenIdentity(_ identity:HavenIdentity)->Bool {
        guard !caught,canSave,haven.identityDay != day else{return false}
        if identity == .boutique {guard simulation.reputation>=60,rooms.reduce(0,{$0+$1.furniture})>=3 else{return false}}
        var state=haven;state.identity=identity;state.identityDay=day;havenLife=state
        havenNote("Your motel is becoming a "+identity.title.lowercased()+". Future guests will reflect this choice.")
        return true
    }
    @discardableResult mutating func neighborAction(_ id:Int,choice:Int)->Bool {
        guard (0..<3).contains(id),nearHavenNeighbor==id else{return false}
        var state=haven,n=neighborState(id)
        switch choice {
        case 0:
            guard n.chattedDay != day else{return false};n.chattedDay=day;n.friendship=min(10,n.friendship+1)
        case 1:
            guard !n.favorPending,n.favorDay != day else{return false};n.favorPending=true;n.favorDay=day;n.parcel=false
        case 2:
            guard n.favorPending,n.parcel else{return false};n.favorPending=false;n.parcel=false;n.friendship=min(10,n.friendship+3)
            cash+=20;logMoney(20,category:"Neighbors",note:ResidentialLayout.names[id]+"'s favor")
        case 3:
            guard n.friendship>=3,n.invitedDay != day else{return false};n.invitedDay=day
        case 4:
            guard cash>=15,n.chattedDay != day else{return false};cash-=15;n.chattedDay=day;n.friendship=min(10,n.friendship+2)
            logMoney(-15,category:"Neighbors",note:"A peace offering")
        default:return false
        }
        state.neighbors[id]=n;havenLife=state
        let messages=["You catch up and grow a little closer.","Please collect my parcel from Otis at Willow Home, then bring it back.",
            "Thank you for keeping your word! +20 coins and +3 friendship.","I'll come over to your home today. See you there!","Thank you for hearing my side. We can start again."]
        havenNote(ResidentialLayout.names[id]+": "+messages[choice]);return true
    }
    @discardableResult mutating func collectNeighborParcels()->Bool {
        guard canTrade(.furniture) else{return false}
        var state=haven,changed=false
        for id in 0..<3 {
            var n=neighborState(id)
            if n.favorPending && !n.parcel {n.parcel=true;state.neighbors[id]=n;changed=true}
        }
        guard changed else{return false};havenLife=state;havenNote("Otis hands over the neighbors' parcels. Return them in the neighborhood.");return true
    }
    var homeNeighborIDs:[Int] {(0..<3).filter{neighborState($0).invitedDay==day}}
    func homeNeighborTile(_ id:Int)->Tile {
        let sites=[Tile(x:5,y:8),Tile(x:7,y:8),Tile(x:9,y:8),Tile(x:4,y:6),Tile(x:6,y:6),Tile(x:8,y:6),Tile(x:4,y:7),Tile(x:6,y:7),Tile(x:8,y:7)]
        var used:Set<Tile>=[]
        for neighbor in 0...max(0,id) {
            let free=sites.first{tile in !used.contains(tile) && !household.placed.contains{$0.tile==tile && $0.kind != .rug} && !OfficeReception.hildarelysRoute.contains(tile)} ?? Tile(x:5+neighbor*2,y:8)
            if neighbor==id {return free};used.insert(free)
        }
        return Tile(x:5,y:8)
    }
    @discardableResult mutating func welcomeHomeNeighbor(_ id:Int)->Bool {
        guard isAtHome,homeNeighborIDs.contains(id),actorTile.distance(to:homeNeighborTile(id))<=2 else{return false}
        var state=haven,n=neighborState(id);guard n.welcomedDay != day else{return false}
        n.welcomedDay=day;n.friendship=min(10,n.friendship+2);state.neighbors[id]=n;havenLife=state
        havenNote(ResidentialLayout.names[id]+" enjoys visiting your home. +2 friendship.");return true
    }
    func employeePersonality(_ role:StaffRole)->String {
        switch role {case .cleaner:return "Meticulous · values a clean, calm workplace"
        case .maintenance:return "Easygoing · works best with a trusted colleague"
        case .security:return "Proud · values fair pay and recognition"
        case .valet:return "Sociable · enjoys community activities"
        case .clerk:return "Ambitious · values training and career progress"
        case .repair:return "Methodical · dislikes exhausting shifts"
        case .pestControl:return "Patient · values rest and steady support"}
    }
    @discardableResult mutating func supportHavenEmployee(_ role:StaffRole,choice:Int)->Bool {
        guard canSave,operationsState.workers.contains(where:{$0.role==role}) else{return false}
        var state=haven,e=state.employees[role.rawValue] ?? HavenEmployee()
        var s=simulation,p=s.profiles[role.rawValue] ?? StaffProfile.make(role)
        if choice==0 {
            guard e.supportDay != day,cash>=10 else{return false}
            cash-=10;e.supportDay=day;p.fatigue=max(0,p.fatigue-([StaffRole.repair,.pestControl].contains(role) ? 40 : 30));p.loyalty=min(100,p.loyalty+5)
        } else if choice==1 {
            guard e.requestDay>0,e.decisionDay<e.requestDay,e.raiseBonus<6 else{return false}
            e.raiseBonus+=2;e.decisionDay=day;p.loyalty=min(100,p.loyalty+(role == .security ? 15 : 12))
        } else if choice==2 {
            guard e.requestDay>0,e.decisionDay<e.requestDay else{return false}
            e.decisionDay=day;p.loyalty=max(0,p.loyalty-12)
        } else {return false}
        state.employees[role.rawValue]=e;havenLife=state;s.profiles[role.rawValue]=p;simulation=s
        if choice==0 {logMoney(-10,category:"Staff support",note:role.name+"'s paid break")}
        havenNote(role.name+(choice==0 ? " takes a paid break. Fatigue falls and morale improves." : choice==1 ? " accepts a permanent +2/day raise. Loyalty improves." : " is disappointed that the raise was declined. Loyalty fell."))
        return true
    }
    static let adventureClues=["a keepsake near the north neighborhood path","a ribbon in the shop plaza","a lure outside Coral Catch","a seed pouch by the cove",
        "a shell on the east beach","a training buckle near the neighbors' homes","a grooming brush beside the laundry","a lost football near the south motel path"]
    static let adventureSites=[Tile(x:45,y:17),Tile(x:54,y:33),Tile(x:47,y:36),Tile(x:56,y:45),
        Tile(x:62,y:48),Tile(x:62,y:17),Tile(x:12,y:8),Tile(x:36,y:31)]
    static let creatureAbilities=["Wizard's insight · +1 toiletry each morning","Twin-tail courier · +1 towel each morning",
        "Blue's lucky cast · +2 fishing score","Shrek's green thumb · +2 snacks each morning",
        "Shark's sea sense · +2 fishing score","Mighty's encouragement · staff fatigue -5 each morning",
        "Fang's pest patrol · +1 pesticide each morning","Messi's team spirit · +2 activity score"]
    func adventure(_ id:Int)->HavenAdventure {haven.adventures[id] ?? HavenAdventure()}
    func adventureTile(_ id:Int)->Tile {groundNearestWalkable(to:groundTile(Self.adventureSites[id]))}
    @discardableResult mutating func startCreatureAdventure(_ id:Int)->Bool {
        guard !caught,(0..<8).contains(id),nearbyCorral==id,!adventure(id).accepted else{return false}
        var state=haven;var quest=adventure(id);quest.accepted=true;state.adventures[id]=quest;havenLife=state
        havenNote(BasementLayout.titles[id]+" wants help finding "+Self.adventureClues[id]+". Look for a golden glimmer.");return true
    }
    var nearbyAdventureFind:Int? {
        guard !caught,visit==nil,worldState.place == .grounds else{return nil}
        return (0..<8).first {id in let q=adventure(id);return q.accepted && !q.found && actorTile.distance(to:adventureTile(id))<=2}
    }
    @discardableResult mutating func collectAdventureFind()->Bool {
        guard let id=nearbyAdventureFind else{return false}
        var state=haven,q=adventure(id);q.found=true;state.adventures[id]=q;havenLife=state
        havenNote("You found the keepsake. Bring it to "+BasementLayout.titles[id]+"'s corral.");return true
    }
    @discardableResult mutating func finishCreatureAdventure(_ id:Int)->Bool {
        guard (0..<8).contains(id),nearbyCorral==id,adventure(id).found,!adventure(id).completed else{return false}
        var state=haven,q=adventure(id);q.completed=true;state.adventures[id]=q;havenLife=state
        cash+=15;logMoney(15,category:"Creature adventures",note:BasementLayout.titles[id])
        havenNote(BasementLayout.titles[id]+" trusts you. +15 coins. Unlocked: "+Self.creatureAbilities[id]);return true
    }
    var exploringPet:String? {
        guard !caught,visit==nil,worldState.place == .grounds,actorTile.x>=40 else{return nil}
        return ["chichu","chichi","mochi"].first{petState($0).following && petState($0).map==petMap && haven.petFindDays[$0] != day}
    }
    @discardableResult mutating func exploreWithPet()->Bool {
        guard let pet=exploringPet else{return false};var state=haven;state.petFindDays[pet]=day;havenLife=state
        var s=simulation
        if pet=="chichu" {s.stock["parts",default:0]+=1}
        else if pet=="chichi" {s.stock["snacks",default:0]+=2}
        else {cash+=12;logMoney(12,category:"Pet discoveries",note:"Tuki found a coin pouch")}
        simulation=s;havenNote(companionName(pet)+(pet=="chichu" ? " uncovers a spare repair part." : pet=="chichi" ? " finds a neighbor's gift of two snacks." : " discovers a pouch containing 12 coins."));return true
    }
    @discardableResult mutating func startHavenActivity()->Bool {
        guard nearHavenActivity,let kind=todaysActivity,cash>=kind.cost,simulation.stock["snacks",default:0]>=kind.snacks,
              haven.activity?.day != day else{return false}
        var state=haven;state.activity=HavenActivityRun(day:day,kind:kind);havenLife=state
        cash-=kind.cost;var s=simulation;s.stock["snacks",default:0]-=kind.snacks;simulation=s
        logMoney(-kind.cost,category:"Weekly activities",note:kind.title)
        havenNote(kind.title+" is ready. Complete three rounds at "+kind.locationName+".");return true
    }
    @discardableResult mutating func playHavenActivity(choice:Int)->Bool {
        guard nearHavenActivity,var run=haven.activity,run.day==day,!run.finished,(0...1).contains(choice) else{return false}
        var state=haven
        let earned:Int
        if run.kind == .fishing {
            earned=choice==0 ? 2 : (day+run.round)%3==0 ? 0 : 4
        } else {earned=choice==0 ? 3 : 1}
        run.score+=earned;run.round+=1
        if run.round==3 {
            if adventure(7).completed {run.score+=2}
            if run.kind == .fishing {if adventure(2).completed {run.score+=2};if adventure(4).completed {run.score+=2}}
            run.finished=true
            let reward=25+run.score*5;cash+=reward
            state.completedActivities.append("Day \(day): "+run.kind.title+" · score \(run.score), +\(reward) coins")
            state.completedActivities=Array(state.completedActivities.suffix(20))
            var s=simulation;s.reputation=min(100,s.reputation+(run.score>=6 ? 2 : 0))
            for worker in operationsState.workers {
                var p=s.profiles[worker.role.rawValue] ?? StaffProfile.make(worker.role)
                let change = run.kind == .food && choice==1 ? -2 : worker.role == .valet ? 5 : 3
                p.loyalty=max(0,min(100,p.loyalty+change));p.fatigue=max(0,p.fatigue-5);s.profiles[worker.role.rawValue]=p
            }
            simulation=s
            if run.kind == .beachParty {
                var nora=state.neighbors[0] ?? HavenNeighbor(),ben=state.neighbors[1] ?? HavenNeighbor()
                nora.friendship=max(-10,min(10,nora.friendship+(choice==0 ? 1 : -2)));ben.friendship=min(10,ben.friendship+1)
                state.neighbors[0]=nora;state.neighbors[1]=ben
            }
            logMoney(reward,category:"Weekly activities",note:run.kind.title)
        }
        state.activity=run;havenLife=state
        havenNote(run.finished ? "Activity complete! Score \(run.score); +\(25+run.score*5) coins. Community and staff remember your effort." : "Round \(run.round) complete. Score \(run.score).")
        return true
    }
    var havenWorldProps:[HavenWorldProp] {
        guard havenLife != nil,visit==nil,worldState.place == .grounds else{return []}
        var props=(0..<8).compactMap {id->HavenWorldProp? in
            let q=adventure(id);return q.accepted && !q.found ? HavenWorldProp(id:"quest-\(id)",tile:adventureTile(id),kind:0) : nil
        }
        if let kind=todaysActivity {props.append(HavenWorldProp(id:"activity-"+kind.rawValue,tile:groundNearestWalkable(to:groundTile(kind.location)),kind:1+(HavenActivity.allCases.firstIndex(of:kind) ?? 0)))}
        return props
    }
    mutating func settleHavenDay() {
        guard havenLife != nil,haven.lastSettledDay != day else{return}
        var state=haven;state.lastSettledDay=day;var s=simulation
        var report:[String]=[]
        for id in 0..<3 {
            var n=state.neighbors[id] ?? HavenNeighbor()
            if n.favorPending && day-n.favorDay>=3 {n.favorPending=false;n.parcel=false;n.friendship=max(-10,n.friendship-2);report.append("An overdue neighbor parcel damaged trust.")}
            if n.friendship>=4 {if id==0 {s.stock["snacks",default:0]+=1}else if id==1 {s.stock["parts",default:0]+=1}else {cash+=5}}
            state.neighbors[id]=n
        }
        if let run=state.activity,run.day<day,!run.finished {report.append("An unfinished activity closed without its prize.")}
        var workforce=operationsState
        for index in workforce.workers.indices {
            let role=workforce.workers[index].role
            var e=state.employees[role.rawValue] ?? HavenEmployee()
            var p=s.profiles[role.rawValue] ?? StaffProfile.make(role)
            if workforce.workers[index].active {
                e.experience+=1
                let level=1+e.experience/4
                if level>e.level {p.skill=min(99,p.skill+3);p.speed=min(95,p.speed+2);e.level=level;report.append(role.name+" gained experience and improved.")}
                if p.fatigue>=85 {p.loyalty=max(0,p.loyalty-5);report.append(role.name+" made an exhausting-shift mistake. Condition in one room fell.")
                    if let room=rooms.indices.first(where:{rooms[$0].guest != nil}) {var h=rooms[room].health;h.condition=max(0,h.condition-8);rooms[room].hospitality=h}}
            }
            if e.experience>=3,e.requestDay<=e.decisionDay,e.raiseBonus<6,day%4==0 {e.requestDay=day;report.append(role.name+" has asked for a raise.")}
            if let friend=workforce.workers.first(where:{$0.role != role && (s.profiles[$0.role.rawValue]?.loyalty ?? 70)>=80}),p.loyalty>=80 {e.friend=friend.role.rawValue}
            if role == .cleaner && rooms.filter({$0.guest != nil}).allSatisfy({$0.health.cleanliness>=70}) {p.loyalty=min(100,p.loyalty+1)}
            s.profiles[role.rawValue]=p;state.employees[role.rawValue]=e
        }
        var damaged=0
        for i in rooms.indices {
            let neglected = !rooms[i].health.faults.isEmpty || rooms[i].health.cleanliness<40
            let days=neglected ? state.neglectedDays[rooms[i].id,default:0]+1 : 0
            state.neglectedDays[rooms[i].id]=days
            if days>=2 {
                damaged+=1;var h=rooms[i].health;h.condition=max(0,h.condition-10);rooms[i].hospitality=h
                s.billDebt+=15
            }
        }
        if damaged>0 {
            let cancelled=min(2,min(damaged,waiting.filter{$0.storyID==nil}.count))
            for _ in 0..<cancelled {if let i=waiting.lastIndex(where:{$0.storyID==nil}) {waiting.remove(at:i)}}
            state.cancellations+=cancelled;s.reputation=max(0,s.reputation-damaged)
            report.append("Neglect caused \(damaged*15) coins in damage bills and \(cancelled) canceled bookings.")
        }
        for id in 0..<8 where adventure(id).completed {
            switch id {
            case 0:s.stock["toiletries",default:0]+=1
            case 1:s.stock["towels",default:0]+=1
            case 3:s.stock["snacks",default:0]+=2
            case 5:for role in StaffRole.allCases {if var p=s.profiles[role.rawValue] {p.fatigue=max(0,p.fatigue-5);s.profiles[role.rawValue]=p}}
            case 6:s.stock["pesticide",default:0]+=1
            default:break
            }
        }
        if state.identity == .lively {
            var n=state.neighbors[0] ?? HavenNeighbor()
            if rooms.contains(where:{$0.guest?.kind == .party && !$0.health.upgrades.contains(.soundproof)}) {n.friendship=max(-10,n.friendship-1);report.append("Unsoundproofed parties upset Nora.")}
            state.neighbors[0]=n
        }
        havenLife=state;simulation=s
        for message in report {havenNote(message)}
    }
    mutating func attractHavenGuests() {
        guard havenLife != nil else{return}
        let mix:[GuestKind]
        switch haven.identity {case .peaceful:mix=[.resident,.traveler,.traveler];case .lively:mix=[.party,.party,.traveler];case .boutique:mix=[.celebrity,.traveler,.celebrity]}
        for i in waiting.indices where waiting[i].storyID == nil {
            if i%3 != 2 {waiting[i].category=mix[(day+i)%mix.count]}
        }
    }
}


// Optional expansion state keeps pre-expansion checkpoints decodable.
enum HavenTrip:String,Codable,CaseIterable,Identifiable {
    case couple,family,business
    var id:String {rawValue}
    var title:String {switch self {case .couple:return "Cozy getaway";case .family:return "Family holiday";case .business:return "Business visit"}}
    var need:String {switch self {case .couple:return "Warm decor and a comfortable bed";case .family:return "Extra sleeping space and a mini-fridge";case .business:return "A quiet room, desk and reliable Wi-Fi"}}
}
enum HavenRoomDesign:String,Codable,CaseIterable,Identifiable {
    case classic,cozy,family,business
    var id:String {rawValue}
    var title:String {rawValue.capitalized}
    var cost:Int {self == .classic ? 0 : 75}
}
enum HavenRoutine:String,Codable {case room,breakfast,beach,bar,walk,shelter}
struct HavenRoutineGuest:Codable {
    var tile:Tile
    var previous:Tile
    var activity:HavenRoutine
}
struct HavenDiscovery:Identifiable {
    let id:String
    let name:String
    let hint:String
    let tile:Tile
    let group:String
}
struct HavenExpansion:Codable {
    var tier=0
    var designs:[Int:HavenRoomDesign]=[:]
    var routines:[Int:HavenRoutineGuest]=[:]
    var satisfaction:[Int:Int]=[:]
    var dailyDay=0
    var daily:[String:Int]=[:]
    var claimedGoals:Set<String>=[]
    var discoveries:Set<String>=[]
    var searches:Set<String>=[]
    var preparedDay=0
    var weatherSettledHour = -1
    var breakfastDay=0
    var buffet=0
    var meals:Set<Int>=[]
    var missedMeals:Set<Int>=[]
    var notes:[String]=[]
}
extension MotelGuest {
    var holiday:HavenTrip {HavenTrip.allCases[abs(id)%HavenTrip.allCases.count]}
}
extension Motel {
    var expansion:HavenExpansion {havenExpansion ?? HavenExpansion()}
    mutating func initializeExpansion() {
        if havenExpansion == nil {havenExpansion=HavenExpansion()}
        refreshExpansionDay()
    }
    mutating func refreshExpansionDay() {
        guard var e=havenExpansion,e.dailyDay != day else{return}
        e.dailyDay=day;e.daily=[:];e.claimedGoals=[];e.searches=[];e.meals=[];e.missedMeals=[]
        e.breakfastDay=day;e.buffet=0;e.weatherSettledHour = -1
        let guests=Set(rooms.compactMap{$0.guest?.id})
        e.routines=e.routines.filter{guests.contains($0.key)}
        e.satisfaction=e.satisfaction.filter{guests.contains($0.key)}
        havenExpansion=e
    }
    mutating func expansionNote(_ text:String) {
        guard var e=havenExpansion else{return}
        e.notes.insert("Day \(day): "+text,at:0);e.notes=Array(e.notes.prefix(20));havenExpansion=e;lastEvent=text
    }
    mutating func countHavenGoal(_ key:String,_ amount:Int=1) {
        guard havenExpansion != nil else{return};refreshExpansionDay()
        var e=expansion;e.daily[key,default:0]+=amount;havenExpansion=e
    }
    static let journeyNames=["Roadside beginnings","Welcoming motel","Coastal retreat","Famous coastal resort"]
    var journeyRequirement:String {
        switch expansion.tier {
        case 0:return "Serve 5 guests, own 3 rooms and reach 45 reputation"
        case 1:return "Serve 15 guests, own 4 rooms and reach 60 reputation"
        case 2:return "Serve 30 guests, own 6 rooms, complete 4 weekly activities and reach 75 reputation"
        default:return "Your coastal resort is famous. Keep building your collection and community."
        }
    }
    var canAdvanceJourney:Bool {
        guard havenExpansion != nil else{return false}
        switch expansion.tier {
        case 0:return guestsServed>=5 && rooms.count>=3 && simulation.reputation>=45
        case 1:return guestsServed>=15 && rooms.count>=4 && simulation.reputation>=60
        case 2:return guestsServed>=30 && rooms.count>=6 && haven.completedActivities.count>=4 && simulation.reputation>=75
        default:return false
        }
    }
    @discardableResult mutating func advanceJourney()->Bool {
        guard !caught,canAdvanceJourney else{return false}
        var e=expansion;e.tier+=1;havenExpansion=e
        let reward=e.tier*100;cash+=reward
        logMoney(reward,category:"Milestone",note:Self.journeyNames[e.tier])
        expansionNote(Self.journeyNames[e.tier]+" earned! +\(reward) coins and new facility permits.");return true
    }
    func facilityJourneyTier(_ facility:Facility)->Int {
        switch facility {case .pool:return 1;case .restaurant:return 2;case .upperFloor:return 3;default:return 0}
    }
    func journeyAllows(_ facility:Facility)->Bool {havenExpansion == nil || expansion.tier>=facilityJourneyTier(facility)}
    func roomDesign(_ room:MotelRoom)->HavenRoomDesign {expansion.designs[room.id] ?? .classic}
    func roomMatch(_ guest:MotelGuest,_ room:MotelRoom)->Int {
        guard havenExpansion != nil else{return 0}
        let design=roomDesign(room);let h=room.health
        var score=0
        switch guest.holiday {
        case .couple:
            if design == .cozy {score+=2};if room.theme==1 || room.theme==3 {score+=1};if h.upgrades.contains(.bed) {score+=1}
        case .family:
            if design == .family {score+=2};if h.upgrades.contains(.fridge) {score+=1};if room.furniture>0 {score+=1}
        case .business:
            if design == .business {score+=2};if h.upgrades.contains(.soundproof) {score+=1};if simulation.facilities.contains(.wifi) && !simulation.powerOut {score+=1}
        }
        return min(4,score)
    }
    func designPremium(_ guest:MotelGuest,_ room:MotelRoom)->Int {roomMatch(guest,room)*4}
    @discardableResult mutating func designHavenRoom(_ id:Int,_ design:HavenRoomDesign)->Bool {
        guard havenExpansion != nil,!caught,let i=rooms.firstIndex(where:{$0.id==id}),rooms[i].guest==nil,roomDesign(rooms[i]) != design,cash>=design.cost else{return false}
        cash-=design.cost;var e=expansion;e.designs[id]=design;havenExpansion=e
        logMoney(-design.cost,category:"Room design",note:"Room \(rooms[i].number): "+design.title)
        playVisual("build");expansionNote("Room \(rooms[i].number) now offers "+design.title.lowercased()+" accommodation.");return true
    }
    mutating func welcomeRoutineGuest(_ guest:MotelGuest,room:MotelRoom) {
        guard havenExpansion != nil else{return}
        var e=expansion;e.satisfaction[guest.id]=min(100,45+roomMatch(guest,room)*10);havenExpansion=e
        countHavenGoal("welcome")
    }
    static func forecastWeather(_ day:Int)->HotelWeather {
        [.sunny,.sunny,.rain,.sunny,.wind,.sunny,.storm][max(0,day-1)%7]
    }
    var nextWeather:HotelWeather {Self.forecastWeather(day+1)}
    var weatherAdvice:String {
        if simulation.economy == .heatwave {return "Heatwave: guests seek the pool. Stock towels and keep the AC working."}
        switch weather {
        case .storm:return "Storm: guests take shelter. Secure equipment before 12:00 to prevent storm damage."
        case .rain:return "Rain: guests gather at the sheltered breakfast terrace."
        case .wind:return "Wind: beach visitors return to sheltered areas."
        case .snow:return "Cold weather: guests stay near warm indoor spaces."
        case .sunny:return "Clear skies: guests visit the beach and pool during the afternoon."
        }
    }
    @discardableResult mutating func prepareHavenWeather()->Bool {
        guard havenExpansion != nil,!caught,expansion.preparedDay != day,simulation.stock["parts",default:0]>=2,cash>=10 else{return false}
        var e=expansion;e.preparedDay=day;havenExpansion=e
        var s=simulation;s.stock["parts",default:0]-=2;simulation=s;cash-=10
        logMoney(-10,category:"Weather preparation",note:"Equipment secured")
        playVisual("repair");expansionNote("Equipment secured, drains cleared and emergency supplies checked for today.");return true
    }
    func guestRoutine(_ guest:MotelGuest)->HavenRoutine {
        let hour=simulation.hour
        if hour>=21 || hour<8 {return .room}
        if hour<11 {return .breakfast}
        if weather != .sunny {return .shelter}
        if hour<12 {return .walk}
        if hour<18 {return .beach}
        return guest.holiday == .family ? .walk : .bar
    }
    func expansionWalkable(to tile:Tile)->Tile {
        if !groundBlocked(tile) {return tile}
        for radius in 1...5 {
            for dy in -radius...radius {for dx in -radius...radius where abs(dx)+abs(dy)==radius {
                let candidate=Tile(x:tile.x+dx,y:tile.y+dy)
                if !groundBlocked(candidate) {return candidate}
            }}
        }
        return groundNearestWalkable(to:tile)
    }
    func routineDestination(_ guest:MotelGuest,room:MotelRoom)->Tile {
        let id=abs(guest.id)%3
        let tile:Tile
        switch guestRoutine(guest) {
        case .room:return groundRoomDoor(room.id)
        case .breakfast,.shelter:tile=Tile(x:3+id,y:29)
        case .beach:tile=simulation.economy == .heatwave ? Tile(x:9,y:17+id) : Tile(x:57+id*2,y:50)
        case .bar:tile=Tile(x:65-id,y:17)
        case .walk:tile=Tile(x:40+id*3,y:33)
        }
        return expansionWalkable(to:groundTile(tile))
    }
    mutating func tickHavenRoutines() {
        guard havenExpansion != nil,managementEnabled,!caught else{return}
        refreshExpansionDay()
        var e=expansion
        let live=rooms.filter{$0.guest != nil && $0.id/9==viewingFloor}
        let ids=Set(live.compactMap{$0.guest?.id});e.routines=e.routines.filter{ids.contains($0.key)}
        var reserved=Set(worldState.travellers.map(\.player)+Array((worldState.guestPositions ?? [:]).values))
        reserved.formUnion(e.routines.values.map(\.tile))
        reserved.insert(groundTile(MotelGrounds.officeDoor));reserved.insert(groundTile(Tile(x:6,y:10)))
        if worldState.place == .grounds {reserved.insert(actorTile)}
        for room in live {
            guard let guest=room.guest,!worldState.travellers.contains(where:{$0.id==guest.id}) else{continue}
            let kind=guestRoutine(guest)
            if kind == .room && e.routines[guest.id]==nil {continue}
            let door=groundRoomDoor(room.id)
            var routine=e.routines[guest.id] ?? HavenRoutineGuest(tile:door,previous:door,activity:kind)
            routine.previous=routine.tile;routine.activity=kind
            reserved.remove(routine.tile)
            let target=routineDestination(guest,room:room)
            let step:Tile?
            if let danger=operationsState.incident?.tile,routine.tile.distance(to:danger)<12 {step=groundEscapeStep(from:routine.tile,danger:danger,avoiding:reserved)}
            else {step=groundNextStep(from:routine.tile,to:target,avoiding:reserved)}
            routine.tile=step ?? routine.tile
            reserved.insert(routine.tile)
            if kind == .room && routine.tile==door {e.routines.removeValue(forKey:guest.id)}
            else {e.routines[guest.id]=routine}
        }
        havenExpansion=e
        // Existing clerk can help the morning rush using actual cooked servings.
        if worldState.tick%12==0,operationsState.workers.contains(where:{$0.active && $0.role == .clerk}),!breakfastQueue.isEmpty {
            _=serveHavenBreakfast(byStaff:true)
        }
    }
    mutating func settleExpansionHour() {
        guard havenExpansion != nil else{return};refreshExpansionDay()
        var e=expansion
        guard e.weatherSettledHour != simulation.absoluteHour else{return}
        e.weatherSettledHour=simulation.absoluteHour
        var s=simulation
        if s.hour==12 {
            for room in rooms {
                guard let g=room.guest,!e.meals.contains(g.id),!e.missedMeals.contains(g.id) else{continue}
                e.missedMeals.insert(g.id);e.satisfaction[g.id,default:50]=max(0,e.satisfaction[g.id,default:50]-8)
            }
            e.buffet=0
            if weather == .storm && e.preparedDay != day,let i=rooms.indices.first {
                var h=rooms[i].health;h.condition=max(0,h.condition-8);h.faults.insert(.pipe);rooms[i].hospitality=h
                s.news="Storm damage: a drain overflowed. Prepare equipment before noon next time."
            }
        }
        for room in rooms {
            guard let guest=room.guest else{continue}
            if !room.health.faults.isEmpty || room.health.cleanliness<45 {e.satisfaction[guest.id,default:50]=max(0,e.satisfaction[guest.id,default:50]-3)}
            if s.economy == .heatwave,room.health.faults.contains(.ac),e.preparedDay != day {e.satisfaction[guest.id,default:50]=max(0,e.satisfaction[guest.id,default:50]-3)}
        }
        simulation=s;havenExpansion=e
    }
    var atBreakfastCounter:Bool {visit==nil && worldState.place == .grounds && actorTile.distance(to:groundTile(HotelService.breakfast.tile))<=2 && !isRidingBike}
    var breakfastOpen:Bool {(8...11).contains(simulation.hour)}
    var breakfastQueue:[MotelGuest] {
        guard breakfastOpen else{return []}
        return rooms.compactMap(\.guest).filter{!expansion.meals.contains($0.id)}.sorted{$0.id<$1.id}
    }
    @discardableResult mutating func cookHavenBreakfast()->Bool {
        guard havenExpansion != nil,!caught,atBreakfastCounter,breakfastOpen,expansion.buffet<=9,simulation.stock["snacks",default:0]>=3,cash>=6 else{return false}
        var s=simulation;s.stock["snacks",default:0]-=3;simulation=s;cash-=6
        var e=expansion;e.buffet+=3;havenExpansion=e
        logMoney(-6,category:"Breakfast",note:"Three fresh portions");playVisual("breakfast")
        expansionNote("Three fresh breakfast portions prepared. Serve guests before noon.");return true
    }
    @discardableResult mutating func serveHavenBreakfast(byStaff:Bool=false)->Bool {
        guard havenExpansion != nil,!caught,(byStaff || atBreakfastCounter),breakfastOpen,expansion.buffet>0,let guest=breakfastQueue.first,
              !byStaff || operationsState.workers.contains(where:{$0.active && $0.role == .clerk}) else{return false}
        var e=expansion;e.buffet-=1;e.meals.insert(guest.id);e.satisfaction[guest.id,default:50]=min(100,e.satisfaction[guest.id,default:50]+12);havenExpansion=e
        cash+=12;logMoney(12,category:"Breakfast",note:guest.name)
        countHavenGoal("breakfast");if !byStaff {playVisual("breakfast",target:groundTile(HotelService.breakfast.tile))}
        expansionNote(guest.name+" enjoyed breakfast. +12 coins.");return true
    }
    static let discoveries:[HavenDiscovery]=[
        .init(id:"shell-pearl",name:"Pearl shell",hint:"Search the east beach",tile:Tile(x:57,y:50),group:"shell"),
        .init(id:"shell-coral",name:"Coral shell",hint:"Search the south shore",tile:Tile(x:61,y:54),group:"shell"),
        .init(id:"shell-moon",name:"Moon shell",hint:"Search the cove at night",tile:Tile(x:55,y:54),group:"shell"),
        .init(id:"fish-silver",name:"Silver sardine",hint:"Fish at the cove on a clear day",tile:Tile(x:58,y:51),group:"fish"),
        .init(id:"fish-red",name:"Red snapper",hint:"Fish at the cove during rain",tile:Tile(x:58,y:51),group:"fish"),
        .init(id:"fish-gold",name:"Golden reef fish",hint:"Fish at the cove after 18:00",tile:Tile(x:58,y:51),group:"fish"),
        .init(id:"furniture-lamp",name:"Vintage lamp",hint:"Find a market treasure on weekday 1",tile:Tile(x:46,y:17),group:"furniture"),
        .init(id:"furniture-chair",name:"Carved beach chair",hint:"Find a market treasure after reaching Welcoming motel",tile:Tile(x:46,y:17),group:"furniture"),
        .init(id:"furniture-clock",name:"Coastal clock",hint:"Find a market treasure after reaching Coastal retreat",tile:Tile(x:46,y:17),group:"furniture"),
        .init(id:"keepsake-paw",name:"Tiny paw charm",hint:"Explore the neighborhood with a pet",tile:Tile(x:46,y:38),group:"keepsake"),
        .init(id:"keepsake-leaf",name:"Emerald leaf",hint:"Explore the neighborhood garden with a pet",tile:Tile(x:49,y:42),group:"keepsake"),
        .init(id:"keepsake-star",name:"Star pebble",hint:"Explore the beach with a pet",tile:Tile(x:60,y:50),group:"keepsake")
    ]
    func canFindDiscovery(_ item:HavenDiscovery)->Bool {
        guard havenExpansion != nil,!caught,visit==nil,worldState.place == .grounds,!isRidingBike,!expansion.discoveries.contains(item.id),
              actorTile.distance(to:expansionWalkable(to:groundTile(item.tile)))<=2 else{return false}
        if item.id=="shell-moon" {return simulation.hour>=19}
        if item.id=="fish-silver" {return weather == .sunny && simulation.hour<18}
        if item.id=="fish-red" {return weather == .rain || weather == .storm}
        if item.id=="fish-gold" {return simulation.hour>=18}
        if item.group=="furniture" {
            let tier=item.id=="furniture-clock" ? 2 : item.id=="furniture-chair" ? 1 : 0
            return havenWeekday==1 && expansion.tier>=tier && cash>=30
        }
        if item.group=="keepsake" {return exploringPet != nil}
        return true
    }
    @discardableResult mutating func findHavenDiscovery(_ id:String)->Bool {
        guard let item=Self.discoveries.first(where:{$0.id==id}),canFindDiscovery(item) else{return false}
        var e=expansion;e.discoveries.insert(id);havenExpansion=e
        if item.group=="furniture" {cash-=30;logMoney(-30,category:"Collection",note:item.name)}
        else {cash+=5;logMoney(5,category:"Discovery",note:item.name)}
        if item.group=="fish" {var s=simulation;s.stock["snacks",default:0]+=2;simulation=s}
        countHavenGoal("discover");playVisual(item.group=="fish" ? "garden" : "luggage")
        expansionNote("Discovered "+item.name+"! Added to your collection journal.");return true
    }
    var nearDiscovery:HavenDiscovery? {Self.discoveries.first{canFindDiscovery($0)}}
    var goalKeys:[String] {
        let rotations=[["welcome","clean","breakfast"],["repair","discover","welcome"],["breakfast","clean","discover"]]
        return rotations[max(0,day-1)%rotations.count]
    }
    func goalTarget(_ key:String)->Int {key=="breakfast" ? 2 : 1}
    func goalTitle(_ key:String)->String {
        switch key {case "welcome":return "Welcome a new guest";case "clean":return "Clean one room";case "repair":return "Complete a repair";case "breakfast":return "Serve two breakfasts";default:return "Find a new discovery"}
    }
    @discardableResult mutating func claimHavenGoal(_ key:String)->Bool {
        guard havenExpansion != nil,!caught,goalKeys.contains(key),!expansion.claimedGoals.contains(key),
              expansion.daily[key,default:0]>=goalTarget(key) else{return false}
        var e=expansion;e.claimedGoals.insert(key);havenExpansion=e;cash+=20
        var s=simulation;s.stock["parts",default:0]+=1;simulation=s
        logMoney(20,category:"Optional goal",note:goalTitle(key));expansionNote("Daily goal complete! +20 coins and one repair part.");return true
    }
}
