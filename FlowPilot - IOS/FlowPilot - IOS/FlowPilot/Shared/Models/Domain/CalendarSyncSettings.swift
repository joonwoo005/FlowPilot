import Foundation
import Combine

// MARK: - Calendar Sync Store

class CalendarSyncStore: ObservableObject {
    static let shared = CalendarSyncStore()

    @Published var isEnabled: Bool = false

    private let userDefaultsKey = "calendarSyncEnabled"

    init() {
        loadSettings()
    }

    // MARK: - Persistence

    func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
    }

    // MARK: - Toggle

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
    }
}
