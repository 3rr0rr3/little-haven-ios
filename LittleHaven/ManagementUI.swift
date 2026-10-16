import SwiftUI

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
                    HStack { Text("▸").foregroundStyle(Color(hex:0xEFC977)); Text(choice.title); Spacer() }
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
                        if let worker { Text(worker.active ? "On duty" : "Off duty: unpaid shift").font(.caption.bold()) }
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
                    Text(String(repeating:"★",count:review.stars)+String(repeating:"☆",count:5-review.stars)).foregroundStyle(Color(hex:0xEFC977))
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
    static func draw(context: inout GraphicsContext,kind: Int,stride:Double) {
        if kind == 1 {
            for i in 0..<3 {
                var flame=Path()
                let x=4.0+Double(i)*5
                flame.move(to:CGPoint(x:x,y:24)); flame.addQuadCurve(to:CGPoint(x:x+4+stride,y:4+Double(i%2)*4),control:CGPoint(x:x-3,y:12)); flame.addQuadCurve(to:CGPoint(x:x+7,y:24),control:CGPoint(x:x+12,y:15)); flame.closeSubpath()
                context.fill(flame,with:.color(Color(hex:i == 1 ? 0xF5CB62 : 0xDE744B)))
            }
        } else if kind == 3 {
            PaperPerson.draw(context:&context,x:4,y:9,color:0xC88370,variant:0,facing:0,walk:stride)
            var burst = Path()
            burst.move(to:CGPoint(x:2,y:7)); burst.addLine(to:CGPoint(x:7,y:10)); burst.move(to:CGPoint(x:20,y:6)); burst.addLine(to:CGPoint(x:17,y:10))
            context.stroke(burst,with:.color(Color(hex:0xF3D583)),lineWidth:1.2)
        } else {
            PaperPerson.draw(context:&context,x:4,y:9,color:0xD99478,variant:2,facing:0,walk:stride)
            for i in 0..<3 { context.stroke(Path(ellipseIn:CGRect(x:Double(i*7+2),y:22+Double(i%2),width:8,height:2)),with:.color(Color(hex:0xD8F0E6)),lineWidth:0.8) }
        }
    }
}
