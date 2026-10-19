import SwiftUI
import SceneKit
import UIKit
import simd

// The simulation stays in tile coordinates. Geometry, shadows and perspective
// are rendered in metres; the original characters remain animated billboards.
struct World3DView: UIViewRepresentable {
    let mapID: String
    let revision: String
    var motel: Motel? = nil
    let actors: [RPGActor]
    var working = false
    var workKind = "mop"
    var tap: ((OfficeTap) -> Void)? = nil

    func makeUIView(context: Context) -> World3DSurface { World3DSurface() }
    func updateUIView(_ view: World3DSurface, context: Context) {
        view.configure(mapID:mapID,revision:revision,motel:motel,actors:actors,working:working,workKind:workKind,tap:tap)
    }
    static func dismantleUIView(_ view: World3DSurface, coordinator: ()) { view.shutdown() }
}

final class World3DSurface: UIView {
    private let viewport=SCNView()
    private let world=SCNScene()
    private let scenery=SCNNode()
    private let cast=SCNNode()
    private let cars=SCNNode()
    private let camera=SCNNode()
    private let sun=SCNNode()
    private let ambient=SCNNode()
    private let weatherNode=SCNNode()
    private var map=""
    private var revision=""
    private var weatherKey=""
    private var appearance:[String:String]=[:]
    private var targets:[String:Tile]=[:]
    private var portraits:[String:UIImage]=[:]
    private var activities:[String:[UIImage]]=[:]
    private var materials:[String:SCNMaterial]=[:]
    private var buttons:[String:UIButton]=[:]
    private var tapTargets:[String:SCNVector3]=[:]
    private var tapAction:((OfficeTap)->Void)?
    private var occluders:[(node:SCNNode,x:Float,z:Float,width:Float,depth:Float)]=[]
    private var visualID = -1

    override init(frame:CGRect) {
        super.init(frame:frame)
        addSubview(viewport)
        viewport.scene=world
        viewport.backgroundColor=UIColor(red:0.66,green:0.76,blue:0.77,alpha:1)
        viewport.antialiasingMode = .multisampling4X
        viewport.preferredFramesPerSecond=60
        viewport.isPlaying=true
        viewport.autoenablesDefaultLighting=false
        viewport.isUserInteractionEnabled=false
        viewport.isAccessibilityElement=false
        world.rootNode.addChildNode(scenery)
        world.rootNode.addChildNode(cast)
        world.rootNode.addChildNode(cars)
        world.rootNode.addChildNode(weatherNode)
        camera.camera=SCNCamera()
        camera.camera!.fieldOfView=42
        camera.camera!.zNear=0.1
        camera.camera!.zFar=160
        camera.camera!.wantsHDR=true
        camera.camera!.wantsExposureAdaptation=false
        camera.camera!.exposureOffset = -0.25
        camera.camera!.bloomIntensity=0.12
        camera.camera!.bloomThreshold=1.2
        world.rootNode.addChildNode(camera)
        viewport.pointOfView=camera
        sun.light=SCNLight()
        sun.light!.type = .directional
        sun.light!.castsShadow=true
        sun.light!.shadowMapSize=CGSize(width:2048,height:2048)
        sun.light!.shadowSampleCount=8
        sun.light!.shadowRadius=5
        sun.light!.shadowColor=UIColor(red:0.13,green:0.2,blue:0.22,alpha:0.4)
        sun.eulerAngles=SCNVector3(-Float.pi/3,-Float.pi/5,0)
        world.rootNode.addChildNode(sun)
        ambient.light=SCNLight()
        ambient.light!.type = .ambient
        world.rootNode.addChildNode(ambient)
        isAccessibilityElement=false
        accessibilityIdentifier="world3DViewport"
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews();viewport.frame=bounds;layoutTargets() }
    func shutdown() { viewport.isPlaying=false;viewport.scene=nil;cast.removeAllActions();weatherNode.removeAllParticleSystems() }

    @MainActor func configure(mapID:String,revision newRevision:String,motel:Motel?,actors:[RPGActor],working:Bool,workKind:String,tap:((OfficeTap)->Void)?) {
        let changed=map != mapID
        let indoor=mapID != "grounds" && mapID != "town"
        if changed || revision != newRevision {
            scenery.childNodes.forEach{$0.removeFromParentNode()}
            occluders=[]
            if changed {
                cast.childNodes.forEach{$0.removeFromParentNode()}
                targets=[:];appearance=[:];visualID = -1
            }
            map=mapID;revision=newRevision
            if mapID == "grounds", let motel { buildGrounds(motel) }
            else if mapID == "family-house", let motel { buildHome(motel) }
            else if mapID == "family-office", let motel { buildOffice(motel) }
            else if mapID.hasPrefix("room-"), let motel,let visit=motel.visit,let room=motel.rooms.first(where:{$0.id == visit.roomID}) { buildRoom(room,visit:visit) }
            else if mapID == "town" { buildTown() }
            else { interiorFloor(width:9,depth:9,color:0xAE9271,wall:0xE3D5B6);bed(x:2.5,z:3,color:0x849A91);plant(x:6.5,z:2.5) }
        }
        configureLight(night:motel?.isNight ?? false,indoor:indoor,powerOut:motel?.simulation.powerOut ?? false,nightVision:motel?.simulation.nightVision ?? false)
        updateActors(actors,working:working,workKind:workKind)
        if let player=actors.first(where:{$0.id == "player"}) {
            SCNTransaction.begin();SCNTransaction.animationDuration=changed ? 0 : 0.16
            if indoor {
                let side:Float=(mapID == "family-house" || mapID == "family-office") ? 15 : 9
                camera.position=SCNVector3(side/2,side*1.48,side*1.62)
                camera.look(at:SCNVector3(side/2,0,side*0.48))
            } else {
                let x=Float(player.tile.x)+0.5,z=Float(player.tile.y)+0.5
                camera.position=SCNVector3(x,17.5,z+13.5)
                camera.look(at:SCNVector3(x,0,z-1.3))
                weatherNode.position=SCNVector3(x,14,z)
                for item in occluders {
                    let behind=abs(x-item.x)<item.width/2+0.6 && z<item.z && item.z-z<item.depth/2+2
                    item.node.opacity=behind ? 0.28 : 1
                }
            }
            SCNTransaction.commit()
        }
        if let motel {
            configureWeather(indoor ? .sunny : motel.weather)
            if mapID == "grounds" { updateCars(motel) } else { cars.childNodes.forEach{$0.removeFromParentNode()} }
            if let visual=motel.operationsState.visual, visual.id != visualID, visual.map == (mapID == "family-office" ? "office" : mapID == "family-house" ? "house" : mapID) {
                visualID=visual.id
                let node=actionNode(visual.kind)
                node.position=SCNVector3(Float(visual.target.x)+0.5,0.8,Float(visual.target.y)+0.5)
                cast.addChildNode(node)
                node.runAction(.sequence([.wait(duration:1.8),.fadeOut(duration:0.25),.removeFromParentNode()]))
            }
        }
        tapAction=tap
        configureTargets(actors,motel:motel)
        setNeedsLayout()
    }

    private func color(_ hex:UInt32)->UIColor { UIColor(red:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1) }
    private func material(_ hex:UInt32,_ kind:String="plaster")->SCNMaterial {
        let key="\(hex)-\(kind)"
        if let value=materials[key] {return value}
        let mat=SCNMaterial();mat.lightingModel = .physicallyBased
        mat.diffuse.contents=texture(hex,kind)
        mat.diffuse.wrapS = .repeat;mat.diffuse.wrapT = .repeat
        mat.roughness.contents=kind == "glass" ? 0.2 : kind == "metal" ? 0.45 : 0.92
        mat.metalness.contents=kind == "metal" ? 0.45 : 0.0
        materials[key]=mat;return mat
    }
    private func texture(_ hex:UInt32,_ kind:String)->UIImage {
        let format=UIGraphicsImageRendererFormat();format.scale=1
        return UIGraphicsImageRenderer(size:CGSize(width:256,height:256),format:format).image { output in
            let c=output.cgContext
            color(hex).setFill();c.fill(CGRect(x:0,y:0,width:256,height:256))
            var seed:UInt64=UInt64(hex)+79
            func random()->CGFloat {seed=(seed &* 6364136223846793005 &+ 1442695040888963407);return CGFloat((seed>>32)%10000)/10000}
            for _ in 0..<(kind == "grass" ? 1800 : 750) {
                let x=random()*256,y=random()*256
                let light=random()>0.48
                c.setFillColor((light ? UIColor.white : UIColor.black).withAlphaComponent(kind == "grass" ? 0.10 : 0.055).cgColor)
                let w:CGFloat=kind == "wood" ? 0.4+random()*1.4 : 1+random()*9
                let h:CGFloat=kind == "wood" ? 8+random()*45 : 1+random()*5
                c.fillEllipse(in:CGRect(x:x,y:y,width:w,height:h))
            }
            if kind == "wood" {
                c.setStrokeColor(UIColor.black.withAlphaComponent(0.18).cgColor);c.setLineWidth(1)
                for x in stride(from:0,to:256,by:64) {c.move(to:CGPoint(x:x,y:0));c.addLine(to:CGPoint(x:x,y:256))};c.strokePath()
                for row in 0..<4 {c.move(to:CGPoint(x:row*64,y:row%2 == 0 ? 90 : 190));c.addLine(to:CGPoint(x:(row+1)*64,y:row%2 == 0 ? 90 : 190))};c.strokePath()
            } else if kind == "stone" || kind == "roof" {
                c.setStrokeColor(UIColor.black.withAlphaComponent(0.17).cgColor);c.setLineWidth(2)
                for row in 0..<8 {
                    c.move(to:CGPoint(x:0,y:row*32));c.addLine(to:CGPoint(x:256,y:row*32))
                    for x in stride(from:row%2*32,to:256,by:64) {c.move(to:CGPoint(x:x,y:row*32));c.addLine(to:CGPoint(x:x,y:(row+1)*32))}
                };c.strokePath()
            }
        }
    }
    @discardableResult private func box(_ x:Float,_ y:Float,_ z:Float,_ w:CGFloat,_ h:CGFloat,_ d:CGFloat,_ hex:UInt32,_ kind:String="plaster",parent:SCNNode?=nil,round:CGFloat=0.025)->SCNNode {
        let geo=SCNBox(width:w,height:h,length:d,chamferRadius:round)
        geo.materials=[material(hex,kind)]
        let node=SCNNode(geometry:geo);node.position=SCNVector3(x,y,z);(parent ?? scenery).addChildNode(node);return node
    }
    private func cylinder(_ x:Float,_ y:Float,_ z:Float,_ radius:CGFloat,_ height:CGFloat,_ hex:UInt32,parent:SCNNode?=nil)->SCNNode {
        let geo=SCNCylinder(radius:radius,height:height);geo.radialSegmentCount=10;geo.materials=[material(hex,"wood")]
        let node=SCNNode(geometry:geo);node.position=SCNVector3(x,y,z);(parent ?? scenery).addChildNode(node);return node
    }
    private func sphere(_ x:Float,_ y:Float,_ z:Float,_ radius:CGFloat,_ hex:UInt32,parent:SCNNode?=nil)->SCNNode {
        let geo=SCNSphere(radius:radius);geo.segmentCount=12;geo.materials=[material(hex,"foliage")]
        let node=SCNNode(geometry:geo);node.position=SCNVector3(x,y,z);(parent ?? scenery).addChildNode(node);return node
    }
    private func slab(x:Float,z:Float,w:CGFloat,d:CGFloat,color:UInt32,kind:String="stone",y:Float=0.015) {
        let node=box(x,y,z,w,0.035,d,color,kind,round:0)
        let mat=material(color,kind).copy() as! SCNMaterial
        mat.diffuse.contentsTransform=SCNMatrix4MakeScale(Float(w/3),Float(d/3),1)
        node.geometry?.materials=[mat]
    }
    private func roof(x:Float,z:Float,w:Float,d:Float,base:Float,rise:Float,color:UInt32,parent:SCNNode) {
        let points:[SIMD3<Float>]=[SIMD3(-w/2,base,-d/2),SIMD3(w/2,base,-d/2),SIMD3(0,base+rise,-d/2),SIMD3(-w/2,base,d/2),SIMD3(w/2,base,d/2),SIMD3(0,base+rise,d/2)]
        let triangles=[[0,2,1],[3,4,5],[0,3,5],[0,5,2],[1,2,5],[1,5,4],[0,1,4],[0,4,3]]
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        for triangle in triangles {
            let a=points[triangle[0]],b=points[triangle[1]],c=points[triangle[2]]
            let n=simd_normalize(simd_cross(b-a,c-a))
            for index in triangle {let p=points[index];vertices.append(SCNVector3(p.x+x,p.y,p.z+z));normals.append(SCNVector3(n.x,n.y,n.z));uv.append(CGPoint(x:Double(p.x/w+0.5),y:Double(p.z/d+0.5)));indices.append(Int32(indices.count))}
        }
        let geo=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        let mat=material(color,"roof").copy() as! SCNMaterial;mat.isDoubleSided=true;mat.diffuse.contentsTransform=SCNMatrix4MakeScale(w/2,d/2,1);geo.materials=[mat]
        parent.addChildNode(SCNNode(geometry:geo))
        box(x,base+rise+0.03,z,0.16,0.15,CGFloat(d+0.1),0x4C514B,"wood",parent:parent)
    }
    private func building(x:Float,z:Float,w:Float,d:Float,doorX:Float,doorZ:Float,paint:UInt32,roofColor:UInt32,title:String,house:Bool=false) {
        let group=SCNNode();scenery.addChildNode(group)
        box(x,0.13,z,CGFloat(w+0.1),0.26,CGFloat(d+0.1),0x8C8A7D,"stone",parent:group)
        box(x,1.35,z,CGFloat(w),2.5,CGFloat(d),paint,parent:group)
        for dx in [-w/2+0.08,w/2-0.08] {box(x+dx,1.35,z+d/2+0.03,0.13,2.5,0.12,0x625443,"wood",parent:group)}
        box(x,0.42,z+d/2+0.025,CGFloat(w),0.38,0.08,0x8A826E,"stone",parent:group)
        roof(x:x,z:z,w:w+0.55,d:d+0.5,base:2.62,rise:house ? 1.45 : 0.85,color:roofColor,parent:group)
        box(doorX,0.95,doorZ-0.02,0.83,1.8,0.13,0x65533D,"wood",parent:group)
        box(doorX+0.27,0.9,doorZ+0.065,0.07,0.07,0.08,0xC5A75C,"metal",parent:group)
        box(doorX,0.08,doorZ+0.3,1.25,0.16,0.62,0xBDB5A0,"stone",parent:group)
        for wx in [x-w*0.32,x+w*0.32] where abs(wx-doorX)>0.9 {window(x:wx,y:1.45,z:z+d/2+0.06,parent:group)}
        sign(title,x:x,y:2.3,z:z+d/2+0.09,width:CGFloat(min(w-0.5,4.6)),parent:group)
        if house {box(x+w*0.28,3.55,z-0.6,0.5,1.5,0.6,0x887F71,"stone",parent:group)}
        occluders.append((group,x,z,w,d))
    }
    private func window(x:Float,y:Float,z:Float,parent:SCNNode) {
        box(x,y,z,1.05,1.15,0.12,0xDDD3BC,"wood",parent:parent)
        let pane=box(x,y,z+0.075,0.88,0.98,0.05,0x8DA9AD,"glass",parent:parent)
        pane.geometry?.firstMaterial?.emission.contents=color(0x273A40)
        box(x,y,z+0.11,0.055,1,0.05,0xDDD3BC,"wood",parent:parent)
        box(x,y,z+0.11,0.9,0.055,0.05,0xDDD3BC,"wood",parent:parent)
    }
    private func sign(_ text:String,x:Float,y:Float,z:Float,width:CGFloat,parent:SCNNode?=nil) {
        box(x,y,z,width,0.37,0.08,0x4B5D50,"wood",parent:parent)
        let geo=SCNPlane(width:width*0.92,height:0.28)
        let mat=SCNMaterial();mat.lightingModel = .constant;mat.diffuse.contents=caption(text);mat.isDoubleSided=true;geo.materials=[mat]
        let node=SCNNode(geometry:geo);node.position=SCNVector3(x,y,z+0.05);(parent ?? scenery).addChildNode(node)
    }
    private func caption(_ text:String)->UIImage {
        let format=UIGraphicsImageRendererFormat();format.scale=1
        return UIGraphicsImageRenderer(size:CGSize(width:512,height:64),format:format).image { _ in
            let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
            (text as NSString).draw(in:CGRect(x:0,y:8,width:512,height:56),withAttributes:[.font:UIFont.systemFont(ofSize:30,weight:.semibold),.foregroundColor:UIColor(red:0.96,green:0.92,blue:0.8,alpha:1),.paragraphStyle:paragraph])
        }
    }
    private func tree(x:Float,z:Float,seed:Int,scale:Float=1) {
        let root=SCNNode();root.position=SCNVector3(x,0,z);root.scale=SCNVector3(scale,scale,scale);scenery.addChildNode(root)
        _=cylinder(0,1.1,0,0.13,2.2,0x766047,parent:root)
        for i in 0..<11 {
            let angle=Float(i)*2.399
            let r:Float=0.15+Float((i+seed)%4)*0.2
            let leaf=sphere(cos(angle)*r,2.0+Float(i%3)*0.43,sin(angle)*r,0.7,[UInt32(0x68815A),0x809266,0x536E51][(i+seed)%3],parent:root)
            leaf.scale=SCNVector3(1,0.85+Float(i%2)*0.3,1)
        }
        root.runAction(.repeatForever(.sequence([.rotateBy(x:0,y:0,z:0.015,duration:2.2),.rotateBy(x:0,y:0,z:-0.015,duration:2.2)])))
    }
    private func plant(x:Float,z:Float,parent:SCNNode?=nil) {
        _=cylinder(x,0.24,z,0.22,0.48,0xA77D5E,parent:parent)
        for i in 0..<5 {let a=Float(i)*1.25;let leaf=sphere(x+cos(a)*0.15,0.64,z+sin(a)*0.15,0.23,0x71885B,parent:parent);leaf.scale=SCNVector3(0.7,1.4,0.7)}
    }
    private func bench(x:Float,z:Float) {
        box(x,0.5,z,0.95,0.14,0.45,0xA18862,"wood")
        box(x,0.85,z-0.2,0.95,0.5,0.09,0x907650,"wood")
        for dx:Float in [-0.34,0.34] {box(x+dx,0.24,z,0.08,0.48,0.4,0x4C564A,"metal")}
    }

    private func buildGrounds(_ motel:Motel) {
        slab(x:36,z:24,w:110,d:90,color:0x7B8F61,kind:"grass",y:-0.04)
        // Narrow, connected lanes leave meadow around the hotel and town.
        slab(x:41.5,z:24,w:3,d:50,color:0x797E75,kind:"gravel")
        slab(x:36,z:36.5,w:74,d:3,color:0x797E75,kind:"gravel")
        slab(x:56,z:19.5,w:30,d:3,color:0x797E75,kind:"gravel")
        slab(x:7,z:12,w:10,d:6,color:0xB8B19A)
        slab(x:12,z:21,w:2,d:27,color:0xB8B19A)
        for z:Float in [9,18,27] {slab(x:25,z:z,w:26,d:2,color:0xB8B19A)}
        slab(x:6.5,z:29,w:3,d:13,color:0xB8B19A)
        slab(x:26.5,z:32,w:23,d:5,color:0x898B7D,kind:"gravel")
        slab(x:56.5,z:30.5,w:27,d:3,color:0xB8B19A)
        slab(x:54.5,z:16.5,w:1.5,d:6,color:0xB8B19A)
        for x in stride(from:3,to:71,by:5) {slab(x:Float(x),z:36.5,w:2,d:0.06,color:0xD9CBA4,kind:"plaster",y:0.04)}
        building(x:7,z:6,w:8,d:6,doorX:6.5,doorZ:9,paint:0xDED3BB,roofColor:0x6A7A78,title:"RECEPTION")
        for index in 0..<9 {
            let id=index+motel.viewingFloor*9
            let origin=MotelGrounds.roomOrigin(index)
            let x=Float(origin.x)+3,z=Float(origin.y)+2
            if let room=motel.rooms.first(where:{$0.id == id}) {
                building(x:x,z:z,w:6,d:4,doorX:Float(MotelGrounds.roomDoor(index).x)+0.5,doorZ:z+2,paint:Motel.themeColors[room.theme],roofColor:0x697472,title:"\(room.number)")
            } else {
                slab(x:x,z:z,w:6,d:4,color:0xA29B7C,kind:"gravel")
                for dx:Float in [-2.7,2.7] {_=cylinder(x+dx,0.5,z+1.7,0.06,1,0x897654)}
            }
        }
        building(x:54.5,z:11.5,w:7,d:5,doorX:54.5,doorZ:14,paint:0xDDD1B7,roofColor:motel.household.level>1 ? 0x657E82 : 0x8A6D5C,title:"HOME",house:true)
        plant(x:51.7,z:14.6);plant(x:57.2,z:14.6)
        for shop in NeighborhoodShop.allCases {
            building(x:Float(shop.door.x)+0.5,z:26,w:7,d:6,doorX:Float(shop.door.x)+0.5,doorZ:29,paint:0xD7C7A8,roofColor:shop == .furniture ? 0x877B68 : shop == .clothing ? 0x857789 : 0x597E78,title:shop.title.uppercased())
        }
        // A recessed pool, stone coping and an animated water surface.
        slab(x:6.5,z:20.5,w:7.6,d:5.6,color:0xC5C1AD)
        box(6.5,0.03,20.5,6.7,0.07,4.7,0x6A9895,"glass",round:0.16)
        let water=box(6.5,0.09,20.5,6.45,0.035,4.45,0x78ADA8,"glass",round:0.1)
        water.geometry?.firstMaterial?.roughness.contents=0.18
        water.runAction(.repeatForever(.sequence([.fadeOpacity(to:0.82,duration:2),.fadeOpacity(to:1,duration:2)])))
        for tile in RPGMaps.landscapeTrees {tree(x:Float(tile.x)+0.5,z:Float(tile.y)+0.5,seed:tile.x+tile.y)}
        for tile in RPGMaps.landscapeBenches {bench(x:Float(tile.x)+0.5,z:Float(tile.y)+0.5)}
        // Trees and low hills beyond the playable boundary create depth without
        // adding invisible obstacles or changing any navigation coordinates.
        for i in 0..<24 {
            let x=Float(i*3)-1
            tree(x:x,z:-2.5-Float(i%3),seed:i,scale:1+Float(i%3)*0.15)
            if i%2 == 0 {tree(x:x,z:50+Float(i%3),seed:i+40,scale:1.2)}
        }
        for i in 0..<10 {let mound=sphere(Float(i*12)-18,-2,-13-Float(i%3)*4,8,0x778B70);mound.scale=SCNVector3(1.8,0.65,1.2)}
        for i in 0..<30 {
            let x=Float((i*19)%70)+1,z=Float((i*13)%45)+1
            if MotelGrounds.blocked(Tile(x:Int(x),y:Int(z))) {continue}
            if z<3 || z>39 || x>69 {
                let rock=sphere(x,0.12,z,0.26,0x919383);rock.scale=SCNVector3(1.4,0.6,1)
            }
        }
        for service in HotelService.allCases {
            let x=Float(service.tile.x)+0.5,z=Float(service.tile.y)+0.5
            switch service {
            case .garden:plant(x:x,z:z)
            case .laundry:box(x,0.55,z,0.8,1.1,0.75,0xD3D1BE,"metal");box(x,0.6,z+0.39,0.46,0.46,0.025,0x6B8586,"glass")
            case .repair:box(x,0.35,z,0.75,0.7,0.6,0x798D89,"metal")
            case .breakfast:table(x:x,z:z);box(x,0.92,z,0.4,0.15,0.35,0xE4D9BA)
            case .luggage:box(x,0.35,z,0.65,0.7,0.35,0x987656,"wood")
            }
        }
        _=cylinder(12.5,0.7,26.5,0.07,1.4,0x806D4F)
        sign("BUILD",x:12.5,y:1.35,z:26.5,width:1.2)
        for role in StaffRole.allCases where role != .clerk {
            let x=Float(role.home.x)+0.5,z=Float(role.home.y)+0.5
            box(x,0.35,z,0.7,0.7,0.45,role.color,"wood")
        }
    }

    private func interiorFloor(width:Float,depth:Float,color:UInt32,wall:UInt32) {
        slab(x:width/2,z:depth/2,w:CGFloat(width),d:CGFloat(depth),color:0x514E43,kind:"stone",y:-0.12)
        slab(x:width/2,z:(depth+2)/2,w:CGFloat(width-2),d:CGFloat(depth-2),color:color,kind:"wood",y:0)
        box(width/2,1.35,1.7,CGFloat(width-2),2.7,0.24,wall)
        // Cutaway side walls keep every character, floor tile and workstation visible.
        box(0.85,0.35,(depth+2)/2,0.25,0.7,CGFloat(depth-2),wall)
        box(width-0.85,0.35,(depth+2)/2,0.25,0.7,CGFloat(depth-2),wall)
        box(width/2,0.14,1.85,CGFloat(width-2),0.24,0.16,0x7B6750,"wood")
        for x:Float in [width*0.25,width*0.75] {window(x:x,y:1.65,z:1.86,parent:scenery)}
        slab(x:width/2,z:depth-0.35,w:1.1,d:1.2,color:0xCFC2A2)
    }
    private func table(x:Float,z:Float,parent:SCNNode?=nil) {
        box(x,0.78,z,0.98,0.14,0.72,0xAD9166,"wood",parent:parent)
        for dx:Float in [-0.36,0.36] {for dz:Float in [-0.24,0.24] {box(x+dx,0.36,z+dz,0.09,0.72,0.09,0x80674A,"wood",parent:parent)}}
    }
    private func bed(x:Float,z:Float,color:UInt32) {
        box(x,0.3,z,1.8,0.6,2.4,0x8E7553,"wood")
        box(x,0.65,z,1.72,0.3,2.3,0xE5DDC8)
        box(x,0.83,z+0.35,1.75,0.12,1.55,color)
        box(x,0.91,z-0.7,1.35,0.16,0.48,0xF0E8D7)
        box(x,0.65,z-1.2,1.95,1.3,0.16,0x8E7553,"wood")
    }
    private func sofa(x:Float,z:Float,color:UInt32) {
        box(x,0.4,z,2.65,0.65,1.3,color)
        box(x,0.95,z-0.5,2.65,0.95,0.32,color)
        for dx:Float in [-1.2,1.2] {box(x+dx,0.65,z,0.3,0.8,1.25,color)}
        for dx:Float in [-0.6,0,0.6] {box(x+dx,0.78,z+0.08,0.56,0.18,0.85,0xB7ACAE)}
    }
    private func workbench() {
        table(x:4.5,z:11.5)
        box(4.3,0.88,11.5,0.38,0.025,0.38,0xE5DDC8)
        box(4.72,0.89,11.5,0.055,0.05,0.38,0x7F684A,"wood")
        box(4.72,0.92,11.34,0.24,0.12,0.1,0x6E7D7C,"metal")
    }
    private func buildHome(_ motel:Motel) {
        interiorFloor(width:15,depth:15,color:HomeInteriorArt.floors[motel.household.floor],wall:Motel.themeColors[motel.household.wallpaper])
        // Every tile shares the same material, including the former west-room block.
        box(11.5,0.45,5.8,2.7,0.8,1.1,0x8D7354,"wood")
        box(11.5,1.25,5.7,2.0,1.15,0.16,0x37403D,"metal")
        let screen=box(11.5,1.27,5.8,1.82,0.94,0.02,0x8EB4B2,"glass")
        screen.geometry?.firstMaterial?.emission.contents=color(0x48666A)
        sofa(x:12.3,z:10.7,color:0x9B8C9C)
        table(x:2.5,z:10.5)
        box(2.5,0.89,10.5,0.52,0.06,0.42,0xE9DFC5)
        workbench()
        for x:Float in [10.5,12.5] {box(x,0.09,12.5,0.9,0.18,0.72,0xB69C7B,round:0.12);_=cylinder(x,0.07,13.2,0.16,0.14,0x83A5A0)}
        for placed in motel.household.placed {homeObject(placed.kind,x:Float(placed.tile.x)+0.5,z:Float(placed.tile.y)+0.5)}
        if motel.household.level>0 {sign("HOME",x:7.5,y:2,z:1.86,width:2)}
    }
    private func homeObject(_ kind:HomeObject,x:Float,z:Float) {
        switch kind {
        case .plant:plant(x:x,z:z)
        case .table:table(x:x,z:z)
        case .rug:slab(x:x,z:z,w:0.95,d:0.95,color:0xA78D75,kind:"fabric",y:0.04)
        case .lamp:
            _=cylinder(x,0.04,z,0.25,0.08,0x6B6C57);_=cylinder(x,0.65,z,0.035,1.3,0x867C5D)
            let cone=SCNCone(topRadius:0.18,bottomRadius:0.34,height:0.42);cone.materials=[material(0xE6D2A4)];let node=SCNNode(geometry:cone);node.position=SCNVector3(x,1.38,z);scenery.addChildNode(node)
        case .bookshelf:
            box(x,0.8,z,0.9,1.6,0.45,0x8E7555,"wood")
            for row in 0..<3 {for col in 0..<5 {box(x-0.31+Float(col)*0.15,0.3+Float(row)*0.47,z+0.25,0.1,0.3,0.18,[UInt32(0x8C6E5B),0x73857A,0xB8A27C][col%3],"wood")}}
        case .armchair:
            box(x,0.4,z,0.8,0.65,0.8,0xA394A2);box(x,0.85,z-0.32,0.8,0.75,0.18,0xA394A2)
        }
    }
    private func buildOffice(_ motel:Motel) {
        interiorFloor(width:15,depth:15,color:0xB49A75,wall:Motel.themeColors[motel.officeTheme])
        box(4.5,0.55,5,5,1.1,2,0x887050,"wood")
        box(4.5,1.15,5,5.15,0.18,2.12,0xB89D73,"wood")
        box(3.5,1.35,4.5,0.12,0.35,0.16,0x4B5553,"metal")
        box(3.5,1.7,4.5,1,0.65,0.1,0x384544,"metal")
        let screen=box(3.5,1.7,4.56,0.86,0.52,0.025,0x8EB6AD,"glass")
        screen.geometry?.firstMaterial?.emission.contents=color(0x37564C)
        box(3.5,1.28,4.95,0.85,0.06,0.3,0xD1CDBC,"metal")
        box(5.5,1.28,4.5,0.6,0.06,0.45,0xE8DFC7)
        sign("RECEPTION",x:4.5,y:0.85,z:6.06,width:3)
        bed(x:1.7,z:3,color:0x8FA99A)
        for z:Float in [7.5,9.5] {box(1.25,0.8,z,0.45,1.6,0.85,0x9B815A,"wood")}
        plant(x:13.2,z:3)
        slab(x:7.5,z:12.2,w:2.8,d:1.5,color:0xAD8D6D,kind:"fabric",y:0.04)
    }
    private func buildRoom(_ room:MotelRoom,visit:RoomVisit) {
        interiorFloor(width:9,depth:9,color:0xB4A084,wall:Motel.themeColors[room.theme])
        bed(x:3,z:2.8,color:Motel.themeColors[room.theme])
        table(x:6.5,z:6.5)
        box(7.5,0.55,2.5,0.7,1.1,0.5,0xA59678,"wood")
        plant(x:2.5,z:3.5)
        if room.dirty {
            if !(room.cleanedTasks ?? []).contains(1) {box(2.5,0.18,6.5,0.7,0.35,0.6,0x7F806B,round:0.12)}
            if !(room.cleanedTasks ?? []).contains(2) {slab(x:5.5,z:5.5,w:0.8,d:0.65,color:0x897758,kind:"gravel",y:0.04)}
        }
        if visit.sneaking {
            for index in RoomVisit.lootTiles.indices where !visit.loot.contains(index) && !room.stolen.contains(index) {
                let tile=RoomVisit.lootTiles[index]
                box(Float(tile.x)+0.5,0.45,Float(tile.y)+0.5,0.55,0.5,0.35,[UInt32(0x967955),0xB8A36B,0x505D59][index%3],"metal")
            }
        }
    }
    private func buildTown() {
        slab(x:10,z:11.5,w:50,d:53,color:0x7B8F61,kind:"grass",y:-0.04)
        slab(x:10,z:11.5,w:3,d:24,color:0xB5AC92)
        slab(x:10,z:9,w:22,d:2,color:0xB5AC92)
        building(x:4,z:5,w:4,d:4,doorX:4,doorZ:7,paint:0xD8C5A8,roofColor:0x7B8175,title:"MARKET")
        building(x:15.5,z:5,w:5,d:4,doorX:15.5,doorZ:7,paint:0xDDD0B7,roofColor:0x8B7762,title:"HOME",house:true)
        building(x:4,z:12.5,w:4,d:3,doorX:4,doorZ:14,paint:0xC6BDA8,roofColor:0x6A827C,title:"CAFÉ")
        building(x:16,z:14.5,w:4,d:3,doorX:16,doorZ:16,paint:0xD2C0AB,roofColor:0x8D7B79,title:"SHOP")
        for i in 0..<12 {tree(x:Float(i*2)-1,z:-1,seed:i);tree(x:Float(i*2)-1,z:24,seed:i+10)}
    }

    @MainActor private func actorImage(_ actor:RPGActor,stride:Double)->UIImage {
        let key="\(actor.color)-\(actor.variant)-\(actor.facing)-\(actor.animal)-\(actor.effect)-\(actor.expression)-\(stride)"
        if let image=portraits[key] {return image}
        let render=ImageRenderer(content:ActorArtwork(actor:actor,stride:stride));render.scale=5
        let image=render.uiImage ?? UIImage();portraits[key]=image;return image
    }
    private func billboard(image:UIImage,width:CGFloat,height:CGFloat)->SCNNode {
        let plane=SCNPlane(width:width,height:height)
        let mat=SCNMaterial();mat.lightingModel = .constant;mat.diffuse.contents=image;mat.isDoubleSided=true;mat.writesToDepthBuffer=false
        plane.materials=[mat]
        let node=SCNNode(geometry:plane);let facing=SCNBillboardConstraint();facing.freeAxes = .all;node.constraints=[facing];return node
    }
    @MainActor private func updateActors(_ actors:[RPGActor],working:Bool,workKind:String) {
        let ids=Set(actors.map{$0.id})
        for node in cast.childNodes where node.name?.hasPrefix("actor:") == true && !ids.contains(String(node.name!.dropFirst(6))) {node.removeFromParentNode()}
        for actor in actors {
            let id="actor:"+actor.id
            let existing=cast.childNode(withName:id,recursively:false)
            let node=existing ?? SCNNode()
            let moved=targets[actor.id] != actor.tile
            if existing == nil {
                node.name=id;cast.addChildNode(node)
                let portrait=billboard(image:actorImage(actor,stride:0),width:1.5*actor.displayScale,height:1.75*actor.displayScale)
                portrait.name="portrait";portrait.position.y=Float(0.82*actor.displayScale);node.addChildNode(portrait)
                let shadow=SCNNode(geometry:SCNPlane(width:0.65*actor.displayScale,height:0.4*actor.displayScale))
                shadow.eulerAngles.x = -.pi/2;shadow.position.y=0.045
                let mat=SCNMaterial();mat.diffuse.contents=UIColor.black.withAlphaComponent(0.19);mat.lightingModel = .constant;shadow.geometry?.materials=[mat];node.addChildNode(shadow)
            }
            let target=SCNVector3(Float(actor.tile.x)+0.5,0.04,Float(actor.tile.y)+0.5)
            if existing == nil {node.position=target} else if moved {node.removeAction(forKey:"move");node.runAction(.move(to:target,duration:actor.duration),forKey:"move")}
            let key="\(actor.color)-\(actor.variant)-\(actor.facing)-\(actor.effect)-\(actor.expression)-\(actor.action)-\(actor.name)-\(actor.marker)"
            if moved || appearance[actor.id] != key, let portrait=node.childNode(withName:"portrait",recursively:false) {
                let frames: [UIImage]
                if actor.effect>0 {frames=(0..<8).map{actorImage(actor,stride:Double($0))}}
                else if moved && existing != nil {frames=[actorImage(actor,stride:1),actorImage(actor,stride:-1),actorImage(actor,stride:0)]}
                else {frames=[actorImage(actor,stride:0)]}
                portrait.removeAllActions();portrait.geometry?.firstMaterial?.diffuse.contents=frames[0]
                if frames.count>1 {
                    let actions=frames.flatMap { image in [SCNAction.run { n in n.geometry?.firstMaterial?.diffuse.contents=image },SCNAction.wait(duration:actor.effect>0 ? 0.1 : actor.duration/3)] }
                    let animation=SCNAction.sequence(actions)
                    portrait.runAction(actor.effect>0 ? .repeatForever(animation) : animation)
                }
                node.childNode(withName:"caption",recursively:false)?.removeFromParentNode()
                let text=[actor.name,actor.marker].filter{!$0.isEmpty}.joined(separator:" ")
                if !text.isEmpty {
                    let label=billboard(image:caption(text),width:min(3,max(1,CGFloat(text.count)*0.1)),height:0.24)
                    label.name="caption";label.position.y=Float(1.9*actor.displayScale);node.addChildNode(label)
                }
                node.childNode(withName:"activity",recursively:false)?.removeFromParentNode()
                if !actor.action.isEmpty {let effect=actionNode(actor.action);effect.name="activity";effect.position=SCNVector3(0.4,0.8,0.1);node.addChildNode(effect)}
            }
            if actor.id == "player" {
                node.childNode(withName:"work",recursively:false)?.removeFromParentNode()
                if working {let effect=actionNode(workKind);effect.name="work";effect.position=SCNVector3(0.3,0.6,0.2);node.addChildNode(effect)}
            }
            targets[actor.id]=actor.tile;appearance[actor.id]=key
        }
    }
    @MainActor private func actionNode(_ kind:String)->SCNNode {
        let frames:[UIImage]
        if let cached=activities[kind] {frames=cached}
        else {frames=(0..<8).map { frame in let r=ImageRenderer(content:HotelActionArtwork(kind:kind,frame:frame));r.scale=3;return r.uiImage ?? UIImage() };activities[kind]=frames}
        let node=billboard(image:frames[0],width:2.5,height:2.5)
        node.runAction(.repeatForever(.sequence(frames.flatMap { image in [SCNAction.run {n in n.geometry?.firstMaterial?.diffuse.contents=image},.wait(duration:0.12)] })))
        return node
    }
    private func updateCars(_ motel:Motel) {
        let ids=Set((motel.operationsState.cars ?? []).map{"car:\($0.id)"})
        for node in cars.childNodes where !ids.contains(node.name ?? "") {node.removeFromParentNode()}
        for car in motel.operationsState.cars ?? [] {
            let name="car:\(car.id)"
            let node=cars.childNode(withName:name,recursively:false) ?? SCNNode()
            if node.parent == nil {
                node.name=name;cars.addChildNode(node)
                box(0,0.48,0,2.8,0.6,1.45,car.color,"metal",parent:node,round:0.18)
                box(0,0.98,0,1.55,0.55,1.25,0x7B939A,"glass",parent:node,round:0.15)
                box(0,1.28,0,1.5,0.1,1.2,car.color,"metal",parent:node)
                for x:Float in [-0.9,0.9] {for z:Float in [-0.72,0.72] {let wheel=cylinder(x,0.28,z,0.29,0.16,0x37413C,parent:node);wheel.eulerAngles.x = .pi/2}}
            }
            let bay=HotelCar.tile(car.slot),fraction=min(1,Double(car.arrival)/4)
            let x=6+Double(bay.x-6)*fraction,z=34+Double(bay.y-34)*min(1,max(0,Double(car.arrival-4))/4)
            let target=SCNVector3(Float(x)+0.5,0.04,Float(z)+0.5)
            if node.position.x == 0 {node.position=target}
            else {SCNTransaction.begin();SCNTransaction.animationDuration=0.9;node.position=target;SCNTransaction.commit()}
        }
    }
    private func configureLight(night:Bool,indoor:Bool,powerOut:Bool,nightVision:Bool) {
        let dark=night && !indoor
        sun.light?.intensity=dark ? 180 : indoor ? 700 : 1250
        sun.light?.color=dark ? UIColor(red:0.65,green:0.77,blue:0.94,alpha:1) : UIColor(red:1,green:0.94,blue:0.81,alpha:1)
        ambient.light?.intensity=powerOut && indoor ? 110 : dark ? 180 : 480
        ambient.light?.color=nightVision ? UIColor(red:0.48,green:0.85,blue:0.5,alpha:1) : UIColor(red:0.79,green:0.86,blue:0.88,alpha:1)
        let sky=dark ? UIColor(red:0.12,green:0.19,blue:0.24,alpha:1) : UIColor(red:0.68,green:0.77,blue:0.77,alpha:1)
        world.background.contents=indoor ? UIColor(red:0.12,green:0.2,blue:0.17,alpha:1) : sky
        world.fogColor=sky;world.fogStartDistance=indoor ? 100 : 32;world.fogEndDistance=indoor ? 150 : 85
    }
    private func configureWeather(_ weather:HotelWeather) {
        let key=weather.rawValue
        guard weatherKey != key else {return};weatherKey=key
        weatherNode.removeAllParticleSystems()
        if weather == .rain || weather == .storm || weather == .snow {
            let snow=weather == .snow
            let particles=SCNParticleSystem();particles.emitterShape=SCNBox(width:28,height:0.1,length:28,chamferRadius:0)
            particles.birthRate=snow ? 90 : 350;particles.particleLifeSpan=snow ? 12 : 1.5
            particles.particleSize=snow ? 0.055 : 0.018;particles.particleColor=snow ? .white : UIColor(red:0.72,green:0.83,blue:0.87,alpha:0.6)
            particles.emittingDirection=SCNVector3(0,-1,0);particles.particleVelocity=snow ? 1.5 : 14
            particles.acceleration=SCNVector3(0.2,0,0);particles.spreadingAngle=8
            weatherNode.addParticleSystem(particles)
        }
    }
    private func configureTargets(_ actors:[RPGActor],motel:Motel?) {
        guard tapAction != nil else {buttons.values.forEach{$0.removeFromSuperview()};buttons=[:];tapTargets=[:];return}
        var entries:[(OfficeTap,String,Tile,Float)]=[]
        if map == "family-house" {
            entries=[(.door,"Leave home",FamilyHome.exit,0.15),(.player,"Home checkpoint",Tile(x:2,y:10),0.8),(.workbench,"Use workbench",FamilyHome.workbench,0.8)]
        } else if map == "family-office" {
            entries=[(.player,"Front desk",OfficeReception.clerk,1),(.computer,"Reception computer",OfficeReception.computer,1.6),(.door,"Leave office",OfficeReception.door,0.1),(.tools,"Take cleaning tools",Tile(x:1,y:7),0.8),(.paint,"Paint office",Tile(x:1,y:9),0.8),(.bed,"Sleep until morning",Tile(x:1,y:2),0.8),(.save,"Save checkpoint",Tile(x:5,y:4),1.25)]
            if let guest=motel?.reception.visitor {entries.append((.guest,"Talk to \(guest.guest.name)",guest.tile,0.8))}
        }
        for actor in actors where ["hildarelys","samhil","chichu","chichi"].contains(actor.id) {
            if let item=OfficeTap(rawValue:actor.id) {entries.append((item,"Talk to \(actor.name)",actor.tile,0.8))}
        }
        let ids=Set(entries.map{$0.0.rawValue})
        for (id,button) in buttons where !ids.contains(id) {button.removeFromSuperview();buttons[id]=nil;tapTargets[id]=nil}
        for (item,label,tile,height) in entries {
            let id=item.rawValue
            if buttons[id] == nil {
                let button=UIButton(type:.custom);button.backgroundColor = .clear
                button.accessibilityIdentifier="office_"+id
                button.addAction(UIAction { [weak self] _ in self?.tapAction?(item) },for:.touchUpInside)
                addSubview(button);buttons[id]=button
            }
            buttons[id]?.accessibilityLabel=label
            tapTargets[id]=SCNVector3(Float(tile.x)+0.5,height,Float(tile.y)+0.5)
        }
        accessibilityElements=entries.compactMap{buttons[$0.0.rawValue]}
    }
    private func layoutTargets() {
        for (id,position) in tapTargets {
            let point=viewport.projectPoint(position)
            buttons[id]?.frame=CGRect(x:CGFloat(point.x)-24,y:CGFloat(point.y)-24,width:48,height:48)
            buttons[id]?.isHidden=point.z<0 || point.z>1
        }
    }
}
