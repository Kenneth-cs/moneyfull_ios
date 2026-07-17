import SwiftUI

struct ReminderSettingView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isEnabled: Bool
    @State private var hour: Int
    @State private var minute: Int
    @State private var selectedStyle: ReminderStyle
    @State private var isWeekendDND: Bool
    @State private var showTimePicker = false
    @State private var notificationAuthorized = false
    
    private let manager = NotificationManager.shared
    
    init() {
        _isEnabled = State(initialValue: NotificationManager.shared.isEnabled)
        _hour = State(initialValue: NotificationManager.shared.hour)
        _minute = State(initialValue: NotificationManager.shared.minute)
        _selectedStyle = State(initialValue: NotificationManager.shared.style)
        _isWeekendDND = State(initialValue: NotificationManager.shared.isWeekendDND)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    toggleSection
                    
                    if isEnabled {
                        timeSection
                        styleSection
                        weekendDNDSection
                    }
                    
                    budgetAlertSection
                    
                    tipSection
                }
                .padding(20)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("记账提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                checkNotificationAuthorization()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("🦫")
                .font(.system(size: 60))
            
            Text("养成记账好习惯")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
            
            Text("每天提醒你记一笔，月底复盘更清晰")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 20)
    }
    
    private var toggleSection: some View {
        HStack {
            Label("开启每日提醒", systemImage: "bell.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.App.textBlack)
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .tint(Color.App.primaryGreen)
                .onChange(of: isEnabled) { _, newValue in
                    manager.isEnabled = newValue
                    if newValue {
                        scheduleReminder()
                    } else {
                        manager.cancelReminder()
                    }
                }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("提醒时间", systemImage: "clock.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.App.textBlack)
            
            Button(action: { showTimePicker = true }) {
                HStack {
                    Text("🕘")
                    Text(String(format: "%02d:%02d", hour, minute))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                    
                    Spacer()
                    
                    Text("更改")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.App.primaryGreen)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.App.primaryGreen)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.App.primaryGreen.opacity(0.1))
                )
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(hour: $hour, minute: $minute, onSave: {
                manager.hour = hour
                manager.minute = minute
                scheduleReminder()
            })
        }
    }
    
    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("提醒文案风格", systemImage: "text.bubble.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.App.textBlack)
            
            ForEach(ReminderStyle.allCases, id: \.rawValue) { style in
                Button(action: {
                    selectedStyle = style
                    manager.style = style
                    scheduleReminder()
                }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(selectedStyle == style ? Color.App.primaryGreen : Color.gray.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                                    .opacity(selectedStyle == style ? 1 : 0)
                            )
                        
                        Text(style.rawValue)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.App.textBlack)
                        
                        Spacer()
                        
                        Text(style.messages.first ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedStyle == style ? Color.App.primaryGreen.opacity(0.05) : Color.clear)
                    )
                }
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var weekendDNDSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("休息日免打扰", systemImage: "moon.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.App.textBlack)
                
                Text("周末不发送提醒")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isWeekendDND)
                .tint(Color.App.primaryGreen)
                .onChange(of: isWeekendDND) { _, newValue in
                    manager.isWeekendDND = newValue
                    scheduleReminder()
                }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var budgetAlertSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("离开 App 后推送", systemImage: "bell.badge.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.App.textBlack)
                    
                    Text("记账触发预算预警时，离开 App 后推送通知")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { manager.isBudgetPushEnabled },
                    set: { manager.isBudgetPushEnabled = $0 }
                ))
                .tint(Color.App.primaryGreen)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("多天未开 App 提醒", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.App.textBlack)
                    
                    Text("多天未记账时，推送预算提醒")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { manager.isBudgetPassiveEnabled },
                    set: { manager.isBudgetPassiveEnabled = $0 }
                ))
                .tint(Color.App.primaryGreen)
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var tipSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Text("关闭后不会再收到提醒")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .padding(.top, 8)
    }
    
    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func scheduleReminder() {
        Task {
            if !notificationAuthorized {
                let granted = await manager.requestPermission()
                if !granted {
                    return
                }
            }
            manager.scheduleReminder()
        }
    }
}

struct TimePickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var hour: Int
    @Binding var minute: Int
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "选择时间",
                    selection: Binding(
                        get: {
                            var components = DateComponents()
                            components.hour = hour
                            components.minute = minute
                            return Calendar.current.date(from: components) ?? Date()
                        },
                        set: { date in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                            hour = components.hour ?? 21
                            minute = components.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle("选择提醒时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ReminderSettingView()
}
