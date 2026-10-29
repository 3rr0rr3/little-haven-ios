import SwiftUI
import UIKit

// Observe the native scroll view without replacing its gesture handling or delegate.
// Save only when leaving a page, rather than writing preferences on every frame.
private struct ManagementScrollMemory:UIViewRepresentable {
    let page:String
    func makeCoordinator()->Coordinator {Coordinator()}
    func makeUIView(context:Context)->UIView {UIView(frame:.zero)}
    func updateUIView(_ view:UIView,context:Context) {
        let coordinator=context.coordinator
        DispatchQueue.main.async { [weak view] in
            guard let view else{return}
            var ancestor=view.superview
            while let current=ancestor {
                if let scroll=current as? UIScrollView {coordinator.attach(scroll,page:page);return}
                ancestor=current.superview
            }
        }
    }
    static func dismantleUIView(_ view:UIView,coordinator:Coordinator) {coordinator.save();coordinator.observation=nil}
    final class Coordinator {
        weak var scroll:UIScrollView?
        var observation:NSKeyValueObservation?
        var page=""
        var offset:CGFloat=0
        var restoring=false
        private let key="littlehaven.management.offsets"
        func save() {
            guard !page.isEmpty else{return}
            var values=UserDefaults.standard.dictionary(forKey:key) as? [String:Double] ?? [:]
            values[page]=Double(max(0,offset))
            UserDefaults.standard.set(values,forKey:key)
        }
        func attach(_ view:UIScrollView,page next:String) {
            guard scroll !== view || page != next else{return}
            save();observation=nil;scroll=view;page=next;restoring=true
            let values=UserDefaults.standard.dictionary(forKey:key) as? [String:Double] ?? [:]
            offset=CGFloat(values[next] ?? 0)
            observation=view.observe(\.contentOffset,options:[.new]) { [weak self] view,_ in
                guard let self,!self.restoring else{return}
                self.offset=max(0,view.contentOffset.y+view.adjustedContentInset.top)
            }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.12) { [weak self,weak view] in
                guard let self,let view,self.page==next else{return}
                view.layoutIfNeeded()
                let maximum=max(0,view.contentSize.height-view.bounds.height+view.adjustedContentInset.bottom+view.adjustedContentInset.top)
                let target=min(self.offset,maximum)-view.adjustedContentInset.top
                view.setContentOffset(CGPoint(x:view.contentOffset.x,y:target),animated:false)
                self.restoring=false
            }
        }
    }
}


struct MenuBackButton:View {
    var id="menuBack"
    let action:()->Void
    var body:some View {
        Button(action:action) {
            Label("Back",systemImage:"chevron.left").labelStyle(.titleAndIcon).font(.subheadline.bold())
                .frame(minWidth:76,minHeight:44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}
struct PurchaseDetails:View {
    let price:Int
    let cash:Int
    let benefit:String
    var requirement:String?=nil
    var body:some View {
        VStack(alignment:.leading,spacing:5) {
            Text(benefit).font(.caption).foregroundStyle(Color(hex:0xDFE8D8))
            HStack {
                Label("\(price) coins",systemImage:"circle.circle.fill").font(.subheadline.bold())
                Spacer(minLength:4)
                Text(cash>=price ? "After: \(cash-price) coins" : "Need \(price-cash) more coins").font(.caption.bold())
            }.foregroundStyle(Color(hex:0xEFC977))
            if let requirement {Label(requirement,systemImage:"lock.fill").font(.caption).foregroundStyle(Color(hex:0xF4BA9E)).fixedSize(horizontal:false,vertical:true)}
        }.accessibilityElement(children:.combine)
    }
}
enum ManagementPrimary:String,CaseIterable,Identifiable {
    case overview="Overview",guests="Guests",rooms="Rooms",staff="Staff",finances="Finances"
    var id:String {rawValue}
    var symbol:String {switch self {case .overview:return "square.grid.2x2.fill";case .guests:return "person.fill";case .rooms:return "bed.double.fill";case .staff:return "person.2.fill";case .finances:return "banknote.fill"}}
    var pages:[ManagementTab] {switch self {
    case .overview:return [.overview,.events,.growth,.cameras,.story]
    case .guests:return [.desk,.guests]
    case .rooms:return [.rooms,.supplies]
    case .staff:return [.team]
    case .finances:return [.books]
    }}
}
extension ManagementTab {
    var primary:ManagementPrimary {ManagementPrimary.allCases.first{$0.pages.contains(self)} ?? .overview}
    var displayTitle:String {switch self {case .overview:return "Overview";case .desk:return "Arrivals";case .guests:return "Staying guests";case .team:return "Staff";case .books:return "Finances";default:return rawValue}}
}

struct NeighborhoodStoreView:View {
    @Binding var game:Game
    let shop:NeighborhoodShop
    @State private var showGardenKitchen=false
    @Environment(\.dismiss) private var dismiss
    private var motel:Motel {game.motel ?? Motel()}
    private func change(_ action:(inout Motel)->Void) {var value=motel;action(&value);game.motel=value}
    var body:some View {
        NavigationStack {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text(shop.keeperName).font(.title2.bold())
                Text("\(motel.cash) COINS").font(.headline.monospaced()).foregroundStyle(Color(hex:0xEFC977))
                Text(shop.keeperName+" / "+shop.detail)
                HygieneGreeting(dirty:motel.isPlayerDirty,speaker:shop.keeperName)
                storeItems
            }.padding(24)
        }.foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x233E33)).tint(Color(hex:0xEFC977)).buttonStyle(.bordered).accessibilityIdentifier("neighborhoodShop")
            .navigationTitle(shop.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {ToolbarItem(placement:.topBarLeading){MenuBackButton {dismiss()}}}
            .sheet(isPresented:$showGardenKitchen){HavenLifeView(game:$game,initialTab:.garden)}
        }
    }
    @ViewBuilder private var storeItems:some View {
        switch shop {
        case .furniture:furnitureItems
        case .clothing:clothingItems
        case .fish:fishItems
        case .bar:barItems
        case .pawn:pawnItems
        }
    }
    private var furnitureItems:some View {
        VStack(alignment:.leading,spacing:16) {
                    if (0..<3).contains(where:{motel.neighborState($0).favorPending && !motel.neighborState($0).parcel}) {
                        Button("Collect neighbor parcels") {change{_=$0.collectNeighborParcels()};game.save()}
                            .disabled(!motel.canTrade(.furniture)).accessibilityIdentifier("collectNeighborParcels")
                    }
                    Text("Furniture & seasonal goods").font(.headline)
                    Text("Halloween: pumpkins and ghost lanterns. Christmas: trees and presents. Available year-round.").font(.caption)
                    ForEach(HomeObject.allCases) {kind in
                        VStack(alignment:.leading,spacing:10) {
                            HStack {HomeItemIcon(kind:kind).frame(width:46,height:46);Text(kind.title).font(.headline);Spacer()}
                            PurchaseDetails(price:kind.price,cash:motel.cash,benefit:"Delivered to home storage. Place it at your workbench.",requirement:motel.canTrade(.furniture) ? nil : "Walk to the shop counter")
                            Button("Buy "+kind.title){change{_=$0.buyHomeObject(kind)}}.disabled(!motel.canTrade(.furniture) || motel.cash<kind.price).accessibilityIdentifier("buy_home_"+kind.rawValue)
                        }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
                    }
                    Text("Take your purchases home and use the workbench to place them.").font(.caption)

        }
    }
    private var clothingItems:some View {
        VStack(alignment:.leading,spacing:16) {
                    ForEach(FamilyHome.outfitNames.indices,id:\.self) {index in
                        HStack {
                            RoundedRectangle(cornerRadius:8).fill(Color(hex:FamilyHome.outfitColors[index])).frame(width:44,height:44)
                            VStack(alignment:.leading,spacing:5) {
                                Text(FamilyHome.outfitNames[index]).font(.headline)
                                PurchaseDetails(price:motel.household.outfits.contains(index) ? 0 : 80,cash:motel.cash,benefit:motel.household.outfits.contains(index) ? "Owned · free to wear" : "Unlock this outfit permanently")
                            };Spacer()
                            Button(motel.household.outfit == index ? "Wearing" : motel.household.outfits.contains(index) ? "Wear" : "Buy / 80") {change{_=$0.wearOutfit(index)}}.disabled(motel.household.outfit == index || (!motel.household.outfits.contains(index) && motel.cash<80)).accessibilityIdentifier("outfit_\(index)")
                        }
                    }

        }
    }
    private var fishItems:some View {
        VStack(alignment:.leading,spacing:16) {
                    Text("Every order shows its total and your remaining balance.").font(.caption)
                    Button("Garden kitchen & recipes") {showGardenKitchen=true}.accessibilityIdentifier("shopGardenKitchen")
                    ForEach(FishMeal.allCases) {meal in
                        HStack {
                            VStack(alignment:.leading,spacing:5) {Label(meal.title,systemImage:"fish.fill");PurchaseDetails(price:meal.price,cash:motel.cash,benefit:"Freshly served by Marina",requirement:motel.canTrade(.fish) ? nil : "Walk to the counter")};Spacer()
                            Button("Order / \(meal.price)") {change{_=$0.orderFishMeal(meal)}}
                                .disabled(!motel.canTrade(.fish) || motel.cash<meal.price)
                                .accessibilityIdentifier("orderMeal_"+meal.rawValue)
                        }
                    }
                    if let meal=motel.worldState.fishMeal {Label("Marina served: "+meal.title,systemImage:"checkmark.circle.fill")}
                    Text("Fresh fish from the coast, shared tables and warm conversation.").font(.caption)

        }
    }
    private var barItems:some View {
        VStack(alignment:.leading,spacing:16) {
                    if motel.lanternShowAvailable {
                        Text("Rowan is ready to play today.").font(.headline)
                        Button("Start Rowan's set / +60 coins") {
                            change {_=$0.startLanternShow()};game.save();dismiss()
                        }.disabled(!motel.canTrade(.bar)).accessibilityIdentifier("startLanternShow")
                    } else if motel.storyBook.performedDay == motel.day {
                        Label("Rowan's live set · promise kept",systemImage:"music.note")
                    }
                    ForEach(BarDrink.allCases) {drink in
                        HStack {
                            VStack(alignment:.leading,spacing:5) {Label(drink.title,systemImage:"wineglass.fill");PurchaseDetails(price:drink.price,cash:motel.cash,benefit:"Freshly served by Jules",requirement:motel.canTrade(.bar) ? nil : "Walk to the counter")};Spacer()
                            Button("Order / \(drink.price)") {change{_=$0.orderBarDrink(drink)}}
                                .disabled(!motel.canTrade(.bar) || motel.cash<drink.price)
                                .accessibilityIdentifier("orderDrink_"+drink.rawValue)
                        }
                    }
                    if let drink=motel.worldState.barDrink {
                        Label("Jules served: "+drink.title,systemImage:"checkmark.circle.fill").foregroundStyle(Color(hex:0xA8D7BA))
                    }
                    Text("Music, warm lights and good company. Take a seat and enjoy the evening.").font(.caption)

        }
    }
    private var pawnItems:some View {
        VStack(alignment:.leading,spacing:16) {
                    if motel.household.stolen.isEmpty {Text("Your bag is empty. No belongings have been sold automatically.")}
                    ForEach(RoomVisit.lootNames.indices,id:\.self) {item in
                        let count=motel.household.stolen.filter{$0 == item}.count
                        if count>0 {HStack {Text("\(RoomVisit.lootNames[item]) x \(count)");Spacer();Button("Sell / \(RoomVisit.lootValues[item])"){change{_=$0.sellBelonging(item)}}.accessibilityIdentifier("pawn_sell_\(item)")}}
                    }

        }
    }

}
struct HomeDesignView:View {
    @Binding var game:Game
    @Environment(\.dismiss) private var dismiss
    @State private var selected:HomeObject?
    @State private var message="Select a stored item, then tap an empty floor tile. Family paths and the entrance stay clear."
    private var motel:Motel {game.motel ?? Motel()}
    private func change(_ action:(inout Motel)->Void) {var value=motel;action(&value);game.motel=value}
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    summary
                    finishRow(wall:true)
                    finishRow(wall:false)
                    storage
                    Text(message).font(.caption)
                    layout
                    Text("Tap placed furniture to store it, then select it and tap another tile to move it. A rug can be walked over.").font(.caption)
                }.padding(22)
            }.foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x233E33)).tint(Color(hex:0xEFC977)).buttonStyle(.bordered)
                .accessibilityIdentifier("homeDesigner")
                .navigationTitle("Make it home").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading){MenuBackButton {dismiss()}}}
        }
    }
    private var summary:some View {
        VStack(alignment:.leading,spacing:12) {
            Text("Storage and finishes").font(.title2.bold())
            Text("\(motel.cash) COINS / LEVEL \(motel.household.level) / \(motel.household.placed.count) OF \(motel.household.capacity) OBJECTS").font(.caption.monospaced())
            if motel.household.level<3 {
                PurchaseDetails(price:motel.household.upgradeCost,cash:motel.cash,benefit:"Four more furniture spaces and improved home finishes")
                Button("Upgrade home / \(motel.household.upgradeCost)"){change{_=$0.upgradeHome()}}
                    .disabled(motel.cash<motel.household.upgradeCost).accessibilityIdentifier("upgradeHome")
            }
        }
    }
    private func finishRow(wall:Bool)->some View {
        HStack {
            Text(wall ? "Walls / 25" : "Floor / 25").font(.caption)
            ForEach(0..<4,id:\.self) {index in finishButton(wall:wall,index:index)}
        }
    }
    private func finishButton(wall:Bool,index:Int)->some View {
        let current=wall ? motel.household.wallpaper : motel.household.floor
        let color=wall ? Motel.themeColors[index] : HomeInteriorArt.floors[index]
        return Button {change{_=$0.finishHome(wall:wall,color:index)}} label:{
            Circle().fill(Color(hex:color)).frame(width:28,height:28).padding(8).contentShape(Circle())
        }.accessibilityLabel("\(wall ? "Wall" : "Floor") finish \(index+1)")
            .accessibilityValue(current==index ? "Selected" : "25 coins").disabled(motel.cash<25 || current==index)
    }
    private var storage:some View {
        VStack(alignment:.leading,spacing:10) {
            Text("Storage").font(.headline)
            if motel.household.storage.isEmpty {Text("Visit Willow Home east of the motel to buy furniture.").font(.caption)}
            ScrollView(.horizontal) {
                HStack {
                    ForEach(HomeObject.allCases.filter{motel.household.storage.contains($0)}) {kind in
                        Button("\(kind.title) x \(motel.household.storage.filter{$0 == kind}.count)"){selected=kind}
                            .tint(selected==kind ? .orange : Color(hex:0xEFC977))
                    }
                }
            }
        }
    }
    private var layout:some View {
        LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:2),count:13),spacing:2) {
            ForEach(2..<13,id:\.self) {y in
                ForEach(1..<14,id:\.self) {x in floorButton(Tile(x:x,y:y))}
            }
        }
    }
    private func floorButton(_ tile:Tile)->some View {
        Button {selectFloor(tile)} label:{floorLabel(tile)}.buttonStyle(.plain).accessibilityIdentifier("home_tile_\(tile.x)_\(tile.y)")
    }
    private func floorLabel(_ tile:Tile)->some View {
        ZStack {
            Rectangle().fill(Color(hex:motel.homeBlocked(tile) ? 0x496451 : HomeInteriorArt.floors[motel.household.floor]))
            if let object=motel.household.placed.first(where:{$0.tile==tile}) {HomeItemIcon(kind:object.kind)}
            else if Motel.familyTiles.contains(tile) || OfficeReception.hildarelysRoute.contains(tile) {Image(systemName:"heart.fill").font(.caption2)}
        }.frame(height:28)
    }
    private func selectFloor(_ tile:Tile) {
        if let object=motel.household.placed.first(where:{$0.tile==tile}) {
            change{_=$0.storeHomeObject(object.id)};message="Returned to storage. Select it to move it."
        } else if let selected {
            change {value in
                message=value.placeHomeObject(selected,at:tile) ? "Placed \(selected.title). Tap it to return it to storage." : "Keep family paths clear. Try another tile or upgrade for more space."
            }
        }
    }
}
struct HomeItemIcon:View {
    let kind:HomeObject
    var body:some View {Canvas {context,size in context.scaleBy(x:size.width/16,y:size.height/16);HomeInteriorArt.object(context:&context,kind:kind,x:0,y:0)}}
}

struct DialogueChoice: Identifiable {
    let title: String
    let action: () -> Void
    var id: String { title }
}
struct RPGFrame: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(14).background(PaintedPanel(color:0x20372F))
            .overlay(Rectangle().stroke(Color(hex:0xE9C77D),lineWidth:2).allowsHitTesting(false))
            .overlay(Rectangle().inset(by:5).stroke(Color(hex:0xE9C77D).opacity(0.25),lineWidth:1).allowsHitTesting(false))
    }
}
struct GameDialogue: View {
    let speaker: String
    let text: String
    let portrait: AnyView
    let choices: [DialogueChoice]
    var dismissible=true
    var hygieneDirty=false
    private var reaction:String {
        let words=text.lowercased()
        if speaker.contains("Officer") {return "cross"}
        if ["sorry","problem","complaint","unhappy"].contains(where:words.contains) {return "shrug"}
        if ["love","thank","happy","celebrat"].contains(where:words.contains) {return "laugh"}
        return "nod"
    }
    let close: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:10) {
                if dismissible {MenuBackButton(id:"dialogueBack",action:close)}
                Text(speaker.uppercased()).font(.system(size:13,weight:.black,design:.monospaced)).foregroundStyle(Color(hex:0xF2CE7F)).frame(maxWidth:.infinity,alignment:.trailing)
            }
            HygieneGreeting(dirty:hygieneDirty,speaker:speaker)
            HStack(alignment:.top,spacing:12) {
                portrait.environment(\.dialogueMotion,hygieneDirty ? "dirty" : reaction).frame(width:64,height:76).background(Color(hex:0x344E40)).overlay(Rectangle().stroke(Color(hex:0xC4A96F),lineWidth:1))
                Text(text).font(.system(size:15,weight:.medium,design:.rounded)).foregroundStyle(Color(hex:0xF5E7C8)).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading)
            }
            ForEach(choices) { choice in
                Button(action:choice.action) {
                    HStack { Text(">").foregroundStyle(Color(hex:0xEFC977)); Text(choice.title); Spacer() }
                        .font(.system(size:13,weight:.bold,design:.monospaced)).padding(11)
                        .foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x385448))
                }.accessibilityLabel(choice.title)
            }
        }.modifier(RPGFrame()).contentShape(Rectangle()).accessibilityElement(children:.contain).accessibilityIdentifier("gameDialogue")
    }
}
struct CatPortrait: View {
    let gray: Bool
    var body: some View { Canvas { context,size in
        context.scaleBy(x:size.width/28,y:size.height/30)
        CatArt.draw(context:&context,gray:gray,walk:0)
    } }
}
struct StaffPanel: View {
    let motel: Motel
    let hire: (StaffRole) -> Void
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:14) {
            Text("HIRE EMPLOYEES").font(.headline).foregroundStyle(Color(hex:0xEFC977))
            Text("Unlock employees by checking in guests. Each hire adds their own work station. First shift included; wages are paid each morning.").font(.caption)
            ForEach(StaffRole.allCases) { role in
                let worker = motel.operationsState.workers.first { $0.role == role }
                HStack(alignment:.top,spacing:10) {
                    PaperPortrait(color:role.color,variant:role.appearanceVariant).frame(width:40,height:52)
                    VStack(alignment:.leading,spacing:5) {
                        Text(role.name+" / "+role.title).font(.subheadline.bold())
                        Text(role.duty).font(.caption)
                        Text("\(role.wage) coins/day").font(.caption.monospaced()).foregroundStyle(Color(hex:0xEFC977))
                        if let worker { Text(worker.active ? (worker.status ?? "On duty") : "Off duty: unpaid shift").font(.caption.bold()) }
                        else { PurchaseDetails(price:role.hireCost,cash:motel.cash,benefit:role.duty+" First shift included; then \(motel.scheduledWage(role)) coins per day.",requirement:motel.hiringUnlocked(role) ? nil : motel.hiringProgress(role)); Button("Hire \(role.name) / \(role.hireCost)") { hire(role) }.buttonStyle(MotelButtonStyle()).disabled(!motel.hiringUnlocked(role) || motel.cash < role.hireCost).accessibilityIdentifier("hire_"+role.rawValue) }
                    }
                }
            }
            if !motel.isAtReception { Text("Hire staff here from anywhere on the grounds.").font(.caption) }
        } }.frame(maxHeight:330)
    }
}
struct ReviewsPanel: View {
    let motel: Motel
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:14) {
            Text(motel.reviewAverage.map { String(format:"%.1f / 5 guest rating",$0) } ?? "No reviews yet").font(.headline).foregroundStyle(Color(hex:0xEFC977))
            Text("Guests review at checkout. Upgraded rooms earn praise. Unresolved chaos or missing belongings hurt your rating.").font(.caption)
            ForEach(motel.operationsState.reviews) { review in
                VStack(alignment:.leading,spacing:5) {
                    Text(String(repeating:"?",count:review.stars)+String(repeating:"?",count:5-review.stars)).foregroundStyle(Color(hex:0xEFC977))
                    Text("\(review.guest) / Room \(review.room) / Day \(review.day)").font(.caption.bold())
                    Text(review.text).font(.subheadline)
                }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.06)).accessibilityIdentifier("guestReview_"+review.id)
            }
        } }.frame(maxHeight:330)
    }
}
struct RoomUpgradesPanel: View {
    let motel: Motel
    let upgrade: (Int) -> Void
    var body: some View {
        ScrollView { VStack(spacing:12) {
            Text("Each tier adds 30 coins per night and helps reviews. Occupied rooms cannot be renovated.").font(.caption)
            ForEach(motel.rooms) { room in
                HStack {
                    RoomIllustration(theme:room.theme,level:room.furniture,office:false).frame(width:58,height:58)
                    VStack(alignment:.leading,spacing:4) {
                        Text("ROOM \(room.number) / TIER \(room.furniture)").font(.caption.monospaced().bold())
                        Text("\(motel.rate(for:room)) coins/night").font(.caption)
                        if room.furniture < 2 {
                            Button("Upgrade / \((room.furniture+1)*90)") { upgrade(room.id) }.buttonStyle(MotelButtonStyle()).disabled(room.guest != nil || motel.cash < (room.furniture+1)*90).accessibilityIdentifier("deskUpgrade_\(room.id)")
                        } else { Text("Fully upgraded").font(.caption.bold()) }
                    }
                }
            }
        } }.frame(maxHeight:330)
    }
}

enum ChaosArt {
    static func draw(context: inout GraphicsContext, kind: Int, stride: Double,
                     color: UInt32 = 0xC88370, variant: Int = 0, facing: Int = 0) {
        let phase = stride * .pi / 4
        func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ tint:UInt32) {
            context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:tint)))
        }
        func line(_ points:[CGPoint],_ tint:UInt32,_ width:Double) {
            var path=Path()
            for (i,p) in points.enumerated() { if i == 0 { path.move(to:p) } else { path.addLine(to:p) } }
            context.stroke(path,with:.color(Color(hex:tint)),lineWidth:width)
        }
        if kind == 1 {
            // Smoke is behind the flames, with a broad hot base and three distinct tongues.
            for i in 0..<4 {
                let rise=(stride*1.4+Double(i)*4).truncatingRemainder(dividingBy:18)
                var smoke=context;smoke.opacity=0.22+rise/80
                smoke.fill(Path(ellipseIn:CGRect(x:5+Double(i)*3+sin(phase)*2,y:12-rise/2,width:5+rise/3,height:4+rise/3)),with:.color(Color(hex:0x746B60)))
            }
            for i in 0..<3 {
                let x=1+Double(i)*7,sway=sin(phase+Double(i)*1.7)*2
                let top=4+Double(i%2)*3+cos(phase)*1.5
                var flame=Path();flame.move(to:CGPoint(x:x,y:26))
                flame.addCurve(to:CGPoint(x:x+4+sway,y:top),control1:CGPoint(x:x-3,y:19),control2:CGPoint(x:x+7,y:15))
                flame.addCurve(to:CGPoint(x:x+8,y:26),control1:CGPoint(x:x+3,y:14),control2:CGPoint(x:x+12,y:20))
                flame.closeSubpath()
                context.fill(flame,with:.linearGradient(Gradient(colors:[Color(hex:0xED7230),Color(hex:0xFFC448)]),startPoint:CGPoint(x:x,y:6),endPoint:CGPoint(x:x,y:26)))
                var core=Path();core.move(to:CGPoint(x:x+1,y:26))
                core.addQuadCurve(to:CGPoint(x:x+5+sway/2,y:15),control:CGPoint(x:x+2,y:21))
                core.addQuadCurve(to:CGPoint(x:x+7,y:26),control:CGPoint(x:x+9,y:24));core.closeSubpath()
                context.fill(core,with:.color(Color(hex:0xFFF0AE)))
                oval(x+4+sway,10-(stride+Double(i)*2).truncatingRemainder(dividingBy:8),0.8,1.4,0xFFCF68)
            }
        } else if kind == 2 {
            // Render the same guest, then submerge the lower body. Identity survives the event.
            let bob=sin(phase)*2
            var swimmer=context
            swimmer.clip(to:Path(CGRect(x:0,y:0,width:24,height:23)))
            swimmer.translateBy(x:0,y:bob+4)
            PaperPerson.draw(context:&swimmer,x:4,y:9,color:color,variant:variant,facing:0,walk:0,expression:"scared")
            oval(2,21,21,5,0x71B2BA)
            let skin:UInt32 = NPCDesign.skinColors[NPCDesign(variant:variant).skin]
            line([CGPoint(x:8,y:21),CGPoint(x:3,y:14+bob),CGPoint(x:2,y:7+sin(phase)*4)],skin,3)
            line([CGPoint(x:17,y:21),CGPoint(x:21,y:13-bob),CGPoint(x:22,y:7-sin(phase)*4)],skin,3)
            for i in 0..<4 {
                let dx=Double(i)*6, rise=abs(sin(phase+Double(i)))*5
                oval(dx,22-rise,1.5,3,0xD7F3F1)
                context.stroke(Path(ellipseIn:CGRect(x:1+dx/3,y:24-Double(i%2),width:15+sin(phase)*3,height:2)),with:.color(Color(hex:0xDDF3E8)),lineWidth:0.7)
            }
        } else if kind == 4 {
            line([CGPoint(x:5,y:23),CGPoint(x:5,y:13),CGPoint(x:15,y:13)],0x8CABB0,4)
            for i in 0..<6 {let k=Double(i);oval(14+k,14+(stride+k*2).truncatingRemainder(dividingBy:12),2,3,0xA3DDE5)}
            oval(5,25,18,3,0x7AB6C1)
        } else if kind == 5 {
            for i in 0..<3 {
                let x=5+Double(i)*6
                line([CGPoint(x:x,y:25),CGPoint(x:x+sin(phase)*3,y:17),CGPoint(x:x-sin(phase)*3,y:7)],0xE1A86B,1.2)
            }
        } else if kind == 6 {
            for i in 0..<4 {
                let x=3+Double(i)*5+sin(phase+Double(i))*2,y=12+Double(i%2)*8
                oval(x,y,3,5,0x6B493C)
                for leg in 0..<3 {line([CGPoint(x:x-1,y:y+Double(leg)),CGPoint(x:x+4,y:y+Double(leg)+1)],0x6B493C,0.6)}
            }
        } else if kind == 7 {
            let lift=sin(phase)*2
            context.stroke(Path(roundedRect:CGRect(x:2,y:8+lift,width:20,height:12),cornerRadius:4),with:.color(Color(hex:0xE1C575)),lineWidth:1)
            line([CGPoint(x:7,y:14+lift),CGPoint(x:7,y:10+lift)],0xE1C575,1.5)
            line([CGPoint(x:12,y:16+lift),CGPoint(x:12,y:11+lift)],0xE1C575,1.5)
            line([CGPoint(x:17,y:14+lift),CGPoint(x:17,y:10+lift)],0xE1C575,1.5)
        } else {
            let left=facing == 1
            let hit=max(0,sin(phase+(left ? .pi : 0)))
            var actorContext=context
            actorContext.translateBy(x:(left ? -1 : 1)*hit,y:0)
            PaperPerson.draw(context:&actorContext,x:4,y:9,color:color,variant:variant,facing:facing,walk:sin(phase),expression:"angry")
            // Clenched fists and alternating punches; the shared face renders the anger.
            let handX=left ? 5-hit*6 : 17+hit*5
            line([CGPoint(x:left ? 8 : 16,y:18),CGPoint(x:handX,y:15)],color,3)
            oval(handX-2,13,4,4,0xDEAB83)
            if hit > 0.7 {
                for i in 0..<3 {
                    let x=left ? 1.0 : 23.0
                    line([CGPoint(x:x,y:12),CGPoint(x:x+(left ? 2 : -2),y:9+Double(i)*3)],0xF5D18B,0.8)
                }
            }
        }
    }
}

enum RoomObjectArt {
    static func draw(context: inout GraphicsContext, index:Int, x:Double, y:Double, scale:Double = 1) {
        var c=context
        c.translateBy(x:x,y:y); c.scaleBy(x:scale,y:scale)
        if PaintedArt.draw(index==0 ? "suitcase" : index==1 ? "watch" : "camera",in:CGRect(x:0,y:0,width:16,height:16),context:&c,fit:true) {return}
        func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32,_ radius:Double = 1) {
            c.fill(Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:radius),with:.color(Color(hex:color)))
        }
        func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
            c.fill(Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:color)))
        }
        if index == 0 {
            box(4,0,7,4,0x3E4145); box(5,1,5,3,0xC3A87C)
            box(1,3,14,11,0x8B6147,2); box(2,4,12,9,0xB0865D,2)
            box(4,4,1,9,0xD5AE77); box(11,4,1,9,0xD5AE77)
            box(7,6,2,3,0xE7C879); oval(3,13,2,2,0x333C42); oval(11,13,2,2,0x333C42)
        } else if index == 1 {
            box(6,0,4,15,0x8A5B3E); box(6.5,0,3,3,0xD9B66B)
            oval(3,3,10,10,0xD7B260); oval(4,4,8,8,0xF4E5BC)
            var hands=Path(); hands.move(to:CGPoint(x:8,y:5)); hands.addLine(to:CGPoint(x:8,y:8)); hands.addLine(to:CGPoint(x:10,y:9))
            c.stroke(hands,with:.color(Color(hex:0x38434C)),lineWidth:0.8)
            box(12,6,1.5,3,0xE9CE81)
        } else {
            box(1,5,14,9,0x34434A,2); box(3,3,5,4,0x34434A)
            box(2,6,4,6,0x53666D); box(10,4,3,2,0xD6C8A2)
            oval(6,6,8,8,0xBAC8C9); oval(7,7,6,6,0x263B4C); oval(8,8,3,3,0x73A6BC)
            box(2,2,2,3,0xCAB474)
            var strap=Path(); strap.move(to:CGPoint(x:1,y:7)); strap.addQuadCurve(to:CGPoint(x:14,y:8),control:CGPoint(x:8,y:22))
            c.stroke(strap,with:.color(Color(hex:0x8B6E52)),lineWidth:0.7)
        }
    }
}
struct HotelActionArtwork: View {
    let kind:String
    let frame:Int
    var body: some View {
        Canvas { context,_ in
            let phase=Double(frame) * .pi / 4
            let swing=sin(phase)
            func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
                context.fill(Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:1),with:.color(Color(hex:color)))
            }
            func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
                context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:color)))
            }
            func line(_ a:CGPoint,_ b:CGPoint,_ color:UInt32,_ width:Double) {
                var p=Path(); p.move(to:a); p.addLine(to:b)
                context.stroke(p,with:.color(Color(hex:color)),lineWidth:width)
            }
            func drops(_ x:Double,_ y:Double) {
                for i in 0..<9 {
                    let k=Double(i), travel=(Double(frame)+k).truncatingRemainder(dividingBy:8)
                    oval(x+k*2,y+travel*2,1.5,3,0xAEE2E9)
                }
            }
            if kind == "checkin" {
                box(18,25,22,18,0xEFE0B8)
                for i in 0..<3 {box(21,29+Double(i*4),12,1,0x9E947D)}
                oval(42,25+swing*2,6,6,0xE2C069)
                line(CGPoint(x:44,y:30+swing*2),CGPoint(x:48,y:39+swing*2),0xE2C069,2)
                box(46,36+swing*2,5,2,0xE2C069)
            } else if kind.hasPrefix("steal-") {
                RoomObjectArt.draw(context:&context,index:Int(kind.suffix(1)) ?? 0,x:22,y:22,scale:1.4)
            } else if kind == "carwash" || kind == "extinguish" {
                box(8,35,9,10,0xD17451); box(10,33,5,3,0xC9DFD7)
                line(CGPoint(x:17,y:34),CGPoint(x:24,y:24+swing*3),0x3F6268,3)
                for i in 0..<10 {
                    let t=Double(i)/10
                    oval(24+t*26,25+swing*3+t*t*8,2+t*2,1.8,0xBFEAF0)
                }
                if kind == "carwash" {
                    for i in 0..<8 { oval(30+Double(i%4)*6,26+Double(i/4)*6+swing,5,4,0xF1F5E4) }
                    box(32+swing*6,28,8,4,0xE5CB69)
                } else {
                    for i in 0..<5 { oval(35+Double(i)*3,18-Double(frame%4)*2,6,9,0xB9C9C5) }
                }
            } else if kind == "rescue" {
                context.stroke(Path(ellipseIn:CGRect(x:22+swing*3,y:25,width:17,height:12)),with:.color(Color(hex:0xECA471)),lineWidth:4)
                line(CGPoint(x:14,y:43),CGPoint(x:29+swing*3,y:31),0xEEE4BE,1)
                drops(20,33)
            } else if kind == "garden" {
                box(12,24,12,12,0x659BA5)
                line(CGPoint(x:22,y:28),CGPoint(x:31,y:24+swing*3),0x659BA5,4)
                drops(29,27+swing*2)
                box(35,42,14,7,0xA27653)
                line(CGPoint(x:42,y:44),CGPoint(x:42,y:31),0x5C8D57,2)
                oval(38,29,9,6,0xD9A2AD)
            } else if kind == "laundry" || kind == "bed" {
                box(15,35,30,12,0x9A7D60)
                for i in 0..<3 {
                    let lift=Double(i == frame%3 ? 3 : 0)
                    box(18,30-Double(i)*5-lift,24,5, i%2 == 0 ? 0xE8E5D1 : 0xA6C5C2)
                }
                if kind == "bed" {
                    var sheet=Path(); sheet.move(to:CGPoint(x:10,y:28))
                    sheet.addQuadCurve(to:CGPoint(x:52,y:28),control:CGPoint(x:32,y:14+swing*7))
                    sheet.addLine(to:CGPoint(x:49,y:39)); sheet.addLine(to:CGPoint(x:13,y:39)); sheet.closeSubpath()
                    context.fill(sheet,with:.color(Color(hex:0xE8ECD9)))
                }
            } else if kind == "trash" {
                box(38,32,10,15,0x6D877B)
                let lift=abs(swing)*10
                oval(18,29-lift,15,15,0x40554F)
                line(CGPoint(x:25,y:30-lift),CGPoint(x:28,y:24-lift),0x40554F,3)
                box(36,30,14,3,0xA3BAB0)
            } else if kind == "mop" {
                line(CGPoint(x:18,y:18),CGPoint(x:38+swing*9,y:42),0xBE9863,2)
                oval(30+swing*9,40,17,5,0xBAD9CC)
                for i in 0..<5 { oval(25+Double(i)*5,44+Double(i%2)*2,4,1,0xA8D8DA) }
            } else if kind == "paint" {
                line(CGPoint(x:24,y:43),CGPoint(x:31,y:24+swing*5),0xC3A573,2)
                box(25,19+swing*5,15,7,0x87AFBA); box(40,21,4,24,0x87AFBA)
            } else if kind == "repair" || kind == "build" {
                let tip=CGPoint(x:35+swing*7,y:25+abs(swing)*8)
                line(CGPoint(x:20,y:43),tip,0xA17D57,3)
                if kind == "build" { box(tip.x-7,tip.y-3,14,6,0xA5B6B8) }
                else {
                    context.stroke(Path(ellipseIn:CGRect(x:tip.x-5,y:tip.y-5,width:10,height:10)),with:.color(Color(hex:0xB6C6CC)),lineWidth:3)
                }
                if frame%2 == 0 { for i in 0..<4 { line(CGPoint(x:38,y:39),CGPoint(x:33+Double(i)*4,y:34-Double(i%2)*4),0xF1D388,1) } }
            } else if kind == "breakfast" {
                box(13,37,37,3,0xB48C5F)
                box(19,28,8,9,0xEEE4C4)
                context.stroke(Path(ellipseIn:CGRect(x:25,y:29,width:5,height:5)),with:.color(Color(hex:0xEEE4C4)),lineWidth:2)
                oval(32,30,12,6,0xD6A86A)
                for i in 0..<3 { oval(20+Double(i)*2+swing,22-Double(frame%3)*2,1,4,0xD5E4D3) }
            } else if kind == "luggage" {
                RoomObjectArt.draw(context:&context,index:0,x:23+swing*4,y:26-abs(swing)*4,scale:1.4)
            } else if kind == "calm" {
                oval(16,22,9,12,0xDFB38C); oval(37,22,9,12,0xDFB38C)
                line(CGPoint(x:21,y:38),CGPoint(x:21,y:26+swing*2),0x7EB8AD,3)
                line(CGPoint(x:41,y:38),CGPoint(x:41,y:26-swing*2),0x7EB8AD,3)
            }
            if !kind.hasPrefix("steal-") {
                for i in 0..<3 {
                    let x=15+Double(i)*16, y=14+Double(i%2)*7
                    if (frame+i)%3 == 0 {
                        line(CGPoint(x:x-2,y:y),CGPoint(x:x+2,y:y),0xF1DF9F,1)
                        line(CGPoint(x:x,y:y-2),CGPoint(x:x,y:y+2),0xF1DF9F,1)
                    }
                }
            }
        }.frame(width:64,height:64)
    }
}
struct HotelCarArtwork: View {
    let color:UInt32
    let dirty:Bool
    var model=0
    var body:some View {
        Canvas {c,_ in BicycleArt.draw(context:&c,color:color,facing:2,pedal:0,dirty:dirty)}
            .frame(width:24,height:16)
    }
}
enum BicycleArt {
    static func draw(context:inout GraphicsContext,color:UInt32,facing:Int,pedal:Double,dirty:Bool=false) {
        var c=context
        func line(_ points:[CGPoint],_ tint:UInt32,_ width:Double=1) {
            var p=Path();p.addLines(points);c.stroke(p,with:.color(Color(hex:tint)),style:StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round))
        }
        func wheel(_ x:Double,_ y:Double,_ w:Double,_ h:Double) {
            let r=CGRect(x:x,y:y,width:w,height:h)
            c.stroke(Path(ellipseIn:r),with:.color(Color(hex:0x283D40)),lineWidth:1.4)
            c.stroke(Path(ellipseIn:r.insetBy(dx:1,dy:1)),with:.color(Color(hex:0xC3CCBE)),lineWidth:0.55)
            line([CGPoint(x:x+w/2,y:y),CGPoint(x:x+w/2,y:y+h)],0xA9B8B1,0.45)
            line([CGPoint(x:x,y:y+h/2),CGPoint(x:x+w,y:y+h/2)],0xA9B8B1,0.45)
        }
        if facing == 0 || facing == 3 {
            wheel(9,0,6,7);wheel(9,9,6,7)
            line([CGPoint(x:12,y:4),CGPoint(x:12,y:12)],color,2)
            line([CGPoint(x:7,y:4),CGPoint(x:17,y:4)],0x3E4F4D,1.4)
            line([CGPoint(x:9,y:9),CGPoint(x:15,y:9)],0x604D3C,2)
            line([CGPoint(x:8,y:11+pedal),CGPoint(x:16,y:11-pedal)],0x6D7C77,1)
        } else {
            if facing == 1 {c.translateBy(x:24,y:0);c.scaleBy(x:-1,y:1)}
            wheel(1,6,8,8);wheel(15,6,8,8)
            line([CGPoint(x:5,y:10),CGPoint(x:10,y:4),CGPoint(x:13,y:11),CGPoint(x:5,y:10)],color,1.2)
            line([CGPoint(x:10,y:4),CGPoint(x:18,y:4),CGPoint(x:13,y:11),CGPoint(x:10,y:4)],color,1.2)
            line([CGPoint(x:18,y:3),CGPoint(x:19,y:10)],color,1.3)
            line([CGPoint(x:16,y:2),CGPoint(x:19,y:2),CGPoint(x:20,y:4)],0x334842,1.3)
            line([CGPoint(x:8,y:3),CGPoint(x:12,y:3)],0x584D3E,2)
            line([CGPoint(x:11,y:11),CGPoint(x:15,y:11+pedal)],0x8B9B93,1)
            line([CGPoint(x:14,y:11+pedal),CGPoint(x:17,y:11+pedal)],0x3B4B46,1)
        }
        if dirty {line([CGPoint(x:5,y:13),CGPoint(x:8,y:13)],0x9A825F,1)}
    }
}



enum RoomBoardFilter:String,CaseIterable,Identifiable {
    case all="All",ready="Ready",occupied="Occupied",attention="Needs care"
    var id:String {rawValue}
}
enum ManagementTab:String,CaseIterable,Identifiable {
    case overview="Today"
    case rooms="Rooms",desk="Desk",guests="Guests",team="Team",supplies="Supplies",events="Events",growth="Growth",cameras="Cameras",story="Story",books="Books"
    var id:String {rawValue}
    var symbol:String {switch self {
    case .overview:return "square.grid.2x2.fill";case .rooms:return "bed.double.fill";case .desk:return "bell.fill"
    case .guests:return "person.crop.circle";case .team:return "person.2.fill";case .supplies:return "shippingbox.fill"
    case .events:return "exclamationmark.bubble.fill";case .growth:return "chart.line.uptrend.xyaxis";case .cameras:return "video.fill"
    case .story:return "book.fill";case .books:return "banknote.fill"
    }}
}
struct HotelMiniRequest:Identifiable {
    let roomID:Int
    let repairing:Bool
    var id:String {"\(roomID)-\(repairing)"}
}
struct ManagementHub:View {
    @Binding var game:Game
    @Environment(\.dismiss) private var dismiss
    var initialTab:ManagementTab?=nil
    @AppStorage("littlehaven.management.tab") private var savedTab="Today"
    @State private var tab:ManagementTab = .overview
    @State private var roomFilter:RoomBoardFilter = .all
    @AppStorage("littlehaven.management.roomFilter") private var savedRoomFilter="All"
    @AppStorage("littlehaven.management.roomSearch") private var roomSearch=""
    @State private var feedback=""
    @State private var mini:HotelMiniRequest?
    @State private var showHavenLife=false
    private var motel:Motel {game.motel ?? Motel()}
    private let gold=Color(hex:0xEFC977)
    var body:some View {
        NavigationStack {
            VStack(spacing:10) {
                boardHeader
                if let incident=motel.operationsState.incident {
                    Button {dismiss()} label:{
                        Label("\(incident.kind.title) · \(incident.remaining)s · Return to grounds",systemImage:"exclamationmark.triangle.fill").font(.subheadline.bold()).padding(12).frame(maxWidth:.infinity).background(Color(hex:0x934936),in:RoundedRectangle(cornerRadius:12))
                    }.buttonStyle(.plain).padding(.horizontal).accessibilityIdentifier("managementEmergency")
                }
                boardNavigation
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        Color.clear.frame(height:1).id(tab.rawValue+"|top")
                        switch tab {
                        case .overview:overviewPanel
                        case .rooms:roomsPanel
                        case .desk:deskPanel
                        case .guests:guestsPanel
                        case .team:teamPanel
                        case .supplies:suppliesPanel
                        case .events:eventsPanel
                        case .growth:growthPanel
                        case .cameras:camerasPanel
                        case .story:storyPanel
                        case .books:booksPanel
                        }
                    }.padding().scrollTargetLayout().background(ManagementScrollMemory(page:tab.rawValue).frame(width:0,height:0))
                }
                if !feedback.isEmpty {Label(feedback,systemImage:"info.circle.fill").font(.subheadline).foregroundStyle(gold).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12)).padding(.horizontal).accessibilityIdentifier("managementFeedback")}
                Text("The hotel keeps running while this board is open.").font(.system(size:10)).foregroundStyle(.secondary).padding(.bottom,6)
            }.foregroundStyle(Color(hex:0xF5E7C8)).background(LinearGradient(colors:[Color(hex:0x143C37),Color(hex:0x102823)],startPoint:.topLeading,endPoint:.bottomTrailing))
                .navigationTitle("Hotel management").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented:$showHavenLife) {HavenLifeView(game:$game)}
                .toolbar {ToolbarItem(placement:.topBarLeading) {MenuBackButton(id:"closeManagement") {dismiss()}}}
        }.tint(gold).presentationBackground(Color(hex:0x172A25))
            .onChange(of:tab) {_,value in savedTab=value.rawValue}
            .onChange(of:roomFilter) {_,value in savedRoomFilter=value.rawValue}
            .onAppear {
                tab=initialTab ?? ManagementTab(rawValue:savedTab) ?? .overview
                roomFilter=RoomBoardFilter(rawValue:savedRoomFilter) ?? .all
                #if DEBUG
                let args=ProcessInfo.processInfo.arguments
                if args.contains("--ui-management") || args.contains("--ui-management-night") {tab = .rooms}
                if args.contains("--ui-management-cameras") {tab = .cameras}
                if args.contains("--ui-management-events") {tab = .events}
                if args.contains("--ui-management-desk") {tab = .desk}
                if args.contains("--ui-management-growth") {tab = .growth}
                if args.contains("--ui-management-dashboard") {tab = .overview}
                #endif
            }
            .sheet(item:$mini) { request in
                HotelMiniGame(repairing:request.repairing,outfit:FamilyHome.outfitColors[motel.household.outfit]) {
                    let result=perform { request.repairing ? $0.repairRoom(request.roomID) : $0.managerClean(request.roomID) }
                    if result {mini=nil}
                    return result
                }.presentationDetents([.medium,.large])
            }
    }
    private func card<Content:View>(@ViewBuilder _ content:()->Content)->some View {
        VStack(alignment:.leading,spacing:12,content:content).padding(16).frame(maxWidth:.infinity,alignment:.leading)
            .background(LinearGradient(colors:[Color(hex:0x254E46),Color(hex:0x1C3F39)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).stroke(.white.opacity(0.09),lineWidth:1))
    }

    private var boardHeader:some View {
        HStack(spacing:12) {
            Image(systemName:"building.2.crop.circle.fill").font(.title).foregroundStyle(gold)
            VStack(alignment:.leading,spacing:3) {
                Text("BRAINSTORM HAVEN").font(.caption.weight(.heavy)).tracking(1.2)
                Text("Day \(motel.day) · \(motel.clockLabel)").font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            VStack(alignment:.trailing,spacing:3) {
                Label(motel.cash.formatted(),systemImage:"circle.circle.fill").font(.headline).foregroundStyle(gold)
                Text("Reputation \(motel.simulation.reputation)/100").font(.caption).foregroundStyle(.white.opacity(0.65))
            }
        }.padding(.horizontal,18).padding(.vertical,8)
    }
    private var boardNavigation:some View {
        VStack(spacing:9) {
            HStack(spacing:3) {
                ForEach(ManagementPrimary.allCases) {group in
                    Button {tab=group.pages[0]} label:{
                        VStack(spacing:5) {
                            Image(systemName:group.symbol).font(.system(size:17))
                            Text(group.rawValue).font(.system(size:10,weight:.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                        }.frame(maxWidth:.infinity,minHeight:51)
                            .foregroundStyle(tab.primary==group ? Color(hex:0x18392F) : Color(hex:0xE6E7D8))
                            .background(tab.primary==group ? gold : Color.white.opacity(0.05),in:RoundedRectangle(cornerRadius:12))
                    }.buttonStyle(.plain).accessibilityIdentifier("managePrimary_"+group.id)
                        .accessibilityValue(tab.primary==group ? "Selected" : "")
                }
            }.padding(.horizontal,12)
            HStack(spacing:5) {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:6) {
                        ForEach(tab.primary.pages) {item in
                            Button(item.displayTitle) {tab=item}.font(.caption.bold()).padding(.horizontal,12).frame(minHeight:44)
                                .background(tab==item ? Color.white.opacity(0.14) : Color.clear,in:Capsule())
                                .buttonStyle(.plain).accessibilityIdentifier("manageTab_"+item.id)
                        }
                    }
                }
                Menu {
                    ForEach(ManagementPrimary.allCases) {group in
                        Section(group.rawValue) {
                            ForEach(group.pages) {item in
                                Button {tab=item} label:{Label(item.displayTitle,systemImage:item.symbol)}.accessibilityIdentifier("manageSection_"+item.id)
                            }
                        }
                    }
                } label:{Image(systemName:"square.grid.2x2.fill").frame(width:44,height:44)}
                    .accessibilityLabel("All management sections").accessibilityIdentifier("managementSections")
            }.padding(.horizontal,14)
        }.accessibilityElement(children:.contain)
    }
    private var readyRooms:Int {motel.rooms.filter(\.available).count}
    private var attentionRooms:Int {motel.rooms.filter{$0.dirty || !$0.health.faults.isEmpty || $0.health.condition<60}.count}
    private var lowSupplies:[Supply] {Supply.allCases.filter{motel.simulation.stock[$0.rawValue,default:0]<3}}
    private func metric(_ title:String,value:String,symbol:String,tint:UInt32)->some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {Image(systemName:symbol).foregroundStyle(Color(hex:tint));Spacer();Text(title).font(.caption.weight(.semibold))}
            Text(value).font(.system(.title2,design:.rounded,weight:.bold)).minimumScaleFactor(0.6).lineLimit(1)
        }.foregroundStyle(Color(hex:0x173A36)).padding(16).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color(hex:0xF3E9D3),in:RoundedRectangle(cornerRadius:18))
    }
    private var overviewPanel:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(alignment:.firstTextBaseline) {
                VStack(alignment:.leading,spacing:5) {Text("Your hotel, at a glance").font(.title2.bold()).accessibilityIdentifier("managementOverview");Text("Start with what needs you today.").font(.subheadline).foregroundStyle(.white.opacity(0.65))}
                Spacer()
            }
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                metric("Occupied",value:"\(motel.occupancy) / \(motel.rooms.count)",symbol:"bed.double.fill",tint:0x467F7E)
                metric("Ready rooms",value:"\(readyRooms)",symbol:"checkmark.seal.fill",tint:0x577B53)
                metric("Arrivals",value:"\(motel.waiting.count)",symbol:"person.crop.circle.badge.plus",tint:0xAA7852)
                metric("Daily wages",value:"\(motel.operationsState.workers.reduce(0,{$0+motel.scheduledWage($1.role)}))",symbol:"person.2.fill",tint:0x8C718D)
            }
            VStack(alignment:.leading,spacing:12) {
                Text("Needs attention").font(.headline)
                if motel.operationsState.incident==nil && motel.simulation.issues.isEmpty && attentionRooms==0 && lowSupplies.isEmpty && !motel.simulation.powerOut && !motel.simulation.waterOut && motel.business.police==nil {
                    Label("Everything is running smoothly",systemImage:"checkmark.circle.fill").foregroundStyle(.mint).font(.subheadline)
                }
                if motel.operationsState.incident != nil {dashboardAction("Respond to emergency",detail:"Return to the grounds now",symbol:"flame.fill",urgent:true,id:"quickEmergency"){dismiss()}}
                if motel.business.police != nil {dashboardAction("Officer needs you",detail:"Return to resolve the police case",symbol:"exclamationmark.shield.fill",urgent:true,id:"quickPolice"){dismiss()}}
                if motel.simulation.powerOut || motel.simulation.waterOut {dashboardAction("Restore utilities",detail:"Power or water is offline",symbol:"bolt.slash.fill",urgent:true,id:"quickUtilities"){tab = .events}}
                if !motel.simulation.issues.isEmpty {dashboardAction("\(motel.simulation.issues.count) guest requests",detail:"Review deadlines and respond",symbol:"exclamationmark.bubble.fill",urgent:true,id:"quickEvents"){tab = .events}}
                if attentionRooms>0 {dashboardAction("\(attentionRooms) rooms need care",detail:"Clean rooms or repair faults",symbol:"sparkles",id:"quickAttention"){roomFilter = .attention;tab = .rooms}}
                if !lowSupplies.isEmpty {dashboardAction("Restock essentials",detail:lowSupplies.map(\.title).joined(separator:", "),symbol:"shippingbox.fill",id:"quickSupplies"){tab = .supplies}}
            }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:18))
            Text("Quick actions").font(.headline)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                dashboardAction("Front desk",detail:"Assign arriving guests",symbol:"bell.fill",id:"quickDesk"){tab = .desk}
                dashboardAction("Rooms",detail:"View availability",symbol:"bed.double.fill",id:"quickRooms"){roomFilter = .all;tab = .rooms}
                dashboardAction("Team",detail:"Shifts and training",symbol:"person.2.fill",id:"quickTeam"){tab = .team}
                dashboardAction("Haven life",detail:"Goals, meals and discoveries",symbol:"leaf.fill",id:"managementHavenLife"){showHavenLife=true}
            }
            card {
                Label("Today's update",systemImage:"newspaper.fill").font(.headline)
                Text(motel.simulation.news).font(.subheadline).foregroundStyle(.white.opacity(0.75)).accessibilityIdentifier("managementNews")
                if motel.simulation.billDebt+motel.simulation.loanDebt>0 {
                    Button("Review bills and loans") {tab = .books}.buttonStyle(.bordered)
                }
            }
        }
    }
    private func dashboardAction(_ title:String,detail:String,symbol:String,urgent:Bool=false,id:String,action:@escaping()->Void)->some View {
        Button(action:action) {
            HStack(alignment:.top,spacing:10) {
                Image(systemName:symbol).font(.title3).frame(width:23).foregroundStyle(urgent ? Color(hex:0xF2A78D) : gold)
                VStack(alignment:.leading,spacing:5) {Text(title).font(.subheadline.weight(.semibold));Text(detail).font(.caption).foregroundStyle(.white.opacity(0.62))}
                Spacer(minLength:0)
                Image(systemName:"chevron.right").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.4))
            }.frame(maxWidth:.infinity,alignment:.leading).padding(14)
                .background(urgent ? Color(hex:0x754D3E).opacity(0.45) : Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
    private var filteredRooms:[MotelRoom] {
        motel.rooms.filter {room in
            let matches=roomSearch.isEmpty || "\(room.number)".contains(roomSearch) || (room.guest?.name.localizedCaseInsensitiveContains(roomSearch) ?? false)
            switch roomFilter {
            case .all:return matches
            case .ready:return matches && room.available
            case .occupied:return matches && room.guest != nil
            case .attention:return matches && (room.dirty || !room.health.faults.isEmpty || room.health.condition<60)
            }
        }
    }

    private var roomsPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Find the right room").font(.title2.bold())
            TextField("Search room number or guest",text:$roomSearch).textFieldStyle(.plain).padding(13).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:12)).submitLabel(.done).autocorrectionDisabled().textInputAutocapitalization(.never).accessibilityIdentifier("roomSearch")
            Picker("Room status",selection:$roomFilter) {ForEach(RoomBoardFilter.allCases) {value in Text(value.rawValue).tag(value)}}.pickerStyle(.segmented).accessibilityIdentifier("roomStatusFilter")
            Text("\(filteredRooms.count) rooms · \(readyRooms) ready to book").font(.caption).foregroundStyle(.white.opacity(0.65)).accessibilityIdentifier("roomResultCount")
            if filteredRooms.isEmpty {Label("No rooms match this filter",systemImage:"magnifyingglass").padding(.vertical,25)}
            ForEach(filteredRooms) {room in roomCard(room).accessibilityElement(children:.contain).accessibilityIdentifier("managementRoom_\(room.id)").id("Rooms|room-\(room.id)")}
        }.scrollTargetLayout()
    }
    private func roomCard(_ room:MotelRoom)->some View {
        card {
            HStack {
                RoomIllustration(theme:room.theme,level:room.furniture,office:false).frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:10))
                VStack(alignment:.leading,spacing:4) {
                    Text("Room \(room.number)").font(.title3.bold())
                    Text(room.health.kind.title+" · "+(room.guest != nil ? "Occupied" : room.available ? "Ready" : "Needs care")).font(.caption.weight(.semibold)).foregroundStyle(room.available ? .mint : gold)
                    Text(room.guest.map { $0.name+" / "+$0.kind.title } ?? (room.available ? "Ready for assignment" : "Needs attention")).font(.caption)
                    Text("\(motel.rate(for:room)) / night").font(.caption.bold()).foregroundStyle(gold)
                }
            }
            Text("Cleanliness \(room.health.cleanliness)%").font(.caption)
            ProgressView(value:Double(room.health.cleanliness)/100).tint(.mint)
            Text("Condition \(room.health.condition)%").font(.caption)
            ProgressView(value:Double(room.health.condition)/100).tint(gold)
            if !room.health.faults.isEmpty {Text(room.health.faults.map(\.title).sorted().joined(separator:", ")).font(.caption).foregroundStyle(.orange)}
            HStack {
                Button("Clean room") {mini=HotelMiniRequest(roomID:room.id,repairing:false)}.accessibilityIdentifier("miniClean_\(room.id)")
                Button("Repair / pests") {mini=HotelMiniRequest(roomID:room.id,repairing:true)}.accessibilityIdentifier("miniRepair_\(room.id)")
            }.font(.caption.bold()).buttonStyle(.bordered)
            DisclosureGroup("Room options & upgrades") {
            if room.guest == nil {
                ForEach(RoomKind.allCases) {kind in
                    let reason=kind==room.health.kind ? "Current room type" : kind == .suite && motel.simulation.reputation<60 ? "Requires reputation 60" : nil
                    VStack(alignment:.leading,spacing:7) {
                        Text(kind.title).font(.subheadline.bold())
                        PurchaseDetails(price:kind==room.health.kind ? 0 : kind.cost,cash:motel.cash,benefit:"Nightly room premium: \(kind.premium) coins",requirement:reason)
                        Button("Change to "+kind.title) {_=perform{$0.changeRoomKind(room.id,kind:kind)}}.disabled(reason != nil || motel.cash<kind.cost)
                    }.padding(.vertical,7)
                }
                ForEach(RoomUpgrade.allCases) {upgrade in
                    let owned=room.health.upgrades.contains(upgrade)
                    VStack(alignment:.leading,spacing:7) {
                        Text(upgrade.title).font(.subheadline.bold())
                        PurchaseDetails(price:owned ? 0 : upgrade.cost,cash:motel.cash,benefit:upgrade.benefit,requirement:owned ? "Already installed" : nil)
                        Button("Install "+upgrade.title) {_=perform{$0.buyRoomUpgrade(room.id,upgrade:upgrade)}}.disabled(owned || motel.cash<upgrade.cost)
                    }.padding(.vertical,7)
                }
            } else {Button("Check out & inspect") {_=perform{$0.checkoutGuest(room.id)}}}
            ForEach(Array(room.health.upgrades).sorted{$0.rawValue<$1.rawValue}) {upgrade in
                Text("? \(upgrade.title): \(upgrade.benefit)").font(.caption2)
            }
            }.font(.subheadline)

        }
    }
    private var deskPanel:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Daytime check-in: 07:00-19:00. Hourly visits check out after two game hours. Weekly stays receive a 20% discount.").font(.caption)
            Picker("Price policy",selection:Binding(get:{motel.simulation.prices},set:{value in change{$0.setPrices(value,plan:$0.simulation.plan)}})) {
                ForEach(PricePolicy.allCases) {value in Text(value.rawValue.capitalized).tag(value)}
            }.pickerStyle(.segmented).accessibilityIdentifier("pricingPolicy")
            Picker("Contract",selection:Binding(get:{motel.simulation.plan},set:{value in change{$0.setPrices($0.simulation.prices,plan:value)}})) {
                ForEach(RentalPlan.allCases) {value in Text(value.rawValue.capitalized).tag(value)}
            }.pickerStyle(.segmented)
            Text("Waiting arrivals").font(.headline)
            if motel.waiting.isEmpty {Text("No arrivals waiting. Night arrivals appear as special event requests.").font(.caption)}
            ForEach(motel.waiting) {guest in arrivalCard(guest).id("Desk|guest-\(guest.id)")}
            Text("Reservations / no-shows \(motel.simulation.noShows)").font(.headline)
            ForEach(motel.simulation.reservations) {reservation in
                card {
                    Text(reservation.guest.name+" / reserved arrival").font(.subheadline.bold())
                    Text("Due at \(reservation.arrivalHour%24):00 / \(reservation.processed ? reservation.noShow ? "No-show fee collected" : "Arrived" : "10-coin no-show guarantee")").font(.caption)
                }
            }
        }.scrollTargetLayout()
    }
    private func arrivalCard(_ guest:MotelGuest)->some View {
        card {
            HStack {
                PaperPortrait(color:guest.color,variant:guest.appearanceSeed).frame(width:40,height:48)
                VStack(alignment:.leading) {Text(guest.name+" / "+guest.kind.title).font(.subheadline.bold());Text(guest.kind.preference).font(.caption)}
            }
            if motel.simulation.visits[guest.name,default:0]>0 {Text("Returning guest / relationship \(motel.simulation.relationships[guest.name,default:0])").font(.caption).foregroundStyle(gold)}
            Button(motel.simulation.checkedIDs.contains(guest.id) ? "Identity verified" : "Verify identity") {change{$0.verifyGuest(guest.id)}}.disabled(motel.simulation.checkedIDs.contains(guest.id)).accessibilityIdentifier("verify_\(guest.id)")
            Menu("Assign room & collect payment") {
                ForEach(motel.rooms.filter(\.available)) {room in
                    Button("\(room.number) / \(motel.bookingQuote(guest,room:room)) coins") {_=perform{$0.managerAssignGuest(guest.id,roomID:room.id)}}.disabled(!motel.mayCheckIn(guest,room:room))
                }
            }.accessibilityIdentifier("assign_\(guest.id)")
            if let room=motel.rooms.first(where:{$0.available}) {Text(motel.checkInExplanation(guest,room:room)).font(.caption2)}
            Button("Reserve for two hours later") {_=perform{$0.reserveGuest(guest.id)}}.disabled(motel.isNight)
        }
    }
    private var guestsPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Guest relationships persist across visits. Clean, quiet rooms, working AC, Wi-Fi and secure doors protect reviews.").font(.caption)
            ForEach(motel.rooms.filter{$0.guest != nil}) {room in
                if let guest=room.guest {
                    card {
                        Text(guest.name+" / "+guest.kind.title+" / Room \(room.number)").font(.headline)
                        Text(guest.kind.preference).font(.caption)
                        Text("Trust \(motel.simulation.relationships[guest.name,default:0]) / stays \(motel.simulation.visits[guest.name,default:0])").font(.caption).foregroundStyle(gold)
                        Text("Clean \(room.health.cleanliness)% / AC \(room.health.faults.contains(.ac) ? "broken" : "working") / Wi-Fi \(motel.simulation.powerOut ? "offline" : motel.simulation.facilities.contains(.wifi) ? "fiber" : "standard")").font(.caption)
                        Button("Personal service / 8 coins + snack") {_=perform{$0.serviceGuest(guest.id)}}.buttonStyle(.bordered)
                    }.id("Guests|guest-\(guest.id)")
                }
            }
            ReviewsPanel(motel:motel)
        }.scrollTargetLayout()
    }
    private var teamPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Speed controls work pace; skill controls emergency response; honesty affects missing cash. Night coverage adds 50% wages and fatigue. Two unpaid shifts can make staff quit.").font(.caption)
            ForEach(StaffRole.allCases) { role in
                let profile=motel.simulation.profiles[role.rawValue] ?? StaffProfile.make(role)
                card {
                    Text(role.name+" / "+role.title).font(.headline)
                    Text(role.duty).font(.caption)
                    Text("Speed \(profile.speed) / honesty \(profile.honesty) / skill \(profile.skill)").font(.caption)
                    Text("Wage \(motel.scheduledWage(role))/day / loyalty \(profile.loyalty) / fatigue \(profile.fatigue)").font(.caption).foregroundStyle(gold)
                    if motel.operationsState.workers.contains(where:{$0.role==role}) {
                        Button(profile.nightShift ? "Remove night coverage" : "Add night coverage (+50% wage)") {change{$0.scheduleNight(role)}}.buttonStyle(.bordered)
                        HStack {
                            Button("Train / rest / 25") {_=perform{$0.trainStaff(role)}}
                            Button("Dismiss") {change{$0.dismissStaff(role)}}
                        }.font(.caption).buttonStyle(.bordered)
                    } else {
                        PurchaseDetails(price:role.hireCost,cash:motel.cash,benefit:role.duty+" First shift included; then \(motel.scheduledWage(role)) coins per day.",requirement:motel.hiringUnlocked(role) ? nil : motel.hiringProgress(role))
                        Button("Hire \(role.name) / \(role.hireCost)") {_=perform{$0.hire(role)}}.buttonStyle(.bordered).disabled(!motel.hiringUnlocked(role) || motel.cash<role.hireCost).accessibilityIdentifier("manageHire_"+role.rawValue)
                    }
                }.id("Team|staff-\(role.rawValue)")
            }
        }.scrollTargetLayout()
    }
    private var suppliesPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Every check-in uses towels and toiletries. Cleaning uses detergent; repairs use parts; pest treatment uses pesticide. Fridges and the restaurant use snacks.").font(.caption)
            ForEach(Supply.allCases) {item in
                card {
                    HStack {Text(item.title).font(.headline);Spacer();Text("In stock: \(motel.simulation.stock[item.rawValue,default:0])").font(.caption)}
                    PurchaseDetails(price:item.price*5,cash:motel.cash,benefit:"Add 5 units; new stock: \(motel.simulation.stock[item.rawValue,default:0]+5)")
                    Button("Buy 5 / \(item.price*5)") {_=perform{$0.buyStock(item)}}.buttonStyle(.bordered).disabled(motel.cash<item.price*5).accessibilityIdentifier("buy_"+item.rawValue)
                }.id("Supplies|supply-\(item.rawValue)")
            }
        }.scrollTargetLayout()
    }
    private var eventsPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Night problems are more frequent. Door cameras give extra response time. Unresolved complaints damage reputation, bills and future bookings.").font(.caption)
            if motel.simulation.powerOut || motel.simulation.waterOut {
                card {
                    Text("Utilities emergency").font(.headline)
                    Text("Power: \(motel.simulation.powerOut ? "OFF" : "ON") / Water: \(motel.simulation.waterOut ? "OFF" : "ON")").font(.caption)
                    Button("Restore utilities / 20 + 2 parts") {_=perform{$0.restoreUtilities()}}.buttonStyle(.bordered).accessibilityIdentifier("restoreUtilities")
                }
            }
            if motel.simulation.issues.isEmpty {Text("No pending complaints. Keep watching room condition and the night shift.")}
            ForEach(motel.simulation.issues) {issue in
                card {
                    Text(issue.kind.title).font(.headline)
                    Text("Room \(motel.rooms.first{$0.id==issue.roomID}?.number ?? 0) / \(issue.guestName) / \(max(0,issue.deadline-motel.simulation.absoluteHour)) hours left").font(.caption).foregroundStyle(.orange)
                    Text(issue.kind.detail).font(.caption)
                    Text("Repairs: 1 part. Pests: 2 pesticide. Service fee: \(issue.kind.cost).").font(.caption2)
                    Button("Respond safely / \(issue.kind.cost)") {_=perform{$0.respondToIssue(issue.id,choice:0)}}.buttonStyle(.bordered).accessibilityIdentifier("respond_\(issue.id)")
                    if [.adultVisitor,.drugDeal,.cult,.celebrity].contains(issue.kind) {
                        Button("Decline request") {_=perform{$0.respondToIssue(issue.id,choice:2)}}.buttonStyle(.bordered)
                        if motel.simulation.shadyOffers {
                            Button("Take off-books cash / reputation & police risk") {_=perform{$0.respondToIssue(issue.id,choice:1)}}.buttonStyle(.bordered).tint(.orange)
                        }
                    }
                }.id("Events|issue-\(issue.id)")
            }
        }.scrollTargetLayout()
    }
    private var growthPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Reputation unlocks better rooms and development. Land expands to nine rooms; an upper floor expands to eighteen. Amenities improve rates and demand.").font(.caption)
            card {
                Text("\(motel.rooms.count)/\(motel.expansionCapacity) rooms / reputation \(motel.simulation.reputation)").font(.headline)
                Button("Build next room / \(motel.expansionCost)") {_=perform{$0.expand()}}.buttonStyle(.bordered).disabled(motel.goalReached || motel.cash<motel.expansionCost).accessibilityIdentifier("manageBuildRoom")
                if motel.simulation.facilities.contains(.upperFloor) {
                    HStack {
                        Button("View ground floor") {_=perform{$0.setViewingFloor(0)}}
                        Button("View upper floor") {_=perform{$0.setViewingFloor(1)}}
                    }.font(.caption).buttonStyle(.bordered)
                    Text("Change floors while standing outside, then use the room doors.").font(.caption2)
                }
            }
            ForEach(Facility.allCases) {facility in
                card {
                    Text(facility.title).font(.headline)
                    PurchaseDetails(price:motel.simulation.facilities.contains(facility) ? 0 : facility.cost,cash:motel.cash,benefit:facilityBenefit(facility),requirement:motel.facilityLockReason(facility))
                    if motel.simulation.facilities.contains(facility) {Text("Operational").foregroundStyle(.mint)}
                    else {
                        if !motel.journeyAllows(facility) {Text("Unlock: "+Motel.journeyNames[motel.facilityJourneyTier(facility)]+" milestone in Haven life").font(.caption).foregroundStyle(.orange)}
                        Button("Develop / \(facility.cost)") {_=perform{$0.installFacility(facility)}}.buttonStyle(.bordered).disabled(motel.facilityLockReason(facility) != nil || motel.cash<facility.cost).accessibilityIdentifier("develop_"+facility.rawValue)
                    }
                }.id("Growth|facility-\(facility.rawValue)")
            }
        }.scrollTargetLayout()
    }
    private var camerasPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Corridor and grounds monitoring. Room interiors stay private.").font(.caption)
            if !motel.simulation.facilities.contains(.cameras) {Text("Install the camera network under Growth to open the monitor.")}
            else if motel.simulation.powerOut {Text("Cameras offline: restore the power.").foregroundStyle(.orange)}
            else {
                MotelGroundsCanvas(motel:motel,x:Double(motel.actorTile.x),y:Double(motel.actorTile.y),npcTick:Double(motel.worldState.tick),fullMap:true)
                    .frame(width:Double(MotelGrounds.width*16),height:Double(MotelGrounds.height*16)).scaleEffect(0.25,anchor:.topLeading).frame(width:288,height:192,alignment:.topLeading)
                    .colorMultiply(motel.simulation.nightVision ? Color.green : .white)
                    .brightness(motel.isNight && !motel.simulation.nightVision ? -0.3 : 0)
                    .clipped().accessibilityElement(children:.ignore).accessibilityLabel("Live corridor and grounds cameras").accessibilityIdentifier("cameraMonitor")
                Button(motel.simulation.nightVision ? "Disable night vision" : "Enable night vision") {change{$0.toggleNightVision()}}.buttonStyle(.bordered).disabled(!motel.simulation.facilities.contains(.nightVision))
                Text("Live grounds feed / floor \(motel.viewingFloor+1) / \(motel.clockLabel)").font(.caption.monospaced())
                ForEach(motel.rooms) {room in
                    HStack {Text("Door \(room.number)");Spacer();Text(room.guest?.name ?? "Vacant").foregroundStyle(gold)}
                        .font(.caption).padding(6).background(Color.white.opacity(0.05))
                }
            }
        }
    }
    private var storyPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Your decisions build a story. Endings unlock after day 14 or eighteen rooms; play can continue afterward.").font(.caption)
            card {
                Text("Current path: "+motel.storyEnding).font(.headline)
                Text("Ethical \(motel.simulation.ethical) / greedy \(motel.simulation.greedy) / criminal \(motel.simulation.criminal) / cult-friendly \(motel.simulation.cultFriendly)").font(.caption)
                Text("Police attention \(motel.simulation.heat) / reputation \(motel.simulation.reputation)").font(.caption).foregroundStyle(.orange)
                Button(motel.simulation.shadyOffers ? "Disable shady offers" : "Enable optional shady offers") {change{$0.toggleShadyOffers()}}.buttonStyle(.bordered).accessibilityIdentifier("shadyOffers")
                Text("Shady offers unlock fictional off-books rentals and event choices, with fines and reputation consequences. Standard lawful bookings remain available.").font(.caption2)
                Button("Record story ending") {change{$0.claimStoryEnding()}}.buttonStyle(.bordered).disabled(motel.day<14 && motel.rooms.count<18)
                ForEach(motel.simulation.endings,id:\.self) {ending in Text("ENDING: "+ending).font(.headline).foregroundStyle(gold)}
            }
            Text("Local economy: "+motel.simulation.economy.headline).font(.subheadline)
            Text("Festivals bring demand and parties. Tourist season supports better rooms. Factory closures increase weekly residents. Heatwaves stress AC.").font(.caption)
        }
    }
    private var booksPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            card {
                Text("Bills \(motel.simulation.billDebt) / loan balance \(motel.simulation.loanDebt)").font(.headline)
                Text("Daily rent: \(30+motel.rooms.count*4). Utilities start at \(8+motel.rooms.count*3); amenities add costs. Staff are paid each morning.").font(.caption)
                Button("Advance one game hour") {change{$0.advanceHotelHour()}}.buttonStyle(.bordered).accessibilityIdentifier("advanceHour")
                Button("Repay bills / loans") {_=perform{$0.repayBills()}}.buttonStyle(.bordered)
                Button("Emergency loan: receive 200, repay 240") {_=perform{$0.emergencyLoan()}}.buttonStyle(.bordered).disabled(motel.simulation.loanDebt>=480)
            }
            ForEach(motel.simulation.ledger) {line in
                HStack(alignment:.top) {
                    VStack(alignment:.leading) {Text("Day \(line.day), \(line.hour):00 / "+line.category).font(.caption.bold());Text(line.note).font(.caption2)}
                    Spacer()
                    Text(line.amount>=0 ? "+\(line.amount)" : "\(line.amount)").foregroundStyle(line.amount>=0 ? Color.mint : Color.orange).font(.caption.monospaced())
                }.padding(8).background(Color.white.opacity(0.05)).id("Books|line-\(line.id)")
            }
        }.scrollTargetLayout()
    }
    private func facilityBenefit(_ facility:Facility)->String {
        switch facility {
        case .adjacentLot:return "Increase development capacity to nine rooms"
        case .upperFloor:return "Increase development capacity to eighteen rooms"
        case .pool:return "Open a staffed swimming pool amenity"
        case .restaurant:return "Serve meals and improve guest demand"
        case .parking:return "Provide six guest parking bays"
        case .wifi:return "Improve room rates and guest connectivity"
        case .cameras:return "Monitor corridors and gain more response time"
        case .nightVision:return "Keep camera monitoring useful at night"
        }
    }
    private func change(_ action:(inout Motel)->Void) {
        guard var current=game.motel else{return};action(&current);game.motel=current;feedback=current.lastEvent;game.save()
    }
    @discardableResult private func perform(_ action:(inout Motel)->Bool)->Bool {
        guard var current=game.motel else{return false};let result=action(&current);game.motel=current
        feedback=result ? current.lastEvent : "Not available yet. Check the cost, supplies and requirements shown on this card."
        if result {game.save()}
        return result
    }
}
struct HotelMiniGame:View {
    let repairing:Bool
    var outfit:UInt32 = 0x6AACA3
    let complete:()->Bool
    @Environment(\.dismiss) private var dismiss
    @State private var started=Date()
    @State private var hits=0
    @State private var misses=0
    @State private var lastCycle = -1
    @State private var message="Tap when the marker is inside the green zone."
    var body:some View {
        VStack(spacing:18) {
            HStack {MenuBackButton(id:"cancelMiniGame") {dismiss()};Spacer();Text(repairing ? "Repair workshop" : "Cleaning challenge").font(.headline)}
            TimelineView(.animation(minimumInterval:0.04)) {timeline in
                let elapsed=timeline.date.timeIntervalSince(started)
                let phase=elapsed.truncatingRemainder(dividingBy:1.6)/1.6
                VStack {
                    WorkingCharacterArtwork(kind:repairing ? "repair" : "mop",frame:Int(elapsed*12)%12,color:outfit)
                        .scaleEffect(2.2).frame(width:150,height:110)
                    GeometryReader {geometry in
                        ZStack(alignment:.leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Rectangle().fill(.green.opacity(0.6)).frame(width:geometry.size.width*0.5).offset(x:geometry.size.width*0.25)
                            Rectangle().fill(Color(hex:0xF1D28A)).frame(width:5).offset(x:phase*(geometry.size.width-5))
                        }
                    }.frame(height:24)
                }
            }
            Text("Good actions \(hits)/3 / missed \(misses)").font(.headline)
            Text(message).font(.caption)
            Button(repairing ? "TIGHTEN" : "SCRUB") {
                let elapsed=Date().timeIntervalSince(started),cycle=Int(elapsed/1.6)
                guard cycle != lastCycle else{message="Wait for the next sweep.";return}
                lastCycle=cycle
                if MiniGameTiming.isHit(elapsed:elapsed) {hits += 1;message="Good timing!"}
                else {misses += 1;message="Missed. Wait for the green zone."}
                if hits>=3 {if !complete(){message="Need supplies and repair coins. Cancel, restock and try again.";hits=2}}
            }.buttonStyle(MotelButtonStyle()).accessibilityIdentifier("miniGameTap")
        }.padding(24).foregroundStyle(Color(hex:0xF5E7C8)).background(PaintedPanel(color:0x172A25))
    }
}

/// Original character art with articulated shoulders, elbows, wrists and held tools.
struct WorkingCharacterArtwork:View {
    let kind:String
    let frame:Int
    var color:UInt32=0xC7D0D4
    var variant=7
    var facing=2
    var body:some View {
        Canvas { c,_ in
            if kind.hasPrefix("care-") {
                PersonalCareArt.draw(context:&c,kind:kind,frame:frame,color:color,variant:variant)
                return
            }
            let wave=sin(Double(frame) * .pi/6)
            let press=(1-cos(Double(frame) * .pi/3))/2
            let skin:UInt32=[7,8,9].contains(variant) ? (variant==8 ? 0xD79F77 : 0xE3B38E) : NPCDesign.skinColors[NPCDesign(variant:variant).skin]
            let garment=[7,8,9].contains(variant) ? color : NPCDesign(variant:variant).shirtColor(base:color)
            if facing == 1 {c.translateBy(x:48,y:0);c.scaleBy(x:-1,y:1)}
            func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ tint:UInt32) {
                c.fill(Path(ellipseIn:CGRect(x:x,y:y,width:w,height:h)),with:.color(Color(hex:tint)))
            }
            func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ tint:UInt32) {
                let p=Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:1)
                c.fill(p,with:.color(Color(hex:tint)));c.stroke(p,with:.color(Color(hex:0x36443D)),lineWidth:0.35)
            }
            func line(_ points:[CGPoint],_ tint:UInt32,_ width:Double) {
                var p=Path()
                for (i,v) in points.enumerated(){if i==0 {p.move(to:v)} else {p.addLine(to:v)}}
                c.stroke(p,with:.color(Color(hex:tint)),style:StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round))
            }
            func arm(_ sx:Double,_ sy:Double,_ ex:Double,_ ey:Double,_ hx:Double,_ hy:Double) {
                line([CGPoint(x:sx,y:sy),CGPoint(x:ex,y:ey),CGPoint(x:hx,y:hy)],0x393733,3.1)
                line([CGPoint(x:sx,y:sy),CGPoint(x:ex,y:ey)],garment,2.7)
                line([CGPoint(x:ex,y:ey),CGPoint(x:hx,y:hy)],skin,2.5)
                oval(hx-1.5,hy-1.5,3,3,skin)
            }
            let bodyX=kind == "cpr" ? 17.0+press*0.5 : 16.0
            let bodyY=kind == "cpr" ? 21.0+press*0.7 : 19.0
            PaperPerson.draw(context:&c,x:bodyX,y:bodyY,color:color,variant:variant,
                facing:kind == "calm" || kind == "swim" ? 0 : 2,walk:0,hands:false,kneeling:kind == "cpr" || kind == "swim")
            switch kind == "breakfast" && frame>=8 ? "wipe" : kind {
            case "extinguish":
                PaintedArt.draw("extinguisher",in:CGRect(x:26,y:23,width:10,height:15),context:&c,fit:true)
                line([CGPoint(x:27,y:24),CGPoint(x:33,y:24+press*0.7)],0x343D3D,1.2)
                var hose=Path();hose.move(to:CGPoint(x:32,y:26))
                hose.addCurve(to:CGPoint(x:37,y:25+wave),control1:CGPoint(x:38,y:36),control2:CGPoint(x:40,y:29))
                c.stroke(hose,with:.color(Color(hex:0x303B39)),style:StrokeStyle(lineWidth:1.3,lineCap:.round))
                arm(19,28,23,27,29,24.7+press*0.5);arm(29,28,31,28,36,25+wave)
                line([CGPoint(x:36,y:25+wave),CGPoint(x:40,y:23+wave)],0x303B39,2)
            case "swim","rescue":
                arm(19,28,16-wave*3,28,13-wave*2,31+wave*3)
                arm(29,28,32+wave*3,28,35+wave*2,31-wave*3)
                for side in [13.0,34] {
                    c.stroke(Path(ellipseIn:CGRect(x:side-4,y:32+wave,width:8,height:2)),with:.color(.white.opacity(0.65)),lineWidth:0.6)
                }
            case "cpr":
                arm(21,27,32,29+press,45,33+press*1.5)
                arm(29,27,37,29+press,45.5,33+press*1.5)
                oval(43.5,32+press*1.5,4,2.2,skin)
            case "calm":
                arm(19,28,15,25-wave,11,21-wave);arm(29,28,33,25-wave,37,21-wave)
                box(9.5,17-wave,3,5,skin);box(35.5,17-wave,3,5,skin)
            case "repair","build":
                box(34,31,10,7,0x75857C)
                let tip=CGPoint(x:38,y:32),handle=CGPoint(x:31+wave*3,y:25-wave)
                line([handle,tip],0xCBD3CE,1.8)
                c.stroke(Path(ellipseIn:CGRect(x:36.4,y:30.4,width:3.2,height:3.2)),with:.color(Color(hex:0xD5DBD6)),lineWidth:1)
                arm(19,28,25,29,34,34);arm(29,28,30,27,handle.x,handle.y)
            case "pest":
                box(27,29,6,9,0xD3B46F);box(29,26,2,3,0x4B6457)
                line([CGPoint(x:30,y:27),CGPoint(x:37,y:28+wave)],0x485B50,1.1)
                arm(19,28,24,29,29,28);arm(29,28,33,29,36,28+wave)
                for i in 0..<5 {let t=Double((frame+i)%12)/12;oval(37+t*9,29+t*6,0.8+t,0.8+t,0xD7DCC2)}
            case "mop","carwash":
                for i in 0..<3 {
                    let fade=Double((frame+i*3)%12)/12
                    var dust=c;dust.opacity=1-fade
                    dust.fill(Path(ellipseIn:CGRect(x:34+Double(i*3)+fade*3,y:39-fade*4,width:1.8,height:1)),with:.color(Color(hex:0xCCBD97)))
                }
                let head=CGPoint(x:35+wave*5,y:40)
                line([CGPoint(x:28,y:24),head],0xB7986A,1.5);oval(head.x-5,head.y-1,10,3,0xB9D1BD)
                for i in 0..<4 {line([CGPoint(x:head.x-4+Double(i)*2,y:40),CGPoint(x:head.x-4+Double(i)*2,y:42)],0xDAE1CF,0.6)}
                arm(19,28,23,29,29+wave,29);arm(29,28,30,29,32+wave*2,33)
            case "garden":
                box(31,29,8,7,0x8EAA70);line([CGPoint(x:38,y:31),CGPoint(x:43,y:29)],0x8EAA70,2)
                arm(19,28,25,29,32,29);arm(29,28,31,27,35,28)
                for i in 0..<4 {oval(42+Double(i),31+Double((frame+i)%6),0.7,1.4,0xD5E8D5)}
            case "paint":
                let ry=28+wave*4
                line([CGPoint(x:31,y:35),CGPoint(x:37,y:ry)],0xB39262,1.4)
                box(34,ry-3,8,3,0xB0C7A4);arm(29,28,30,29,32,32);arm(19,28,22,29,24,32)
            case "supplies","restock":
                for i in 0..<3 {box(33+Double(i)*3,30,2.5,7,UInt32(0x9DBAA8)+UInt32(i*0x090400))}
                box(32,37,13,1,0x947454)
                arm(19,28,24,30,31+press*7,30);arm(29,28,32,30,35,33)
            case "wipe":
                box(29,34,17,2,0x947454)
                box(32+wave*4,32,6,2,0xD8DFCA)
                arm(19,28,24,30,29,33);arm(29,28,33,30,35+wave*4,32)
            case "bed","laundry":
                var sheet=Path();sheet.move(to:CGPoint(x:27,y:28-wave))
                sheet.addQuadCurve(to:CGPoint(x:43,y:28+wave),control:CGPoint(x:35,y:24-wave*3))
                sheet.addLine(to:CGPoint(x:43,y:36));sheet.addLine(to:CGPoint(x:27,y:36));sheet.closeSubpath()
                c.fill(sheet,with:.color(Color(hex:0xF0EBD8)));c.stroke(sheet,with:.color(Color(hex:0xADBBA6)),lineWidth:0.5)
                arm(19,28,23,28,27,28-wave);arm(29,28,35,27,42,28+wave)
            case "trash","luggage":
                box(34,32-wave*2,8,9,kind == "trash" ? 0x46584C : 0xAA7856)
                line([CGPoint(x:36,y:32-wave*2),CGPoint(x:36,y:30-wave*2),CGPoint(x:40,y:30-wave*2),CGPoint(x:40,y:32-wave*2)],0x33453C,1)
                arm(29,28,32,28,38,30-wave*2);arm(19,28,19,28,19,31)
            default:
                box(27,31,16,1.5,0xB18C60);box(32,27,4,4,0xEEE1C4);oval(38,28,5,3,0xCEAB6E)
                arm(19,28,24,29,28,31);arm(29,28,33,29,40,31)
            }
        }.frame(width:48,height:48)
    }
}

enum GardenSection:String,CaseIterable,Identifiable {
    case grow="Grow",cook="Cook",pantry="Pantry"
    var id:String {rawValue}
}
enum HavenTab:String,CaseIterable,Identifiable {
    case neighbors="Neighbors",identity="Identity",team="Team",creatures="Creatures",calendar="Calendar",consequences="Consequences"
    case inspections="Inspections",rival="Rival motel",celebrations="Celebrations"
    case journey="Journey",rooms="Room design",breakfast="Breakfast",forecast="Weather",journal="Journal",goals="Daily goals",garden="Garden & kitchen"
    var id:String {rawValue}
}
struct HavenLifeView:View {
    @Binding var game:Game
    var initialTab:HavenTab = .neighbors
    @AppStorage("littlehaven.haven.tab") private var savedHavenTab="Neighbors"
    @State private var tab:HavenTab = .neighbors
    @State private var gardenSection:GardenSection = .grow
    @State private var gardenCrop:GardenCrop = .basil
    @State private var feedback=""
    @Environment(\.dismiss) private var dismiss
    private var motel:Motel {game.motel ?? Motel()}
    private func act(_ action:(inout Motel)->Bool) {
        guard var value=game.motel else{return}
        if action(&value) {feedback=value.lastEvent;game.motel=value;game.save()}
        else {feedback="Meet the location, cost or daily requirement shown below first."}
    }
    var body:some View {
        NavigationStack {
            VStack(spacing:12) {
                Text("DAY \(motel.day) · WEEKDAY \(motel.havenWeekday)/7 · \(motel.cash) COINS").font(.caption.monospaced())
                ScrollViewReader {proxy in
                    ScrollView(.horizontal,showsIndicators:false) {
                        HStack {ForEach(HavenTab.allCases) {item in
                            Button(item.rawValue) {tab=item}.buttonStyle(.bordered)
                                .tint(tab==item ? Color(hex:0xEFC977) : .gray).accessibilityIdentifier("havenTab_"+item.rawValue).id(item.id)
                        }}.padding(.horizontal)
                    }.onChange(of:tab) {_,value in proxy.scrollTo(value.id,anchor:.center)}
                }
                ScrollView {
                    VStack(alignment:.leading,spacing:18) {
                        switch tab {
                        case .inspections:inspectionPanel
                        case .rival:rivalPanel
                        case .celebrations:celebrationPanel
                        case .garden:gardenKitchen
                        case .journey:journey
                        case .rooms:roomDesigns
                        case .breakfast:breakfastService
                        case .forecast:forecast
                        case .journal:journal
                        case .goals:dailyGoals
                        case .neighbors:neighbors
                        case .identity:identity
                        case .team:team
                        case .creatures:creatures
                        case .calendar:calendar
                        case .consequences:consequences
                        }
                    }.padding(20)
                }
                if !feedback.isEmpty {Text(feedback).font(.caption).padding(.horizontal).accessibilityIdentifier("havenFeedback")}
            }.foregroundStyle(Color(hex:0xF5E7C8)).background(PaintedPanel(color:0x172A25))
                .navigationTitle("Haven life").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading) {MenuBackButton {dismiss()}}}
                .tint(Color(hex:0xEFC977)).onChange(of:tab){_,value in savedHavenTab=value.rawValue}.onAppear{tab=(initialTab == .neighbors && motel.nearHavenNeighbor == nil ? HavenTab(rawValue:savedHavenTab) : nil) ?? initialTab;if var value=game.motel {value.initializeExpansion();value.initializeKitchenGarden();if value.havenOccasions == nil {value.havenOccasions=HavenOccasions()};game.motel=value;gardenSection=value.atGardenKitchen ? .cook : .grow}}
                .accessibilityElement(children:.contain)
        }
    }
    private var neighbors:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Meet your neighbors outside their homes. Keep promises, make peace after noisy nights, and invite friends over. At 4 friendship they send a small daily gift.").font(.subheadline)
            ForEach(0..<3,id:\.self) {id in
                let n=motel.neighborState(id)
                VStack(alignment:.leading,spacing:8) {
                    if motel.nearHavenNeighbor == id {HygieneGreeting(dirty:motel.isPlayerDirty,speaker:ResidentialLayout.names[id])}
                    Text(ResidentialLayout.names[id]+" · friendship \(n.friendship)").font(.headline)
                    Text(id==0 ? "Nora loves peaceful evenings and thoughtful favors." : id==1 ? "Ben enjoys celebrations and repairing things." : "Elena values kindness and visiting friends.").font(.caption)
                    if n.favorPending {Text(n.parcel ? "Parcel collected. Bring it back here." : "Collect the parcel from Otis at Willow Home.").font(.caption)}
                    Button("Chat") {act{$0.neighborAction(id,choice:0)}}
                        .disabled(motel.nearHavenNeighbor != id || n.chattedDay==motel.day).accessibilityIdentifier("neighborChat\(id)")
                    Button(n.favorPending ? "Deliver parcel / +20 coins" : "Offer a favor") {act{$0.neighborAction(id,choice:n.favorPending ? 2 : 1)}}
                        .disabled(motel.nearHavenNeighbor != id || (n.favorPending && !n.parcel) || (!n.favorPending && n.favorDay==motel.day)).accessibilityIdentifier("neighborFavor\(id)")
                    Button("Invite home · needs 3 friendship") {act{$0.neighborAction(id,choice:3)}}
                        .disabled(motel.nearHavenNeighbor != id || n.friendship<3 || n.invitedDay==motel.day).accessibilityIdentifier("neighborInvite\(id)")
                    Button("Make peace / 15 coins") {act{$0.neighborAction(id,choice:4)}}
                        .disabled(motel.nearHavenNeighbor != id || motel.cash<15 || n.chattedDay==motel.day)
                    if n.invitedDay==motel.day {Text("Visiting your home today. Walk over and welcome them.").font(.caption)}
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
        }.buttonStyle(.bordered)
    }
    private var identity:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Reputation: \(motel.simulation.reputation)/100").font(.title2.bold())
            Text("Your direction changes tomorrow's guest mix. Honest service and good room care protect your reputation. You can change direction once per day.")
            ForEach(HavenIdentity.allCases) {identity in
                VStack(alignment:.leading,spacing:8) {
                    Text(identity.title).font(.headline);Text(identity.detail).font(.caption)
                    Button(motel.haven.identity==identity ? "Current direction" : "Choose this direction") {act{$0.chooseHavenIdentity(identity)}}
                        .disabled(motel.haven.identity==identity || motel.haven.identityDay==motel.day ||
                            (identity == .boutique && (motel.simulation.reputation<60 || motel.rooms.reduce(0,{$0+$1.furniture})<3)))
                        .accessibilityIdentifier("havenIdentity_"+identity.rawValue)
                }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
        }.buttonStyle(.bordered)
    }
    private var team:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Good shifts earn experience. Every 4 shifts improve skill and speed. Happy colleagues become friends and work faster together; exhausted workers can make mistakes.").font(.subheadline)
            if motel.operationsState.workers.isEmpty {Text("Hire your first employee at the reception PC after unlocking recruitment.")}
            ForEach(motel.operationsState.workers) {worker in
                let role=worker.role
                let employee=motel.haven.employees[role.rawValue] ?? HavenEmployee()
                let profile=motel.simulation.profiles[role.rawValue] ?? StaffProfile.make(role)
                VStack(alignment:.leading,spacing:8) {
                    HygieneGreeting(dirty:motel.isPlayerDirty,speaker:role.name)
                    Text(role.name+" · "+role.title).font(.headline)
                    Text(motel.employeePersonality(role)).font(.caption)
                    Text("Level \(employee.level) · experience \(employee.experience) · loyalty \(profile.loyalty) · fatigue \(profile.fatigue)").font(.caption)
                    Text("Wage: \(motel.scheduledWage(role))/day").font(.caption)
                    if let friend=employee.friend,let friendRole=StaffRole(rawValue:friend) {Text("Work friend: "+friendRole.name).font(.caption)}
                    Button("Paid break / 10 coins") {act{$0.supportHavenEmployee(role,choice:0)}}
                        .disabled(motel.cash<10 || employee.supportDay==motel.day).accessibilityIdentifier("employeeBreak_"+role.rawValue)
                    if employee.requestDay>employee.decisionDay {
                        Text("I'd like a raise for my work here.").font(.caption)
                        Button("Accept permanent +2/day raise") {act{$0.supportHavenEmployee(role,choice:1)}}.accessibilityIdentifier("employeeRaise_"+role.rawValue)
                        Button("Decline · loyalty -12") {act{$0.supportHavenEmployee(role,choice:2)}}
                    }
                }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
        }.buttonStyle(.bordered)
    }
    private var creatures:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Visit each corral to begin a quest. Find its golden glimmer, then return the keepsake to unlock a unique ability. Chichu, Chichi and Tuki can also discover supplies once daily while following you outside the motel.")
            ForEach(BasementLayout.residents,id:\.self) {id in
                let quest=motel.adventure(id)
                VStack(alignment:.leading,spacing:8) {
                    Text(BasementLayout.titles[id]).font(.headline)
                    Text(Motel.adventureClues[id].capitalized+".").font(.caption)
                    Text(Motel.creatureAbilities[id]).font(.caption)
                    if quest.completed {Label("Ability unlocked",systemImage:"checkmark.circle.fill")}
                    else {
                        Button(quest.found ? "Return keepsake / +15 coins" : quest.accepted ? "Search for the golden glimmer" : "Accept adventure") {
                            act{quest.found ? $0.finishCreatureAdventure(id) : $0.startCreatureAdventure(id)}
                        }.disabled(motel.nearbyCorral != id || (quest.accepted && !quest.found))
                            .accessibilityIdentifier("creatureAdventure\(id)")
                    }
                }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
        }.buttonStyle(.bordered)
    }
    private var calendar:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("A repeating seven-day calendar").font(.headline)
            Text("Bring coins and any required snacks. Visit the activity's physical location and finish three rounds before resting. Prizes can be collected once per event.")
            ForEach(HavenActivity.allCases) {kind in
                VStack(alignment:.leading,spacing:8) {
                    Text("Day \(kind.weekday) · "+kind.title).font(.headline)
                    Text("At "+kind.locationName+" · entry \(kind.cost) coins, \(kind.snacks) snacks").font(.caption)
                    if motel.todaysActivity==kind {
                        if let run=motel.haven.activity,run.day==motel.day {
                            if run.finished {Text("Complete · score \(run.score)")}
                            else {
                                Text(kind.rounds[run.round]).font(.headline)
                                ForEach(0..<2,id:\.self) {choice in
                                    Button(kind.options[run.round][choice]) {act{$0.playHavenActivity(choice:choice)}}
                                        .disabled(!motel.nearHavenActivity).accessibilityIdentifier("activityChoice\(choice)")
                                }
                            }
                        } else {
                            Button("Prepare and enter") {act{$0.startHavenActivity()}}
                                .disabled(!motel.nearHavenActivity || motel.cash<kind.cost || motel.simulation.stock["snacks",default:0]<kind.snacks)
                                .accessibilityIdentifier("startHavenActivity")
                        }
                    }
                }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
            ForEach(motel.haven.completedActivities,id:\.self) {Text($0).font(.caption)}
        }.buttonStyle(.bordered)
    }



    private var inspectionPanel:some View {
        VStack(alignment:.leading,spacing:16) {
            Label("Coastal motel inspections",systemImage:"checkmark.seal.fill").font(.title2.bold())
            Text("Book from reception for 20 coins, once every seven days. Pass with 75 overall and at least 60 in every check. A pass pays 60 coins and improves reputation; 90 earns gold.")
            ForEach(Array(zip(["Hygiene · clean dirty rooms","Maintenance · repair faults","Safety · restore utilities and resolve emergencies","Hospitality · reputation and employees"],motel.inspectionScores).enumerated()),id:\.offset) {_,item in
                VStack(alignment:.leading) {Text(item.0);ProgressView(value:Double(item.1),total:100);Text("\(item.1)/100").font(.caption)}
            }
            Text("Live score: \(motel.inspectionTotal)/100").font(.headline)
            Text("Last award: "+motel.occasions.award)
            ForEach(motel.occasions.inspectionNotes,id:\.self) {Text($0).font(.caption)}
            Button("Request inspection / 20 coins") {act{$0.requestHavenInspection()}}.disabled(!motel.canRequestInspection).accessibilityIdentifier("requestInspection")
            if !motel.atOccasionDesk {Text("Visit your reception office to book.").font(.caption)}
            if motel.occasions.inspectionDay>0 {Text("Next booking: day \(motel.occasions.inspectionDay+7)").font(.caption)}
        }.buttonStyle(.bordered)
    }
    private var rivalPanel:some View {
        VStack(alignment:.leading,spacing:16) {
            Label("Seabreeze Lodge",systemImage:"building.2.fill").font(.title2.bold())
            Text("Owner Mara runs the neighboring coastal motel. Each completed week compares your upkeep, service and inspection award with Seabreeze. Winning earns 50 coins and reputation. Falling behind costs one reputation point.")
            Text("Week \(motel.occasionWeek) · your appeal \(motel.rivalAppeal)/100").font(.headline)
            Text("Previous Seabreeze score: \(motel.occasions.rivalScore) · your wins: \(motel.occasions.wins)")
            Button("Promote your service / 30 coins") {act{$0.rivalCampaign(cooperate:false)}}.disabled(!motel.atOccasionDesk || motel.cash<30 || motel.occasions.campaignWeek==motel.occasionWeek).accessibilityIdentifier("rivalCampaign")
            Text("+10 appeal in this week's comparison. Cleanliness and fair service still matter.").font(.caption)
            Button("Partner with Mara / 25 coins") {act{$0.rivalCampaign(cooperate:true)}}.disabled(!motel.atOccasionDesk || motel.cash<25 || motel.occasions.allianceWeek==motel.occasionWeek).accessibilityIdentifier("rivalPartner")
            Text("A joint coastal promotion returns 45 coins and one referral at week's end if your queue has space. You can cooperate while competing. Book at reception.").font(.caption)
            occasionMemories
        }.buttonStyle(.bordered)
    }
    private var celebrationPanel:some View {
        VStack(alignment:.leading,spacing:16) {
            Label("Guest celebrations",systemImage:"gift.fill").font(.title2.bold())
            Text("Birthdays, anniversaries and weddings are offered by staying guests. Accept at reception, decorate, bring cooked garden dishes, and prepare hosting before resting. Unfinished promises disappoint guests.")
            if let event=motel.occasions.celebration {
                Text(event.guestName+" · "+event.kind.title).font(.headline)
                Text("Today · payment \(event.kind.fee) coins · "+(event.completed ? "Hosted successfully" : "Preparation in progress"))
                celebrationTask(event,task:0,title:"Decorations / \(event.kind.decorCost) coins",done:event.decorated,enabled:motel.atOccasionDesk && motel.cash>=event.kind.decorCost)
                celebrationTask(event,task:1,title:"Cater / \(event.kind.portions) cooked portions",done:event.catered,enabled:motel.atGardenKitchen && motel.kitchen.plates.values.reduce(0,+)>=event.kind.portions)
                Text("Cook and pack dishes at the breakfast counter or Coral Catch. Portions are consumed.").font(.caption)
                celebrationTask(event,task:2,title:"Prepare hosting / \(motel.operationsState.workers.isEmpty ? 15 : 5) coins",done:event.staffReady,enabled:motel.atOccasionDesk && motel.cash >= (motel.operationsState.workers.isEmpty ? 15 : 5))
                Button("Host celebration") {act{$0.hostCelebration()}}.disabled(!motel.atOccasionDesk || !event.decorated || !event.catered || !event.staffReady || event.completed || motel.operationsState.incident != nil).accessibilityIdentifier("hostCelebration")
            } else if let offer=motel.celebrationOffer {
                Text(offer.guestName+" would like a "+offer.kind.title.lowercased()+". Payment: \(offer.kind.fee) coins.").font(.headline)
                Text("Budget: \(offer.kind.decorCost) decorations + hosting + \(offer.kind.portions) garden meals.").font(.caption)
                Button("Accept today's celebration") {act{$0.acceptCelebration()}}.disabled(!motel.atOccasionDesk).accessibilityIdentifier("acceptCelebration")
            } else {Text("Welcome a staying guest to receive a new celebration offer. One booking per day.")}
            Text("Hosted: \(motel.occasions.celebrations) · missed promises: \(motel.occasions.missed)").font(.caption)
            occasionMemories
        }.buttonStyle(.bordered)
    }
    private func celebrationTask(_ event:CelebrationBooking,task:Int,title:String,done:Bool,enabled:Bool)->some View {
        Button {act{$0.prepareCelebration(task)}} label:{Label(title,systemImage:done ? "checkmark.circle.fill" : "circle")}
            .disabled(done || event.completed || !enabled).accessibilityIdentifier("celebrationTask\(task)")
    }
    private var occasionMemories:some View {
        VStack(alignment:.leading,spacing:8) {ForEach(Array(motel.occasions.notes.enumerated()),id:\.offset) {_,note in Text(note).font(.caption)}}
    }

    private var gardenKitchen:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Garden to kitchen").font(.title2.bold())
            Text("Grow fresh ingredients beside the motel, unlock dishes and serve your guests. Garden tools are by the pool; cooking is at the breakfast counter or Coral Catch.").font(.subheadline)
            Picker("Garden section",selection:$gardenSection) {
                ForEach(GardenSection.allCases) {section in Text(section.rawValue).tag(section)}
            }.pickerStyle(.segmented).accessibilityIdentifier("gardenSection")
            switch gardenSection {
            case .grow:growGarden
            case .cook:gardenRecipes
            case .pantry:gardenPantry
            }
        }
    }
    private var growGarden:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Water once each day, then rest to grow. Rain waters plants for you. Dry plants wait safely; they do not disappear.").font(.caption)
            if motel.simulation.waterOut {Label("Water outage: repair the supply before watering.",systemImage:"drop.triangle.fill").foregroundStyle(.orange)}
            Picker("Seeds",selection:$gardenCrop) {
                ForEach(GardenCrop.allCases) {crop in Text(crop.title+" / \(crop.seedCost)").tag(crop)}
            }.accessibilityIdentifier("gardenSeeds")
            ForEach(Motel.gardenPlots.indices,id:\.self) {id in
                let plot=motel.kitchenPlot(id)
                VStack(alignment:.leading,spacing:10) {
                    Label("Plot \(id+1)",systemImage:plot.crop==nil ? "square.dashed" : motel.plotReady(id) ? "carrot.fill" : "leaf.fill").font(.headline)
                    if let crop=plot.crop {
                        Text(crop.title+" · "+(motel.plotReady(id) ? "Ready to harvest" : "\(plot.growth)/\(crop.days) growing nights")).font(.subheadline)
                        ProgressView(value:Double(plot.growth),total:Double(crop.days)).tint(.mint)
                        Text(motel.plotReady(id) ? "Harvest yields \(crop.harvestYield) ingredients." : motel.plotWatered(id) ? "Watered for today" : "Needs water before resting").font(.caption)
                        Button("Water plot") {act{$0.waterKitchenPlot(id)}}.disabled(motel.nearKitchenPlot != id || motel.plotReady(id) || motel.plotWatered(id) || motel.simulation.waterOut).accessibilityIdentifier("waterPlot\(id)")
                        Button("Harvest "+crop.title) {act{$0.harvestKitchenPlot(id)}}.disabled(motel.nearKitchenPlot != id || !motel.plotReady(id)).accessibilityIdentifier("harvestPlot\(id)")
                    } else {
                        Text("Empty soil · \(gardenCrop.days) watered nights to harvest").font(.caption)
                        Button("Plant "+gardenCrop.title+" / \(gardenCrop.seedCost) coins") {act{$0.plantKitchenCrop(id,crop:gardenCrop)}}.disabled(motel.nearKitchenPlot != id || motel.cash<gardenCrop.seedCost).accessibilityIdentifier("plantPlot\(id)")
                    }
                    if motel.nearKitchenPlot != id {Text("Stand beside this plot to tend it.").font(.caption).foregroundStyle(.secondary)}
                }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
            }
        }.buttonStyle(.bordered)
    }
    private var gardenRecipes:some View {
        VStack(alignment:.leading,spacing:16) {
            if !motel.atGardenKitchen {Label("Visit the breakfast counter or Marina's counter to cook and serve.",systemImage:"location.fill").font(.caption)}
            if motel.simulation.powerOut {Label("Power outage: hot dishes need electricity. Salad can still be prepared.",systemImage:"bolt.slash.fill").font(.caption).foregroundStyle(.orange)}
            if motel.simulation.waterOut {Text("Restore the water supply before preparing food.").font(.caption).foregroundStyle(.orange)}
            ForEach(GardenRecipe.allCases) {recipe in
                let unlocked=motel.kitchen.unlocked.contains(recipe.rawValue)
                let guest=motel.rooms.compactMap(\.guest).first{motel.canServeGardenDish(recipe,guestID:$0.id)}
                VStack(alignment:.leading,spacing:10) {
                    Label(recipe.title,systemImage:unlocked ? "fork.knife" : "lock.fill").font(.headline)
                    Text(recipe.ingredientText.capitalized+" · makes 2 portions").font(.caption)
                    Text(recipe.unlockHint).font(.caption).foregroundStyle(.secondary)
                    if unlocked {
                        Text("Ready: \(motel.kitchen.plates[recipe.rawValue,default:0]) · serve for \(recipe.price) coins").font(.caption.bold())
                        Button("Cook "+recipe.title) {act{$0.cookGardenRecipe(recipe)}}.disabled(!motel.canCookGardenRecipe(recipe)).accessibilityIdentifier("cookRecipe_"+recipe.id)
                        Button(guest.map{"Serve to "+$0.name} ?? "No guest waiting for this meal") {
                            if let guest {act{$0.serveGardenDish(recipe,guestID:guest.id)}}
                        }.disabled(guest==nil).accessibilityIdentifier("serveRecipe_"+recipe.id)
                    } else {Text("Keep harvesting and cooking to unlock.").font(.caption)}
                }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
            }
            Text("Each guest buys one garden dish per day. A morning dish counts as their breakfast. Meals improve satisfaction and reputation; ingredients and portions are consumed.").font(.caption)
        }.buttonStyle(.bordered)
    }
    private var gardenPantry:some View {
        VStack(alignment:.leading,spacing:14) {
            Label("Fresh pantry",systemImage:"basket.fill").font(.headline)
            ForEach(GardenCrop.allCases) {crop in
                HStack {Text(crop.title);Spacer();Text("\(motel.kitchen.pantry[crop.rawValue,default:0])").font(.headline.monospaced())}.padding(12).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:10))
            }
            Text("\(motel.kitchen.harvests) harvests · \(motel.kitchen.batches) batches cooked · \(motel.kitchen.unlocked.count)/\(GardenRecipe.allCases.count) recipes").font(.caption)
            ForEach(GardenRecipe.allCases) {recipe in Text(recipe.title+": \(motel.kitchen.plates[recipe.rawValue,default:0]) portions").font(.caption)}
        }
    }

    private var journey:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(Motel.journeyNames[motel.expansion.tier]).font(.title2.bold())
            Text(motel.journeyRequirement)
            Text("Guests served: \(motel.guestsServed) · rooms: \(motel.rooms.count) · reputation: \(motel.simulation.reputation)").font(.caption)
            Button("Claim next milestone") {act{$0.advanceJourney()}}
                .disabled(!motel.canAdvanceJourney).accessibilityIdentifier("claimJourney")
            Text("Welcoming motel unlocks the pool permit. Coastal retreat unlocks the restaurant permit. Famous coastal resort unlocks upper-floor construction. Existing facilities remain yours.").font(.subheadline)
            Text("Daily life").font(.headline)
            Text("Guests eat breakfast, carry luggage between destinations, visit the beach or pool in clear weather, meet near the bar in the evening and return to their rooms at night. Bad weather brings them to shelter.")
            ForEach(motel.rooms.filter{$0.guest != nil}) {room in
                if let guest=room.guest {
                    VStack(alignment:.leading,spacing:4) {
                        Text(guest.name+" · "+guest.holiday.title).font(.headline)
                        Text("Now: "+motel.guestRoutine(guest).rawValue+" · satisfaction \(motel.expansion.satisfaction[guest.id,default:50])/100").font(.caption)
                    }
                }
            }
        }.buttonStyle(.bordered)
    }
    private var roomDesigns:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Design for your guests").font(.title2.bold())
            Text("Couples like cozy decor and good beds; families value sleeping space and a fridge; business travelers prefer desks, soundproofing and Wi-Fi. Each match adds 4 coins per night and improves satisfaction. Changes require a vacant room.")
            ForEach(motel.rooms) {room in
                VStack(alignment:.leading,spacing:10) {
                    Text("Room \(room.number) · "+motel.roomDesign(room).title).font(.headline)
                    if let guest=room.guest {
                        Text(guest.holiday.title+" · "+guest.holiday.need).font(.caption)
                        Text("Match \(motel.roomMatch(guest,room))/4 · nightly bonus +\(motel.designPremium(guest,room))").font(.caption)
                    }
                    ForEach(HavenRoomDesign.allCases) {design in
                        Button(design.title+(design == .classic ? " / restore" : " / \(design.cost) coins")) {act{$0.designHavenRoom(room.id,design)}}
                            .disabled(room.guest != nil || motel.roomDesign(room)==design || motel.cash<design.cost)
                            .accessibilityIdentifier("design_\(room.id)_"+design.rawValue)
                    }
                }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
        }.buttonStyle(.bordered)
    }
    private var breakfastService:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("The morning rush").font(.title2.bold())
            Text("Open 08:00–11:59 at the breakfast counter. Cook three portions using 3 snacks and 6 coins. Serve each guest once for 12 coins and happier reviews. Fresh food expires at noon. A hired receptionist helps serve prepared food.")
            Text("Fresh portions: \(motel.expansion.buffet) · waiting: \(motel.breakfastQueue.count)").font(.headline)
            if !motel.atBreakfastCounter {Text("Walk to the breakfast counter to cook and serve.").font(.caption)}
            Button("Cook three breakfasts / 6 coins + 3 snacks") {act{$0.cookHavenBreakfast()}}
                .disabled(!motel.atBreakfastCounter || !motel.breakfastOpen || motel.cash<6 || motel.simulation.stock["snacks",default:0]<3 || motel.expansion.buffet>9)
                .accessibilityIdentifier("cookBreakfast")
            Button("Serve next guest / +12 coins") {act{$0.serveHavenBreakfast()}}
                .disabled(!motel.atBreakfastCounter || motel.expansion.buffet==0 || motel.breakfastQueue.isEmpty)
                .accessibilityIdentifier("serveBreakfast")
            ForEach(motel.breakfastQueue) {guest in Text(guest.name+" · "+guest.holiday.title).font(.caption)}
            Text("Stock: \(motel.simulation.stock["snacks",default:0]) snacks").font(.caption)
        }.buttonStyle(.bordered)
    }
    private var forecast:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Today: "+motel.weather.title).font(.title2.bold())
            Text(motel.weatherAdvice)
            Text("Tomorrow: "+motel.nextWeather.title).font(.headline)
            Text("Weather is forecast for the whole day. Unprepared storms can damage a drain at noon. Heatwaves draw guests to the pool and make broken AC more upsetting.")
            Button(motel.expansion.preparedDay==motel.day ? "Prepared for today" : "Secure equipment / 10 coins + 2 parts") {act{$0.prepareHavenWeather()}}
                .disabled(motel.expansion.preparedDay==motel.day || motel.cash<10 || motel.simulation.stock["parts",default:0]<2)
                .accessibilityIdentifier("prepareWeather")
        }.buttonStyle(.bordered)
    }
    private var journal:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Discoveries \(motel.expansion.discoveries.count)/\(Motel.discoveries.count)").font(.title2.bold())
            Text("Explore on foot, fish at the cove, visit the weekly market and bring a following pet. Market treasures cost 30 coins and appear in your reception display. Other discoveries earn 5 coins; fish also add food supplies.")
            ForEach(Motel.discoveries) {item in
                VStack(alignment:.leading,spacing:8) {
                    Text((motel.expansion.discoveries.contains(item.id) ? "✓ " : "◇ ")+item.name).font(.headline)
                    Text(item.hint).font(.caption)
                    if !motel.expansion.discoveries.contains(item.id) {
                        Button(item.group=="fish" ? "Cast fishing line" : item.group=="furniture" ? "Buy market treasure / 30 coins" : "Collect discovery") {act{$0.findHavenDiscovery(item.id)}}
                            .disabled(!motel.canFindDiscovery(item)).accessibilityIdentifier("discovery_"+item.id)
                    }
                }.padding(12).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
        }.buttonStyle(.bordered)
    }
    private var dailyGoals:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Three optional goals").font(.title2.bold())
            Text("No penalty for skipping a goal. Today's rewards are 20 coins and one repair part each. A new set arrives tomorrow.")
            ForEach(motel.goalKeys,id:\.self) {key in
                VStack(alignment:.leading,spacing:8) {
                    Text(motel.goalTitle(key)).font(.headline)
                    Text("\(min(motel.goalTarget(key),motel.expansion.daily[key,default:0]))/\(motel.goalTarget(key))").font(.caption)
                    Button(motel.expansion.claimedGoals.contains(key) ? "Reward collected" : "Collect reward") {act{$0.claimHavenGoal(key)}}
                        .disabled(motel.expansion.claimedGoals.contains(key) || motel.expansion.daily[key,default:0]<motel.goalTarget(key))
                        .accessibilityIdentifier("goal_"+key)
                }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
            }
            ForEach(Array(motel.expansion.notes.enumerated()),id:\.offset) {_,note in Text(note).font(.caption)}
        }.buttonStyle(.bordered)
    }

    private var consequences:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Canceled bookings: \(motel.haven.cancellations)").font(.headline)
            Text("Two neglected days can cause damage bills, lost condition and cancellations. Repair faults and keep rooms clean to stop the damage. Neighbor promises expire after three days.")
            Text("Recent memories").font(.headline)
            if motel.haven.notes.isEmpty {Text("Your decisions will be recorded here.")}
            ForEach(Array(motel.haven.notes.enumerated()),id:\.offset) { _,note in Text(note).font(.caption).padding(.vertical,4)}
        }
    }
}

// Randomize once per speaker encounter, never on every walking/render tick.
struct HygieneGreeting:View {
    let dirty:Bool
    let speaker:String
    @State private var remark=""
    var body:some View {
        Group {if dirty {Text(speaker+": "+remark).font(.caption).foregroundStyle(Color(hex:0xF0CF91)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("npcHygieneRemark")}}
            .onAppear {if dirty && remark.isEmpty {remark=PlayerNeeds.hygieneRemarks.randomElement()!}}
            .onChange(of:dirty) {_,value in remark=value ? PlayerNeeds.hygieneRemarks.randomElement()! : ""}
    }
}
struct PlayerNeedsPanel:View {
    let motel:Motel
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Text(motel.playerNeedsSummary).font(.title2.bold())
                    meter("Food",value:motel.playerNeeds.fullness,symbol:"fork.knife",id:"needFood")
                    meter("Bathroom pressure",value:motel.playerNeeds.bladder,symbol:"toilet.fill",id:"needBathroom")
                    meter("Hygiene",value:motel.playerNeeds.hygiene,symbol:"shower.fill",id:"needHygiene")
                    Text(motel.playerNeeds.toiletDay==motel.day ? "Bathroom: done today" : "Bathroom: due today")
                    Text(motel.playerNeeds.showerDay==motel.day ? "Shower: done today" : "Shower: due today")
                    Text("Food: use your home fridge (one snack or a prepared garden dish), or order a meal at Coral Catch.")
                    Text("Bathroom: enter the BATH door on the upper hallway wall, beside the bedrooms. Walk to the toilet or shower and interact.")
                    Text("Eat regularly. Use the toilet and shower every day. After 24 game hours without a shower, your character looks dirty and people may comment. Time pauses in menus; needs never prevent walking or emergency responses.").font(.caption)
                }.padding(22)
            }.foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x20372F))
                .navigationTitle("Personal needs").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading){MenuBackButton {dismiss()}}}
        }
    }
    private func meter(_ title:String,value:Int,symbol:String,id:String)->some View {
        VStack(alignment:.leading,spacing:7) {Label("\(title): \(value)/100",systemImage:symbol);ProgressView(value:Double(value),total:100).tint(Color(hex:(id=="needBathroom" ? value>=75 : value<=35) ? 0xD58B65 : 0xE9C77D))}.accessibilityElement(children:.combine).accessibilityIdentifier(id)
    }
}

enum HavenExperienceTab:String,CaseIterable,Identifiable {
    case guests="Guests",identity="Hotel style",rooms="Room sets",team="Team",district="District",creatures="Training",events="Events",scrapbook="Scrapbook"
    var id:String {rawValue}
    var icon:String {switch self {case .guests:return "person.2.fill";case .identity:return "building.2.fill";case .rooms:return "bed.double.fill";case .team:return "person.3.fill";case .district:return "map.fill";case .creatures:return "pawprint.fill";case .events:return "party.popper.fill";case .scrapbook:return "photo.on.rectangle.angled"}}
}

struct HavenExperienceView:View {
    @Binding var game:Game
    var initialTab:HavenExperienceTab = .guests
    @State private var tab:HavenExperienceTab
    @Environment(\.dismiss) private var dismiss
    init(game:Binding<Game>,initialTab:HavenExperienceTab = .guests) {_game=game;self.initialTab=initialTab;_tab=State(initialValue:initialTab)}
    private var motel:Motel {game.motel ?? Motel()}
    private let cream=Color(hex:0xF5E7C8),gold=Color(hex:0xEFC977),panel=Color(hex:0x29443A)
    var body:some View {
        NavigationStack {
            VStack(spacing:0) {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:9) {ForEach(HavenExperienceTab.allCases) {item in
                        Button {tab=item} label:{VStack(spacing:5){Image(systemName:item.icon);Text(item.rawValue).font(.caption2.bold())}.frame(width:78,height:58).background(tab==item ? gold.opacity(0.24):Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).stroke(tab==item ? gold:Color.clear,lineWidth:1.5))}.buttonStyle(.plain).accessibilityIdentifier("experience_"+item.id)
                    }}.padding(.horizontal,16).padding(.vertical,12)
                }
                ScrollView {content.padding(18)}
            }.foregroundStyle(cream).background(Color(hex:0x172A25))
                .navigationTitle("Hotel life & memories").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.topBarLeading){MenuBackButton {dismiss()}}}
                .onAppear {if motel.havenExperiences == nil {mutate{$0.activateExperiences()}}}
        }.tint(gold)
    }
    @ViewBuilder private var content:some View {
        switch tab {
        case .guests:guestContent
        case .identity:identityContent
        case .rooms:roomContent
        case .team:teamContent
        case .district:districtContent
        case .creatures:creatureContent
        case .events:eventContent
        case .scrapbook:scrapbookContent
        }
    }
    private var activeGuests:[MotelGuest] {motel.rooms.compactMap(\.guest)+motel.waiting+(motel.world?.travellers ?? [])}
    private var knownGuestNames:[String] {Array(Set(motel.experiences.bonds.filter{$0.value.visits>0}.map(\.key))).sorted()}
    private var guestContent:some View {section("Returning guests",detail:"Guests remember every stay. Listen nearby to unlock a personal three-part story, then invite friends back.") {
        if knownGuestNames.isEmpty {empty("Welcome a guest to begin your relationship journal.")}
        ForEach(knownGuestNames,id:\.self) {name in let bond=motel.guestBond(name)
            card {HStack{VStack(alignment:.leading){Text(name).font(.headline);Text("Visits \(bond.visits) · Story \(bond.chapter)/3 · Likes \(motel.guestInterest(name))").font(.caption)};Spacer();if bond.friend {Image(systemName:"heart.fill").foregroundStyle(.pink)}}
                ProgressView(value:Double(bond.chapter),total:3).tint(gold)
                if activeGuests.contains(where:{$0.name==name}) {Button(bond.chapter>=3 ? "Share a memory" : "Listen to their story") {mutate{_=$0.shareGuestStory(name)}}.buttonStyle(MotelButtonStyle(subdued:true)).disabled(!motel.canShareGuestStory(name))}
                if bond.friend {Button("Invite for another visit") {mutate{_=$0.inviteGuestFriend(name)}}.buttonStyle(MotelButtonStyle(subdued:true)).disabled(motel.experiences.inviteDay==motel.day)}
                ForEach(bond.memories,id:\.self){Text($0).font(.caption).foregroundStyle(.secondary)}
            }
        }
    }}
    private var identityContent:some View {section("Choose a hotel specialization",detail:"Your choice changes tomorrow’s guest mix and adds honest room premiums. You can choose once each game day at reception.") {
        ForEach(HotelFocus.allCases) {focus in card {HStack{VStack(alignment:.leading,spacing:5){Text(focus.title).font(.headline);Text(focus.detail).font(.caption)};Spacer();if motel.experiences.focus==focus {Image(systemName:"checkmark.seal.fill").foregroundStyle(gold)}}
            Button(motel.experiences.focus==focus ? "Current specialization":"Choose") {mutate{_=$0.chooseHotelFocus(focus)}}.buttonStyle(MotelButtonStyle(subdued:true)).disabled(motel.experiences.focus==focus || motel.experiences.focusDay==motel.day || !motel.isAtReception)
        }}
        Text(motel.isAtReception ? "You are at reception.":"Go to the reception desk to change your hotel style.").font(.caption)
    }}
    private var roomContent:some View {section("Matching room collections",detail:"Buy three coordinated pieces for a vacant room. A complete set adds 10 coins to matching bookings; owned sets remain available forever.") {
        ForEach(motel.rooms) {room in card {Text("Room \(room.number)").font(.headline);Text(room.guest==nil ? "Vacant · \(motel.collection(room.id).selected.title) set":"Occupied by \(room.guest!.name)").font(.caption)
            ForEach(DecorCollection.allCases) {kind in let owned=motel.collection(room.id).owned[kind.rawValue,default:[]]
                HStack{Text(kind.title).frame(maxWidth:.infinity,alignment:.leading);Text("\(owned.count)/3").font(.caption.bold());if motel.collection(room.id).selected==kind {Image(systemName:"eye.fill")}}
                HStack{ForEach(0..<3,id:\.self){piece in Button(owned.contains(piece) ? "✓ \(piece+1)":"Buy \(15+piece*5)") {mutate{_=$0.buyCollectionPiece(room.id,kind:kind,piece:piece)}}.buttonStyle(.bordered).disabled(owned.contains(piece) || room.guest != nil || !motel.isAtReception)}
                    if owned.count==3 && motel.collection(room.id).selected != kind {Button("Use") {mutate{_=$0.selectCollection(room.id,kind:kind)}}.buttonStyle(.borderedProminent).disabled(room.guest != nil || !motel.isAtReception)}
                }
            }
        }}
        Text(motel.isAtReception ? "Collection catalogue open.":"Use the room catalogue at reception.").font(.caption)
    }}
    private var teamContent:some View {section("Employee relationships",detail:"Staff gain personality and friendship bonuses. Tired colleagues may disagree once per week; resolve it before their work cadence slows.") {
        ForEach(motel.operationsState.workers) {worker in let profile=motel.simulation.profiles[worker.role.rawValue] ?? StaffProfile.make(worker.role)
            card {HStack{VStack(alignment:.leading){Text(worker.role.name+" · "+worker.role.title).font(.headline);Text("\(motel.employeePersonality(worker.role)) · loyalty \(profile.loyalty) · fatigue \(profile.fatigue)").font(.caption)};Spacer();Circle().fill(Color(hex:worker.role.color)).frame(width:24,height:24)}}
        }
        if let dispute=motel.experiences.dispute {card {Text("Team disagreement").font(.headline);Text("\(staffName(dispute.first)) and \(staffName(dispute.second)) need your help.").font(.caption);HStack{Button("Mediate") {mutate{_=$0.resolveEmployeeDispute(paid:false)}}.buttonStyle(.bordered);Button("Team meal · 10") {mutate{_=$0.resolveEmployeeDispute(paid:true)}}.buttonStyle(.borderedProminent)}}} else {empty("No unresolved disagreements.")}
    }}
    private var districtContent:some View {section("Neighborhood reputation",detail:"Residents bring referrals, businesses send parts, and trusted police reduce heat. Your choices change each group separately.") {
        ForEach(["residents","businesses","police"],id:\.self) {key in card {HStack{Label(key.capitalized,systemImage:key=="residents" ? "house.fill" : key=="businesses" ? "storefront.fill" : "shield.fill");Spacer();Text("\(motel.districtScore(key))/100").bold()};ProgressView(value:Double(motel.districtScore(key)),total:100).tint(gold);Button("Community support · 10") {mutate{_=$0.communityAction(key)}}.buttonStyle(MotelButtonStyle(subdued:true)).disabled(!motel.isAtReception || motel.experiences.communityDay==motel.day || motel.cash<10)}}
        Text(motel.isAtReception ? "Choose one community action today.":"Community support is arranged from reception.").font(.caption)
    }}
    private var creatureContent:some View {section("Creature training & contests",detail:"Train once per day at a corral gate. Favorite exercises give more progress. Enter one three-round sanctuary contest each week.") {
        ForEach(BasementLayout.residents,id:\.self) {id in let progress=motel.training(id)
            card {HStack{VStack(alignment:.leading){Text(BasementLayout.titles[id]).font(.headline);Text("Level \(progress.level) · \(progress.medals) medals · favorite: \(motel.creatureExercise(id).title)").font(.caption)};Spacer();Image(systemName:"pawprint.fill").foregroundStyle(gold)}
                HStack{ForEach(CreatureExercise.allCases){exercise in Button(exercise.title){mutate{_=$0.trainCreature(id,exercise:exercise)}}.buttonStyle(.bordered).disabled(motel.nearbyTrainingCreature != id || progress.trainedDay==motel.day || motel.simulation.stock["snacks",default:0]<=0)}}
                if motel.experiences.contest == nil || motel.experiences.contest?.finished==true {Button("Enter weekly contest · 10") {mutate{_=$0.enterSanctuaryContest(id)}}.buttonStyle(.borderedProminent).disabled(motel.nearbyTrainingCreature != id || motel.cash<10 || motel.experiences.contestWeek==motel.experienceWeek)}
            }
        }
        if let run=motel.experiences.contest,!run.finished {card {Text("Contest round \(run.round+1) of 3").font(.headline);Text("Score: \(run.score)");HStack{ForEach(CreatureExercise.allCases){exercise in Button(exercise.title){mutate{_=$0.contestRound(exercise)}}.buttonStyle(.bordered)}}}}
        Text("Stand beside the selected creature’s corral gate in the basement.").font(.caption)
    }}
    private var eventContent:some View {section("Seasonal hosting",detail:"Every season has a physical celebration. Book at reception, then visit its marked location to decorate, cater and welcome guests.") {
        Text("\(motel.seasonTitle) · Week \(motel.experienceWeek)").font(.title3.bold())
        let available=SeasonalParty.allCases[motel.experienceSeason]
        if let hosting=motel.experiences.hosting,hosting.startedDay<=motel.day {card {Text(hosting.kind.title).font(.headline);Text(hosting.completed ? "Complete — saved in your scrapbook." : hosting.stage==0 ? "Next: decorate at \(hosting.kind.place)." : hosting.stage==1 ? "Next: bring 3 snacks to \(hosting.kind.place)." : "Next: welcome guests at \(hosting.kind.place).").font(.caption);if !hosting.completed {Button("Continue event") {mutate{_=$0.prepareSeasonalParty()}}.buttonStyle(MotelButtonStyle(subdued:true)).disabled(motel.seasonalHostTile.map{motel.worldState.place != .grounds || motel.actorTile.distance(to:$0)>2} ?? true)}}}
        else {card {Text(available.title).font(.headline);Text("Booking \(available.cost) coins · hosted at \(available.place)").font(.caption);Button("Book this season") {mutate{_=$0.bookSeasonalParty(available)}}.buttonStyle(MotelButtonStyle(subdued:true)).disabled(!motel.isAtReception || motel.cash<available.cost || motel.experiences.hostingWeek==motel.experienceWeek)}}
    }}
    private var scrapbookContent:some View {section("Family scrapbook",detail:"Photos and meaningful moments stay here across saves. Photo mode is opened from the main pause menu.") {
        if motel.experiences.photos.isEmpty {empty("No photos yet. Open Photo mode from the pause menu and capture your favorite view.")} else {ForEach(motel.experiences.photos){photo in card {HavenPhotoThumbnail(photo:photo).frame(height:150).clipShape(RoundedRectangle(cornerRadius:11));Label(photo.caption.isEmpty ? photo.place:photo.caption,systemImage:"photo.fill").font(.headline);Text("Day \(photo.day) · \(photo.place)").font(.caption)}}}
        Text("Memories").font(.title3.bold()).padding(.top,8)
        if motel.experiences.memories.isEmpty {empty("Stories, friendships, contests and celebrations will appear here.")} else {ForEach(motel.experiences.memories){memory in card {Text(memory.text);Text("Day \(memory.day)").font(.caption).foregroundStyle(.secondary)}}}
    }}
    private func section<Content:View>(_ title:String,detail:String,@ViewBuilder content:()->Content)->some View {VStack(alignment:.leading,spacing:13){Text(title).font(.title2.bold());Text(detail).font(.subheadline).foregroundStyle(.secondary);content()}.frame(maxWidth:.infinity,alignment:.leading)}
    private func card<Content:View>(@ViewBuilder _ content:()->Content)->some View {VStack(alignment:.leading,spacing:10){content()}.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(panel,in:RoundedRectangle(cornerRadius:15))}
    private func empty(_ text:String)->some View {Text(text).font(.subheadline).foregroundStyle(.secondary).padding(14).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))}
    private func staffName(_ id:String)->String {StaffRole(rawValue:id)?.name ?? id.capitalized}
    private func mutate(_ action:(inout Motel)->Void) {var value=game.motel ?? Motel();action(&value);game.motel=value;game.save()}
}

private struct HavenPhotoThumbnail:View {
    let photo:HavenPhoto
    var body:some View {Group {if let image=Self.load(photo.fileName) {Image(uiImage:image).resizable().scaledToFill()} else {ZStack{Color.white.opacity(0.06);Image(systemName:"photo.badge.exclamationmark").font(.largeTitle)}}}.frame(maxWidth:.infinity,maxHeight:.infinity).clipped()}
    private static func load(_ name:String)->UIImage? {guard let root=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first else{return nil};return UIImage(contentsOfFile:root.appendingPathComponent("HavenPhotos",isDirectory:true).appendingPathComponent(name).path)}
}
