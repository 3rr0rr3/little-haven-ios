import SwiftUI

struct NeighborhoodStoreView:View {
    @Binding var game:Game
    let shop:NeighborhoodShop
    @Environment(\.dismiss) private var dismiss
    private var motel:Motel {game.motel ?? Motel()}
    private func change(_ action:(inout Motel)->Void) {var value=motel;action(&value);game.motel=value}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                HStack {Text(shop.title).font(.largeTitle.bold());Spacer();Button("Close"){dismiss()}}
                Text("\(motel.cash) COINS").font(.headline.monospaced()).foregroundStyle(Color(hex:0xEFC977))
                Text(shop.keeperName+" / "+shop.detail)
                if shop == .furniture {
                    if (0..<3).contains(where:{motel.neighborState($0).favorPending && !motel.neighborState($0).parcel}) {
                        Button("Collect neighbor parcels") {change{_=$0.collectNeighborParcels()};game.save()}
                            .disabled(!motel.canTrade(.furniture)).accessibilityIdentifier("collectNeighborParcels")
                    }
                    ForEach(HomeObject.allCases) {kind in
                        HStack {HomeItemIcon(kind:kind).frame(width:46,height:46);Text(kind.title);Spacer();Button("Buy / \(kind.price)"){change{_=$0.buyHomeObject(kind)}}.disabled(motel.cash<kind.price).accessibilityIdentifier("buy_home_"+kind.rawValue)}
                    }
                    Text("Take your purchases home and use the workbench to place them.").font(.caption)
                } else if shop == .clothing {
                    ForEach(FamilyHome.outfitNames.indices,id:\.self) {index in
                        HStack {
                            RoundedRectangle(cornerRadius:8).fill(Color(hex:FamilyHome.outfitColors[index])).frame(width:44,height:44)
                            Text(FamilyHome.outfitNames[index]);Spacer()
                            Button(motel.household.outfit == index ? "Wearing" : motel.household.outfits.contains(index) ? "Wear" : "Buy / 80") {change{_=$0.wearOutfit(index)}}.disabled(motel.household.outfit == index || (!motel.household.outfits.contains(index) && motel.cash<80)).accessibilityIdentifier("outfit_\(index)")
                        }
                    }
                } else if shop == .fish {
                    ForEach(FishMeal.allCases) {meal in
                        HStack {
                            Label(meal.title,systemImage:"fish.fill");Spacer()
                            Button("Order / \(meal.price)") {change{_=$0.orderFishMeal(meal)}}
                                .disabled(!motel.canTrade(.fish) || motel.cash<meal.price)
                                .accessibilityIdentifier("orderMeal_"+meal.rawValue)
                        }
                    }
                    if let meal=motel.worldState.fishMeal {Label("Marina served: "+meal.title,systemImage:"checkmark.circle.fill")}
                    Text("Fresh fish from the coast, shared tables and warm conversation.").font(.caption)
                } else if shop == .bar {
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
                            Label(drink.title,systemImage:"wineglass.fill");Spacer()
                            Button("Order / \(drink.price)") {change{_=$0.orderBarDrink(drink)}}
                                .disabled(!motel.canTrade(.bar) || motel.cash<drink.price)
                                .accessibilityIdentifier("orderDrink_"+drink.rawValue)
                        }
                    }
                    if let drink=motel.worldState.barDrink {
                        Label("Jules served: "+drink.title,systemImage:"checkmark.circle.fill").foregroundStyle(Color(hex:0xA8D7BA))
                    }
                    Text("Music, warm lights and good company. Take a seat and enjoy the evening.").font(.caption)
                } else {
                    if motel.household.stolen.isEmpty {Text("Your bag is empty. No belongings have been sold automatically.")}
                    ForEach(RoomVisit.lootNames.indices,id:\.self) {item in
                        let count=motel.household.stolen.filter{$0 == item}.count
                        if count>0 {HStack {Text("\(RoomVisit.lootNames[item]) x \(count)");Spacer();Button("Sell / \(RoomVisit.lootValues[item])"){change{_=$0.sellBelonging(item)}}.accessibilityIdentifier("pawn_sell_\(item)")}}
                    }
                }
            }.padding(24)
        }.foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x233E33)).tint(Color(hex:0xEFC977)).buttonStyle(.bordered).accessibilityIdentifier("neighborhoodShop")
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
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                HStack {Text("Make it home").font(.title.bold());Spacer();Button("Done"){dismiss()}}
                Text("\(motel.cash) COINS / LEVEL \(motel.household.level) / \(motel.household.placed.count) OF \(motel.household.capacity) OBJECTS").font(.caption.monospaced())
                if motel.household.level<3 {
                    Text(motel.household.level == 0 ? "Improve home finishes and add furniture space." : "Expand furniture space and renovate the exterior.")
                    Button("Upgrade home / \(motel.household.upgradeCost)"){change{_=$0.upgradeHome()}}.disabled(motel.cash<motel.household.upgradeCost).accessibilityIdentifier("upgradeHome")
                }
                HStack {Text("Walls / 25");ForEach(0..<4,id:\.self) {index in Button {change{_=$0.finishHome(wall:true,color:index)}} label:{Circle().fill(Color(hex:Motel.themeColors[index])).frame(width:28,height:28)}.disabled(motel.cash<25 || motel.household.wallpaper == index)}}
                HStack {Text("Floor / 25");ForEach(0..<4,id:\.self) {index in Button {change{_=$0.finishHome(wall:false,color:index)}} label:{Circle().fill(Color(hex:HomeInteriorArt.floors[index])).frame(width:28,height:28)}.disabled(motel.cash<25 || motel.household.floor == index)}}
                Text("Storage").font(.headline)
                if motel.household.storage.isEmpty {Text("Visit Willow Home east of the motel to buy furniture.").font(.caption)}
                ScrollView(.horizontal) {HStack {ForEach(HomeObject.allCases.filter{motel.household.storage.contains($0)}) {kind in Button("\(kind.title) x \(motel.household.storage.filter{$0 == kind}.count)"){selected=kind}.tint(selected == kind ? .orange : Color(hex:0xEFC977))}}}
                Text(message).font(.caption)
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:2),count:13),spacing:2) {
                    ForEach(2..<13,id:\.self) {y in ForEach(1..<14,id:\.self) {x in
                        let tile=Tile(x:x,y:y)
                        let object=motel.household.placed.first{$0.tile == tile}
                        Button {
                            if let object {change{_=$0.storeHomeObject(object.id)};message="Returned to storage. Select it to move it."}
                            else if let selected {change {value in message=value.placeHomeObject(selected,at:tile) ? "Placed \(selected.title). Tap it to return it to storage." : "Keep family paths clear. Try another tile or upgrade for more space."}}
                        } label:{ZStack {Rectangle().fill(Color(hex:motel.homeBlocked(tile) ? 0x496451 : HomeInteriorArt.floors[motel.household.floor]));if let object {HomeItemIcon(kind:object.kind)}else if Motel.familyTiles.contains(tile) || OfficeReception.hildarelysRoute.contains(tile) {Image(systemName:"heart.fill").font(.caption2)}}.frame(height:28)}.buttonStyle(.plain).accessibilityIdentifier("home_tile_\(x)_\(y)")
                    }}
                }
                Text("Tap placed furniture to store it, then select it and tap another tile to move it. A rug can be walked over.").font(.caption)
            }.padding(22)
        }.foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x233E33)).tint(Color(hex:0xEFC977)).buttonStyle(.bordered).accessibilityIdentifier("homeDesigner")
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
        content.padding(14).background(Color(hex:0x20372F))
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
    let close: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text(speaker.uppercased()).font(.system(size:13,weight:.black,design:.monospaced)).tracking(1).foregroundStyle(Color(hex:0xF2CE7F))
                Spacer()
                if dismissible {Button("Back",action:close).font(.system(size:11,weight:.bold,design:.monospaced)).foregroundStyle(Color(hex:0xE9DAB9))}
            }
            HStack(alignment:.top,spacing:12) {
                portrait.frame(width:64,height:76).background(Color(hex:0x344E40)).overlay(Rectangle().stroke(Color(hex:0xC4A96F),lineWidth:1))
                Text(text).font(.system(size:15,weight:.medium,design:.rounded)).foregroundStyle(Color(hex:0xF5E7C8)).fixedSize(horizontal:false,vertical:true).frame(maxWidth:.infinity,alignment:.leading)
            }
            ForEach(choices) { choice in
                Button(action:choice.action) {
                    HStack { Text(">").foregroundStyle(Color(hex:0xEFC977)); Text(choice.title); Spacer() }
                        .font(.system(size:13,weight:.bold,design:.monospaced)).padding(11)
                        .foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x385448))
                }.accessibilityLabel(choice.title)
            }
        }.modifier(RPGFrame()).accessibilityElement(children:.contain).accessibilityIdentifier("gameDialogue")
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
                    PaperPortrait(color:role.color,variant:role == .cleaner ? 1 : role == .maintenance ? 4 : 0).frame(width:40,height:52)
                    VStack(alignment:.leading,spacing:5) {
                        Text(role.name+" / "+role.title).font(.subheadline.bold())
                        Text(role.duty).font(.caption)
                        Text("\(role.wage) coins/day").font(.caption.monospaced()).foregroundStyle(Color(hex:0xEFC977))
                        if let worker { Text(worker.active ? (worker.status ?? "On duty") : "Off duty: unpaid shift").font(.caption.bold()) }
                        else { Text(motel.hiringProgress(role)).font(.caption).foregroundStyle(Color(hex:0xEFC977)); Button("Hire \(role.name) / \(role.hireCost)") { hire(role) }.buttonStyle(MotelButtonStyle()).disabled(!motel.hiringUnlocked(role) || motel.cash < role.hireCost).accessibilityIdentifier("hire_"+role.rawValue) }
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
            let skin:UInt32 = [UInt32(0xF0C9A0),0xD6A477,0xA87350,0x734A37,0xE9B693][abs(variant)%5]
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



enum ManagementTab:String,CaseIterable,Identifiable {
    case rooms="Rooms",desk="Desk",guests="Guests",team="Team",supplies="Supplies",events="Events",growth="Growth",cameras="Cameras",story="Story",books="Books"
    var id:String {rawValue}
}
struct HotelMiniRequest:Identifiable {
    let roomID:Int
    let repairing:Bool
    var id:String {"\(roomID)-\(repairing)"}
}
struct ManagementHub:View {
    @Binding var game:Game
    @Environment(\.dismiss) private var dismiss
    @State private var tab:ManagementTab = .rooms
    @State private var feedback=""
    @State private var mini:HotelMiniRequest?
    @State private var showHavenLife=false
    private var motel:Motel {game.motel ?? Motel()}
    private let gold=Color(hex:0xEFC977)
    var body:some View {
        NavigationStack {
            VStack(spacing:10) {
                HStack {
                    Text("DAY \(motel.day)  \(motel.clockLabel)").font(.caption.monospaced().bold())
                    Spacer()
                    Text("\(motel.cash) coins  /  REP \(motel.simulation.reputation)").font(.caption.bold()).foregroundStyle(gold)
                }.padding(.horizontal)
                if let incident=motel.operationsState.incident {
                    Button("EMERGENCY: \(incident.kind.title) / \(incident.remaining)s - return to grounds") {dismiss()}
                        .font(.caption.bold()).foregroundStyle(.orange).accessibilityIdentifier("managementEmergency")
                }
                if motel.business.police != nil {Button("Police case needs attention - return to grounds"){dismiss()}.font(.caption.bold()).foregroundStyle(.orange)}
                Button("Community & activities") {showHavenLife=true}.accessibilityIdentifier("managementHavenLife")
                Text(motel.simulation.news).font(.caption).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal).accessibilityIdentifier("managementNews")
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:8) {
                        ForEach(ManagementTab.allCases) { item in
                            Button(item.rawValue) {tab=item}.font(.caption.bold()).padding(9)
                                .background(tab==item ? gold.opacity(0.3) : Color.white.opacity(0.08),in:Capsule())
                                .accessibilityIdentifier("manageTab_"+item.id)
                        }
                    }.padding(.horizontal)
                }.accessibilityIdentifier("managementTabs")
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        switch tab {
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
                    }.padding()
                }
                if !feedback.isEmpty {Text(feedback).font(.caption).foregroundStyle(gold).padding(.horizontal).accessibilityIdentifier("managementFeedback")}
                Text("The hotel keeps running while this board is open.").font(.system(size:10)).foregroundStyle(.secondary).padding(.bottom,6)
            }.foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x172A25))
                .navigationTitle("Hotel management").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented:$showHavenLife) {HavenLifeView(game:$game)}
                .toolbar {ToolbarItem(placement:.topBarTrailing) {Button("Done") {dismiss()}.accessibilityIdentifier("closeManagement")}}
        }.tint(gold).presentationBackground(Color(hex:0x172A25))
            .onAppear {
                let args=ProcessInfo.processInfo.arguments
                if args.contains("--ui-management-cameras") {tab = .cameras}
                if args.contains("--ui-management-events") {tab = .events}
                if args.contains("--ui-management-desk") {tab = .desk}
                if args.contains("--ui-management-growth") {tab = .growth}
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
        VStack(alignment:.leading,spacing:9,content:content).padding(12).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
    }
    private var roomsPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Room condition controls availability, comfort, complaints and reviews. Suites unlock at reputation 60.").font(.caption)
            ForEach(motel.rooms) {room in roomCard(room)}
        }
    }
    private func roomCard(_ room:MotelRoom)->some View {
        card {
            HStack {
                RoomIllustration(theme:room.theme,level:room.furniture,office:false).frame(width:70,height:70)
                VStack(alignment:.leading,spacing:4) {
                    Text("ROOM \(room.number) / \(room.health.kind.title)").font(.headline)
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
                Button("Clean mini-game") {mini=HotelMiniRequest(roomID:room.id,repairing:false)}.accessibilityIdentifier("miniClean_\(room.id)")
                Button("Repair / pests") {mini=HotelMiniRequest(roomID:room.id,repairing:true)}.accessibilityIdentifier("miniRepair_\(room.id)")
            }.font(.caption.bold()).buttonStyle(.bordered)
            if room.guest == nil {
                Menu("Change room type") {
                    ForEach(RoomKind.allCases) { kind in
                        Button("\(kind.title) / \(kind.cost)") {_=perform{$0.changeRoomKind(room.id,kind:kind)}}.disabled(kind==room.health.kind || motel.cash<kind.cost || kind == .suite && motel.simulation.reputation<60)
                    }
                }
                Menu("Install meaningful upgrade") {
                    ForEach(RoomUpgrade.allCases) { upgrade in
                        Button("\(upgrade.title) / \(upgrade.cost)") {_=perform{$0.buyRoomUpgrade(room.id,upgrade:upgrade)}}.disabled(room.health.upgrades.contains(upgrade)||motel.cash<upgrade.cost)
                    }
                }
            } else {Button("Check out & inspect") {_=perform{$0.checkoutGuest(room.id)}}}
            ForEach(Array(room.health.upgrades).sorted{$0.rawValue<$1.rawValue}) {upgrade in
                Text("? \(upgrade.title): \(upgrade.benefit)").font(.caption2)
            }
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
            ForEach(motel.waiting) {guest in arrivalCard(guest)}
            Text("Reservations / no-shows \(motel.simulation.noShows)").font(.headline)
            ForEach(motel.simulation.reservations) {reservation in
                card {
                    Text(reservation.guest.name+" / reserved arrival").font(.subheadline.bold())
                    Text("Due at \(reservation.arrivalHour%24):00 / \(reservation.processed ? reservation.noShow ? "No-show fee collected" : "Arrived" : "10-coin no-show guarantee")").font(.caption)
                }
            }
        }
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
                    }
                }
            }
            ReviewsPanel(motel:motel)
        }
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
                        Text(motel.hiringProgress(role)).font(.caption).foregroundStyle(gold)
                        Button("Hire \(role.name) / \(role.hireCost)") {_=perform{$0.hire(role)}}.buttonStyle(.bordered).disabled(!motel.hiringUnlocked(role) || motel.cash<role.hireCost).accessibilityIdentifier("manageHire_"+role.rawValue)
                    }
                }
            }
        }
    }
    private var suppliesPanel:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Every check-in uses towels and toiletries. Cleaning uses detergent; repairs use parts; pest treatment uses pesticide. Fridges and the restaurant use snacks.").font(.caption)
            ForEach(Supply.allCases) {item in
                card {
                    HStack {
                        VStack(alignment:.leading) {Text(item.title).font(.headline);Text("In stock: \(motel.simulation.stock[item.rawValue,default:0])").font(.caption)}
                        Spacer()
                        Button("Buy 5 / \(item.price*5)") {_=perform{$0.buyStock(item)}}.buttonStyle(.bordered).disabled(motel.cash<item.price*5).accessibilityIdentifier("buy_"+item.rawValue)
                    }
                }
            }
        }
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
                }
            }
        }
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
                    Text("\(facility.cost) coins / reputation \(facility.requiredRep)").font(.caption)
                    if motel.simulation.facilities.contains(facility) {Text("Operational").foregroundStyle(.mint)}
                    else {
                        if !motel.journeyAllows(facility) {Text("Unlock: "+Motel.journeyNames[motel.facilityJourneyTier(facility)]+" milestone in Haven life").font(.caption).foregroundStyle(.orange)}
                        Button("Develop / \(facility.cost)") {_=perform{$0.installFacility(facility)}}.buttonStyle(.bordered).disabled(!motel.journeyAllows(facility) || motel.cash<facility.cost || motel.simulation.reputation<facility.requiredRep).accessibilityIdentifier("develop_"+facility.rawValue)
                    }
                }
            }
        }
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
                }.padding(8).background(Color.white.opacity(0.05))
            }
        }
    }
    private func change(_ action:(inout Motel)->Void) {
        guard var current=game.motel else{return};action(&current);game.motel=current;feedback=current.lastEvent
    }
    @discardableResult private func perform(_ action:(inout Motel)->Bool)->Bool {
        guard var current=game.motel else{return false};let result=action(&current);game.motel=current
        feedback=result ? "Changes applied." : "Unavailable. Check coins, supplies, room occupancy and unlock requirements."
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
            HStack {Text(repairing ? "Repair workshop" : "Cleaning challenge").font(.title2.bold());Spacer();Button("Cancel"){dismiss()}}
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
        }.padding(24).foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x172A25))
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
            let wave=sin(Double(frame) * .pi/6)
            let press=(1-cos(Double(frame) * .pi/3))/2
            let skin:UInt32=variant == 7 ? 0xE3B38E : [UInt32(0xF0C9A0),0xD6A477,0xA87350,0x734A37,0xE9B693][abs(variant)%5]
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
                line([CGPoint(x:sx,y:sy),CGPoint(x:ex,y:ey)],color,2.7)
                line([CGPoint(x:ex,y:ey),CGPoint(x:hx,y:hy)],skin,2.5)
                oval(hx-1.5,hy-1.5,3,3,skin)
            }
            let bodyX=kind == "cpr" ? 17.0+press*0.5 : 16.0
            let bodyY=kind == "cpr" ? 21.0+press*0.7 : 19.0
            PaperPerson.draw(context:&c,x:bodyX,y:bodyY,color:color,variant:variant,
                facing:kind == "calm" || kind == "swim" ? 0 : 2,walk:0,hands:false,kneeling:kind == "cpr" || kind == "swim")
            switch kind {
            case "extinguish":
                box(27,27,6.5,11,0xC94B38);box(28,30,4.5,4.5,0xF3E8CD)
                box(29,24,2,3,0x525B55)
                line([CGPoint(x:27,y:24),CGPoint(x:33,y:24+press*0.7)],0x343D3D,1.2)
                var hose=Path();hose.move(to:CGPoint(x:32,y:26))
                hose.addCurve(to:CGPoint(x:37,y:25+wave),control1:CGPoint(x:38,y:36),control2:CGPoint(x:40,y:29))
                c.stroke(hose,with:.color(Color(hex:0x303B39)),style:StrokeStyle(lineWidth:1.3,lineCap:.round))
                arm(20,25,23,27,29,24.7+press*0.5);arm(28,25,31,28,36,25+wave)
                line([CGPoint(x:36,y:25+wave),CGPoint(x:40,y:23+wave)],0x303B39,2)
            case "swim","rescue":
                arm(20,25,16-wave*3,28,13-wave*2,31+wave*3)
                arm(28,25,32+wave*3,28,35+wave*2,31-wave*3)
                for side in [13.0,34] {
                    c.stroke(Path(ellipseIn:CGRect(x:side-4,y:32+wave,width:8,height:2)),with:.color(.white.opacity(0.65)),lineWidth:0.6)
                }
            case "cpr":
                arm(21,27,32,29+press,45,33+press*1.5)
                arm(29,27,37,29+press,45.5,33+press*1.5)
                oval(43.5,32+press*1.5,4,2.2,skin)
            case "calm":
                arm(20,25,15,25-wave,11,21-wave);arm(28,25,33,25-wave,37,21-wave)
                box(9.5,17-wave,3,5,skin);box(35.5,17-wave,3,5,skin)
            case "repair","build":
                box(34,31,10,7,0x75857C)
                let tip=CGPoint(x:38,y:32),handle=CGPoint(x:31+wave*3,y:25-wave)
                line([handle,tip],0xCBD3CE,1.8)
                c.stroke(Path(ellipseIn:CGRect(x:36.4,y:30.4,width:3.2,height:3.2)),with:.color(Color(hex:0xD5DBD6)),lineWidth:1)
                arm(20,25,25,29,34,34);arm(28,25,30,27,handle.x,handle.y)
            case "pest":
                box(27,29,6,9,0xD3B46F);box(29,26,2,3,0x4B6457)
                line([CGPoint(x:30,y:27),CGPoint(x:37,y:28+wave)],0x485B50,1.1)
                arm(20,25,24,29,29,28);arm(28,25,33,29,36,28+wave)
                for i in 0..<5 {let t=Double((frame+i)%12)/12;oval(37+t*9,29+t*6,0.8+t,0.8+t,0xD7DCC2)}
            case "mop","carwash":
                let head=CGPoint(x:35+wave*5,y:40)
                line([CGPoint(x:28,y:24),head],0xB7986A,1.5);oval(head.x-5,head.y-1,10,3,0xB9D1BD)
                for i in 0..<4 {line([CGPoint(x:head.x-4+Double(i)*2,y:40),CGPoint(x:head.x-4+Double(i)*2,y:42)],0xDAE1CF,0.6)}
                arm(20,25,23,29,29+wave,29);arm(28,25,30,29,32+wave*2,33)
            case "garden":
                box(31,29,8,7,0x8EAA70);line([CGPoint(x:38,y:31),CGPoint(x:43,y:29)],0x8EAA70,2)
                arm(20,25,25,29,32,29);arm(28,25,31,27,35,28)
                for i in 0..<4 {oval(42+Double(i),31+Double((frame+i)%6),0.7,1.4,0xD5E8D5)}
            case "paint":
                let ry=28+wave*4
                line([CGPoint(x:31,y:35),CGPoint(x:37,y:ry)],0xB39262,1.4)
                box(34,ry-3,8,3,0xB0C7A4);arm(28,25,30,29,32,32);arm(20,25,22,29,24,32)
            case "bed","laundry":
                var sheet=Path();sheet.move(to:CGPoint(x:27,y:28-wave))
                sheet.addQuadCurve(to:CGPoint(x:43,y:28+wave),control:CGPoint(x:35,y:24-wave*3))
                sheet.addLine(to:CGPoint(x:43,y:36));sheet.addLine(to:CGPoint(x:27,y:36));sheet.closeSubpath()
                c.fill(sheet,with:.color(Color(hex:0xF0EBD8)));c.stroke(sheet,with:.color(Color(hex:0xADBBA6)),lineWidth:0.5)
                arm(20,25,23,28,27,28-wave);arm(28,25,35,27,42,28+wave)
            case "trash","luggage":
                box(34,32-wave*2,8,9,kind == "trash" ? 0x46584C : 0xAA7856)
                line([CGPoint(x:36,y:32-wave*2),CGPoint(x:36,y:30-wave*2),CGPoint(x:40,y:30-wave*2),CGPoint(x:40,y:32-wave*2)],0x33453C,1)
                arm(28,25,32,28,38,30-wave*2);arm(20,25,19,28,19,31)
            default:
                box(27,31,16,1.5,0xB18C60);box(32,27,4,4,0xEEE1C4);oval(38,28,5,3,0xCEAB6E)
                arm(20,25,24,29,28,31);arm(28,25,33,29,40,31)
            }
        }.frame(width:48,height:48)
    }
}

enum HavenTab:String,CaseIterable,Identifiable {
    case neighbors="Neighbors",identity="Identity",team="Team",creatures="Creatures",calendar="Calendar",consequences="Consequences"
    case journey="Journey",rooms="Room design",breakfast="Breakfast",forecast="Weather",journal="Journal",goals="Daily goals"
    var id:String {rawValue}
}
struct HavenLifeView:View {
    @Binding var game:Game
    var initialTab:HavenTab = .neighbors
    @State private var tab:HavenTab = .neighbors
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
            }.foregroundStyle(Color(hex:0xF5E7C8)).background(Color(hex:0x172A25))
                .navigationTitle("Haven life").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.confirmationAction) {Button("Done") {dismiss()}}}
                .tint(Color(hex:0xEFC977)).onAppear{tab=initialTab;if var value=game.motel {value.initializeExpansion();game.motel=value}}
                .accessibilityElement(children:.contain)
        }
    }
    private var neighbors:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Meet your neighbors outside their homes. Keep promises, make peace after noisy nights, and invite friends over. At 4 friendship they send a small daily gift.").font(.subheadline)
            ForEach(0..<3,id:\.self) {id in
                let n=motel.neighborState(id)
                VStack(alignment:.leading,spacing:8) {
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
            ForEach(0..<8,id:\.self) {id in
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
