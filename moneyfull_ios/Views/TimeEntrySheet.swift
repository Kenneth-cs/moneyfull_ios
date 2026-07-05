import SwiftUI

/// 记工时 Sheet：支持同时输入小时和天数
struct TimeEntrySheet: View {
    @Environment(\.presentationMode) var presentationMode

    var defaultRate: Double = 100
    var onSave: (TimeEntryUI) -> Void = { _ in }

    @State private var hoursText: String = ""
    @State private var daysText: String = ""
    @State private var hourlyRateText: String = ""
    @State private var dailyRateText: String = ""
    @State private var note: String = ""
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker: Bool = false

    @FocusState private var hoursFocused: Bool
    @FocusState private var daysFocused: Bool

    private var hours: Double { Double(hoursText) ?? 0 }
    private var days: Double { Double(daysText) ?? 0 }
    private var hourlyRate: Double { Double(hourlyRateText) ?? defaultRate }
    private var dailyRate: Double { Double(dailyRateText) ?? defaultRate * 8 }
    private var totalCost: Double { hours * hourlyRate + days * dailyRate }
    private var isValid: Bool { (hours > 0 && hourlyRate > 0) || (days > 0 && dailyRate > 0) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: 输入区
                    VStack(spacing: 16) {
                        // 小时输入
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("工时").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                                Spacer()
                                Text("（选填一项或两项都填）")
                                    .font(.system(size: 11)).foregroundColor(.gray)
                            }
                            HStack {
                                TextField("0", text: $hoursText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(Color.App.textBlack)
                                    .focused($hoursFocused)
                                Text("小时")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding(16)
                            .background(Color.App.tabBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // 天数输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("工日").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            HStack {
                                TextField("0", text: $daysText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(Color.App.textBlack)
                                    .focused($daysFocused)
                                Text("天")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding(16)
                            .background(Color.App.tabBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // 费率
                        VStack(alignment: .leading, spacing: 8) {
                            Text("费率").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("¥/h 时薪").font(.system(size: 11)).foregroundColor(.gray)
                                    HStack {
                                        Text("¥").font(.system(size: 14, weight: .bold)).foregroundColor(Color.App.darkGreen)
                                        TextField("0", text: $hourlyRateText).keyboardType(.decimalPad)
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.App.tabBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("¥/天 日薪").font(.system(size: 11)).foregroundColor(.gray)
                                    HStack {
                                        Text("¥").font(.system(size: 14, weight: .bold)).foregroundColor(Color.App.darkGreen)
                                        TextField("0", text: $dailyRateText).keyboardType(.decimalPad)
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.App.tabBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // 任务描述
                        VStack(alignment: .leading, spacing: 8) {
                            Text("任务描述（选填）").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            TextField("完成原型图第二版...", text: $note)
                                .font(.system(size: 15))
                                .padding(16)
                                .background(Color.App.tabBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // 日期
                        VStack(alignment: .leading, spacing: 8) {
                            Text("日期").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            Button {
                                hoursFocused = false
                                daysFocused = false
                                withAnimation { showDatePicker.toggle() }
                            } label: {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(Color.App.darkGreen)
                                    Text(selectedDate, style: .date)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color.App.textBlack)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                                }
                                .padding(16)
                                .background(Color.App.tabBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            if showDatePicker {
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .tint(Color.App.darkGreen)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // MARK: 成本预览
                    if totalCost > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("时间成本预览")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.gray)
                                Text("¥\(totalCost.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(Color.App.darkGreen)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                if hours > 0 {
                                    Text("\(hoursText)小时 × ¥\(Int(hourlyRate))/h")
                                        .font(.system(size: 13)).foregroundColor(.gray)
                                }
                                if days > 0 {
                                    Text("\(daysText)天 × ¥\(Int(dailyRate))/天")
                                        .font(.system(size: 13)).foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.App.primaryGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24)
                    }

                    // MARK: 保存按钮
                    Button {
                        if hours > 0 {
                            let entry = TimeEntryUI(
                                duration: hours,
                                granularity: "hour",
                                rate: hourlyRate,
                                note: note,
                                date: selectedDate
                            )
                            onSave(entry)
                        }
                        if days > 0 {
                            let entry = TimeEntryUI(
                                duration: days,
                                granularity: "day",
                                rate: dailyRate,
                                note: note,
                                date: selectedDate
                            )
                            onSave(entry)
                        }
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? Color.App.darkGreen : Color.gray.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!isValid)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("记工时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                hourlyRateText = "\(Int(defaultRate))"
                dailyRateText = "\(Int(defaultRate * 8))"
            }
        }
    }
}
