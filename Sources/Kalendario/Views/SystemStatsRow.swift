import SwiftUI

/// The row under the header with the machine's own numbers: CPU and GPU temperature, memory and
/// disk usage. `SystemStats` reads them with no privileges and refreshes while the row is on screen.
struct SystemStatsRow: View {
    private var stats: SystemStats { AppState.shared.stats }

    var body: some View {
        HStack(spacing: 16) {
            metric(symbol: "thermometer.medium",
                   label: "CPU",
                   value: SystemStats.temperature(stats.cpuTemperature))
            metric(symbol: "thermometer.medium",
                   label: "GPU",
                   value: SystemStats.temperature(stats.gpuTemperature))
            metric(symbol: "memorychip",
                   label: "RAM",
                   value: "\(SystemStats.bytes(stats.memoryUsed, style: .memory)) of \(SystemStats.bytes(stats.memoryTotal, style: .memory)) · \(SystemStats.percent(stats.memoryFraction))")
            metric(symbol: "internaldrive",
                   label: "Disk",
                   value: "\(SystemStats.bytes(stats.diskUsed, style: .file)) used · \(SystemStats.percent(stats.diskFraction))")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .background(Theme.paperElevated.opacity(0.32))
        .task { await stats.monitor() }
        .help("Internal sensors, memory and disk of this Mac")
    }

    private func metric(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(Theme.inkFaint)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
        }
        .fixedSize()
    }
}