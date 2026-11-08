import Charts
import SwiftUI

struct NativeStatisticsView: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var range = 7
    private var daily: [(date: Date, attempts: Int, correct: Int)] { model.store.dailyStats(days: range) }

    var body: some View {
        NativePage(eyebrow: "LEARNING RECORD", title: "学习统计", subtitle: "统计来自本机 SQLite 学习记录。", accent: .green) { layout in
            VStack(alignment: .leading, spacing: 21) {
                NativeMetricGrid {
                    NativeMetric(label: "已学习词条", value: model.store.studiedWordCount.formatted(), detail: "词条 ID 去重")
                    NativeMetric(label: "稳定掌握", value: model.store.masteredWordCount.formatted(), detail: "熟练度 4 / 5 以上")
                    NativeMetric(label: "复习作答", value: model.store.totalAttempts.formatted(), detail: "首次与重练均计入")
                    NativeMetric(label: "累计正确率", value: model.store.totalAttempts == 0 ? "—" : "\(Int(Double(model.store.totalCorrect) / Double(model.store.totalAttempts) * 100))%", detail: "跨全部词条累计")
                }
                Divider()
                if layout.isCompact {
                    VStack(alignment: .leading, spacing: 8) {
                        NativeSectionHeading(title: "每日作答", trailing: "正确次数 / 总作答")
                        rangePicker
                    }
                } else {
                    HStack {
                    NativeSectionHeading(title: "每日作答", trailing: "正确次数 / 总作答")
                        rangePicker.frame(width: 150)
                    }
                }
                if daily.contains(where: { $0.attempts > 0 }) {
                    Chart {
                        ForEach(daily.indices, id: \.self) { index in
                            let item = daily[index]
                            BarMark(x: .value("日期", item.date, unit: .day), y: .value("总作答", item.attempts))
                                .foregroundStyle(Color.teal.opacity(0.3))
                                .position(by: .value("系列", "总作答"))
                            BarMark(x: .value("日期", item.date, unit: .day), y: .value("正确", item.correct))
                                .foregroundStyle(Color.green.opacity(0.82))
                                .position(by: .value("系列", "正确"))
                        }
                    }
                    .chartLegend(.hidden)
                    .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 4)) { value in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                    .frame(height: layout.isShort ? 170 : 220)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: range)
                } else {
                    ContentUnavailableView("还没有练习记录", systemImage: "chart.bar", description: Text("完成一轮每日训练后，这里会显示你的练习节奏。"))
                        .frame(height: layout.isShort ? 170 : 220)
                }
                Divider()
                NativeSectionHeading(title: "词汇熟练度")
                let unlearned = max(0, model.store.words.count - model.store.studiedWordCount)
                let levels = (0...5).map { level in model.store.progress.values.filter { $0.level == level }.count }
                VStack(spacing: 10) {
                    GeometryReader { geometry in
                    HStack(spacing: 0) {
                        if unlearned > 0 { Rectangle().fill(Color.secondary.opacity(0.22)).frame(width: CGFloat(unlearned) / CGFloat(max(model.store.words.count, 1)) * geometry.size.width) }
                        ForEach(0...5, id: \.self) { level in
                            Rectangle().fill(level >= 4 ? Color.green.opacity(0.82) : Color.teal.opacity(0.15 + Double(level) * 0.09))
                                .frame(width: CGFloat(levels[level]) / CGFloat(max(model.store.words.count, 1)) * geometry.size.width)
                        }
                    }.frame(height: 10).clipShape(Capsule())
                    }
                    .frame(height: 10)
                    HStack {
                        Text("未学习  \(unlearned.formatted())")
                        Spacer()
                        Text("学习中  ·  \(levels[0...3].reduce(0, +).formatted())")
                        Spacer()
                        Text("稳定掌握  \(model.store.masteredWordCount.formatted())")
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Divider()
                NativeSectionHeading(title: "口语与写作", trailing: "表达练习保存在本机")
                NativeMetricGrid {
                    NativeMetric(label: "口语录音", value: model.store.expressionRecords.filter { $0.kind == "speaking" }.count.formatted(), detail: "包含本机音频路径与自评")
                    NativeMetric(label: "写作草稿", value: model.store.writingDrafts.count.formatted(), detail: "Task 1 与 Task 2")
                }
            }
        }
    }

    private var rangePicker: some View {
        Picker("时间范围", selection: $range) { Text("近 7 天").tag(7); Text("近 28 天").tag(28) }
            .pickerStyle(.segmented)
    }
}
