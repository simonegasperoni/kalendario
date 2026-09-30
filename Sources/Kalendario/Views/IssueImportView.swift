import SwiftUI

struct IssueImportView: View {
    @Bindable var model: IssueImportModel
    /// In a static preview the sheet is not sized, so the whole body can be rendered at once.
    @Environment(\.kalendarioPreview) private var preview

    private let app = AppState.shared
    private let hours = Array(6...22)
    private let steps = [10, 15, 30, 60]
    private let durations = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Separator()

            VerticalFlow {
                VStack(alignment: .leading, spacing: 16) {
                    repositoryField
                    tokenField
                    filtersField

                    if !model.status.isEmpty {
                        statusLine
                    }

                    issuesField
                    placementField
                }
                .padding(20)
            }

            Separator()
            footer
        }
        .frame(width: preview ? nil : 640, height: preview ? nil : 720)
        .background(Theme.paper)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Import GitHub issues")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("Pick issues from a repository and place them on your week.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            IconButton(symbol: "xmark", help: "Close") { app.closeIssueImport() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.paperElevated.opacity(0.6))
    }

    // MARK: - Repository

    private var repositoryField: some View {
        FieldBox(title: "Repository") {
            HStack(spacing: 8) {
                TextField("owner/name or a GitHub URL", text: $model.repository)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                    .fieldChrome()

                Button {
                    app.loadIssues()
                } label: {
                    Label(model.isLoading ? "Loading…" : "Load issues", systemImage: "arrow.down.circle")
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .disabled(model.isLoading)
            }
        }
    }

    // MARK: - Token

    private var tokenField: some View {
        FieldBox(title: "Access token") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    SecureField("ghp_… (optional)", text: $model.tokenInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .fieldChrome()

                    Button("Save") { model.saveToken() }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                        .disabled(model.tokenInput.isEmpty)

                    if model.hasStoredToken {
                        Button("Remove") { model.clearToken() }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                }

                HStack(spacing: 5) {
                    Image(systemName: model.hasStoredToken ? "checkmark.seal.fill" : "info.circle")
                        .font(.system(size: 10))
                    Text(model.hasStoredToken
                         ? "A token is stored in the macOS Keychain. It is never written to your calendar file."
                         : "Without a token only public repositories work, with a 60 requests/hour limit.")
                        .font(Theme.tinyFont)
                }
                .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    // MARK: - Filters

    private var filtersField: some View {
        FieldBox(title: "Filters") {
            HStack(spacing: 14) {
                Toggle(isOn: $model.includeClosed) {
                    Text("Include closed").font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.accent)

                TextField("labels (comma separated)", text: $model.labelsFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink)
                    .fieldChrome()

                HStack(spacing: 6) {
                    Text("Max").font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                    Stepper(value: $model.limit, in: 5...100, step: 5) {
                        Text("\(model.limit)")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                    }
                    .fixedSize()
                }
            }
        }
    }

    private var statusLine: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: model.issues.isEmpty ? "info.circle" : "checkmark.circle")
                .font(.system(size: 11, weight: .semibold))
            Text(model.status)
                .font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.inkSoft)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Issues

    private var issuesField: some View {
        FieldBox(title: "Issues (\(model.selected.count) of \(model.issues.count) selected)") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button("Select all") { model.selectAll() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .disabled(model.issues.isEmpty)

                    Button("Select none") { model.selectNone() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .disabled(model.selected.isEmpty)

                    Spacer()

                    if model.isLoading || model.isRefreshing {
                        ProgressView().controlSize(.small)
                    }
                }

                if model.issues.isEmpty {
                    Text(model.loadedRepository == nil
                         ? "Load a repository to see its issues."
                         : "Nothing to show for these filters.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.issues) { issue in
                            issueRow(issue)
                            Separator()
                        }
                    }
                    .background(Theme.paperElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func issueRow(_ issue: GitHubIssue) -> some View {
        let isSelected = model.selected.contains(issue.number)
        return Button {
            model.toggle(issue.number)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12.5))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inkFaint)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(issue.reference)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.inkFaint)
                        Text(issue.title)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 5) {
                        chip(issue.isClosed ? "closed" : "open",
                             tint: issue.isClosed ? Theme.inkFaint : Theme.accent)
                        if let due = issue.milestoneDue {
                            chip("due \(DateText.monthDayShort.string(from: due))", tint: Theme.accentStrong)
                        }
                        ForEach(issue.labels.prefix(4), id: \.self) { label in
                            chip(label, tint: Theme.inkSoft)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Placement

    private var placementField: some View {
        FieldBox(title: "Place them") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(WeekMath.daysInWeek(from: app.weekStart), id: \.self) { day in
                        let selected = WeekMath.isSameDay(day, model.day)
                        Button {
                            model.day = day
                        } label: {
                            VStack(spacing: 1) {
                                Text(DateText.weekdayTitle(day)).font(.system(size: 9, weight: .semibold))
                                Text(DateText.dayNumber.string(from: day))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .foregroundStyle(selected ? Color.white : Theme.ink)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? Theme.accent : Theme.ink.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    picker("Start", selection: $model.hour) {
                        ForEach(hours, id: \.self) { hour in
                            Text("\(WeekMath.hourLabel(hour)):00").tag(hour)
                        }
                    }

                    picker("Every", selection: $model.stepMinutes) {
                        ForEach(steps, id: \.self) { step in
                            Text("\(step) min").tag(step)
                        }
                    }

                    picker("Lasting", selection: $model.durationMinutes) {
                        ForEach(durations, id: \.self) { duration in
                            Text(WeekMath.durationLabel(duration)).tag(duration)
                        }
                    }

                    picker("Category", selection: $model.category) {
                        ForEach(EventCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                }

                Text("Issues with a milestone due date land on that date; the others stack on the chosen day, one every \(model.stepMinutes) minutes.")
                    .font(Theme.tinyFont)
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func picker<Value: Hashable, Content: View>(
        _ title: String,
        selection: Binding<Value>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Picker("", selection: selection) { content() }
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if app.store.importedIssueCount > 0 {
                Button {
                    app.refreshImportedIssues()
                } label: {
                    Label(model.isRefreshing ? "Updating…" : "Update imported (\(app.store.importedIssueCount))",
                          systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .disabled(model.isRefreshing)
            }

            Spacer()

            Button("Done") { app.closeIssueImport() }
                .buttonStyle(PillButtonStyle(kind: .secondary))

            Button {
                app.importSelectedIssues()
            } label: {
                Text(model.selected.isEmpty
                     ? "Place on the calendar"
                     : "Place \(model.selected.count) on the calendar")
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
            .disabled(model.selected.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.paperElevated.opacity(0.4))
    }
}