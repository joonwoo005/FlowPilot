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

    /// Returns a random color that's not already used by existing priorities
    /// If all colors are used, returns a random color from the available pool
    static func nextUniqueColor(excluding existingPriorities: [Priority]) -> Color {
        let usedColors = Set(existingPriorities.map { $0.color })
        let unusedColors = availableColors.filter { !usedColors.contains($0) }

        if let randomUnused = unusedColors.randomElement() {
            return randomUnused
        }

        // All colors used, return a random one
        return availableColors.randomElement() ?? .priorityBlue
    }
}
