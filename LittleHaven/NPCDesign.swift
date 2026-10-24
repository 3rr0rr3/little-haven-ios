import Foundation

/// Visual identity only: no fields are added to checkpoints or guest progression.
/// Mixed-radix features replace the four repeated human sprite atlases.
struct NPCDesign: Hashable {
    let hairStyle: Int
    let hairColor: Int
    let skin: Int
    let outfit: Int
    let accessory: Int
    let facialHair: Int

    init(variant: Int) {
        // A permutation of 51,840 designs. Adjacent IDs get different silhouettes
        // and palettes; the same person keeps the same design in every scene.
        let identity=Int(UInt(bitPattern:variant) % 51_840)
        var code=(identity * 131_071 + 17_399) % 51_840
        hairStyle=code % 12; code /= 12
        hairColor=code % 10; code /= 10
        skin=code % 6; code /= 6
        outfit=code % 6; code /= 6
        accessory=code % 3; code /= 3
        facialHair=code % 4
    }

    // Includes actual visible drawing features, never the original ID.
    var fingerprint: String {
        "\(hairStyle):\(hairColor):\(skin):\(outfit):\(accessory):\(facialHair)"
    }
    static let skinColors: [UInt32] = [0xF0C9A0,0xD6A477,0xA87350,0x734A37,0xE9B693,0xB9886C]
    static let hairColors: [UInt32] = [0x49352B,0x252A2C,0x795334,0xA15D3A,0xBA8C48,0xC2BDB0,0x594537,0xB26962,0x715875,0xD5B476]
    static let accentColors: [UInt32] = [0xEEE3BA,0x445B69,0x6C7A52,0xB47865,0x86739B,0xC09B50]
}
