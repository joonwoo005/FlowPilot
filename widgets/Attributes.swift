import ActivityKit
import SwiftUI

struct WeekFillWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentBlock: String?
        var timeRemaining: String?
    }

    var blockName: String
}
