//
//  PinlyLiveActivityLiveActivity.swift
//  PinlyLiveActivity
//
//  Created by Ferhat Akköprü on 31.03.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PinlyLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PinlyLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PinlyLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PinlyLiveActivityAttributes {
    fileprivate static var preview: PinlyLiveActivityAttributes {
        PinlyLiveActivityAttributes(name: "World")
    }
}

extension PinlyLiveActivityAttributes.ContentState {
    fileprivate static var smiley: PinlyLiveActivityAttributes.ContentState {
        PinlyLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PinlyLiveActivityAttributes.ContentState {
         PinlyLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PinlyLiveActivityAttributes.preview) {
   PinlyLiveActivityLiveActivity()
} contentStates: {
    PinlyLiveActivityAttributes.ContentState.smiley
    PinlyLiveActivityAttributes.ContentState.starEyes
}
