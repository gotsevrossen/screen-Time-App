import FamilyControls
import SwiftUI

struct DowntimeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: DowntimeSchedule?
    @State private var pendingEdit: DowntimeSchedule?
    @State private var askPIN = false

    var body: some View {
        BloomPage(title: "Downtime", subtitle: "Quiet hours. The apps you pick stay closed between the times you set.") {
            AddButton(label: "Add downtime") { editing = DowntimeSchedule(name: "") }
        } content: {
            if model.data.downtimes.isEmpty {
                BloomCard(style: .cream, showsArrow: true) {
                    Text("No downtime yet").font(.bloomHeading(22))
                    Text("Try a bedtime window, like 10:30 PM to 7:00 AM, so your evenings wind down on their own.")
                        .font(.bloomBody(.subheadline))
                    Button("Add downtime") { editing = DowntimeSchedule(name: "Bedtime") }
                        .buttonStyle(.bloomDark)
                }
            }

            ForEach(model.data.downtimes) { downtime in
                Button {
                    pendingEdit = downtime
                    askPIN = true
                } label: {
                    DowntimeCard(downtime: downtime)
                }
                .buttonStyle(.plain)
            }
        }
        .pinProtected(isPresented: $askPIN, message: "Enter your PIN to change this downtime.") {
            editing = pendingEdit
        }
        .sheet(item: $editing) { downtime in
            DowntimeEditorView(downtime: downtime, isNew: !model.data.downtimes.contains { $0.id == downtime.id })
        }
    }
}

private struct DowntimeCard: View {
    let downtime: DowntimeSchedule

    var body: some View {
        let active = downtime.isActive(at: Date())
        BloomCard(style: active ? .lavender : .surface) {
            HStack(alignment: .firstTextBaseline) {
                Text(downtime.name).font(.bloomHeading(22)).lineLimit(1)
                Spacer()
                if !downtime.isEnabled {
                    StatusPill(text: "Paused", style: .surface)
                } else if active {
                    StatusPill(text: "On now", style: .surface)
                }
            }
            Text("\(downtime.start.formatted) to \(downtime.end.formatted)")
                .font(.bloomDisplay(26, relativeTo: .title2))
            Text(downtime.weekdaySummary)
                .font(.bloomBody(.subheadline))
                .opacity(0.75)
            SelectionIcons(selection: downtime.selection)
        }
        .opacity(downtime.isEnabled ? 1 : 0.6)
    }
}

struct DowntimeEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var downtime: DowntimeSchedule
    let isNew: Bool
    @State private var showPicker = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel(text: "Name")
                    BloomTextField(placeholder: "Bedtime, Focus, Dinner...", text: $downtime.name)

                    SectionLabel(text: "Apps, categories & sites")
                    Button { showPicker = true } label: {
                        HStack {
                            if downtime.selection.isEmpty {
                                Text("Choose what to block").font(.bloomBody())
                            } else {
                                SelectionIcons(selection: downtime.selection)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Color.bloomInkSecondary)
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 56)
                        .foregroundStyle(Color.bloomInk)
                        .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: BloomRadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    SectionLabel(text: "When")
                    BloomCard {
                        DatePicker("Starts", selection: timeBinding(\.start), displayedComponents: .hourAndMinute)
                        Rectangle().fill(Color.bloomHairline).frame(height: 1)
                        DatePicker("Ends", selection: timeBinding(\.end), displayedComponents: .hourAndMinute)
                        if downtime.crossesMidnight {
                            Text("Ends the next morning.")
                                .font(.bloomBody(.caption))
                                .foregroundStyle(Color.bloomInkSecondary)
                        }
                    }
                    .font(.bloomBody())

                    SectionLabel(text: "Repeat on")
                    HStack(spacing: 6) {
                        ForEach(orderedWeekdays, id: \.self) { day in
                            BloomChip(title: Calendar.current.veryShortWeekdaySymbols[day - 1],
                                      isSelected: downtime.weekdays.contains(day)) {
                                if downtime.weekdays.contains(day) {
                                    downtime.weekdays.remove(day)
                                } else {
                                    downtime.weekdays.insert(day)
                                }
                            }
                            .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                        }
                    }

                    if !isNew {
                        Toggle("Downtime is on", isOn: $downtime.isEnabled)
                            .font(.bloomBody())
                            .padding(.top, 8)
                    }

                    Button(isNew ? "Add downtime" : "Save changes") {
                        model.save(downtime)
                        dismiss()
                    }
                    .buttonStyle(.bloomPrimary)
                    .disabled(downtime.name.trimmingCharacters(in: .whitespaces).isEmpty
                              || downtime.selection.isEmpty
                              || downtime.weekdays.isEmpty
                              || downtime.start == downtime.end)
                    .padding(.top, 12)

                    if !isNew {
                        Button("Delete downtime", role: .destructive) { confirmDelete = true }
                            .buttonStyle(.bloomSecondary)
                    }
                }
                .padding(20)
            }
            .background(Color.bloomCanvas.ignoresSafeArea())
            .navigationTitle(isNew ? "New downtime" : "Edit downtime")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $downtime.selection)
            .confirmationDialog("Delete \(downtime.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.deleteDowntime(downtime)
                    dismiss()
                }
            }
        }
    }

    /// Weekdays in the order the user's locale starts the week.
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<DowntimeSchedule, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: { downtime[keyPath: keyPath].date },
            set: { downtime[keyPath: keyPath] = TimeOfDay(date: $0) })
    }
}
