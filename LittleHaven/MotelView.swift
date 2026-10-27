import SwiftUI
import UIKit

struct WakeUpView: View {
    let begin: () -> Void
    @State private var awake = false
    var body: some View {
        ScrollView {
        VStack(spacing: 22) {
            Text(awake ? "7:00 AM / A NEW CHAPTER" : "THE DREAM FADES")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(3).foregroundStyle(Color(hex: 0xEFC977))
            ZStack {
                RoundedRectangle(cornerRadius: 32).fill(Color(hex: 0x435B52))
                VStack(spacing: 0) {
                    Text(awake ? "RING... RING..." : "Z z z").font(.caption.monospaced()).foregroundStyle(.white.opacity(0.6))
                    PaperPortrait(color: 0x6AACA3, variant: 7).frame(width: 95, height: 100).offset(y: awake ? 0 : 10)
                    RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0xB8C5A0)).frame(width: 140, height: 70)
                }
            }.frame(height: 245)
            Text("You wake up.\nThe keys were real.").font(.system(size: 31, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
            Text("The town, the coins, the little house... a dream.\nOn your desk: three room keys and the deed to a tired roadside Airb&b.\n\nYour first guests are already outside.")
                .font(.body).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button("Start my first shift", action: begin).buttonStyle(MotelButtonStyle()).accessibilityIdentifier("wakeUp")
        }.padding(28)
        }.foregroundStyle(Color(hex: 0xF5E7C8)).frame(maxWidth: .infinity, maxHeight: .infinity).background(PaintedPanel(color:0x172A25))
            .task {
                withAnimation(.easeInOut(duration: 1.5)) { awake = true }
                guard let attempt=StartupTrace.activeID else{return}
                StartupTrace.stage("wake_screen_visible")
                do {try await Task.sleep(for:.seconds(10))} catch {return}
                StartupTrace.finish("wake_screen_stable",ifID:attempt)
            }
    }
}
struct MotelButtonStyle: ButtonStyle {
    var subdued = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius:14))
            .foregroundStyle(Color(hex: subdued ? 0xF5E7C8 : 0x203B32))
            .background(PaintedPanel(color:subdued ? 0x385348 : 0xDCC08C).clipShape(RoundedRectangle(cornerRadius:14)))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private enum PauseDestination {case reviews,staff,creative,map,options}
private enum MotelPanel: Equatable { case guest(Int), paint(Int?), desk, construction, staff, reviews, roomUpgrades }
struct MotelView: View {
    @Binding var game: Game
    @Environment(\.returnToTitle) private var returnToTitle
    @AppStorage("littlehaven.fullscreenTouch") private var fullscreenTouch = false
    @AppStorage("littlehaven.hideFullscreenToolbar") private var hideFullscreenToolbar = false
    @State private var responseDuration = 0.0
    @State private var joystickDirection:Tile?
    @AppStorage("littlehaven.hints") private var showHints = true
    @AppStorage("littlehaven.haptics") private var haptics = true
    @State private var neighborhood: NeighborhoodShop?
    @State private var showHome = false
    @State private var showCreative = false
    @State private var showOptions = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var movement: Tile?
    @State private var working = false
    @State private var workProgress = 0.0
    @State private var panel: MotelPanel?
    @State private var selectedRoom: Int?
    @State private var showMap = false
    @State private var mapFocus:String?
    @State private var managementFocus:ManagementTab?
    @State private var showActionPicker=false
    @State private var pauseDestination:PauseDestination?
    @AppStorage("littlehaven.autoHideHUD") private var autoHideHUD=true
    @State private var showPause = false
    @State private var showManagement = false
    @State private var confirmRest = false
    @State private var confirmSneak: Int?
    @State private var showSneak = false
    @State private var confirmRestore = false
    @State private var toast: String?
    @State private var corral:Int?
    @State private var family: OfficeTap?
    @State private var showPolice = false
    @State private var showIncident = false
    @State private var expandedAlarm=false
    @State private var talkingRoom: Int?
    @State private var storyGuest: MotelGuest?
    @State private var showStoryJournal = false
    @State private var showHavenLife=false
    @State private var havenTab:HavenTab = .neighbors
    @State private var lifeAfterPause=false
    @State private var journalAfterPause=false
    private var motel: Motel { game.motel ?? Motel() }
    private var mapIdentity: String {motel.petMap}
    private let cream = Color(hex: 0xF5E7C8)
    private let gold = Color(hex: 0xEFC977)
    private var testingUI: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        return false
        #endif
    }
    private var paused: Bool { showActionPicker || pauseDestination != nil || showHavenLife || lifeAfterPause || journalAfterPause || storyGuest != nil || showStoryJournal || motel.policeRequiresDecision || responseDuration > 0 || showCreative || corral != nil || talkingRoom != nil || neighborhood != nil || showHome || showManagement || showOptions || showPolice || showIncident || family != nil || panel != nil || showMap || showPause || confirmRest || showSneak || confirmRestore }

    var body: some View {
        StartupTrace.stage("hotel_body_begin")
        let content=AnyView(hotelContent)
        StartupTrace.stage("hotel_content_constructed")
        return content
    }
    // Erase each small modifier group before building the next one. Erasing only
    // the final hotelContent still constructed the entire nested value on the
    // wake-button call stack (the final stage reported by the physical phone).
    // Keep these calls out of line in optimized builds as well as Debug builds.
    private var hotelContent: AnyView {
        var content=AnyView(MotelScreenSection(makeContent:makeHotelScreen))
        StartupTrace.stage("hotel_screen_deferred")
        content=hotelChrome(content)
        StartupTrace.stage("hotelChrome_constructed")
        content=hotelStartupTasks(content)
        StartupTrace.stage("hotelStartupTasks_constructed")
        content=hotelMovementTasks(content)
        StartupTrace.stage("hotelMovementTasks_constructed")
        content=hotelSimulationTasks(content)
        StartupTrace.stage("hotelSimulationTasks_constructed")
        content=hotelObservers(content)
        StartupTrace.stage("hotelObservers_constructed")
        content=hotelSheets(content)
        StartupTrace.stage("hotelSheets_constructed")
        return content
    }

    @inline(never) private func makeHotelScreen() -> AnyView {
        StartupTrace.stage("hotel_screen_begin")
        if motel.caught {
            StartupTrace.stage("hotel_game_over_begin")
            return AnyView(gameOver)
        }
        if fullscreenTouch {
            StartupTrace.stage("hotel_fullscreen_begin")
            let screen=AnyView(fullscreenWorld)
            StartupTrace.stage("hotel_fullscreen_constructed")
            return screen
        }
        StartupTrace.stage("hotel_standard_begin")
        let screen=AnyView(worldScreen)
        StartupTrace.stage("hotel_standard_constructed")
        return screen
    }

    @inline(never) private func hotelChrome(_ content:AnyView) -> AnyView {
        AnyView(content
        .sheet(isPresented:$showCreative) {
            CreativeModeView(motel:motel,move:{id,tile in
                var moved=false
                change {moved=$0.relocateStructure(id,to:tile)}
                if moved {game.save()}
                return moved
            },reset:{change{$0.resetCreativeLayout()};game.save()})
        }
        .foregroundStyle(cream).background(PaintedPanel(color:0x172A25))
        .overlay {
            if let police=motel.business.police,police.arrived {
                ZStack(alignment:.bottom) {
                    Color.black.opacity(0.3).ignoresSafeArea().contentShape(Rectangle()).onTapGesture {}
                    policeDialogue(police).padding(12)
                }.accessibilityAddTraits(.isModal)
            }
        }
        .overlay(alignment: .bottom) {
            Group {
                if let toast, !paused {
                    HotelNoticeCard(title: noticeTitle(toast), message: toast, symbol: noticeSymbol(toast), tint: noticeColor(toast))
                        .padding(.horizontal, 24).padding(.bottom, 180)
                }
            }.allowsHitTesting(false)
        }
        .transaction { if testingUI { $0.disablesAnimations = true } }
        )
    }

    @inline(never) private func hotelStartupTasks(_ content:AnyView) -> AnyView {
        AnyView(content
        .task {
            StartupTrace.stage("hotel_initialization_begin")
            change { $0.reconcileInteriorSpawn(); if !testingUI || ProcessInfo.processInfo.arguments.contains("--ui-management") { $0.enableManagement() } }
            StartupTrace.stage("hotel_initialization_complete")
            if motel.business.police?.arrived == true { showPolice=true }
            #if DEBUG
            if let kind=ChaosKind.allCases.first(where:{ProcessInfo.processInfo.arguments.contains("--ui-action-response-"+$0.rawValue)}) {
                change{_=$0.resolveNearbyIncident()};responseDuration=kind.responseDuration
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-dialogue") { family = .hildarelys }
            if ProcessInfo.processInfo.arguments.contains("--ui-menu-pause") {showPause=true}
            if ProcessInfo.processInfo.arguments.contains("--ui-menu-map") {showMap=true}
            if ProcessInfo.processInfo.arguments.contains("--ui-menu-staff") {managementFocus = .team;showManagement=true}
            if ProcessInfo.processInfo.arguments.contains("--ui-menu-purchases") {neighborhood = .furniture}
            for id in BasementLayout.residents where ProcessInfo.processInfo.arguments.contains("--ui-corral-\(id)") {corral=id}
            if ProcessInfo.processInfo.arguments.contains("--ui-creative-preview") {showCreative=true}
            if ProcessInfo.processInfo.arguments.contains("--ui-creature-portrait") { family = .mochi }
            if ProcessInfo.processInfo.arguments.contains("--ui-guest-dialogue") { talkingRoom=0 }
            if ProcessInfo.processInfo.arguments.contains("--ui-story-preview") { storyGuest=motel.receptionGuest }
            for (argument,tab) in [("--ui-occasion-inspection",HavenTab.inspections),("--ui-occasion-rival",.rival),("--ui-occasion-celebration",.celebrations),("--ui-occasion-host",.celebrations),("--ui-garden-plant",HavenTab.garden),("--ui-garden-harvest",.garden),("--ui-garden-kitchen",.garden),("--ui-expansion-breakfast",HavenTab.breakfast),("--ui-expansion-design",.rooms),("--ui-expansion-journey",.journey),("--ui-expansion-journal",.journal),("--ui-expansion-goals",.goals)] {
                if ProcessInfo.processInfo.arguments.contains(argument) {havenTab=tab;showHavenLife=true}
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-haven-neighbor") {havenTab = .neighbors;showHavenLife=true}
            if ProcessInfo.processInfo.arguments.contains("--ui-haven-team") {havenTab = .team;showHavenLife=true}
            if ProcessInfo.processInfo.arguments.contains("--ui-haven-calendar") {havenTab = .calendar;showHavenLife=true}
            if ProcessInfo.processInfo.arguments.contains("--ui-haven-creature") {corral=0}

            if ProcessInfo.processInfo.arguments.contains("--ui-police") { showPolice = true }
            if ProcessInfo.processInfo.arguments.contains("--ui-hiring") { panel = .staff }
            if ProcessInfo.processInfo.arguments.contains(where:{$0.hasPrefix("--ui-management-") && $0 != "--ui-management-night"}) {showManagement=true}
            #endif
        }
        .task {
            guard let attempt=StartupTrace.activeID else{return}
            StartupTrace.stage("hotel_mounted")
            do {try await Task.sleep(for:.seconds(10))} catch {return}
            StartupTrace.finish("hotel_stable",ifID:attempt)
        }
        )
    }

    @inline(never) private func hotelMovementTasks(_ content:AnyView) -> AnyView {
        AnyView(content
        .task(id:joystickDirection != nil) {
            guard fullscreenTouch,joystickDirection != nil else{return}
            let clock=ContinuousClock()
            while !Task.isCancelled,let direction=joystickDirection,!paused,!motel.caught,scenePhase == .active {
                change {$0.moveActor(dx:direction.x,dy:direction.y)}
                let interval=Duration.seconds(motel.isRidingBike ? (direction.x != 0 && direction.y != 0 ? 0.12 : 0.09) : (direction.x != 0 && direction.y != 0 ? 0.19 : 0.14))
                do {try await clock.sleep(for:interval)} catch {return}
            }
        }
        .onChange(of:fullscreenTouch) {_,_ in stop()}
        .task(id:responseDuration) {
            guard responseDuration > 0 else{return}
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-response-time") {return}
            #endif
            do {try await Task.sleep(for:.seconds(responseDuration))} catch {return}
            responseDuration=0
        }
        .task(id: movement) {
            guard let direction = movement else { return }
            let clock=ContinuousClock()
            let interval=Duration.seconds(direction.x != 0 && direction.y != 0 ? 0.19 : 0.14)
            var nextStep=clock.now+interval
            while !Task.isCancelled && movement == direction && scenePhase == .active && !motel.caught && !paused {
                do { try await clock.sleep(until:nextStep) } catch { break }
                guard movement == direction, !Task.isCancelled, !paused else { break }
                change { $0.moveActor(dx: direction.x, dy: direction.y) }
                nextStep=max(nextStep+interval,clock.now+interval/4)
            }
        }
        )
    }

    @inline(never) private func hotelSimulationTasks(_ content:AnyView) -> AnyView {
        AnyView(content
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            var ticks = 0
            while !Task.isCancelled && scenePhase == .active {
                do { try await Task.sleep(for: .seconds(MotelCadence.travel)) } catch { break }
                guard !Task.isCancelled, scenePhase == .active else { break }
                if !paused && !motel.caught {
                    ticks += 1
                    change { current in
                        if current.operationsState.incident != nil || ticks % 2 == 0 { current.tickWorld() }
                        if ticks % 2 == 0 && (current.isAtReception || current.isAtHome || current.reception.visitor != nil) { current.tickReception() }
                        if ticks % 6 == 0 && current.visit?.sneaking == true { current.tick() }
                        current.tickManagement(advanceClock:ticks % MotelCadence.businessSteps == 0)
                    }
                }
            }
        }
        .task(id: working) {
            guard working, motel.worldState.hasCleaningKit, let target = motel.cleaningTarget else { return }
            let start = motel.actorTile
            workProgress = 0
            let clock = ContinuousClock()
            let started = clock.now
            while workProgress < 1 {
                do { try await Task.sleep(for: .seconds(0.05)) } catch { workProgress = 0; return }
                guard !Task.isCancelled, working, !paused, scenePhase == .active,
                      motel.actorTile == start, motel.cleaningTarget == target else { workProgress = 0; return }
                let elapsed = started.duration(to: clock.now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                workProgress = min(1, seconds / 1.4)
            }
            change { _ = $0.cleanNearbyTask() }
            working = false
            workProgress = 0
        }
        .task(id: toast) {
            guard let text = toast else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled && toast == text { toast = nil }
        }
        )
    }

    @inline(never) private func hotelObservers(_ content:AnyView) -> AnyView {
        AnyView(content
        .onChange(of: motel.business.police?.arrived) { _, arrived in
            if arrived == true {
                stop();panel=nil;family=nil;talkingRoom=nil;corral=nil
                showIncident=false;showCreative=false;showManagement=false;showHome=false
                neighborhood=nil;showOptions=false;showPause=false;showMap=false;showActionPicker=false;pauseDestination=nil;lifeAfterPause=false;journalAfterPause=false
                confirmRest=false;showSneak=false;confirmRestore=false;showPolice=true
                game.save()
            }
        }
        .onChange(of: mapIdentity) { _, _ in stop() }
        .onChange(of: motel.actorTile) { _, _ in
            working=false;workProgress=0
            if fullscreenTouch,autoHideHUD,!paused {hideFullscreenToolbar=true}
        }
        .onChange(of: motel.caught) { _, caught in if caught { stop(); panel = nil } }
        .onChange(of: paused) { _, value in if value { stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
        .onDisappear { stop() }
        )
    }

    @inline(never) private func hotelSheets(_ content:AnyView) -> AnyView {
        let shared=AnyView(content
        .sheet(item:$storyGuest) { guest in GuestStoriesView(game:$game,guest:guest) }
        .sheet(isPresented:$showHavenLife) {HavenLifeView(game:$game,initialTab:havenTab)}
        .sheet(isPresented:$showStoryJournal) { GuestStoriesView(game:$game) }
        .sheet(item:$neighborhood) { shop in NeighborhoodStoreView(game:$game,shop:shop) }
        .sheet(isPresented:$showHome) { HomeDesignView(game:$game) }
        )
        return AnyView(shared
        .sheet(isPresented:$showManagement,onDismiss:{managementFocus=nil}) {
            ManagementHub(game:$game,initialTab:managementFocus).presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMap,onDismiss:{mapFocus=nil}) {
            MotelPocketMap(motel:motel,initialFocus:mapFocus).presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPause,onDismiss:{
            if lifeAfterPause {lifeAfterPause=false;showHavenLife=true}
            if journalAfterPause {journalAfterPause=false;showStoryJournal=true}
            if let destination=pauseDestination {
                pauseDestination=nil
                if !motel.policeRequiresDecision {
                    switch destination {
                    case .reviews:panel = .reviews
                    case .staff:panel = .staff
                    case .creative:showCreative=true
                    case .map:showMap=true
                    case .options:showOptions=true
                    }
                }
            }
        }) { pauseSheet.presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented:$showActionPicker) {
            NavigationStack {
                List {
                    Section("Nearby actions") {
                        ForEach(Array(motel.contextActions.enumerated()),id:\.offset) {_,action in
                            Button(motel.actionTitle(action)) {showActionPicker=false;performAction(action)}
                                .frame(minHeight:44).accessibilityIdentifier("chooseContext_"+motel.actionTitle(action))
                        }
                    }
                }.scrollContentBackground(.hidden).background(Color(hex:0x172F29))
                    .navigationTitle("Choose an action").navigationBarTitleDisplayMode(.inline)
                    .toolbar {ToolbarItem(placement:.topBarLeading){MenuBackButton {showActionPicker=false}}}
            }.tint(gold).presentationDetents([.medium,.large])
        }
        )
    }

    private var nearbyTouchActions:some View {
        ZStack {
                if motel.isRidingBike {
                    Button("Dismount bike") {stop();change{_=$0.dismountBike()}}.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("dismountBike")
                } else if let visitor=motel.homeNeighborIDs.first(where:{motel.isAtHome && motel.currentBedroom == nil && motel.actorTile.distance(to:motel.homeNeighborTile($0))<=2 && motel.neighborState($0).welcomedDay != motel.day}) {
                    Button("Welcome "+ResidentialLayout.names[visitor]) {stop();change{_=$0.welcomeHomeNeighbor(visitor)};game.save()}
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("welcomeHomeNeighbor")
                } else if motel.nearbyAdventureFind != nil {
                    Button("Collect the golden keepsake") {stop();change{_=$0.collectAdventureFind()};game.save()}
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("collectAdventureFind")
                } else if let id=motel.nearHavenNeighbor {
                    Button("Talk to "+ResidentialLayout.names[id]) {stop();havenTab = .neighbors;showHavenLife=true}
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("talkHavenNeighbor")
                } else if motel.nearHavenActivity {
                    Button(motel.todaysActivity?.title ?? "Weekly activity") {stop();havenTab = .calendar;showHavenLife=true}
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("openHavenActivity")
                } else if let pet=motel.exploringPet {
                    HStack(spacing:6) {
                        if !fullscreenTouch {
                            ForEach(motel.visiblePets.filter({motel.actorTile.distance(to:$0.value.tile)<=2}),id:\.key) { companion in
                                Button(motel.companionName(companion.key)) {stop();family=OfficeTap(rawValue:companion.key)}
                                    .buttonStyle(MotelButtonStyle(subdued:true))
                            }
                        }
                        Button(fullscreenTouch ? "Explore with "+motel.companionName(pet) : "Explore") {stop();change{_=$0.exploreWithPet()};game.save()}
                            .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("exploreWithPet")
                    }
                } else if motel.nearbyBike != nil {
                    Button("Ride bike") {stop();change{_=$0.mountNearbyBike()}}.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("rideBike")
                } else if motel.isRelaxing {
                    Button("Stand up") {stop();change{$0.standFromBeachChair()}}
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("standFromChair")
                } else if motel.nearbyBeachChair != nil {
                    Button("Sit and relax") {stop();change{_=$0.sitOnBeachChair()}}
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("sitOnChair")
                } else if let car = motel.nearbyCar {
                    Button("Clean bike / +35 coins") { stop(); change { _ = $0.washNearbyCar() } }
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("washCar")
                        .accessibilityHint("Parking bay \(car.slot+1)")
                } else if motel.canCollectGuestFavour {
                    Button("Collect guest supplies") { stop();change { _ = $0.collectGuestFavour() } }
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("collectGuestSupplies")
                } else if motel.nearKitchenPlot != nil {
                    Button("Tend garden plot") {stop();havenTab = .garden;showHavenLife=true}.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("openKitchenGarden")
                } else if let room=motel.nearbyHospitalityRoom {
                    Button("Talk to "+(room.guest?.name ?? "guest")) { stop();talkingRoom=room.id }
                        .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("talkToGuest")
                } else if let discovery=motel.nearDiscovery {
                    Button(discovery.group=="fish" ? "Fish at the cove" : "Discover "+discovery.name) {stop();change{_=$0.findHavenDiscovery(discovery.id)};game.save()}.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("collectDiscovery")
                } else if motel.havenExpansion != nil,motel.atBreakfastCounter {
                    HStack {
                        Button("Breakfast counter") {stop();havenTab = .breakfast;showHavenLife=true}.accessibilityIdentifier("openBreakfast")
                        Button("Garden kitchen") {stop();havenTab = .garden;showHavenLife=true}.accessibilityIdentifier("openGardenKitchen")
                    }.buttonStyle(MotelButtonStyle())
                } else if let service = motel.nearbyService {
                    Button(service.title + " / +\(service.reward) coins") {
                        stop(); change { _ = $0.performService(service) }
                    }.buttonStyle(MotelButtonStyle()).disabled(!motel.serviceAvailable(service))

                } else if motel.isAtReception {
                    HStack(spacing:10) {
                        Button("Front desk") { stop(); panel = .desk }.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("receptionDesk")
                        Button(motel.hiringUnlocked(.cleaner) ? "Hire employees" : "Staff unlocks • \(motel.guestsServed)/3 guests") { stop(); panel = .staff }.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("hireEmployees")
                    }
                } else if !fullscreenTouch && !motel.visiblePets.filter({motel.actorTile.distance(to:$0.value.tile)<=2}).isEmpty {
                    HStack {
                        ForEach(motel.visiblePets.filter({motel.actorTile.distance(to:$0.value.tile)<=2}), id: \.key) { pet in
                            Button(motel.companionName(pet.key)) { stop(); family=OfficeTap(rawValue:pet.key) }.buttonStyle(MotelButtonStyle(subdued:true))
                        }
                    }
                } else { Color.clear }
            }
    }
    private var fullscreenWorld:some View {
        ZStack {
            deferredScene.ignoresSafeArea()
                .environment(\.worldTouch,interactAtTouch)
                .allowsHitTesting(!paused)
            VStack(spacing:8) {
                if hideFullscreenToolbar {
                    HStack {
                        Spacer()
                        Button {hideFullscreenToolbar=false} label:{
                            Label("Menu",systemImage:"eye").font(.caption.bold()).padding(.horizontal,14).frame(minHeight:44)
                                .background(.ultraThinMaterial,in:Capsule())
                        }.buttonStyle(.plain).accessibilityLabel("Show top toolbar").accessibilityIdentifier("restoreFullscreenToolbar")
                    }
                } else {
                    HStack(spacing:12) {
                        VStack(alignment:.leading,spacing:3) {
                            Text(motel.mapName).font(.system(size:13,weight:.bold,design:.rounded)).lineLimit(1)
                            Text("DAY \(motel.day) · \(motel.clockLabel)").font(.system(size:10,design:.monospaced)).opacity(0.75)
                        }.accessibilityElement(children:.ignore).accessibilityLabel(motel.mapName)
                            .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).").accessibilityIdentifier("touchPosition")
                        Spacer(minLength:0)
                        Label("\(motel.cash)",systemImage:"circle.circle.fill").font(.subheadline.bold()).foregroundStyle(gold)
                            .accessibilityLabel("Cash \(motel.cash) coins").accessibilityIdentifier("motelCash")
                        Button {hideFullscreenToolbar=true} label:{Image(systemName:"eye.slash").frame(width:44,height:44)}
                            .accessibilityLabel("Hide top toolbar").accessibilityIdentifier("hideFullscreenToolbar")
                        Button {stop();showPause=true} label:{Image(systemName:"pause.fill").frame(width:44,height:44)}
                            .accessibilityLabel("Pause game").accessibilityIdentifier("fullscreenPause")
                    }.padding(.horizontal,12).padding(.vertical,5)
                        .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:18))
                }
                priorityAlerts
                Spacer()
                if working {ProgressView(value:workProgress).tint(gold)}
                nearbyTouchActions.fixedSize(horizontal:false,vertical:true)
                contextActionChooser
                HStack(alignment:.bottom) {
                    FullscreenJoystick(diagonals:true,direction:steer).disabled(paused || motel.caught)
                        .accessibilityValue("Column \(motel.actorTile.x), row \(motel.actorTile.y).")
                    Spacer()
                    if motel.nearbyAction != .none {actionButton.frame(width:160,height:82)}
                }
            }.padding(.horizontal,16).padding(.vertical,8)
            if motel.policeRequiresDecision {Color.black.opacity(0.25).ignoresSafeArea().contentShape(Rectangle()).onTapGesture {}}
            worldOverlay
        }
    }
    private func toolbarItem(_ title:String,symbol:String,id:String,action:@escaping ()->Void)->some View {
        Button {guard !motel.policeRequiresDecision else{return};stop();action()} label:{
            VStack(spacing:4) {
                Image(systemName:symbol).font(.system(size:16,weight:.semibold))
                Text(title).font(.system(size:8,weight:.semibold))
            }.frame(maxWidth:.infinity).frame(height:38)
        }.buttonStyle(.plain).accessibilityLabel(title == "Pause" ? "Pause game" : title == "Map" ? "Airb&b map" : title).accessibilityIdentifier(id)
    }
    private func steer(_ direction:Tile?) {
        guard !paused,!motel.caught,scenePhase == .active else{joystickDirection=nil;return}
        if direction != nil {movement=nil;working=false;workProgress=0}
        joystickDirection=direction
    }
    private func interactAtTouch(_ target:Tile,_ completion:(()->Void)?) {
        guard fullscreenTouch,!paused,!motel.caught else{return}
        stop()
        guard motel.canTouchInteract(at:target) else {toast="Move closer to interact.";return}
        completion?()
    }
    private var worldScreen: some View {
        VStack(spacing: 10) {
            HStack(spacing:10) {
                VStack(alignment:.leading,spacing:3) {
                    Text(motel.mapName).font(.system(size:18,weight:.bold,design:.rounded)).lineLimit(1)
                    Text("Day \(motel.day) · \(motel.clockLabel) \(motel.weather.title)").font(.system(size:10,design:.monospaced)).foregroundStyle(gold)
                }
                Spacer(minLength:0)
                Label("\(motel.cash)",systemImage:"circle.circle.fill").font(.headline).foregroundStyle(gold)
                    .accessibilityElement(children:.ignore).accessibilityLabel("Cash \(motel.cash) coins").accessibilityIdentifier("motelCash")
                Button {stop();showPause=true} label:{Image(systemName:"pause.fill").frame(width:44,height:44)}
                    .accessibilityLabel("Pause game").accessibilityIdentifier("standardPause")
            }
            priorityAlerts
            deferredScene
                .allowsHitTesting(!paused)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(cream.opacity(0.18), lineWidth: 1))
                // Notifications must not participate in the map's layout or move its touch targets.
                .overlay {if motel.policeRequiresDecision {Color.black.opacity(0.25).contentShape(Rectangle()).onTapGesture {}}}
                .overlay(alignment: .bottom) { worldOverlay }
                .frame(maxHeight: .infinity)
            if let visit = motel.visit, visit.sneaking {
                HStack {
                    Text("SUSPICION").font(.system(size: 9, weight: .black, design: .monospaced))
                    ProgressView(value: Double(visit.alert), total: 100).tint(visit.alert >= 70 ? .red : gold)
                    Text("\(visit.alert)%").font(.caption.monospaced().bold())
                    Text("+\(visit.pocket)").font(.caption.monospaced().bold()).foregroundStyle(gold)
                }
            } else if let visit = motel.visit, let room = motel.rooms.first(where: { $0.id == visit.roomID }), room.dirty {
                HStack {
                    Label("CLEANING", systemImage: "sparkles").font(.system(size: 9, weight: .black, design: .monospaced))
                    ProgressView(value: working ? workProgress : Double(room.cleanedTasks?.count ?? 0) / 3).tint(gold)
                    Text("\(room.cleanedTasks?.count ?? 0)/3").font(.caption.monospaced().bold())
                }
            }
            Text(showHints ? (motel.isAtReception ? "Walk freely. Tap guests, family and office objects to interact." : hint) : "").font(.system(size: 11, weight: .medium)).foregroundStyle(cream.opacity(0.8)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 29, alignment: .leading)
            nearbyTouchActions.frame(height:44).clipped()
            contextActionChooser
            HStack(spacing: 16) {
                MotelJoystick(direction: { direction in
                    if let direction, !paused && !motel.caught {
                        guard movement != direction else { return }
                        movement = direction
                        change { $0.moveActor(dx: direction.x, dy: direction.y) }
                    } else if direction == nil { movement = nil }
                }, active: movement, step: { direction in
                    stop()
                    if !paused && !motel.caught { change { $0.moveActor(dx: direction.x, dy: direction.y) } }
                })
                Spacer(minLength: 0)
                VStack(spacing: 7) {
                    actionButton
                    Label(motel.worldState.hasCleaningKit ? "MOP + FRESH SHEETS" : "GET TOOLS IN OFFICE", systemImage: "sparkles")
                        .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(cream.opacity(0.6))
                }.frame(width: 160)
            }.frame(height: 150).padding(.horizontal, 8)
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }


    // Persistent safety alerts remain visible until the actual incident is resolved.
    // They do not present a modal or stop movement until the player taps Respond.
    @ViewBuilder private var priorityAlerts:some View {
        if let incident=motel.operationsState.incident {
            VStack(alignment:.leading,spacing:5) {
                Button {stop();showIncident=true} label:{
                    VStack(alignment:.leading,spacing:3) {
                        HStack(spacing:8) {
                            Image(systemName:incident.kind == .fire ? "flame.fill" : incident.kind == .pool ? "figure.pool.swim" : "exclamationmark.shield.fill").font(.title2)
                            VStack(alignment:.leading,spacing:3) {
                                Text("EMERGENCY").font(.system(size:8,weight:.black)).tracking(1)
                                Text(incident.kind.title).font(.subheadline.bold())
                                if expandedAlarm {Text("Motel grounds · Column \(incident.tile.x), row \(incident.tile.y)").font(.caption2)}
                            }
                            Spacer(minLength:0)
                            Text("\(incident.remaining)s").font(.headline.monospaced())
                        }
                        ProgressView(value:Double(incident.remaining),total:Double(incident.limit)).tint(.white)
                        if incident.remaining<=20 {Text("CRITICAL · Respond now").font(.caption2.bold())}
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("incidentAlarm")
                HStack(spacing:9) {
                    Button {stop();mapFocus="incident";showMap=true} label:{Label("Map",systemImage:"map.fill")}
                        .accessibilityIdentifier("emergencyShowLocation")
                    Button {stop();change{_=$0.dispatchEmergencyResponder()}} label:{Label("Send staff",systemImage:"person.fill.checkmark")}
                        .disabled(motel.emergencyDispatchReason != nil).accessibilityIdentifier("emergencyDispatch")
                    Button {expandedAlarm.toggle()} label:{Image(systemName:expandedAlarm ? "chevron.up" : "info.circle").frame(minWidth:44,minHeight:44)}.accessibilityLabel("Emergency details")
                }.font(.caption2.bold()).buttonStyle(.bordered).controlSize(.small).frame(minHeight:44)
                if expandedAlarm,let reason=motel.emergencyDispatchReason {Text(reason).font(.caption2).fixedSize(horizontal:false,vertical:true)}
            }.padding(8).foregroundStyle(.white).tint(.white)
                .background(Color(hex:incident.remaining<=20 ? 0xA51F30 : 0x923D31),in:RoundedRectangle(cornerRadius:15))
        } else if let police=motel.business.police {
            Button {stop();showPolice=true} label:{HotelNoticeCard(title:police.arrived ? "POLICE HERE" : "OFFICER ON THE WAY",message:police.arrived ? "Speak to the officer to settle your case" : "An officer is looking for you",symbol:"light.beacon.max.fill",tint:Color(hex:0xF4BA9E))}
                .buttonStyle(.plain).accessibilityIdentifier("policeAlarm")
        } else if let room=motel.rooms.first(where:{$0.squatters == true}) {
            Button {stop();mapFocus="care-\(room.id)";showMap=true} label:{
                Label("Room \(room.number) · Squatters moved in. Clean the room.",systemImage:"person.2.fill").font(.caption.bold()).padding(9).frame(maxWidth:.infinity,alignment:.leading).background(Color(hex:0x80552E),in:RoundedRectangle(cornerRadius:10))
            }.buttonStyle(.plain).foregroundStyle(.white).accessibilityIdentifier("neglectAlarm")
        } else if motel.managementEnabled,let issue=motel.simulation.issues.first {
            VStack(spacing:4) {
                Button {stop();managementFocus = .events;showManagement=true} label:{
                    HotelNoticeCard(title:"ROOM \(motel.rooms.first(where:{$0.id==issue.roomID})?.number ?? issue.roomID) · NEEDS ATTENTION",message:issue.kind.title+" · \(max(0,issue.deadline-motel.simulation.absoluteHour)) hours left",symbol:"exclamationmark.bubble.fill",tint:gold)
                }.buttonStyle(.plain).accessibilityIdentifier("issueNotification")
                Button("Show request location") {stop();mapFocus="issue-\(issue.id)";showMap=true}.font(.caption.bold()).frame(minHeight:44).accessibilityIdentifier("issueShowLocation")
            }
        } else if motel.managementEnabled && (motel.simulation.powerOut || motel.simulation.waterOut) {
            Button {stop();managementFocus = .events;showManagement=true} label:{HotelNoticeCard(title:"SERVICE OUTAGE",message:"Review power and water under Overview → Events",symbol:"bolt.slash.fill",tint:gold)}
                .buttonStyle(.plain).accessibilityIdentifier("utilityNotification")
        }
    }
    @ViewBuilder private var contextActionChooser:some View {
        if motel.contextActions.count>1 {
            Button {stop();showActionPicker=true} label:{Label("Nearby actions (\(motel.contextActions.count))",systemImage:"list.bullet.circle")}
                .font(.caption.bold()).frame(minHeight:44).disabled(paused || motel.caught).accessibilityIdentifier("otherNearbyActions")
        }
    }
    private func noticeTitle(_ message:String)->String {
        let text=message.lowercased()
        if text.contains("saved") || text.contains("restored") {return "CHECKPOINT"}
        if text.contains("handled") || text.contains("completed") || text.contains("delivered") || text.contains("thanks you") {return "SUCCESS"}
        if text.contains("need") || text.contains("out of") || text.contains("cannot") || text.contains("fell") || text.contains("broken promise") {return "ATTENTION"}
        return "HOTEL UPDATE"
    }
    private func noticeSymbol(_ message:String)->String {
        switch noticeTitle(message) {
        case "CHECKPOINT":return "externaldrive.fill.badge.checkmark"
        case "SUCCESS":return "checkmark.circle.fill"
        case "ATTENTION":return "exclamationmark.triangle.fill"
        default:return "bell.badge.fill"
        }
    }
    private func noticeColor(_ message:String)->Color {
        noticeTitle(message) == "ATTENTION" ? Color(hex:0xEFC977) : Color(hex:0xA8D7BA)
    }

    private func policeDialogue(_ police: PoliceCase) -> some View {
        var choices: [DialogueChoice] = []
        if police.arrived {
            choices.append(DialogueChoice(title:"Pay fine / \(police.fine)",action:{ change { _ = $0.payPoliceFine() }; if motel.business.police == nil {showPolice=false};game.save() }))
            if !police.bribeTried && motel.cash >= 80 {
                choices.append(DialogueChoice(title:"Risk a bribe / 80",action:{ change { _ = $0.tryPoliceBribe() }; if motel.business.police == nil { showPolice = false };game.save() }))
            }
        }
        let detail = police.arrived ? "\(police.guest) died in the \(police.cause.rawValue) emergency. Your fine is \(police.fine) coins. Bribery may be refused and increase the fine. Unpaid fines are deducted from future room income. \(police.message)" : "An officer is looking for you and will approach wherever you are. You must settle the case when the officer speaks to you."
        let report=police.reason.map {police.arrived ? $0+" Fine: \(police.fine) coins. "+police.message : "An officer is on the way after complaints about night operations."} ?? detail
        return GameDialogue(speaker:"Officer Vega",text:report,portrait:AnyView(PaperPortrait(color:0x54739C,variant:0)),choices:choices,dismissible:!police.arrived) { if !police.arrived {showPolice=false} }
    }

    @ViewBuilder private var worldOverlay: some View {
                if let police=motel.business.police, showPolice && !police.arrived {
                    policeDialogue(police).padding(12)
                } else if let id=talkingRoom, let room=motel.rooms.first(where:{$0.id==id}), let guest=room.guest {
                    guestDialogue(room:room,guest:guest).padding(12)
                } else if let id=corral {
                    GameDialogue(speaker:BasementLayout.titles[id],text:motel.corralCare(id).fedDay == motel.day ? "Fresh food and water are ready. Your friend looks content in its own cozy corral." : "Your friend wanders around its decorated corral and watches you from the fence.",portrait:AnyView(CorralCreaturePortrait(kind:id+1)),choices:[
                        DialogueChoice(title:motel.corralCare(id).fedDay == motel.day ? "Fed today" : "Feed",action:{change{_=$0.careForCorral(id,feed:true)};corral=nil}),
                        DialogueChoice(title:"Pet",action:{change{_=$0.careForCorral(id,feed:false)};corral=nil}),
                        DialogueChoice(title:"Adventure & ability",action:{corral=nil;havenTab = .creatures;showHavenLife=true})
                    ]) {corral=nil}.padding(12)
                } else if let family {
                    GameDialogue(speaker:familyTitle,text:familyMessage,portrait:familyPortrait(family),choices:familyChoices(family)) { self.family = nil }.padding(12)
                } else if showIncident, let incident = motel.operationsState.incident {
                    GameDialogue(speaker:incident.kind.title,text:incident.kind.detail,portrait:AnyView(Image(systemName:"exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(gold)),choices:incidentChoices(incident.kind)) { showIncident = false }.padding(12)
                } else if showSneak {
                    GameDialogue(speaker:"Occupied room",text:"Keep away from the guest. Taking belongings makes noise. Get back to the door before you are caught.",portrait:AnyView(PaperPortrait(color:0xC7D0D4,variant:7)),choices:[DialogueChoice(title:"Enter quietly",action:{
                        if let id = confirmSneak { change { _ = $0.enter(id) } }
                        showSneak = false; confirmSneak = nil
                    })]) { showSneak = false; confirmSneak = nil }.padding(12)
                } else if confirmRest {
                    GameDialogue(speaker:"End the day?",text:"Guests check out, reviews arrive, and wages are paid. An ignored emergency can kill a guest. Police cases must be settled before sleeping. Your morning is saved.",portrait:AnyView(PaperPortrait(color:0xC7D0D4,variant:7)),choices:[DialogueChoice(title:"Sleep until morning",action:{
                        var rested=false;change {rested=$0.restAtBed()};confirmRest=false
                        if rested {game.save();toast="Morning checkpoint saved."} else {toast="Rest is available from 20:00 after police cases are settled."}
                    })]) { confirmRest = false }.padding(12)
                } else if confirmRestore {
                    GameDialogue(speaker:"Load checkpoint?",text:"Progress since your last save will be lost.",portrait:AnyView(PaperPortrait(color:0xC7D0D4,variant:7)),choices:[DialogueChoice(title:"Load last save",action:{ stop(); panel = nil; game = Game.load(); confirmRestore = false })]) { confirmRestore = false }.padding(12)
                } else if let panel {
                    interactionPanel(panel).modifier(RPGFrame()).padding(12)
                }
    }

    private var deferredScene: some View {
        MotelScreenSection {
            StartupTrace.stage("hotel_map_begin")
            let map=AnyView(scene)
            StartupTrace.stage("hotel_map_constructed")
            return map
        }
    }

    @ViewBuilder private var scene: some View {
        let tile = motel.actorTile
        if let visit = motel.visit, let room = motel.rooms.first(where: { $0.id == visit.roomID }) {
            MotelRPGView(motel: motel, workProgress: workProgress)
                .id(mapIdentity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(motel.mapName). Column \(tile.x), row \(tile.y).")
                .accessibilityValue("\(room.dirty ? "Cleaning \(room.cleanedTasks?.count ?? 0)/3" : "Ready for guests"). Theme \(room.theme). Furnishings \(room.furniture).")
                .accessibilityIdentifier("motelWorld")
        } else if let shop=motel.currentShop {
            ShopInteriorView(motel:motel,shop:shop,chat:{toast=$0},trade:{if motel.canTrade(shop) {performAction()} else {toast="Walk to "+shop.keeperName+"'s counter first."}},exit:{stop();var left=false;change{left=$0.leaveShop()};if !left {toast="Walk to the lower shop door first."}})
        } else if motel.isAtBasement {
            BasementView(motel:motel,corral:openCorral,exit:{stop();change{_=$0.leaveBasement()}}).id(mapIdentity)
        } else if let bedroom=motel.currentBedroom {
            HomeBedroomView(motel:motel,bedroom:bedroom,exit:{stop();change{_=$0.leaveBedroom()}},save:saveHere).id(mapIdentity)
        } else if motel.isAtHome {
            FamilyHouseView(motel:motel,tap:officeTap).id(mapIdentity)
        } else if motel.isAtReception {
            OfficeReceptionView(motel: motel, tap: officeTap).id(mapIdentity)
        } else {
            MotelRPGView(motel: motel)
                .id(mapIdentity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Airb&b GROUNDS. Column \(tile.x), row \(tile.y).")
                .accessibilityValue("\(motel.rooms.count) rooms. \(motel.worldState.travellers.count) guests walking to their destinations.")
                .accessibilityIdentifier("motelWorld")
        }
    }

    private var actionName:String {motel.actionTitle(motel.nearbyAction)}
    private var actionSymbol: String {
        switch motel.nearbyAction {
        case .incident: return "exclamationmark.triangle.fill"
        case .guest: return "bubble.left.fill"
        case .clean, .tools: return "sparkles"
        case .save, .desk: return "book.closed.fill"
        case .paint: return "paintbrush.fill"
        case .construction, .furniture: return "hammer.fill"
        case .rest: return "moon.zzz.fill"
        case .loot: return "hand.raised.fill"
        default: return "door.left.hand.open"
        }
    }
    private var actionButton: some View {
        WorkActionButton(title: actionName, symbol: actionSymbol, cleaning: motel.cleaningTarget != nil,
                         enabled: !paused && motel.nearbyAction != .none && (motel.cleaningTarget == nil || motel.worldState.hasCleaningKit),
                         progress: workProgress, pressed: { pressed in
            if pressed { stop() }
            working = pressed
        }, action:{performAction()}).accessibilityIdentifier("worldAction")
    }
    private var hint: String {
        if motel.isRelaxing {return "Relaxing by the sea. Stand up or move whenever you are ready."}
        switch motel.nearbyAction {
        case .bedroom(let bedroom):return "Enter "+bedroom.title+"."
        case .family(let person):return "Talk to "+person.capitalized+"."
        case .basement:return "Stairs to your basement sanctuary."
        case .corral(let id):return "Visit "+BasementLayout.titles[id]+" at its corral gate."
        case .computer: return "RECEPTION PC"
        case .pet: return "CALL PET"
        case .home: return "Your family home. Visit, decorate and upgrade with motel profits."
        case .homeDecor: return "Use the workbench to decorate or renovate. Bought furniture goes into storage."
        case .shop(let shop): return shop.detail
        case .incident: return motel.operationsState.incident?.kind.detail ?? "The grounds are quiet."
        case .guest(let id):
            let guest = motel.waiting.first { $0.id == id }
            return "\(guest?.name ?? "Guest") wants a room. Talk, choose a room and collect payment."
        case .room(let id):
            let room = motel.rooms.first { $0.id == id }
            return room?.guest != nil ? "Room \(101 + id) is occupied. Entering means sneaking." : "Room \(101 + id): \(room?.dirty == true ? "needs cleaning" : "ready"). Walk through the door."
        case .clean(let task): return motel.worldState.hasCleaningKit ? "\(MotelGrounds.cleaningNames[task]): hold the work button until it finishes." : "Get a cleaning kit from the TOOLS closet in your office."
        case .paint: return "Choose wall paint here. 25 coins per change."
        case .furniture: return "Upgrade the bed and room furnishings here to improve its nightly rate."
        case .desk: return "Your front desk: save a checkpoint or upgrade the office."
        case .save: return "Logbook: save your current Airb&b, guests and upgrades."
        case .rest: return "Your bed: end the day, handle checkouts and save the next morning."
        case .tools: return "Pick up a mop, fresh sheets and bin bags for cleaning."
        case .office: return "Office entrance. Walk through the door or tap ENTER."
        case .exit: return motel.currentBedroom != nil ? "Return to the living room through the lower door." : "Walk through the lower door to go outside."
        case .construction: return "Build room \(101 + motel.rooms.count) here for \(motel.expansionCost) coins."
        case .loot(let item): return "\(RoomVisit.lootNames[item]): +\(RoomVisit.lootValues[item]) value, +\(RoomVisit.lootNoise[item]) suspicion. Sell it at the pawn shop after escaping."
        case .none:
            if let shop=motel.currentShop {return "Browse the displays. Walk to "+shop.keeperName+"'s counter to buy or sell, and use the lower door to leave."}
            if motel.isAtBasement {return "Twelve private corrals. Walk along the central aisle to visit, feed, and pet each resident. Return upstairs at the south stairs."}
            if motel.isAtHome {return "Relax with your family and the animated TV. Use the workbench to arrange your furniture."}
            if motel.worldState.place == .grounds && BeachLayout.contains(motel.actorTile) {return "Sunset Cove: palms, umbrellas and beach chairs. Follow the sand; deep water is out of bounds."}
            if motel.visit?.sneaking == true { return "Avoid the guest. Take belongings and return to the door before suspicion reaches 100%." }
            if motel.visit != nil { return "Walk to the bed, trash or spill to clean. Paint cabinet is in the upper right." }
            return motel.worldState.place == .office ? "Move with the stick or hold an arrow. Desk, tools, paint, bed and logbook are physical objects." : "Explore the grounds. Guests wait outside the office. Room entrances lead inside."
        }
    }

    private func guestDialogue(room:MotelRoom,guest:MotelGuest)->some View {
        var choices=[DialogueChoice(title:"Ask about their stay",action:{change { _ = $0.greetGuest(room.id) };talkingRoom=nil})]
        if let id=guest.storyID {
            choices.insert(DialogueChoice(title:"Talk: "+id.title,action:{talkingRoom=nil;storyGuest=guest}),at:0)
        }
        let favour=motel.worldState.guestFavour
        if favour?.guestID == guest.id && favour?.status == .pending {
            if favour?.collected == true {
                choices.append(DialogueChoice(title:"Deliver supplies / +25 tip",action:{change { _ = $0.deliverGuestFavour(room.id) };talkingRoom=nil}))
            }
        } else if favour?.guestID == guest.id && favour?.status == .expired {
            choices.append(DialogueChoice(title:"Apologize and refund 20",action:{change { _ = $0.apologizeGuestFavour(room.id) };talkingRoom=nil}))
        } else if motel.canOfferGuestFavour(room.id) {
            choices.append(DialogueChoice(title:"Promise to bring "+GuestFavourKind.forGuest(guest.id).title,action:{change { _ = $0.acceptGuestFavour(room.id) };talkingRoom=nil}))
            choices.append(DialogueChoice(title:"Politely decline the request",action:{change { _ = $0.declineGuestFavour(room.id) };talkingRoom=nil}))
        }
        return GameDialogue(speaker:guest.name,text:motel.guestConversation(room.id),portrait:AnyView(PaperPortrait(color:guest.color,variant:guest.appearanceSeed)),choices:choices) { talkingRoom=nil }
    }

    private func openCorral(_ id:Int) {
        guard motel.isAtBasement,motel.actorTile.distance(to:BasementLayout.gate(id))<=1 else{toast="Walk to this corral's gate in the central aisle.";return}
        stop();corral=id
    }
    private func performAction(_ selected:MotelAction?=nil) {
        if let selected,!motel.contextActions.contains(selected) {toast="Move closer to that action.";return}
        guard !paused else { return }
        guard !motel.isRidingBike else{toast="Dismount your bike before interacting.";return}
        stop()
        if haptics { UIImpactFeedbackGenerator(style:.light).impactOccurred() }
        switch selected ?? motel.nearbyAction {
        case .bedroom(let bedroom):change{_=$0.enterBedroom(bedroom)}
        case .family(let person):family=OfficeTap(rawValue:person)
        case .basement:change{_=$0.enterBasement()}
        case .corral(let id):openCorral(id)
        case .home: change { _ = $0.useEntrance() }
        case .computer: showManagement=true
        case .pet(let id): family=OfficeTap(rawValue:id)
        case .homeDecor: showHome=true
        case .shop(let shop):
            if motel.isAtShop {neighborhood=shop} else {change {_=$0.enterShop(shop)}}
        case .incident: showIncident = true
        case .office, .exit: change { _ = $0.useEntrance() }
        case .room(let id):
            if motel.rooms.first(where: { $0.id == id })?.guest != nil { confirmSneak = id; showSneak = true }
            else { change { _ = $0.useEntrance() } }
        case .guest: toast = "Clients check in at reception. Tap the office door to return to your desk."
        case .construction: panel = .construction
        case .desk: panel = .desk
        case .save: saveHere()
        case .rest: confirmRest = true
        case .tools: change { _ = $0.collectTools() }
        case .paint(let roomID): panel = .paint(roomID)
        case .furniture: change { _ = $0.furnishNearby() }
        case .loot: change { _ = $0.steal() }
        case .none, .clean: break
        }
    }
    @ViewBuilder private func interactionPanel(_ selected: MotelPanel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {MenuBackButton(id:"closeInteraction") {panel=nil};Spacer();Text(panelTitle(selected)).font(.headline)}
            switch selected {
            case .guest(let id):
                if let guest = motel.waiting.first(where: { $0.id == id }) {
                    HStack {
                        PaperPortrait(color: guest.color, variant: guest.appearanceSeed).frame(width: 43, height: 55)
                        Text("Hello! My name is \(guest.name). \(guest.story) Could I stay for \(guest.nights) night\(guest.nights == 1 ? "" : "s")?").font(.caption)
                    }
                    if let story=guest.storyID {
                        Button("Talk: "+story.title) {storyGuest=guest}
                            .buttonStyle(MotelButtonStyle(subdued:true)).accessibilityIdentifier("openGuestStory")
                    }
                    if motel.managementEnabled {
                        Text(guest.kind.title+" / "+guest.kind.preference).font(.caption)
                        Button(motel.simulation.checkedIDs.contains(guest.id) ? "Identity verified" : "Verify guest identity") {change{$0.verifyGuest(guest.id)}}.disabled(motel.simulation.checkedIDs.contains(guest.id))
                        if let room=motel.rooms.first(where:{$0.id==selectedRoom}) {Text(motel.checkInExplanation(guest,room:room)).font(.caption2)}
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(motel.rooms.filter(\.available)) { room in
                                Button { selectedRoom = room.id } label: {
                                    VStack(spacing: 4) {
                                        RoomIllustration(theme: room.theme, level: room.furniture, office: false).frame(width: 70, height: 48)
                                        Text("\(room.number) / \(motel.bookingQuote(guest,room:room)) coins").font(.system(size: 10, weight: .bold))
                                    }.padding(7).background(selectedRoom == room.id ? gold.opacity(0.3) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                }.accessibilityIdentifier("chooseRoom\(room.id)")
                            }
                        }
                    }
                    Button("Accept guest & collect payment") {
                        if let roomID = selectedRoom { change { _ = $0.acceptReceptionGuest(roomID: roomID) } }
                        panel = nil
                    }.buttonStyle(MotelButtonStyle()).disabled(selectedRoom == nil || (motel.rooms.first{$0.id==selectedRoom}.map{!motel.mayCheckIn(guest,room:$0)} ?? true)).accessibilityIdentifier("chargeGuest")
                    Button("Decline politely") {
                        change { _ = $0.declineReceptionGuest() }; panel = nil
                    }.buttonStyle(MotelButtonStyle(subdued: true)).accessibilityIdentifier("declineGuest")
                    if selectedRoom == nil { Text("No clean, empty rooms. You can decline or return after preparing a room.").font(.caption) }
                }
            case .staff:
                StaffPanel(motel:motel) { role in change { _ = $0.hire(role) } }
            case .reviews:
                VStack(alignment:.leading,spacing:6) {
                    Text("Safety deaths: \(motel.business.deaths) / Lost daily bookings: \(motel.bookingPenalty) / Fine balance: \(motel.business.debt)").font(.caption)
                    ReviewsPanel(motel:motel)
                }
            case .roomUpgrades:
                RoomUpgradesPanel(motel:motel) { id in change { _ = $0.upgradeFromDesk(id) } }
            case .paint(let roomID):
                let current = roomID.flatMap { id in motel.rooms.first { $0.id == id }?.theme } ?? motel.officeTheme
                HStack {
                    ForEach(0..<4) { theme in
                        Button { change { _ = $0.paintNearby(theme) }; panel = nil } label: {
                            VStack(spacing: 4) {
                                Circle().fill(Color(hex: Motel.themeColors[theme])).frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(current == theme ? gold : .clear, lineWidth: 3))
                                Text(Motel.themeNames[theme]).font(.caption2)
                            }.frame(maxWidth: .infinity)
                        }.disabled(motel.cash < 25 || current == theme).accessibilityIdentifier("paint\(theme)")
                    }
                }
                Text("25 coins per color change.").font(.caption).foregroundStyle(gold)
            case .desk:
                HStack {
                    Button("Staff") { panel = .staff }.accessibilityIdentifier("deskStaff")
                    Button("Reviews") { panel = .reviews }.accessibilityIdentifier("deskReviews")
                    Button("Room upgrades") { panel = .roomUpgrades }.accessibilityIdentifier("deskRooms")
                }.font(.caption.bold()).foregroundStyle(gold).padding(.bottom,6)
                HStack {
                    Button("Save checkpoint", action: saveHere).buttonStyle(MotelButtonStyle()).accessibilityIdentifier("saveCheckpoint")
                    Button("Upgrade / \((motel.officeLevel + 1) * 120)") {
                        change { _ = $0.furnishNearby() }; panel = nil
                    }.buttonStyle(MotelButtonStyle(subdued: true)).disabled(motel.officeLevel >= 2 || motel.cash < (motel.officeLevel + 1) * 120)
                }
                Text("Office upgrades improve every room's nightly rate by 15 coins.").font(.caption)
            case .construction:
                HStack {
                    RoomIllustration(theme: 0, level: 0, office: false).frame(width: 88, height: 70).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Room \(101 + motel.rooms.count)\n\(motel.expansionCost) coins\n\(motel.rooms.count)/\(motel.expansionCapacity) rooms built").font(.subheadline.bold())
                }
                Button("Build this room") {
                    change { _ = $0.buildNearby() }; panel = nil
                }.buttonStyle(MotelButtonStyle()).disabled(motel.cash < motel.expansionCost || motel.goalReached).accessibilityIdentifier("buildRoom")
            }
        }
    }
    private func panelTitle(_ value: MotelPanel) -> String {
        switch value {
        case .guest(let id): return motel.waiting.first { $0.id == id }?.name ?? "Guest"
        case .paint(let id): return id.map { "Room \(101 + $0) paint" } ?? "Office paint"
        case .staff: return "Your team"
        case .reviews: return "Guest reviews"
        case .roomUpgrades: return "Room upgrades"
        case .desk: return "Front desk"
        case .construction: return "Airb&b expansion"
        }
    }
    private var pauseSheet:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    Text("Take a break").font(.title2.bold())
                    Text("Your game is paused. Choose what you need.").font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                        pauseTile("Map",symbol:"map.fill",id:"pauseMap",destination:.map)
                        pauseTile("Reviews",symbol:"star.bubble.fill",id:"openReviews",destination:.reviews)
                        pauseTile("Creative mode",symbol:"square.and.pencil",id:"openCreative",destination:.creative)
                        if !motel.operationsState.workers.isEmpty {pauseTile("Team",symbol:"person.2.fill",id:"openStaff",destination:.staff)}
                        pauseTile("Options",symbol:"gearshape.fill",id:"pauseOptions",destination:.options)
                    }
                    Button("Haven life & weekly activities") {havenTab = .neighbors;lifeAfterPause=true;showPause=false}.buttonStyle(MotelButtonStyle(subdued:true)).accessibilityIdentifier("openHavenLife")
                    Button("Guest stories") {journalAfterPause=true;showPause=false}.buttonStyle(MotelButtonStyle(subdued:true)).accessibilityIdentifier("guestStoriesJournal")
                    Divider()
                    Button("Load last checkpoint") {showPause=false;confirmRestore=true}.buttonStyle(MotelButtonStyle(subdued:true))
                    Button("Save & return to title") {stop();game.save();showPause=false;returnToTitle()}.buttonStyle(MotelButtonStyle(subdued:true)).accessibilityIdentifier("backToTitle")
                    Text("The reception computer holds Guests, Rooms, Staff and Finances. Your last section and room-board position are remembered.").font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.navigationTitle("Menu").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading){MenuBackButton {showPause=false}}}
                .foregroundStyle(cream).background(Color(hex:0x172A25))
        }.tint(gold).sheet(isPresented:$showOptions){GameOptionsView()}
    }
    private func pauseTile(_ title:String,symbol:String,id:String,destination:PauseDestination)->some View {
        Button {if case .options = destination {showOptions=true} else {pauseDestination=destination;showPause=false}} label:{
            VStack(alignment:.leading,spacing:11) {
                Image(systemName:symbol).font(.title2).foregroundStyle(gold)
                Text(title).font(.subheadline.bold()).foregroundStyle(cream)
            }.frame(maxWidth:.infinity,minHeight:78,alignment:.leading).padding(14)
                .background(Color.white.opacity(0.07),in:RoundedRectangle(cornerRadius:15))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityIdentifier(id)
    }
    private var gameOver: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "eye.fill").font(.system(size: 60)).foregroundStyle(Color(hex: 0xDE927D))
            Text("CAUGHT").font(.system(size: 46, weight: .black, design: .rounded)).tracking(5)
            Text("The guest saw you.").font(.title2.bold())
            Text("Load your last checkpoint to try again. Everything after that save is lost.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Load last save") { stop(); panel = nil; game = Game.load(); toast = "Checkpoint restored." }
                .buttonStyle(MotelButtonStyle()).accessibilityIdentifier("restoreCheckpoint")
            Spacer()
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: 0x2C292A))
    }
    private func familyPortrait(_ person: OfficeTap) -> AnyView {
        if person == .mochi {return AnyView(MochiPortrait())}
        if person == .chichu || person == .chichi { return AnyView(CatPortrait(gray:person == .chichu)) }
        return AnyView(PaperPortrait(color:person == .samhil ? 0xD88BAA : 0x292A2C,variant:person == .samhil ? 9 : 8))
    }
    private func familyChoices(_ person: OfficeTap) -> [DialogueChoice] {
        if person == .mochi {
            return [DialogueChoice(title:motel.petState("mochi").following ? "Stay here" : "Follow me",action:{change{$0.togglePet("mochi")};family=nil}),DialogueChoice(title:"Play",action:{toast="Tuki wiggles its little feet and chirps happily.";family=nil})]
        }
        if person == .chichu || person == .chichi {
            return [DialogueChoice(title:motel.petState(person.rawValue).following ? "Stay here" : "Follow me",action:{
                        change { $0.togglePet(person.rawValue) }; family=nil
                    }), DialogueChoice(title:"Pet",action:{ toast = "\(familyTitle) purrs happily."; family = nil }),
                    DialogueChoice(title:"Give a treat",action:{ toast = "\(familyTitle) enjoys a little treat."; family = nil })]
        }
        if person == .hildarelys { return [DialogueChoice(title:"Give her a kiss",action:{ toast = "Hildarelys smiles: We make a good team."; family = nil })] }
        return [DialogueChoice(title:"Watch together",action:{ toast = "You share a funny cartoon with Samhil."; family = nil })]
    }
    private func incidentChoices(_ kind: ChaosKind) -> [DialogueChoice] {
        if motel.nearbyIncident { return [DialogueChoice(title:kind.action,action:{
            let duration=kind.responseDuration
            change { _ = $0.resolveNearbyIncident() };showIncident=false;responseDuration=duration
        })] }
        if motel.isAtReception { return [DialogueChoice(title:"Go outside",action:{ change { _ = $0.leaveReception() }; showIncident = false })] }
        return []
    }

    private var receptionPrompt: Int? { motel.isAtReception ? motel.receptionGuest?.id : nil }
    private func openReceptionGuest(_ id: Int) {
        guard motel.isAtReception, motel.receptionGuest?.id == id else { return }
        stop(); selectedRoom = motel.rooms.first(where: \.available)?.id; panel = .guest(id)
    }
    private func officeTap(_ item: OfficeTap) {
        guard !paused, motel.isAtReception || motel.isAtHome else { return }
        stop()
        switch item {
        case .girlBedroom:change{_=$0.enterBedroom(.samhil)}
        case .parentsBedroom:change{_=$0.enterBedroom(.parents)}
        case .basement:change{_=$0.enterBasement()}
        case .door:
            change { value in
                if value.isAtHome {value.world!.place = .grounds;value.world!.player=Tile(x:value.groundTile(FamilyHome.door).x,y:value.groundTile(FamilyHome.door).y+1)}
                else {_=value.leaveReception()}
            }
        case .computer: showManagement=true
        case .workbench: if motel.actorTile.distance(to:FamilyHome.workbench)<=1 {showHome=true} else {toast="Walk to the workbench."}
        case .player: panel = .desk
        case .save: saveHere()
        case .tools: change { _ = $0.receptionTools() }
        case .paint: panel = .paint(nil)
        case .bed: confirmRest = true
        case .guest:
            if let guest = motel.receptionGuest { openReceptionGuest(guest.id) }
            else { toast = "The client is walking to the desk." }
        case .chichu, .chichi, .mochi, .samhil, .hildarelys: family = item
        }
    }
    private var familyTitle: String {
        switch family {
        case .chichu: return "Chichu"
        case .chichi: return "Chichi"
        case .mochi: return "Tuki"
        case .samhil: return "Samhil"
        case .hildarelys: return "Hildarelys"
        default: return "Family"
        }
    }
    private var familyMessage: String {
        switch family {
        case .chichu: return "Your gray tabby looks up with green eyes and gives a soft meow."
        case .mochi: return "Your little purple friend rocks on its berry-colored feet and gives a cheerful chirp. Want some company on your walk?"
        case .chichi: return "Chichi flicks her calico tail and waits for some attention."
        case .samhil: return "This cartoon is so funny! Can we watch another episode when you finish helping the guests?"
        case .hildarelys: return "I love our new home. Samhil and the cats are happy here. Come visit whenever you can."
        default: return ""
        }
    }
    private func saveHere() {
        guard motel.atSavePoint else { return }
        stop(); game.save(); panel = nil; toast = "Checkpoint saved."
    }
    private func stop() { movement = nil; working = false; workProgress = 0; joystickDirection=nil }
    private func change(_ action: (inout Motel) -> Void) {
        guard var current = game.motel else { return }
        let before = current.lastEvent
        let previousTile=current.actorTile
        let previousMap=current.petMap
        action(&current)
        current.updateCompanions(from:previousTile,map:previousMap)
        if current.lastEvent != before {
            var state = current.operationsState
            let event = current.lastEvent.lowercased()
            if (state.actionUntil ?? 0) <= state.tick {
                state.actionLabel = event.contains("fire") ? "??" : event.contains("pool") ? "?" : event.contains("fight") ? "?" : event.contains("paint") ? "?" : event.contains("clean") ? "?" : event.contains("room") ? "?" : "?"
                state.actionUntil = state.tick + 3
                current.operations = state
            }
        }
        if current.lastEvent != before && current.operationsState.visual?.id == game.motel?.operationsState.visual?.id {
            let message = current.lastEvent.lowercased()
            if message.contains("paint") { current.playVisual("paint") }
            else if message.contains("built") || message.contains("furnish") || message.contains("upgraded") { current.playVisual("build") }
            else if message.contains("tools collected") || message.contains("fresh sheets collected") { current.playVisual("laundry") }
        }
        game.motel = current
        if current.lastEvent != before { toast = current.lastEvent }
    }
}

private struct HotelNoticeCard:View {
    let title:String
    let message:String
    let symbol:String
    let tint:Color
    var body:some View {
        HStack(alignment:.top,spacing:10) {
            Image(systemName:symbol).font(.system(size:21,weight:.bold)).foregroundStyle(tint).frame(width:30)
            VStack(alignment:.leading,spacing:4) {
                Text(title).font(.system(size:10,weight:.black,design:.rounded)).tracking(0.8).foregroundStyle(tint)
                Text(message).font(.system(size:12,weight:.semibold)).foregroundStyle(Color(hex:0xF5E7C8))
                    .fixedSize(horizontal:false,vertical:true)
            }
            Spacer(minLength:0)
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color(hex:0x20392E).opacity(0.98),in:RoundedRectangle(cornerRadius:13))
            .overlay(RoundedRectangle(cornerRadius:13).stroke(tint.opacity(0.65),lineWidth:1))
            .accessibilityElement(children:.combine)
    }
}

private struct CreativeModeView:View {
    let motel:Motel
    let move:(String,Tile)->Bool
    let reset:()->Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected:String?
    @State private var destination:Tile?
    @State private var message="Hold a structure, then drag it to open ground."
    @State private var zoom=0.75
    @State private var source:UIImage?
    @State private var confirmReset=false
    private var selectedObject:CreativeStructure? {motel.creativeStructures.first{$0.id==selected}}
    var body:some View {
        NavigationStack {
            VStack(spacing:8) {
                HStack {
                    Image(systemName:"hand.draw.fill").foregroundStyle(Color(hex:0xEFC977))
                    Text(message).font(.system(size:12,weight:.medium,design:.rounded))
                    Spacer()
                }.padding(.horizontal)
                HStack {
                    Picker("Structure",selection:$selected) {
                        Text("Choose an object").tag(String?.none)
                        ForEach(motel.creativeStructures) {item in Text(item.title).tag(Optional(item.id))}
                    }.accessibilityIdentifier("creativeObjectPicker")
                    Spacer()
                    Button {zoom=max(0.4,zoom-0.15)} label:{Image(systemName:"minus.magnifyingglass")}
                    Button {zoom=min(1.5,zoom+0.15)} label:{Image(systemName:"plus.magnifyingglass")}
                }.padding(.horizontal)
                ScrollView([.horizontal,.vertical]) {
                    ZStack(alignment:.topLeading) {
                        if let source {
                            Image(uiImage:source).resizable()
                                .frame(width:1152,height:1024)
                        }
                        ForEach(motel.creativeStructures.filter{$0.parent==nil}) {item in objectHandle(item)}
                        ForEach(motel.creativeStructures.filter{$0.parent != nil}) {item in objectHandle(item)}
                        if let item=selectedObject,let destination {
                            Rectangle().fill(Color(hex:0xEFC977).opacity(0.28))
                                .overlay(Rectangle().stroke(Color(hex:0xEFC977),style:StrokeStyle(lineWidth:2,dash:[4])))
                                .frame(width:CGFloat(item.footprint.width*16),height:CGFloat(item.footprint.height*16))
                                .offset(x:CGFloat(destination.x*16),y:CGFloat(destination.y*16)).allowsHitTesting(false)
                        }
                    }.frame(width:1152,height:1024).coordinateSpace(name:"creativeMap")
                        .scaleEffect(zoom,anchor:.topLeading)
                        .frame(width:1152*zoom,height:1024*zoom,alignment:.topLeading)
                }.background(Color(hex:0x233E32))
                if let item=selectedObject {
                    HStack {
                        Text(item.title).font(.caption.bold())
                        Spacer()
                        Text("Hold and drag to move").font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal)
                }
                Text("Changes save automatically. Doors, services and walking routes move with structures.")
                    .font(.system(size:10)).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom,8)
            }.navigationTitle("Creative mode").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.topBarLeading) {MenuBackButton(id:"closeCreative") {dismiss()}}
                    ToolbarItem(placement:.topBarTrailing) {Button("Reset"){confirmReset=true}}
                }
                .confirmationDialog("Restore the original outdoor layout?",isPresented:$confirmReset,titleVisibility:.visible) {
                    Button("Restore layout",role:.destructive){reset();selected=nil;destination=nil;message="Original layout restored."}
                }
                .task(id:(motel.worldState.structureOffsets ?? [:]).keys.sorted().map{key in "\(key):\(motel.creativeOffset(key).x):\(motel.creativeOffset(key).y)"}.joined(separator:",")) {
                    let renderer=ImageRenderer(content:MotelGroundsCanvas(motel:motel,x:0,y:0,npcTick:0,sceneryOnly:true,fullMap:true).frame(width:1152,height:1024))
                    source=renderer.uiImage
                }
        }
    }
    private func objectHandle(_ item:CreativeStructure)->some View {
        let a=item.art,d=motel.creativeOffset(item.id),f=item.footprint
        let active=selected==item.id
        let fill:Color=active ? Color.yellow.opacity(0.12) : Color.white.opacity(0.001)
        let border:Color=active ? Color.yellow : Color.white.opacity(0.2)
        let positionText="Column \(f.x+d.x), row \(f.y+d.y)."
        let handle=Rectangle().fill(fill)
            .overlay(Rectangle().stroke(border,lineWidth:active ? 2 : 0.5))
            .frame(width:CGFloat(a.width),height:CGFloat(a.height))
            .offset(x:CGFloat(a.x+d.x*16),y:CGFloat(a.y+d.y*16))
        return handle
            .accessibilityElement(children:.ignore).accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(item.title)).accessibilityValue(Text(positionText))
            .accessibilityIdentifier("creative-"+item.id)
            .onTapGesture {selected=item.id;message="Hold and drag "+item.title.lowercased()+" to relocate it."}
            .gesture(relocationGesture(item))
    }
    private func relocationGesture(_ item:CreativeStructure)->some Gesture {
        let f=item.footprint,d=motel.creativeOffset(item.id)
        return LongPressGesture(minimumDuration:0.35)
            .sequenced(before:DragGesture(minimumDistance:0,coordinateSpace:.named("creativeMap")))
            .onChanged { (value:SequenceGesture<LongPressGesture,DragGesture>.Value) in
                switch value {
                case .first(true):selected=item.id
                case .second(true,let drag):
                    selected=item.id
                    if let drag {
                        let dx=Int((drag.translation.width/16).rounded())
                        let dy=Int((drag.translation.height/16).rounded())
                        destination=Tile(x:f.x+d.x+dx,y:f.y+d.y+dy)
                    }
                default:break
                }
            }
            .onEnded {_ in
                if let target=destination {
                    message=move(item.id,target) ? item.title+" placed." : "That position blocks a structure or entrance. Try open ground."
                }
                destination=nil
            }
    }
}

struct GuestStoriesView: View {
    @Binding var game: Game
    var guest: MotelGuest?
    @Environment(\.dismiss) private var dismiss
    @State private var result: String?
    private var motel: Motel { game.motel ?? Motel() }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    if let guest, let id=guest.storyID {
                        HStack(spacing:14) {
                            PaperPortrait(color:guest.color,variant:guest.appearanceSeed).frame(width:56,height:70)
                            VStack(alignment:.leading,spacing:5) {
                                Text(guest.name).font(.title.bold())
                                Text(id.title).font(.headline)
                                Text("Trust: \(motel.storyProgress(id).relationship)").font(.caption)
                            }
                        }
                        if let result { Text(result).font(.body).accessibilityIdentifier("storyResult") }
                        else if motel.canDiscussStory(guest) {
                            Text(motel.guestStoryText(id)).accessibilityIdentifier("storyPrompt")
                            ForEach(motel.guestStoryChoices(id)) { choice in
                                Button {
                                    guard var value=game.motel,value.chooseGuestStory(guest,choiceID:choice.id) else {return}
                                    result=value.lastEvent;game.motel=value;game.save()
                                } label: {
                                    VStack(alignment:.leading,spacing:5) {
                                        Text(choice.title).font(.headline)
                                        Text(choice.consequence).font(.caption).opacity(0.85)
                                    }.frame(maxWidth:.infinity,alignment:.leading).padding(12)
                                }.buttonStyle(.bordered)
                                    .disabled(!motel.storyChoiceEnabled(guest,choice:choice))
                                    .accessibilityIdentifier("storyChoice\(choice.id)")
                            }
                            Text("Choices are remembered. You can leave and decide later.").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(motel.storyProgress(id).memories.last ?? "Meet this guest at reception or outside their room to hear their story.")
                            if motel.storyProgress(id).chapter < 3 { Text("Next chapter: a return visit from day \(motel.storyProgress(id).nextVisitDay).").font(.caption) }
                        }
                    } else {
                        Text("People who remember you").font(.title.bold())
                        Text("Meet these travelers at reception. Their stories continue over several visits; decisions and promises survive saving.")
                        if motel.lanternShowAvailable { Label("Rowan's show is promised today. Visit Jules at the Lantern Bar before resting.",systemImage:"music.note").foregroundStyle(Color(hex:0xEFC977)) }
                        ForEach(GuestStoryID.allCases) { id in
                            let progress=motel.storyProgress(id)
                            VStack(alignment:.leading,spacing:8) {
                                HStack {
                                    PaperPortrait(color:id.color,variant:id.appearance).frame(width:36,height:45)
                                    VStack(alignment:.leading) {Text(id.name+" · "+id.title).font(.headline);Text("Trust \(progress.relationship) · \(min(3,progress.chapter))/3 chapters").font(.caption)}
                                }
                                if progress.memories.isEmpty {Text("A new face to meet.").font(.caption)}
                                ForEach(Array(progress.memories.enumerated()),id:\.offset) { _, memory in Text(memory).font(.caption) }
                                if progress.chapter > 0 && progress.chapter < 3 {Text("Returns from day \(progress.nextVisitDay), when not already staying.").font(.caption)}
                                if progress.chapter >= 3 {Label("Story complete",systemImage:"checkmark.circle.fill").font(.caption)}
                            }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                                .background(Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
                        }
                        if motel.storyBook.musicPartnership {Label("Lantern music nights · +12 coins/day, +1 arrival",systemImage:"music.note")}
                        if motel.storyBook.travelFeature {Label("Travel guide feature · +1 arrival/day",systemImage:"newspaper")}
                        if motel.storyBook.familyReunited {Label("Emilia's family reunited",systemImage:"heart.fill")}
                    }
                }.padding(22)
            }.foregroundStyle(Color(hex:0xF5E7C8)).background(PaintedPanel(color:0x172A25))
                .navigationTitle(guest?.storyID?.title ?? "Guest stories").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading) {MenuBackButton {dismiss()}}}
                .tint(Color(hex:0xEFC977)).accessibilityIdentifier("guestStorySheet")
        }
    }
}

// A fixed-size, non-generic boundary between hotel chrome and its active screen.
// SwiftUI evaluates the closure only when this child's body is requested.
private struct MotelScreenSection: View {
    let makeContent: () -> AnyView
    var body: AnyView { makeContent() }
}
