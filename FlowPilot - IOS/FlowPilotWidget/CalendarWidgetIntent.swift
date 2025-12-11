//
//  CalendarWidgetIntent.swift
//  FlowPilotWidget
//

import AppIntents
import WidgetKit

// MARK: - View Mode Enum
enum CalendarWidgetViewMode: String, AppEnum {
    case today = "today"
    case week = "week"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "View Mode"

    static var caseDisplayRepresentations: [CalendarWidgetViewMode: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: "Today", subtitle: "Show today's time blocks"),
        .week: DisplayRepresentation(title: "Week", subtitle: "Show week overview")
    ]
}

// MARK: - Widget Configuration Intent
struct CalendarWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Calendar Widget"
    static var description: IntentDescription = IntentDescription("Configure your calendar widget view")

    @Parameter(title: "View Mode", default: .today)
    var viewMode: CalendarWidgetViewMode

    init() {}

    init(viewMode: CalendarWidgetViewMode) {
        self.viewMode = viewMode
    }
}
