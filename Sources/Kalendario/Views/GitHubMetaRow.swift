import SwiftUI

/// The row at the foot of the calendar body with the GitHub metadata of the repositories the calendar
/// imports issues from: how many commits each one has on each day of the week, in seven cells aligned
/// with the days above.
///
/// The first read happens on its own and **without** the token, so nothing is asked of the keychain
/// when the app opens. The button repeats it with the stored token, for private repositories, and the
/// numbers are then kept in the preferences, so from the next launch they are there straight away.
struct GitHubMetaRow: View {
    @Environment(DataStore.self) private var store

    private var model: RepoMetaModel { AppState.shared.repoMeta }
    /// The repositories written in the settings plus the ones the imported issues come from.
    private var names: [String] { model.names(imported: store.importedRepositories) }
    private var week: Date { AppState.shared.weekStart }

    var body: some View {
        VStack(spacing: 1) {
            title

            if names.isEmpty {
                Text("No repository yet — add one in the settings (⌘,) or import an issue from it")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            } else {
                days
            }
        }
        .padding(.top, 3)
        .padding(.bottom, 4)
        .background(Theme.paperElevated.opacity(0.22))
        .task(id: "\(week.timeIntervalSince1970)|\(names.joined(separator: ","))") {
            model.loadCache(for: week, names: names)
            guard !model.hasLoaded else { return }
            await model.refresh(names, week: week, useToken: false)
        }
    }

    // MARK: - Title

    private var title: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10, weight: .semibold))
                Text("GITHUB")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(0.5)
            }
            .foregroundStyle(Theme.inkFaint)
            .fixedSize()

            if !names.isEmpty {
                Text("commits per day")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)

                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            Spacer(minLength: 0)

            if !names.isEmpty {
                Button {
                    Task { await model.refresh(names, week: week, useToken: true) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 18, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Read again with the GitHub token — needed for private repositories, and macOS may then ask for the keychain password")
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - One cell per day, aligned with the day columns above

    private var days: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                dayCell(index)
            }
        }
    }

    private func dayCell(_ index: Int) -> some View {
        // The name of the repository and its count for that day: the user asked for exactly this on
        // 2026-10-04, with no repository names beside the GITHUB label any more. Up to three
        // repositories fit as one line each; beyond that only the day's total is shown and the
        // tooltip carries the detail.
        VStack(spacing: 1) {
            if model.repositories.count <= 3 {
                ForEach(model.repositories) { repository in
                    HStack(spacing: 3) {
                        Text(repository.shortName)
                            .foregroundStyle(Theme.inkSoft)
                        Text(RepoMetaModel.dayText(repository.days[index]))
                            .monospacedDigit()
                            .foregroundStyle((repository.days[index] ?? 0) > 0 ? Theme.ink : Theme.inkFaint)
                    }
                    .font(.system(size: 10))
                    .lineLimit(1)
                }
            } else {
                let count = total(index)
                Text(RepoMetaModel.dayText(count))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle((count ?? 0) > 0 ? Theme.ink : Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
        }
        .help(help(for: index))
    }

    /// What the day counts: every repository of that day, so the tooltip carries the detail.
    private func help(for index: Int) -> String {
        let weekday = DateText.weekdayTitle(WeekMath.date(dayOfWeek: index, inWeekFrom: week))
        let detail = model.repositories
            .map { "\($0.name) \(RepoMetaModel.dayText($0.days[index]))" }
            .joined(separator: " · ")
        return detail.isEmpty ? weekday : "\(weekday): \(detail)"
    }

    private func total(_ index: Int) -> Int? {
        let values = model.repositories.map { $0.days[index] }
        guard values.contains(where: { $0 != nil }) else { return nil }
        return values.compactMap { $0 }.reduce(0, +)
    }
}