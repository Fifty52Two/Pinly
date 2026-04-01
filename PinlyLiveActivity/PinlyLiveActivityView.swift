import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Live Activity Widget

struct PinlyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PinlyActivityAttributes.self) { context in
            // MARK: Lock Screen View
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.nextPlaceName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.remainingDistance)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "arrow.turn.up.right")
                            .foregroundColor(.blue)
                        Text(context.state.instruction)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 4)

                    ProgressView(value: context.state.completionPercentage)
                        .tint(.blue)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text(context.state.remainingDistance)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            } minimal: {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let state: PinlyActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "arrow.turn.up.right")
                    .font(.title3)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.instruction)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(state.remainingDistance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Durak \(state.stopIndex)/\(state.totalStops)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(state.nextPlaceName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }

            ProgressView(value: state.completionPercentage)
                .tint(.blue)
        }
        .padding(16)
    }
}
