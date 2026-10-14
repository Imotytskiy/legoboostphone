import CoreGraphics
import Foundation

enum FaceDirection: String {
    case searching = "SEARCHING"
    case left = "LEFT"
    case center = "CENTER"
    case right = "RIGHT"

    var pupilOffset: CGFloat {
        switch self {
        case .left:
            return -18
        case .right:
            return 18
        case .center:
            return 0
        case .searching:
            return 0
        }
    }
}
