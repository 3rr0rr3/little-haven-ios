import Foundation

// Authored fictional character presentation, never guessed from a person's name.
enum NPCPresentation:String {case feminine,masculine,neutral}
struct NPCDesign:Hashable {
    let hairStyle:Int
    let hairColor:Int
    let skin:Int
    let outfit:Int
    let accessory:Int
    let facialHair:Int
    let faceShape:Int
    let build:Int
    let eyeStyle:Int
    let nose:Int
    let collar:Int
    let presentation:NPCPresentation
    let variant:Int

    init(variant:Int) {
        self.variant=variant
        let identity=Int(UInt(bitPattern:variant)%1_048_576)
        let mixed=identity*2_654_435_761
        var code=(mixed ^ (mixed>>16)) % (20*10*6*8*8*4*4*3*3*3*4)
        func take(_ radix:Int)->Int {let value=code%radix;code/=radix;return value}
        let rawHair=take(20)
        hairColor=take(10);skin=take(6);outfit=take(8);accessory=take(8)
        let beard=take(4)
        faceShape=take(4);build=take(3);eyeStyle=take(3);nose=take(3);collar=take(4)
        presentation=Self.feminine.contains(variant) ? .feminine : Self.masculine.contains(variant) ? .masculine : .neutral
        switch presentation {
        case .feminine:hairStyle=[1,3,6,8,9,12,13,14,15,16,17,18][rawHair%12]
        case .masculine:hairStyle=[0,2,4,5,7,13,14,16,18,19][rawHair%10]
        case .neutral:hairStyle=rawHair
        }
        facialHair=presentation == .masculine ? beard : 0
    }
    // Only actual visible traits participate; no raw ID masks repeated artwork.
    var fingerprint:String {"\(presentation.rawValue):\(hairStyle):\(hairColor):\(skin):\(outfit):\(accessory):\(facialHair):\(faceShape):\(build):\(eyeStyle):\(nose):\(collar)"}
    func shirtColor(base:UInt32)->UInt32 {
        if (200...207).contains(variant) || (461...465).contains(variant) || variant==700 {return base}
        let tint=Self.clothingColors[(outfit+hairColor)%Self.clothingColors.count]
        func mix(_ shift:UInt32)->UInt32 {(((base>>shift)&255)*2+((tint>>shift)&255)*3)/5}
        return (mix(16)<<16)|(mix(8)<<8)|mix(0)
    }
    static let feminine:Set<Int>=[1,3,6,110,112,114,116,118,120,122,181,182,200,204,206,207,311,313,315,462,465,520,522,524,560,562,564,610,612]
    static let masculine:Set<Int>=[0,2,4,111,113,115,117,119,121,123,201,203,312,314,316,461,521,523,525,561,563,565,611,700]
    static let names:[Int:String] = {
        var result:[Int:String]=[:]
        func add(_ start:Int,_ values:[String]) {for (i,name) in values.enumerated(){result[start+i]=name}}
        add(0,["Milo","June","Theo","Fern","Otis","Pip","Rose"])
        add(100,["Robin","Sasha","Ellis","Alex","Morgan","Casey","Jamie","Blair","Drew","Quinn","Camila","Mateo","Luna","Diego","Amara","Noah","Valentina","Leo","Zoe","Hugo","Isabel","Finn","Lucia","Oscar"])
        add(180,["Rowan","Celeste","Emilia"])
        add(200,["Luna","Mateo","Riley","Diego","Nora","Alex","Iris","Mina"])
        add(310,["Avery","Mila","Theo","Iris","Leon","Rosa","Nico"])
        add(461,["Otis","Mira","Sal","Jules","Marina"])
        add(520,["Cleo","Dante","Petra","Emil","Nia","Orson"])
        add(560,["Elena","Marcus","Priya","Bruno","Nadia","Felix"])
        add(610,["Nora","Ben","Elena"])
        result[585]="Bar server";result[586]="Restaurant server";result[700]="Officer Vega"
        return result
    }()
    static let skinColors:[UInt32]=[0xF0C9A0,0xD6A477,0xA87350,0x734A37,0xE9B693,0xB9886C]
    static let hairColors:[UInt32]=[0x49352B,0x252A2C,0x795334,0xA15D3A,0xBA8C48,0xC2BDB0,0x594537,0xB26962,0x715875,0xD5B476]
    static let accentColors:[UInt32]=[0xEEE3BA,0x445B69,0x6C7A52,0xB47865,0x86739B,0xC09B50,0xA8C5BD,0xD2A4AC]
    static let clothingColors:[UInt32]=[0x699C8A,0xC58568,0x6D96AD,0xA285B2,0xD4B268,0x8C9D64,0xB56F82,0x5E7D89,0xB9A080,0x8A7770,0x78A8A1,0xA5A0BC]
}
