import SwiftUI

enum CraftyStyle {
    static let green = Color(red: 0.25, green: 0.68, blue: 0.49)
    static let background = Color(uiColor: .systemGroupedBackground)
}

struct StatusPill: View {
    let running: Bool
    var body: some View {
        Label(running ? "Online" : "Offline", systemImage: "circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(running ? CraftyStyle.green : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background((running ? CraftyStyle.green : Color.secondary).opacity(0.12), in: Capsule())
    }
}

struct ErrorNotice: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityAddTraits(.isStaticText)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(detail))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(CraftyStyle.green)
            Text(value).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
