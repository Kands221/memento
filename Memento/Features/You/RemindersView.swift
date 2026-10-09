import SwiftUI

/// One gentle daily nudge with a lock-screen preview (prototype L429–458).
struct RemindersView: View {
    @AppStorage(SettingsKey.reminderOn) private var reminderOn = false
    @AppStorage(SettingsKey.reminderMinutes) private var minutes = 1230
    @State private var denied = false

    private let presets = [(480, "8:00 AM"), (750, "12:30 PM"), (1230, "8:30 PM"), (1320, "10:00 PM")]

    var body: some View {
        Screen(spacing: 20, horizontalPadding: 16) {
            PageTitle("Daily reminder", size: 34).padding(.horizontal, 4)
            SettingsGroup {
                Toggle(isOn: $reminderOn) { Text("Remind me to write").font(.ui(17, weight: .medium)).foregroundStyle(Color.mInk) }
                    .toggleStyle(SageToggleStyle())
                    .padding(.horizontal, 16)
                    .frame(minHeight: 60)
                    .accessibilityIdentifier("reminders.toggle")
                if reminderOn {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .font(.ui(17)).foregroundStyle(Color.mInk)
                        FlowLayout(spacing: 8) {
                            ForEach(presets, id: \.0) { value, label in
                                FilterChip(label: label, isOn: minutes == value) { minutes = value }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("PREVIEW").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut).padding(.horizontal, 4)
                lockScreenPreview.opacity(reminderOn ? 1 : 0.35)
                Text(caption).font(.ui(13.5)).foregroundStyle(Color.mMut).padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("How streaks work").font(.serif(19, relativeTo: .headline)).foregroundStyle(Color.mInk)
                Text("Each day with a saved entry or saved Sol reflection counts. If a day slips by, a new streak simply begins — your entries stay exactly where they are.")
                    .font(.ui(14)).foregroundStyle(Color.mMut).lineSpacing(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.mLine, lineWidth: 1))
        }
        .onChange(of: reminderOn) { _, _ in reschedule() }
        .onChange(of: minutes) { _, _ in if reminderOn { reschedule() } }
    }

    private var caption: String {
        if denied { return "Notifications are off for Memento. Turn them on in Settings to get a gentle nudge." }
        return reminderOn
            ? "One gentle nudge at \(ReminderScheduler.label(minutes: minutes)) each day. No follow-ups, no “you missed a day.”"
            : "Reminders are off. Memento will stay quiet — write whenever you like."
    }

    private var timeBinding: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (c.hour ?? 20) * 60 + (c.minute ?? 30)
        }
    }

    private var lockScreenPreview: some View {
        ZStack(alignment: .top) {
            if UIImage(named: "reminder-scene") != nil {
                Color.clear.overlay { Image("reminder-scene").resizable().scaledToFill() }
            } else {
                LinearGradient(colors: [Color(hex: 0xCDBFA8), Color(hex: 0x9C8C74)], startPoint: .top, endPoint: .bottom)
            }
            VStack(spacing: 16) {
                Text(ReminderScheduler.label(minutes: minutes).replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: ""))
                    .font(.system(size: 52, weight: .light)).tracking(-1).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                HStack(alignment: .top, spacing: 12) {
                    Image("AppIconPreview").resizable().frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Memento").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("now").font(.system(size: 13)).foregroundStyle(Color(hex: 0x6F675D))
                        }
                        Text("A few lines tonight? Even one sentence counts.").font(.system(size: 14))
                    }
                }
                .foregroundStyle(Color(hex: 0x2B2723))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: 0xFFFCF6).opacity(0.82)))
            }
            .padding(.horizontal, 14)
            .padding(.top, 22)
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview: Memento notification, “A few lines tonight? Even one sentence counts.”")
    }

    private func reschedule() {
        Task {
            let ok = await ReminderScheduler.setEnabled(reminderOn, minutes: minutes)
            denied = !ok
            if !ok { reminderOn = false }
        }
    }
}
