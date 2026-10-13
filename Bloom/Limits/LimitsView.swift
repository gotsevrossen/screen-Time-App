import FamilyControls
import SwiftUI

struct LimitsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: AppLimit?
    @State private var pendingEdit: AppLimit?
    @State private var askPIN = false

    var body: some View {
        BloomPage(title: "Limits", subtitle: "A daily time budget for the apps you choose. When it's used up, they rest until midnight.") {
            AddButton(label: "Add limit") { editing = AppLimit(name: "") }
        } content: {
            if model.data.limits.isEmpty {
                BloomCard(style: .cream, showsArrow: true) {
                    Text("No limits yet").font(.bloomHeading(22))
                    Text("Start with the one app you open without thinking. Even 30 minutes a day makes a difference.")
                        .font(.bloomBody(.subheadline))
                    Button("Add your first limit") { editing = AppLimit(name: "") }
                        .buttonStyle(.bloomDark)
                }
            }

            ForEach(model.data.limits) { limit in
                Button {
                    // Changing an existing limit could loosen it, so it needs the PIN.
                    pendingEdit = limit
                    askPIN = true
                } label: {
                    LimitCard(limit: limit, reached: model.data.limitsReached[limit.storeKey] == Date().bloomDayKey)
                }
                .buttonStyle(.plain)
            }
        }
        .pinProtected(isPresented: $askPIN, message: "Enter your PIN to change this limit.") {
            editing = pendingEdit
        }
        .sheet(item: $editing) { limit in
            LimitEditorView(limit: limit, isNew: !model.data.limits.contains { $0.id == limit.id })
        }
    }
}

private struct LimitCard: View {
    let limit: AppLimit
    let reached: Bool

    var body: some View {
        BloomCard {
            HStack(alignment: .firstTextBaseline) {
                Text(limit.name).font(.bloomHeading(22)).lineLimit(1)
                Spacer()
                if !limit.isEnabled {
                    StatusPill(text: "Paused", style: .surface)
                } else if reached {
                    StatusPill(text: "Used up today")
                }
            }
            Text("\(DurationText.minutes(limit.minutesPerDay)) a day")
                .font(.bloomBody(.subheadline))
                .foregroundStyle(Color.bloomInkSecondary)
            SelectionIcons(selection: limit.selection)
        }
        .opacity(limit.isEnabled ? 1 : 0.6)
    }
}

struct LimitEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var limit: AppLimit
    let isNew: Bool
    @State private var showPicker = false
    @State private var confirmDelete = false

    private let presets = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel(text: "Name")
                    BloomTextField(placeholder: "Social, Games, Instagram...", text: $limit.name)

                    SectionLabel(text: "Apps, categories & sites")
                    Button { showPicker = true } label: {
                        HStack {
                            if limit.selection.isEmpty {
                                Text("Choose what to limit").font(.bloomBody())
                            } else {
                                SelectionIcons(selection: limit.selection)
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

                    SectionLabel(text: "Time each day")
                    Text(DurationText.minutes(limit.minutesPerDay))
                        .font(.bloomDisplay(44))
                        .foregroundStyle(Color.bloomInk)
                        .contentTransition(.numericText())
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(presets, id: \.self) { minutes in
                            BloomChip(title: DurationText.minutes(minutes), isSelected: limit.minutesPerDay == minutes) {
                                withAnimation { limit.minutesPerDay = minutes }
                            }
                        }
                    }
                    Stepper("Fine-tune by 5 minutes", value: $limit.minutesPerDay, in: 5...720, step: 5)
                        .font(.bloomBody(.subheadline))

                    if !isNew {
                        Toggle("Limit is on", isOn: $limit.isEnabled)
                            .font(.bloomBody())
                            .padding(.top, 8)
                    }

                    Button(isNew ? "Add limit" : "Save changes") {
                        model.save(limit)
                        dismiss()
                    }
                    .buttonStyle(.bloomPrimary)
                    .disabled(limit.name.trimmingCharacters(in: .whitespaces).isEmpty || limit.selection.isEmpty)
                    .padding(.top, 12)

                    if !isNew {
                        Button("Delete limit", role: .destructive) { confirmDelete = true }
                            .buttonStyle(.bloomSecondary)
                    }
                }
                .padding(20)
            }
            .background(Color.bloomCanvas.ignoresSafeArea())
            .navigationTitle(isNew ? "New limit" : "Edit limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $limit.selection)
            .confirmationDialog("Delete \(limit.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.deleteLimit(limit)
                    dismiss()
                }
            }
        }
    }
}
