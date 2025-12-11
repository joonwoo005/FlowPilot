//
//  FlowPilotWidgetBundle.swift
//  FlowPilotWidget
//
//  Created by junyu on 6/12/25.
//

import WidgetKit
import SwiftUI

@main
struct FlowPilotWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlowPilotWidget()
        FlowPilotLockScreenWidget()
        FlowPilotCalendarWidget()
        TimeBlockLiveActivity()
    }
}
