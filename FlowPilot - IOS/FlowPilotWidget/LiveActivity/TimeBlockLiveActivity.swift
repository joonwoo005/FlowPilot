//
//  TimeBlockLiveActivity.swift
//  FlowPilotWidget
//
//  Created by Claude on 12/12/25.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TimeBlockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimeBlockActivityAttributes.self) { context in
            // Lock Screen / Banner presentation
            if context.state.isCompleted {
                TimeBlockCompletedView(context: context)
                    .activityBackgroundTint(Color(hex: "0D0D0F"))
            } else {
                TimeBlockLiveActivityExpandedView(context: context)
                    .activityBackgroundTint(Color(hex: "0D0D0F"))
            }
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    TimeBlockDynamicIslandExpandedLeading(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TimeBlockDynamicIslandExpandedTrailing(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    TimeBlockDynamicIslandExpandedCenter(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    TimeBlockDynamicIslandExpandedBottom(context: context)
                }
            } compactLeading: {
                TimeBlockDynamicIslandCompactLeading(context: context)
            } compactTrailing: {
                TimeBlockDynamicIslandCompactTrailing(context: context)
            } minimal: {
                TimeBlockMinimalView(context: context)
            }
        }
    }
}
