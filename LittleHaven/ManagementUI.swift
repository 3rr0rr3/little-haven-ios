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
                Text(shop.detail)
                if shop == .furniture {
                    ForEach(HomeObject.allCases) {kind in
                        HStack {HomeItemIcon(kind:kind).frame(width:46,height:46);Text(kind.title);Spacer();Button("Buy / \(kind.price)"){change{_=$0.buyHomeObject(kind)}}.disabled(motel.cash<kind.price).accessibilityIdentifier("buy_home_"+kind.rawValue)}
                    }
                    Text("Walk north to your house, enter and choose DECORATE to place purchases.").font(.caption)
                } else if shop == .clothing {
                    ForEach(FamilyHome.outfitNames.indices,id:\.self) {index in
                        HStack {
                            RoundedRectangle(cornerRadius:8).fill(Color(hex:FamilyHome.outfitColors[index])).frame(width:44,height:44)
                            Text(FamilyHome.outfitNames[index]);Spacer()
                            Button(motel.household.outfit == index ? "Wearing" : motel.household.outfits.contains(index) ? "Wear" : "Buy / 80") {change{_=$0.wearOutfit(index)}}.disabled(motel.household.outfit == index || (!motel.household.outfits.contains(index) && motel.cash<80)).accessibilityIdentifier("outfit_\(index)")
                        }
                    }
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
    let close: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text(speaker.uppercased()).font(.system(size:13,weight:.black,design:.monospaced)).tracking(1).foregroundStyle(Color(hex:0xF2CE7F))
                Spacer()
                Button("Back",action:close).font(.system(size:11,weight:.bold,design:.monospaced)).foregroundStyle(Color(hex:0xE9DAB9))
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
            Text("First shift included. Wages are paid each morning. Unpaid staff rest until the next paid shift.").font(.caption)
            ForEach(StaffRole.allCases) { role in
                let worker = motel.operationsState.workers.first { $0.role == role }
                HStack(alignment:.top,spacing:10) {
                    PaperPortrait(color:role.color,variant:role == .cleaner ? 1 : role == .maintenance ? 4 : 0).frame(width:40,height:52)
                    VStack(alignment:.leading,spacing:5) {
                        Text(role.name+" / "+role.title).font(.subheadline.bold())
                        Text(role.duty).font(.caption)
                        Text("\(role.wage) coins/day").font(.caption.monospaced()).foregroundStyle(Color(hex:0xEFC977))
                        if let worker { Text(worker.active ? (worker.status ?? "On duty") : "Off duty: unpaid shift").font(.caption.bold()) }
                        else { Button("Hire \(role.name) / \(role.hireCost)") { hire(role) }.buttonStyle(MotelButtonStyle()).disabled(motel.cash < role.hireCost).accessibilityIdentifier("hire_"+role.rawValue) }
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
            // Flames stretch, sparks rise and smoke drifts independently.
            for i in 0..<4 {
                let x=2+Double(i)*4.5
                let sway=sin(phase+Double(i))*2.5
                var flame=Path()
                flame.move(to:CGPoint(x:x,y:26))
                flame.addQuadCurve(to:CGPoint(x:x+4+sway,y:3+Double(i%2)*5),control:CGPoint(x:x-3,y:15))
                flame.addQuadCurve(to:CGPoint(x:x+8,y:26),control:CGPoint(x:x+13,y:14))
                context.fill(flame,with:.color(Color(hex:i%2 == 0 ? 0xE96D38 : 0xF8C74F)))
                oval(x+2,18,4,8,0xFFE7A0)
                let rise=(stride*2+Double(i)*3).truncatingRemainder(dividingBy:16)
                oval(x+sin(phase)*2,14-rise,5+rise/4,4+rise/4,0x79776E)
                oval(x+3,20-rise,1.2,1.8,0xFFD879)
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
            if kind.hasPrefix("steal-") {
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
    var model = 0
    var body: some View {
        Canvas { context,_ in
            func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ tint:UInt32,_ radius:Double = 2) {
                context.fill(Path(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerRadius:radius),with:.color(Color(hex:tint)))
            }
            let suv = model % 3 == 1
            let pickup = model % 3 == 2
            box(5,8,38,18,0x303D42,5)
            box(2,7,8,6,0x293137); box(38,7,8,6,0x293137)
            box(2,24,8,6,0x293137); box(38,24,8,6,0x293137)
            box(3,5,42,22,color,5); box(12,8,22,14,0x344F64,4)
            box(14,9,18,4,0x9FC8CE); box(14,18,18,3,0x83A8B5)
            box(34,7,7,18,color); box(4,8,5,3,0xFFF1BE); box(4,21,5,3,0xFFF1BE)
            box(40,8,3,3,0xD77364); box(40,21,3,3,0xD77364)
            box(10,15,2,4,0xD5D9C5); box(35,15,2,4,0xD5D9C5)
            // Recognizable sedan, SUV and pickup silhouettes with glass, panels and hardware.
            box(12,7,suv ? 24 : 19,17,0x344F64,3)
            box(14,8,suv ? 20 : 15,6,0xA8D1D5,2)
            box(14,17,suv ? 20 : 15,5,0x7AA6B8,2)
            box(13,14,suv ? 22 : 17,2,color)
            box(22,7,1,17,0x263F4A,0)
            box(9,4,5,2,color); box(9,26,5,2,color)
            box(3,13,2,8,0x3A4547,1)
            for slat in 0..<4 { box(3,14+Double(slat)*1.7,2,0.6,0xB8C4C2,0) }
            box(2,16,1,3,0xF1E9CF,0); box(43,15,2,4,0xF1E9CF,0)
            box(6,6,3,1,0xF1D49A,0); box(6,25,3,1,0xF1D49A,0)
            box(31,7,2,1,0xD6DBCC,0); box(31,24,2,1,0xD6DBCC,0)
            if suv { box(13,6,22,1,0xCDD3C9,0); box(13,25,22,1,0xCDD3C9,0) }
            if pickup {
                box(30,7,12,18,color,2); box(32,9,8,14,0x4C5756,1)
                for rib in 0..<4 { box(33+Double(rib)*2,10,0.6,12,0x78807A,0) }
            }
            if dirty { for i in 0..<7 { box(6+Double(i*5),12+Double(i%3)*4,4,3,0x927A58) } }
        }.frame(width:48,height:34)
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
                HotelMiniGame(repairing:request.repairing) {
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
                        Button("Hire \(role.name) / \(role.hireCost)") {_=perform{$0.hire(role)}}.buttonStyle(.bordered).disabled(motel.cash<role.hireCost).accessibilityIdentifier("manageHire_"+role.rawValue)
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
                        Button("Develop / \(facility.cost)") {_=perform{$0.installFacility(facility)}}.buttonStyle(.bordered).disabled(motel.cash<facility.cost || motel.simulation.reputation<facility.requiredRep).accessibilityIdentifier("develop_"+facility.rawValue)
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
                    HotelActionArtwork(kind:repairing ? "repair" : "mop",frame:Int(elapsed*8)%8).frame(width:130,height:100)
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
