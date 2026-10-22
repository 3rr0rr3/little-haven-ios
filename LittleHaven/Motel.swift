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
