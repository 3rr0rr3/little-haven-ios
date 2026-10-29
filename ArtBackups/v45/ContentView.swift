import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}

struct ContentView: View {
    @State private var game = ContentView.initialGame()
    @State private var playing = ContentView.bypassTitle
    @State private var sessionID = UUID()
    @AppStorage("littlehaven.fullscreenTouch") private var fullscreenTouch = false
    @State private var townDirection:Tile?
    @State private var showTownOptions=false
    @AppStorage("littlehaven.hints") private var showHints = true
    private static var bypassTitle: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--ui-") }) && !ProcessInfo.processInfo.arguments.contains("--ui-title")
        #else
        return false
        #endif
    }
    @State private var conversation: Neighbor?
    @State private var message: String?
    @State private var showHouse = false
    @State private var showJournal = false
    @State private var reset = false
    @State private var heldDirection: Tile?
    @Environment(\.scenePhase) private var scenePhase
    private let stepDuration = 0.16
    private let cream = Color(hex: 0xF5E7C8)
    private let gold = Color(hex: 0xEFC977)

    private static func initialGame() -> Game {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-painted-check") {
            let actors=PaintedArt.creatures+["player","hildarelys","samhil","tuki","chichu","chichi","guest-a","guest-b","guest-c","guest-d","guest-a-beach","guest-b-beach","guest-c-beach","guest-d-beach"]
            for name in actors {for facing in 0..<4 {for step in [-1.0,0,1] {precondition(PaintedArt.frame(name,facing:facing,walk:step) != nil,"Missing painted sprite: "+name)}}}
            for name in ["stone-a","stone-b","timber","lantern","bedding","fence-h","desk","sofa-front","sofa-back","washer","linen","tv-frame","bath-sink","clothes-rack","extinguisher"] {precondition(PaintedArt.image("bh-"+name) != nil,"Missing scenery: "+name)}
        }
        Motel.randomizeGuestArrivals = !args.contains("--ui-testing")
        if args.contains(where:{$0.hasPrefix("--ui-")}) {UserDefaults.standard.removeObject(forKey:"littlehaven.compatibleOffice")}
        if args.contains(where:{$0.hasPrefix("--ui-")}) {UserDefaults.standard.set(args.contains("--ui-touch"),forKey:"littlehaven.fullscreenTouch");UserDefaults.standard.set(false,forKey:"littlehaven.hideFullscreenToolbar")}




        if args.contains(where:{$0.hasPrefix("--ui-occasion-")}) {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement();sample.motel!.initializeExpansion();sample.motel!.initializeKitchenGarden()
            sample.motel!.cash=500;sample.motel!.waiting=[];sample.motel!.operations!.nextIncidentTick=100000
            sample.motel!.havenOccasions=HavenOccasions();sample.motel!.world!.place = .office;sample.motel!.world!.player=Tile(x:4,y:5)
            var reputation=sample.motel!.simulation;reputation.reputation=80;sample.motel!.simulation=reputation
            sample.motel!.rooms[0].guest=Motel.arrivals(day:1,count:1,randomize:false)[0];sample.motel!.rooms[0].nightsLeft=3
            if args.contains("--ui-occasion-host") || args.contains("--ui-occasion-decor") {
                _=sample.motel!.acceptCelebration();_=sample.motel!.prepareCelebration(0);_=sample.motel!.prepareCelebration(2)
                var o=sample.motel!.occasions;o.celebration!.catered=true;sample.motel!.havenOccasions=o
                if args.contains("--ui-occasion-decor") {_=sample.motel!.hostCelebration()}
            }
            sample.save();return sample
        }

        if args.contains(where:{$0.hasPrefix("--ui-garden-") || $0.hasPrefix("--ui-outage-")}) {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement();sample.motel!.initializeExpansion();sample.motel!.initializeKitchenGarden()
            sample.motel!.cash=500;sample.motel!.waiting=[];sample.motel!.operations!.nextIncidentTick=100000
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:2,y:17)
            var k=sample.motel!.kitchen
            if args.contains("--ui-garden-harvest") {
                k.plots[0]=KitchenPlot(crop:.tomato,growth:2,wateredDay:1);k.harvested=["carrot"];k.harvests=1
            }
            if args.contains("--ui-garden-world") {
                k.plots[0]=KitchenPlot(crop:.tomato,growth:2,wateredDay:1)
                k.plots[1]=KitchenPlot(crop:.carrot,growth:1,wateredDay:1)
                k.plots[2]=KitchenPlot(crop:.basil,growth:1,wateredDay:1)
                sample.motel!.world!.player=Tile(x:2,y:20)
            }
            if args.contains("--ui-garden-kitchen") {
                k.pantry=["basil":3,"tomato":3,"carrot":3,"pepper":3]
                sample.motel!.world!.player=sample.motel!.groundTile(HotelService.breakfast.tile)
                sample.motel!.rooms[0].guest=Motel.arrivals(day:1,count:1,randomize:false)[0];sample.motel!.rooms[0].nightsLeft=2
            }
            sample.motel!.kitchenGarden=k
            if args.contains(where:{$0.hasPrefix("--ui-outage-")}) {
                sample.motel!.world!.player=Tile(x:12,y:16)
                var s=sample.motel!.simulation;s.powerOut=true
                s.hour=args.contains("--ui-outage-night") ? 22 : 12;sample.motel!.simulation=s
                sample.motel!.operations!.weatherOverride = .sunny
            }
            sample.save();return sample
        }

        if args.contains("--ui-beach-outfits") || args.contains("--ui-beach-outfits-street") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement();sample.motel!.initializeExpansion()
            sample.motel!.waiting=[];sample.motel!.operations!.nextIncidentTick=100000
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:54,y:48)
            var sim=sample.motel!.simulation;sim.hour=14;sample.motel!.simulation=sim
            let guests=Motel.arrivals(day:1,count:3,randomize:false)
            var life=sample.motel!.expansion
            for i in 0..<3 {
                sample.motel!.rooms[i].guest=guests[i];sample.motel!.rooms[i].nightsLeft=2
                let tile=Tile(x:53+i,y:49)
                life.routines[guests[i].id]=HavenRoutineGuest(tile:tile,previous:tile,activity:.beach)
            }
            sample.motel!.havenExpansion=life
            if args.contains("--ui-beach-outfits-street") {
                sample.motel!.world!.player=Tile(x:54,y:36)
                var state=sample.motel!.expansion
                for i in 0..<3 {let tile=Tile(x:53+i,y:37);state.routines[guests[i].id]=HavenRoutineGuest(tile:tile,previous:tile,activity:.walk)}
                sample.motel!.havenExpansion=state
            }
            sample.save();return sample
        }

        if args.contains(where:{$0.hasPrefix("--ui-expansion-")}) {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement();sample.motel!.initializeExpansion()
            sample.motel!.cash=5000;sample.motel!.waiting=[];sample.motel!.operations!.nextIncidentTick=100000
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=sample.motel!.groundTile(HotelService.breakfast.tile)
            if args.contains("--ui-expansion-breakfast") {
                let guests=Motel.arrivals(day:1,count:2,randomize:false)
                for i in 0..<2 {sample.motel!.rooms[i].guest=guests[i];sample.motel!.rooms[i].nightsLeft=2}
            }
            if args.contains("--ui-expansion-journey") {
                sample.motel!.guestsServed=5;var s=sample.motel!.simulation;s.reputation=50;sample.motel!.simulation=s
            }
            if args.contains("--ui-expansion-journal") {sample.motel!.world!.player=sample.motel!.groundNearestWalkable(to:Tile(x:57,y:50))}
            if args.contains("--ui-expansion-routines") {
                let guests=Motel.arrivals(day:1,count:3,randomize:false)
                for i in 0..<3 {sample.motel!.rooms[i].guest=guests[i];sample.motel!.rooms[i].nightsLeft=2}
                var sim=sample.motel!.simulation;sim.hour=14;sample.motel!.simulation=sim
                for _ in 0..<120 {sample.motel!.tickWorld()}
                sample.motel!.world!.player=Tile(x:57,y:50)
            }
            sample.save();return sample
        }

        if args.contains(where:{$0.hasPrefix("--ui-haven-")}) {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement();sample.motel!.initializeHavenLife()
            sample.motel!.cash=5000;sample.motel!.waiting=[];sample.motel!.operations!.nextIncidentTick=100000
            sample.motel!.world!.place = .grounds
            sample.motel!.world!.neighborPositions=[0:Tile(x:47,y:9)]
            sample.motel!.world!.player=Tile(x:47,y:10)
            if args.contains("--ui-haven-calendar") {sample.motel!.world!.player=sample.motel!.groundNearestWalkable(to:HavenActivity.market.location)}
            if args.contains("--ui-haven-creature") {
                sample.motel!.world!.place = .basement;sample.motel!.world!.player=BasementLayout.gate(0)
            }
            if args.contains("--ui-haven-glimmer") {
                sample.motel!.world!.place = .basement;sample.motel!.world!.player=BasementLayout.gate(0)
                _=sample.motel!.startCreatureAdventure(0)
                sample.motel!.world!.place = .grounds;sample.motel!.world!.player=sample.motel!.adventureTile(0)
            }
            if args.contains("--ui-haven-team") {
                sample.motel!.guestsServed=20;_=sample.motel!.hire(.cleaner);_=sample.motel!.hire(.security)
                var state=sample.motel!.haven
                state.employees[StaffRole.security.rawValue]=HavenEmployee(experience:3,requestDay:4)
                sample.motel!.havenLife=state;sample.motel!.day=4
            }
            sample.save();return sample
        }
        if args.contains("--ui-police-pursuit") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.cash=500;sample.motel!.world!.place = .office
            sample.motel!.world!.player=OfficeReception.clerk
            sample.motel!.operations=MotelOperations()
            sample.motel!.operations!.consequences=BusinessConsequences(police:PoliceCase(number:1,guest:"Test",cause:.fire,tile:Tile(x:7,y:7),acceptsBribe:false,map:"office"))
            sample.save();return sample
        }
        if args.contains("--ui-entrance-flow") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.waiting=Motel.arrivals(day:8,count:12,randomize:false)
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:10,y:11)
            let entrance=sample.motel!.groundTile(Tile(x:6,y:10))
            sample.motel!.world!.guestPositions=Dictionary(uniqueKeysWithValues:sample.motel!.waiting.map{($0.id,entrance)})
            for _ in 0..<90 {sample.motel!.tickWorld()}
            sample.motel!.operations!.nextIncidentTick=10000
            sample.save();return sample
        }
        if args.contains("--ui-counter") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.world!.place = .office;sample.motel!.world!.player=OfficeReception.clerk
            var visitor=OfficeVisitor(guest:sample.motel!.waiting[0]);visitor.phase = .waiting;visitor.pathIndex=OfficeVisitor.path.count-1
            sample.motel!.world!.reception!.visitor=visitor
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            sample.save();return sample
        }
        if let kind=ChaosKind.allCases.first(where:{args.contains("--ui-action-response-"+$0.rawValue)}) {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            for id in 0..<3 {_=sample.motel!.checkIn(guestID:10+id,roomID:id)}
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=kind.approach
            sample.motel!.operations=MotelOperations()
            sample.motel!.operations!.incident=MotelIncident(kind:kind,guest:sample.motel!.rooms[1].guest,otherGuest:sample.motel!.rooms[2].guest)
            sample.motel!.operations!.nextIncidentTick=10000
            sample.save();return sample
        }
        if args.contains("--ui-story") || args.contains("--ui-story-bar") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.cash=500;sample.motel!.prepareStoryArrivals()
            let guest=sample.motel!.waiting.first{$0.storyID == .musician}!
            var visitor=OfficeVisitor(guest:guest);visitor.phase = .waiting;visitor.pathIndex=OfficeVisitor.path.count-1
            sample.motel!.world!.reception!.visitor=visitor
            sample.motel!.world!.place = .office;sample.motel!.world!.player=OfficeReception.clerk
            sample.motel!.operations!.nextIncidentTick=100000
            if args.contains("--ui-story-bar") {
                _=sample.motel!.chooseGuestStory(guest,choiceID:1)
                sample.motel!.world!.place = .shop;sample.motel!.world!.shop = .bar
                sample.motel!.world!.player=ShopLayout.counter
                if args.contains("--ui-story-playing") {_=sample.motel!.startLanternShow()}
            }
            sample.save();return sample
        }
        if args.contains("--ui-creative") || args.contains("--ui-creative-moved") {
            var sample=Game();sample.coins=5000;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement();sample.motel!.cash=5000
            sample.motel!.guestsServed=20
            for role in StaffRole.allCases {_=sample.motel!.hire(role)}
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:12,y:8)
            if args.contains("--ui-creative-moved") {
                _=sample.motel!.relocateStructure("laundry",to:Tile(x:20,y:30))
                sample.motel!.world!.player=Tile(x:22,y:35)
            }
            sample.motel!.operations!.nextIncidentTick=10000;sample.save();return sample
        }
        if args.contains("--ui-bike") || args.contains("--ui-bike-riding") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.waiting=[];sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:15,y:32)
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-bike-riding") {_=sample.motel!.mountNearbyBike();sample.motel!.world!.player=Tile(x:20,y:34)}
            sample.save();return sample
        }
        if args.contains("--ui-fish") || args.contains("--ui-fish-exterior") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.cash=500;sample.motel!.waiting=[];sample.motel!.world!.place = .grounds
            sample.motel!.world!.player=NeighborhoodShop.fish.door
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-fish") {_=sample.motel!.enterShop(.fish);sample.motel!.world!.player=ShopLayout.counter}
            sample.save();return sample
        }
        if args.contains("--ui-action-checkin") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.world!.player=Tile(x:4,y:6)
            _=sample.motel!.checkIn(guestID:sample.motel!.waiting[0].id,roomID:0)
            sample.save();return sample
        }
        if args.contains("--ui-basement") || args.contains("--ui-home-stairs") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.waiting=[];sample.motel!.world!.place = .house
            sample.motel!.world!.player=Tile(x:2,y:13)
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-basement") {
                _=sample.motel!.enterBasement();sample.motel!.world!.player=Tile(x:12,y:23)
                for id in 0..<8 where args.contains("--ui-corral-\(id)") {sample.motel!.world!.player=BasementLayout.gate(id)}
            }
            sample.save();return sample
        }
        if args.contains("--ui-creature") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.waiting=[];sample.motel!.world!.place = .house;sample.motel!.world!.player=Tile(x:5,y:8)
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            sample.save();return sample
        }
        if args.contains("--ui-neighbors") || args.contains("--ui-chair") || args.contains("--ui-facilities") || args.contains("--ui-laundry") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.cash=900;sample.motel!.waiting=[];sample.motel!.world!.place = .grounds
            sample.motel!.world!.player=args.contains("--ui-neighbors") ? Tile(x:58,y:9) : args.contains("--ui-chair") ? BeachLayout.approach(0) : args.contains("--ui-laundry") ? Tile(x:12,y:8) : HotelService.repair.tile
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            for _ in 0..<12 {sample.motel!.tickWorld()}
            if args.contains("--ui-chair") {_=sample.motel!.sitOnBeachChair()}
            sample.save();return sample
        }
        if args.contains("--ui-bar") || args.contains("--ui-bar-exterior") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.cash=500;sample.motel!.waiting=[]
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=NeighborhoodShop.bar.door
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-bar") {
                _=sample.motel!.enterShop(.bar)
                sample.motel!.world!.player=ShopLayout.counter
            }
            sample.save();return sample
        }
        if args.contains("--ui-guest-favour") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.enableManagement();sample.motel!.cash=900
            sample.motel!.rooms[0].guest=Motel.arrivals(day:1,count:1)[0]
            sample.motel!.waiting=[];sample.motel!.world!.place = .grounds
            sample.motel!.world!.player=Tile(x:16,y:9)
            sample.motel!.operations!.nextIncidentTick=10000
            sample.save();return sample
        }
        if args.contains("--ui-beach") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.cash=2500;sample.motel!.waiting=[]
            sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:57,y:50)
            sample.motel!.operations=MotelOperations();sample.motel!.operations!.nextIncidentTick=10000
            for _ in 0..<20 {sample.motel!.tickWorld()}
            sample.save();return sample
        }
        if args.contains("--ui-motel-room") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld()
            sample.motel!.waiting=[];sample.motel!.rooms[0].guest=nil
            _=sample.motel!.enter(0);sample.motel!.visit!.player=Tile(x:4,y:6)
            sample.save();return sample
        }
        if args.contains("--ui-staff-posts") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.cash=5000
            sample.motel!.waiting=[];sample.motel!.world!.place = .grounds;sample.motel!.world!.player=Tile(x:12,y:23)
            sample.motel!.guestsServed=12
            for role in StaffRole.allCases {_=sample.motel!.hire(role)}
            sample.motel!.operations!.nextIncidentTick=10000
            sample.save();return sample
        }
        if args.contains(where:{$0.hasPrefix("--ui-management")}) {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement()
            sample.motel!.cash=6000
            var sim=sample.motel!.simulation;sim.reputation=75;sample.motel!.simulation=sim
            _=sample.motel!.checkIn(guestID:10,roomID:0)
            sample.motel!.rooms[1].dirty=true
            var health=sample.motel!.rooms[1].health;health.cleanliness=35;health.faults=[.pipe];sample.motel!.rooms[1].hospitality=health
            sample.motel!.world!.place = .office;sample.motel!.world!.player=Tile(x:3,y:3)
            sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-management-night") || args.contains("--ui-management-cameras") {
                var state=sample.motel!.simulation;state.hour=22;state.absoluteHour=22;state.facilities=[.cameras,.nightVision,.adjacentLot,.upperFloor];state.nightVision=args.contains("--ui-management-cameras");sample.motel!.simulation=state
                sample.motel!.injectIssue(.leak,roomID:0)
            }
            if args.contains("--ui-management-events") {
                sample.motel!.injectIssue(.outage,roomID:0);sample.motel!.injectIssue(.bedbugs,roomID:1)
                var state=sample.motel!.simulation;state.powerOut=true;sample.motel!.simulation=state
            }
            sample.save();return sample
        }
        if args.contains(where: { $0.hasPrefix("--ui-parking") || $0.hasPrefix("--ui-weather") || $0.hasPrefix("--ui-action") }) {
            var sample=Game()
            sample.coins=545; sample.wakeUp(); sample.motel!.initializeWorld()
            sample.motel!.cash=900
            sample.motel!.world!.place = .grounds
            sample.motel!.world!.player = Tile(x:18,y:32)
            for _ in 0..<8 { sample.motel!.tickManagement() }
            sample.motel!.operations!.nextIncidentTick=10000
            if args.contains("--ui-parking-staff") {
                sample.motel!.guestsServed=12
                _ = sample.motel!.hire(.valet)
                sample.motel!.operations!.workers[0].tile=HotelCar.approach(0)
                sample.motel!.operations!.workers[0].progress=3
            }
            for weather in HotelWeather.allCases where args.contains("--ui-weather-"+weather.rawValue) {
                sample.motel!.operations!.weatherOverride=weather
                sample.motel!.world!.player=Tile(x:9,y:23)
            }
            if args.contains("--ui-action-theft") {
                _ = sample.motel!.checkIn(guestID:10,roomID:0)
                _ = sample.motel!.enter(0); sample.motel!.visit!.player=Tile(x:2,y:4)
                _ = sample.motel!.steal()
            }
            if args.contains("--ui-action-wash") { _ = sample.motel!.washNearbyCar() }
            sample.save(); return sample
        }
        if args.contains("--ui-police") || args.contains("--ui-hiring") || args.contains("--ui-operations") || args.contains("--ui-chaos-fire") || args.contains("--ui-chaos-pool") || args.contains("--ui-chaos-fight") || args.contains("--ui-dialogue") {
            var sample = Game()
            sample.coins = 545; sample.wakeUp(); sample.motel!.initializeWorld()
            sample.motel!.waiting = []; sample.motel!.cash = 900
            if args.contains("--ui-hiring") || args.contains("--ui-operations") {sample.motel!.guestsServed=12}
            sample.motel!.operations = MotelOperations()
            if args.contains("--ui-operations") {
                sample.motel!.operations!.reviews = [GuestReview(id:"good",guest:"Robin",day:2,room:101,stars:5,text:"Lovely room and a peaceful stay!"),GuestReview(id:"bad",guest:"Sasha",day:2,room:102,stars:1,text:"The trouble outside spoiled my stay.")]
            }
            let kind: ChaosKind? = args.contains("--ui-chaos-fire") ? .fire : args.contains("--ui-chaos-pool") ? .pool : args.contains("--ui-chaos-fight") ? .fight : nil
            if let kind {
                sample.motel!.world!.place = .grounds
                sample.motel!.world!.player = kind.approach
                let guests=Motel.arrivals(day:1,count:4)
                sample.motel!.rooms[0].guest=guests[0]
                sample.motel!.rooms[1].guest=guests[1]
                sample.motel!.waiting=Array(guests.dropFirst(2))
                sample.motel!.operations!.incident = MotelIncident(kind:kind,guest:guests[0],otherGuest:guests[1])
                if args.contains("--ui-responder") {
                    sample.motel!.guestsServed=12
                    _=sample.motel!.hire(kind.responder)
                    sample.motel!.operations!.workers[0].tile=kind.approach
                    sample.motel!.world!.player=Tile(x:kind.approach.x+1,y:kind.approach.y)
                }
            }
            if args.contains("--ui-police") {
                _ = sample.motel!.checkIn(guestID:10,roomID:0)
                sample.motel!.rooms[0].guest = Motel.arrivals(day:1,count:1)[0]
                sample.motel!.operations!.incident = MotelIncident(kind:.pool,elapsed:89)
                sample.motel!.tickManagement()
                sample.motel!.operations!.consequences!.police!.tile = Tile(x:6,y:10)
                sample.motel!.operations!.consequences!.police!.arrived = true
                sample.motel!.operations!.consequences!.police!.acceptsBribe = false
            }
            sample.save()
            return sample
        }
        if args.contains("--ui-home-exterior") || args.contains("--ui-family-home") || args.contains("--ui-neighborhood") || args.contains("--ui-home-store") || args.contains("--ui-clothes-store") || args.contains("--ui-pawn-store") {
            var sample=Game();sample.coins=545;sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.cash=2500;sample.motel!.waiting=[]
            sample.motel!.world!.place = args.contains("--ui-family-home") ? .house : .grounds
            sample.motel!.world!.player = args.contains("--ui-family-home") ? Tile(x:7,y:12) : args.contains("--ui-home-exterior") ? Tile(x:54,y:17) : Tile(x:43,y:18)
            if args.contains("--ui-home-store") {sample.motel!.world!.player=NeighborhoodShop.furniture.door}
            if args.contains("--ui-clothes-store") {sample.motel!.world!.player=NeighborhoodShop.clothing.door}
            if args.contains("--ui-pawn-store") {sample.motel!.world!.player=NeighborhoodShop.pawn.door;sample.motel!.home=FamilyHome();sample.motel!.home!.stolen=[0,1,2]}
            if args.contains("--ui-store-inside") {
                let shop:NeighborhoodShop=args.contains("--ui-clothes-store") ? .clothing : args.contains("--ui-pawn-store") ? .pawn : .furniture
                _=sample.motel!.enterShop(shop);sample.motel!.world!.player=ShopLayout.counter
            }
            sample.motel!.home = sample.motel!.home ?? FamilyHome();sample.motel!.home!.storage=[.plant,.rug]
            for _ in 0..<12 {sample.motel!.tickWorld()}
            sample.save();return sample
        }
        if args.contains("--ui-office-preview") || args.contains("--ui-office-family") {
            var sample = Game()
            sample.coins = 545
            sample.wakeUp()
            sample.motel!.initializeWorld()
            if args.contains("--ui-office-family") { sample.motel!.waiting = [] }
            sample.save()
            return sample
        }
        if args.contains("--ui-fresh") {
            UserDefaults.standard.removeObject(forKey: "littlehaven.save.v1")
            return Game()
        }
        if args.contains(where: { $0.hasPrefix("--ui-world") || $0.hasPrefix("--ui-motel") || $0 == "--ui-wake" }) {
            var fresh = Game()
            fresh.coins = 545
            if !args.contains("--ui-wake") {
                fresh.wakeUp()
                fresh.motel!.initializeWorld()
                if args.contains("--ui-motel") {
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 12, y: 10)
                }
                if args.contains("--ui-world-clean") || args.contains("--ui-world-decor") {
                    fresh.motel!.world!.hasCleaningKit = true
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 16, y: 9)
                    fresh.motel!.rooms[0].dirty = args.contains("--ui-world-clean")
                    fresh.save()
                    _ = fresh.motel!.enter(0)
                    fresh.motel!.visit!.player = args.contains("--ui-world-clean") ? Tile(x: 4, y: 3) : Tile(x: 7, y: 3)
                    return fresh
                }
                if args.contains("--ui-world-build") {
                    fresh.motel!.cash = 600
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 12, y: 27)
                }
                if args.contains("--ui-motel-risk") || args.contains("--ui-motel-preview") {
                    _ = fresh.motel!.checkIn(guestID: 10, roomID: 0)
                    fresh.motel!.world!.place = .grounds
                    fresh.motel!.world!.player = Tile(x: 16, y: 9)
                    fresh.save()
                    _ = fresh.motel!.enter(0)
                    fresh.motel!.visit!.alert = args.contains("--ui-motel-risk") ? 98 : 10
                    return fresh
                }
            }
            fresh.save()
            return fresh
        }
        #endif
        StartupTrace.stage("checkpoint_read_begin")
        let loaded=Game.load()
        StartupTrace.stage("checkpoint_read_complete")
        return loaded
    }
    var body: some View {
        Group {
            if playing { gameplay.id(sessionID) }
            else {
                MotelTitleScreen(hasSave: UserDefaults.standard.data(forKey:"littlehaven.save.v1") != nil, start: {
                    StartupTrace.begin("continue game")
                    StartupTrace.stage("continue_checkpoint_read")
                    game = Game.load(); sessionID = UUID(); playing = true
                    StartupTrace.stage("continue_state_assigned")
                }, newGame: {
                    heldDirection = nil; conversation = nil; message = nil; showHouse = false; showJournal = false
                    game = Game(); game.save(); sessionID = UUID(); playing = true
                })
            }
        }.environment(\.returnToTitle, {
            heldDirection = nil; game.save(); playing = false
        }).onChange(of:scenePhase) { _, phase in if phase != .active { heldDirection = nil } }
        .statusBarHidden(fullscreenTouch && playing)
        .persistentSystemOverlays(fullscreenTouch && playing ? .hidden : .automatic)
        .onAppear { if ProcessInfo.processInfo.arguments.contains("--ui-title") { playing = false } }
    }
    private var gameplay: some View {
        Group {
            if game.motel != nil {
                AnyView(MotelView(game: $game))
            } else if game.readyToWake {
                WakeUpView {
                    StartupTrace.begin("wake button")
                    conversation = nil
                    heldDirection = nil
                    var firstShift = game
                    firstShift.wakeUp()
                    StartupTrace.stage("motel_created")
                    firstShift.motel?.reconcileInteriorSpawn()
                    StartupTrace.stage("world_prepared")
                    firstShift.motel?.enableManagement()
                    StartupTrace.stage("management_prepared")
                    firstShift.save()
                    StartupTrace.stage("checkpoint_written")
                    var transition = Transaction(animation:nil)
                    transition.disablesAnimations = true
                    withTransaction(transition) { game = firstShift }
                    StartupTrace.stage("hotel_state_assigned")
                }
            } else {
                townBody
            }
        }
    }


    private var touchTown:some View {
        ZStack {
            TownRPGView(game:game).ignoresSafeArea()
            VStack {
                HStack {
                    Text("BRAINSTORM HAVEN").font(.headline)
                    Spacer()
                    Button {townDirection=nil;showJournal=true} label:{Image(systemName:"book.closed.fill").padding(12)}.accessibilityLabel("Open journal")
                }.padding(10).background(Color(hex:0x172A25).opacity(0.9),in:RoundedRectangle(cornerRadius:16))
                Spacer()
                HStack(alignment:.bottom) {
                    FullscreenJoystick(diagonals:false) {townDirection=$0}
                        .disabled(conversation != nil || message != nil || showHouse || showJournal)
                    Spacer()
                    Button(game.atHouse ? "Cottage" : "Talk",action:interact).buttonStyle(MotelButtonStyle()).frame(width:160).accessibilityIdentifier("interact")
                }
            }.padding(16)
        }
        .foregroundStyle(cream).background(PaintedPanel(color:0x172A25))
        .task(id:townDirection != nil) {
            guard townDirection != nil else{return}
            defer {game.save()}
            let clock=ContinuousClock()
            while !Task.isCancelled,let direction=townDirection,scenePhase == .active,conversation == nil,message == nil,!showHouse,!showJournal {
                let inside=game.inside
                game.move(dx:direction.x,dy:direction.y)
                if game.inside != inside {townDirection=nil;return}
                do {try await clock.sleep(for:.seconds(0.14))} catch {return}
            }
        }
        .onChange(of:conversation != nil || message != nil || showHouse || showJournal) {_,paused in if paused {townDirection=nil}}
        .onChange(of:scenePhase) {_,phase in if phase != .active {townDirection=nil}}
        .onChange(of:fullscreenTouch) {_,_ in townDirection=nil}
        .onDisappear {townDirection=nil;game.save()}
    }
    private var townBody: some View {
        Group {
            if fullscreenTouch { touchTown } else { classicTown }
        }
        .sheet(item: $conversation) { person in
            dialogue(person)
                .presentationDetents([.height(340)]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showJournal) { journal.sheet(isPresented:$showTownOptions) {GameOptionsView()} }
        .alert("The Willow Cottage", isPresented: $showHouse) {
            if game.ownsHouse {
                Button("Go inside") { game.enterHouse(); game.save() }
            } else if game.coins >= Game.housePrice {
                Button("Buy for 500 coins") {
                    if game.buyHouse() { game.save(); message = "The key is yours! Your neighbors helped you find a home. Walk up to the cottage and tap ENTER to step inside." }
                }
            }
            Button("Keep exploring", role: .cancel) { }
        } message: {
            Text(game.ownsHouse ? "Your own little corner of Brainstorm Haven. Welcome home." : game.coins >= 500 ? "A sunny room, a warm bed, and a fresh start. Ready to make it yours?" : "FOR SALE / 500 coins\nYou need \(500 - game.coins) more. Ask the townspeople if they can help with your cottage fund.")
        }
        .alert("Brainstorm Haven", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Continue") { message = nil }
        } message: { Text(message ?? "") }
    }
    private var classicTown: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BRAINSTORM HAVEN").font(.system(size: 22, weight: .black, design: .rounded)).tracking(2)
                        Text(game.inside ? "YOUR COTTAGE / HOME AT LAST" : "WILLOW TOWN / A NEW BEGINNING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                            .foregroundStyle(cream.opacity(0.6))
                    }
                    Spacer(minLength: 4)
                    Button { stopMoving(); showJournal = true } label: { Image(systemName: "book.closed.fill").frame(width: 44, height: 44).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)) }
                        .accessibilityLabel("Open journal")
                }
                HStack {
                    Label("\(game.coins)", systemImage: "circle.circle.fill").font(.system(size: 21, weight: .heavy, design: .monospaced)).foregroundStyle(gold)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(game.ownsHouse ? "A PLACE TO CALL YOURS" : "COTTAGE FUND  \(game.coins) / 500")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                        ProgressView(value: game.ownsHouse ? 1 : min(Double(game.coins) / 500, 1)).tint(gold).frame(width: 160)
                    }
                }.padding(14).background(Color(hex: 0x283D36), in: RoundedRectangle(cornerRadius: 16))

                ZStack(alignment: .topLeading) {
                    TownRPGView(game: game)
                        .animation(.linear(duration: stepDuration), value: game.player)
                        .id(game.inside)
                    Text(game.inside ? "HOME, SWEET HOME" : "WILLOW TOWN")
                        .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1.5)
                        .padding(9).background(Color(hex: 0x203A30).opacity(0.9), in: Capsule()).padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(cream.opacity(0.15), lineWidth: 2))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("townMap")
                .accessibilityLabel(game.inside ? "Inside your cottage" : "Town map. Your position: column \(game.player.x), row \(game.player.y)")
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    Circle().fill(gold).frame(width: 5, height: 5)
                    Text(showHints ? hint : "").font(.system(size: 11, weight: .medium)).lineLimit(2)
                    Spacer(minLength: 0)
                }.frame(height: 28)

                HStack(alignment: .center) {
                    VStack(spacing: 3) {
                        direction("chevron.up", dx: 0, dy: -1, label: "Walk north")
                        HStack(spacing: 3) {
                            direction("chevron.left", dx: -1, dy: 0, label: "Walk west")
                            Image(systemName: "sparkle").foregroundStyle(cream.opacity(0.3)).frame(width: 40, height: 40)
                            direction("chevron.right", dx: 1, dy: 0, label: "Walk east")
                        }
                        direction("chevron.down", dx: 0, dy: 1, label: "Walk south")
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        Button(action: interact) {
                            VStack(spacing: 4) {
                                Image(systemName: game.atHouse ? "key.fill" : "bubble.left.fill").font(.system(size: 23))
                                Text(game.atHouse ? (game.ownsHouse ? "ENTER" : "COTTAGE") : "TALK").font(.system(size: 10, weight: .black, design: .monospaced))
                            }.frame(width: 94, height: 82).foregroundStyle(Color(hex: 0x243A30))
                                .background(gold, in: RoundedRectangle(cornerRadius: 26))
                        }.accessibilityIdentifier("interact")
                        Text("MEET YOUR NEIGHBORS").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(cream.opacity(0.5))
                    }
                }.frame(height: geometry.size.height < 700 ? 130 : 148).padding(.horizontal, 22)
            }.padding(.horizontal, 18).padding(.vertical, 10)
            .foregroundStyle(cream).background(PaintedPanel(color:0x172A25))
        }
        .task(id: heldDirection) {
            guard let direction = heldDirection else { return }
            while !Task.isCancelled && scenePhase == .active {
                do { try await Task.sleep(for: .seconds(stepDuration)) } catch { break }
                guard heldDirection == direction, !Task.isCancelled else { break }
                guard conversation == nil, message == nil, !showHouse, !showJournal else { break }
                let wasInside = game.inside
                game.move(dx: direction.x, dy: direction.y)
                if wasInside != game.inside { stopMoving(); break }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopMoving() }
        }
        .onDisappear { stopMoving() }

    }

    private var hint: String {
        if game.inside { return "You made it home. Walk down through the door to go outside." }
        if let person = game.nearby { return "\(person.name), the \(person.role.lowercased()) / Tap TALK" }
        if game.atHouse { return game.ownsHouse ? "Your cottage / Tap ENTER" : "Cottage for sale / Tap COTTAGE" }
        return game.coins >= 500 && !game.ownsHouse ? "Your fund is ready! Find the cottage in the northeast." : "Hold an arrow to walk. Stand beside a neighbor to TALK."
    }
    private func direction(_ symbol: String, dx: Int, dy: Int, label: String) -> some View {
        HoldDirection(symbol: symbol, label: label, isActive: heldDirection == Tile(x: dx, y: dy)) { pressed in
            let direction = Tile(x: dx, y: dy)
            if pressed {
                guard scenePhase == .active, conversation == nil, message == nil, !showHouse, !showJournal else { return }
                heldDirection = direction
                let wasInside = game.inside
                game.move(dx: dx, dy: dy)
                if wasInside != game.inside { stopMoving() }
            } else if heldDirection == direction {
                stopMoving()
            }
        } singleStep: {
            stopMoving()
            game.move(dx: dx, dy: dy)
            game.save()
        }
    }
    private func stopMoving() {
        townDirection = nil
        heldDirection = nil
        game.save()
    }
    private func interact() {
        stopMoving()
        if let person = game.nearby { conversation = person }
        else if game.atHouse { showHouse = true }
        else { message = game.inside ? "A little bed, a well-loved rug, and room for new memories. This is your home now." : "Move right next to a neighbor to talk. Look for the people with a gold dot above their heads. The cottage is in the northeast." }
    }
    private func dialogue(_ person: Neighbor) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PaperPortrait(color: person.color, variant: person.id).frame(width: 54, height: 62)
                VStack(alignment: .leading) {
                    Text(person.name).font(.title2.bold())
                    Text(person.role.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(gold)
                }
                Spacer()
                Button("Close") { conversation = nil }.tint(cream)
            }
            Text(game.gifts.contains(person.id) ? person.reply : person.greeting).font(.system(size: 17)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !game.gifts.contains(person.id) {
                Button {
                    _ = game.ask(person.id)
                    game.save()
                } label: { Text("Could you help me buy a house?").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(15) }
                    .foregroundStyle(Color(hex: 0x172A25)).background(gold, in: RoundedRectangle(cornerRadius: 14))
            } else {
                Label("\(person.gift) coins contributed / Thank you!", systemImage: "heart.fill").font(.subheadline.bold()).foregroundStyle(gold)
            }
        }.padding(24).foregroundStyle(cream).presentationBackground(Color(hex: 0x263D33))
    }
    private var journal: some View {
        NavigationStack {
            List {
                Section("A place to call home") {
                    Text(game.ownsHouse ? "You bought the Willow Cottage! Visit your home whenever you like." : "Raise 500 coins by asking the seven neighbors for help. Each can contribute once. Then a new chapter begins.")
                    Text("Press and hold a direction to keep walking. Release to stop. Stand one tile beside a person and tap TALK. Buildings, trees, and the pond block your way.")
                }
                Section("Your neighbors / \(game.gifts.count)/7") {
                    ForEach(Town.neighbors) { person in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(person.name + " / " + person.role).font(.headline)
                                Text("Column \(person.tile.x), row \(person.tile.y)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(game.gifts.contains(person.id) ? "+\(person.gift) OK" : "Say hello").foregroundStyle(gold).font(.caption.bold())
                        }
                    }
                }
                Section {
                    Text("Progress saves automatically on this device. All coins are fictional game currency.").font(.footnote)
                    Button("Save & return to title") { stopMoving(); showJournal = false; playing = false }
                    Button("Start a new adventure", role: .destructive) { reset = true }
                }
            }.navigationTitle("Your journal").toolbar {
                ToolbarItem(placement:.topBarLeading) {Button("Options") {showTownOptions=true}}
                ToolbarItem(placement:.topBarTrailing) {Button("Done") {showJournal=false}}
            }
                .confirmationDialog("Erase your saved adventure?", isPresented: $reset, titleVisibility: .visible) {
                    Button("Start over", role: .destructive) { game = Game(); game.save(); showJournal = false }
                }
        }.tint(gold)
    }
}

struct HoldDirection: View {
    @AppStorage("littlehaven.largeControls") private var largeControls = false
    let symbol: String
    let label: String
    let isActive: Bool
    let changed: (Bool) -> Void
    let singleStep: () -> Void

    var body: some View {
        DirectionTouchSurface(symbol:symbol,label:label,active:isActive,changed:changed,singleStep:singleStep)
            .frame(width:largeControls ? 50 : 44,height:largeControls ? 46 : 40)
            .onDisappear { changed(false) }
    }
}

/// A single native accessible control receives touch-down without gesture delays.
private struct DirectionTouchSurface: UIViewRepresentable {
    let symbol:String
    let label:String
    let active:Bool
    let changed:(Bool)->Void
    let singleStep:()->Void
    func makeUIView(context:Context)->DirectionTouchView { DirectionTouchView(frame:.zero) }
    func updateUIView(_ view:DirectionTouchView,context:Context) {
        view.changed=changed; view.singleStep=singleStep
        view.accessibilityLabel=label; view.accessibilityIdentifier=label
        view.accessibilityHint="Hold to walk. Release or slide off to stop. Activate to take one step."
        view.icon.image=UIImage(systemName:symbol,withConfiguration:UIImage.SymbolConfiguration(pointSize:16,weight:.black))
        view.backgroundColor=active ? UIColor(red:0.396,green:0.525,blue:0.420,alpha:1) : UIColor(red:0.204,green:0.294,blue:0.251,alpha:1)
    }
    static func dismantleUIView(_ view:DirectionTouchView,coordinator:()) { view.setHeld(false) }
}
private final class DirectionTouchView:UIControl {
    let icon=UIImageView()
    var changed:(Bool)->Void={_ in}
    var singleStep:()->Void={}
    private var held=false
    override init(frame:CGRect) {
        super.init(frame:frame)
        isAccessibilityElement=true; accessibilityTraits = .button
        icon.isAccessibilityElement=false
        icon.contentMode = .center
        icon.tintColor=UIColor(red:0.961,green:0.906,blue:0.784,alpha:1)
        addSubview(icon); layer.cornerRadius=10; clipsToBounds=true
    }
    required init?(coder:NSCoder) { fatalError("Use init(frame:)") }
    override func layoutSubviews() { super.layoutSubviews(); icon.frame=bounds }
    func setHeld(_ value:Bool) { guard held != value else{return};held=value;changed(value) }
    override func beginTracking(_ touch:UITouch,with event:UIEvent?)->Bool { setHeld(true);return true }
    override func continueTracking(_ touch:UITouch,with event:UIEvent?)->Bool { setHeld(bounds.contains(touch.location(in:self)));return true }
    override func endTracking(_ touch:UITouch?,with event:UIEvent?) { setHeld(false) }
    override func cancelTracking(with event:UIEvent?) { setHeld(false) }
    override func accessibilityActivate()->Bool { singleStep();return true }
    override func didMoveToWindow() { if window == nil { setHeld(false) } }
}


private struct TitleReturnKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
extension EnvironmentValues {
    var returnToTitle: () -> Void {
        get { self[TitleReturnKey.self] }
        set { self[TitleReturnKey.self] = newValue }
    }
}

struct GameOptionsView: View {
    @AppStorage("littlehaven.hideFullscreenToolbar") private var hideFullscreenToolbar = false
    @AppStorage("littlehaven.fullscreenTouch") private var fullscreenTouch = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("littlehaven.hints") private var hints = true
    @AppStorage("littlehaven.haptics") private var haptics = true
    @AppStorage("littlehaven.largeControls") private var largeControls = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    Text("MAKE YOURSELF AT HOME").font(.caption.monospaced().bold()).foregroundStyle(Color(hex:0xEFC977))
                    Text("Gameplay").font(.title2.monospaced().bold())
                    Toggle("Show gameplay hints", isOn: $hints).accessibilityIdentifier("optionHints")
                    Toggle("Action haptics", isOn: $haptics)
                    Toggle("Full screen / joystick controls", isOn: $fullscreenTouch).accessibilityIdentifier("optionFullscreenTouch")
                    Text("Fill the screen with the world. Move the visible joystick to walk and release it to stop. Tap nearby objects or use the action button.").font(.caption)
                    if fullscreenTouch {Toggle("Hide top toolbar",isOn:$hideFullscreenToolbar).accessibilityIdentifier("optionHideToolbar");Text("Tap the small eye button to restore the toolbar. Emergency alerts remain visible.").font(.caption)}
                    if !fullscreenTouch { Toggle("Larger D-pad buttons", isOn: $largeControls).accessibilityIdentifier("optionLargeControls") }
                    Divider().overlay(Color(hex:0xEFC977))
                    Text("Controls").font(.title2.monospaced().bold())
                    Text(fullscreenTouch ? "Move the joystick at the bottom left in the direction you want to walk. Release to stop. Map touches do not move your character. Use the action button at the bottom right to interact. Open Pause to change controls." : "Hold an arrow to walk. Release or slide off the button to stop. Nearby tasks never move your character; press their action button when you want to work.")
                    Text("Inside the office, walk freely and tap guests, the desk, tools, family, or the door to interact.")
                    Divider().overlay(Color(hex:0xEFC977))
                    Text("Saved game").font(.title2.monospaced().bold())
                    Text("Continue loads your last checkpoint. New Game starts from zero after confirmation. Save at the office before leaving. Quit closes the game session; use the Home gesture to leave the app.")
                    Button("Restore default options") { hints = true; haptics = true; largeControls = false; fullscreenTouch = false; hideFullscreenToolbar = false }
                        .buttonStyle(MotelButtonStyle(subdued:true))
                }.font(.subheadline).padding(22)
                    .background(Color(hex:0x29483D),in:RoundedRectangle(cornerRadius:16))
                    .overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xC6DDC8),lineWidth:2))
                    .padding(18)
            }.navigationTitle("Options")
                .background(PaintedPanel(color:0x172A25)).foregroundStyle(Color(hex:0xF5E7C8))
                .toolbarBackground(Color(hex:0x172A25),for:.navigationBar).toolbarBackground(.visible,for:.navigationBar)
                .toolbarColorScheme(.dark,for:.navigationBar)
                .toolbar { Button("Done") { dismiss() } }
        }.tint(Color(hex:0xEFC977))
    }
}

struct MotelTitleScreen: View {
    let hasSave: Bool
    let start: () -> Void
    let newGame: () -> Void
    @State private var options = false
    @State private var confirmNew = false
    @State private var confirmQuit = false
    @State private var closed = false
    private let cream = Color(hex:0xF5E7C8)
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MotelTitleLandscape().ignoresSafeArea()
                TimelineView(.animation(minimumInterval:0.16)) { timeline in
                    Canvas { context,_ in
                        context.scaleBy(x:3,y:3)
                        PaperPerson.draw(context:&context,x:4,y:9,color:0x6AACA3,variant:7,facing:0,walk:sin(timeline.date.timeIntervalSinceReferenceDate*3)*0.25)
                    }.frame(width:72,height:84)
                }.position(x:proxy.size.width*0.72,y:proxy.size.height*0.52).allowsHitTesting(false)
                Color.black.opacity(0.13).ignoresSafeArea()
                if closed {
                    VStack(spacing:24) {
                        Image(systemName:"moon.stars.fill").font(.system(size:48))
                        Text("See you soon").font(.largeTitle.bold())
                        Text("Your game session is closed.\nUse the Home gesture to leave the app.").multilineTextAlignment(.center)
                        menuButton("RETURN TO TITLE", tint:0x344B40, id:"returnTitle") { closed = false }
                    }.padding(28).background(Color(hex:0x29483D),in:RoundedRectangle(cornerRadius:16))
                        .overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xEFC977),lineWidth:3)).padding(24)
                } else {
                    VStack(spacing:12) {
                        VStack(spacing:0) {
                            Text("BRAINSTORM").font(.system(size:min(42,proxy.size.width*0.10),weight:.black,design:.rounded)).tracking(3)
                                .foregroundStyle(Color(hex:0xFFB4A4)).shadow(color:.red,radius:8)
                            Text("HAVEN").font(.system(size:min(36,proxy.size.width*0.082),weight:.heavy,design:.rounded)).tracking(2)
                                .foregroundStyle(Color(hex:0xB8F2EE)).shadow(color:.cyan,radius:8)
                            Text("A GAME OF HOSPITALITY").font(.system(size:11,weight:.bold,design:.monospaced)).tracking(1).padding(.top,8)
                        }.padding(20).background(Color(hex:0x193D43).opacity(0.96),in:RoundedRectangle(cornerRadius:20))
                            .overlay(RoundedRectangle(cornerRadius:20).stroke(Color(hex:0xA5E1DE),lineWidth:3)).padding(.top,12)
                        Spacer(minLength:20)
                        VStack(spacing:12) {
                            menuButton(hasSave ? "CONTINUE GAME" : "START GAME",tint:0x264E42,id:"startGame",action:start)
                            menuButton("NEW GAME",tint:0x45594A,id:"newGame") { confirmNew = true }
                            HStack(spacing:12) {
                                menuButton("OPTIONS",tint:0x4B495E,id:"titleOptions") { options = true }
                                menuButton("QUIT",tint:0x653C35,id:"titleQuit") { confirmQuit = true }
                            }
                        }.frame(maxWidth:460)
                        Text("BRAINSTORM HAVEN / YOUR NEXT SHIFT AWAITS").font(.system(size:9,weight:.bold,design:.monospaced)).shadow(color:.black,radius:3)
                        Text("VERSION \(StartupTrace.version)").font(.system(size:9,design:.monospaced)).accessibilityIdentifier("installedVersion")
                    }.padding(24)
                }
                if confirmQuit {
                    Color(hex:0x172A25).opacity(0.8).ignoresSafeArea()
                    VStack(spacing:20) {
                        Image(systemName:"key.fill").font(.system(size:34)).foregroundStyle(Color(hex:0xEFC977))
                        Text("END YOUR SHIFT?").font(.title2.monospaced().bold())
                        Text("Close this game session and return when you're ready for another shift.").multilineTextAlignment(.center)
                        menuButton("Quit session",tint:0x653C35,id:"confirmQuit") { confirmQuit = false; closed = true }
                        menuButton("Cancel",tint:0x344B40,id:"cancelQuit") { confirmQuit = false }
                    }.padding(24).background(Color(hex:0x29483D),in:RoundedRectangle(cornerRadius:16))
                        .overlay(RoundedRectangle(cornerRadius:16).stroke(Color(hex:0xEFC977),lineWidth:3)).padding(24)
                }
            }.foregroundStyle(cream)
        }.accessibilityIdentifier("titleScreen")
            .onAppear {
                StartupTrace.finish("title_visible")
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-options-preview") { options=true }
                if ProcessInfo.processInfo.arguments.contains("--ui-quit-preview") { confirmQuit=true }
                #endif
            }
            .sheet(isPresented:$options) { GameOptionsView() }
            .confirmationDialog("Start again from zero?",isPresented:$confirmNew,titleVisibility:.visible) {
                Button("Erase checkpoint and start new game",role:.destructive,action:newGame)
                Button("Cancel",role:.cancel) {}
            } message: { Text("Your current saved adventure will be replaced. Your options will be kept.") }
    }
    private func menuButton(_ title:String,tint:UInt32,id:String,action:@escaping ()->Void)->some View {
        Button(action:action) {
            Text(title).font(.system(size:16,weight:.black,design:.monospaced))
                .frame(maxWidth:.infinity,minHeight:50)
                .background(Color(hex:tint),in:RoundedRectangle(cornerRadius:5))
                .overlay(RoundedRectangle(cornerRadius:5).stroke(Color(hex:0xC6DDC8),lineWidth:2))
                .shadow(color:.black.opacity(0.45),radius:0,x:0,y:4)
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

/// Code-drawn courtyard, inspired by the supplied title-screen reference.
struct MotelTitleLandscape: View {
    var body: some View {
        Canvas { context,size in
            let w=size.width,h=size.height
            context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(Color(hex:0x91B86D)))
            for y in 0..<22 { for x in 0..<12 where (x+y)%2 == 0 {
                context.fill(Path(CGRect(x:CGFloat(x)*w/12,y:CGFloat(y)*h/22,width:w/12,height:h/22)),with:.color(Color(hex:0x82AA60).opacity(0.45)))
            }}
            var courtyard=Path()
            courtyard.move(to:CGPoint(x:w*0.12,y:h*0.32));courtyard.addLine(to:CGPoint(x:w*0.88,y:h*0.32))
            courtyard.addLine(to:CGPoint(x:w*1.1,y:h));courtyard.addLine(to:CGPoint(x:-w*0.1,y:h));courtyard.closeSubpath()
            context.fill(courtyard,with:.color(Color(hex:0xC9C49A)))
            let colors:[UInt32]=[0x91B8A8,0xDBA083,0x89B3A3,0xAD96C0,0x91B8A8,0xB19BC7]
            for i in 0..<6 {
                let bw=w*0.23,bh=h*0.105,x=w*(0.09+Double(i%3)*0.30),y=h*(i<3 ? 0.37:0.57)
                let r=CGRect(x:x,y:y,width:bw,height:bh)
                context.fill(Path(r),with:.color(Color(hex:colors[i])))
                context.fill(Path(CGRect(x:x-3,y:y-7,width:bw+6,height:bh*0.25)),with:.color(Color(hex:colors[i]).opacity(0.9)))
                for line in 0..<3 {
                    context.fill(Path(CGRect(x:x-3,y:y-7+CGFloat(line)*bh*0.08,width:bw+6,height:2)),with:.color(Color(hex:0x496957).opacity(0.6)))
                }
                context.fill(Path(CGRect(x:x+bw*0.37,y:y+bh*0.45,width:bw*0.24,height:bh*0.55)),with:.color(Color(hex:0x515649)))
                context.fill(Path(CGRect(x:x+bw*0.7,y:y+bh*0.43,width:bw*0.21,height:bh*0.26)),with:.color(Color(hex:0xB4D5CA)))
                context.fill(Path(CGRect(x:x+bw*0.08,y:y+bh*0.24,width:bw*0.84,height:bh*0.14)),with:.color(Color(hex:0x385549)))
                context.draw(Text("\(101+i) / GUEST").font(.system(size:7,weight:.bold,design:.monospaced)).foregroundColor(Color(hex:0xF5E7C8)),at:CGPoint(x:x+bw/2,y:y+bh*0.31))
                context.fill(Path(CGRect(x:x+bw*0.24,y:y+bh*1.22,width:bw*0.5,height:bh*0.12)),with:.color(Color(hex:0x9B7958)))
                for flower in 0..<5 {
                    context.fill(Path(ellipseIn:CGRect(x:x+bw*0.25+CGFloat(flower)*bw*0.09,y:y+bh*1.15,width:bw*0.07,height:bh*0.12)),with:.color(Color(hex:flower%2 == 0 ? 0xEAB7B4:0xEDD189)))
                }
            }
            for i in 0..<10 {
                let x=i%2 == 0 ? w*0.035:w*0.92,y=h*(0.12+Double(i/2)*0.16)
                context.fill(Path(CGRect(x:x+w*0.015,y:y+h*0.03,width:w*0.02,height:h*0.03)),with:.color(Color(hex:0x8F7950)))
                context.fill(Path(ellipseIn:CGRect(x:x-w*0.015,y:y,width:w*0.085,height:h*0.055)),with:.color(Color(hex:i%3 == 0 ? 0x527C48:0x628D4E)))
            }
        }.accessibilityHidden(true)
    }
}
