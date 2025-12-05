import SwiftUI

// MARK: - Priority Model
struct Priority: Identifiable, Equatable {
    let id: UUID
    var name: String
    var color: Color
    var hoursPerWeek: Double

    static let availableColors: [Color] = [
        .priorityBlue,
        .priorityPurple,
        .priorityGreen,
        .priorityOrange,
        .priorityPink,
        .priorityCyan
    ]

    /// Returns the next color in the cycle based on current priority count
    static func nextColor(forIndex index: Int) -> Color {
        availableColors[index % availableColors.count]
    }
}
