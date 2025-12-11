import SwiftUI

// MARK: - Project Model
struct Project: Identifiable, Equatable {
    let id: UUID
    var name: String
    var color: Color
    var icon: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: Color = availableColors[0],
        icon: String = "folder.fill",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
    }

    static let availableColors: [Color] = [
        .priorityBlue,
        .priorityPurple,
        .priorityGreen,
        .priorityOrange,
        .priorityPink,
        .priorityCyan
    ]

    static let availableIcons: [String] = [
        "folder.fill",
        "briefcase.fill",
        "book.fill",
        "star.fill",
        "heart.fill",
        "flag.fill",
        "bolt.fill",
        "leaf.fill",
        "graduationcap.fill",
        "house.fill",
        "car.fill",
        "airplane",
        "gamecontroller.fill",
        "music.note",
        "photo.fill",
        "gift.fill"
    ]

    static func nextColor(forIndex index: Int) -> Color {
        availableColors[index % availableColors.count]
    }
}
