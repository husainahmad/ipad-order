import SwiftUI

struct DailyReportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = DailyReportViewModel()

    @State private var startDate = TimeUtils.todayDate()
    @State private var endDate = TimeUtils.todayDate()
    @State private var startDateValue = Date()
    @State private var endDateValue = Date()

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            dateBar
            columnHeader
            reportBody
            totalFooter
            volumeSection
            if let error = viewModel.error, !error.isEmpty {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.posStatusVoid)
                    .padding(8)
            }
        }
        .background(Color.posBgLight)
        .task {
            await viewModel.load(startDate: startDate, endDate: endDate)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                Text("Daily Report")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.posPrimaryGradient)
    }

    private var dateBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(.posPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("START")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.posTextSecondary)
                    DatePicker("", selection: $startDateValue, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(.posPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("END")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.posTextSecondary)
                    DatePicker("", selection: $endDateValue, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                startDate = formatter.string(from: startDateValue)
                endDate = formatter.string(from: endDateValue)
                Task { await viewModel.load(startDate: startDate, endDate: endDate) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Load Report")
                }
                .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(PosButtonStyle(filled: true))
            .frame(width: 180)
            Spacer()
        }
        .padding(14)
        .background(Color.posBgLight)
        .onChange(of: startDateValue) { newValue in
            startDate = formatter.string(from: newValue)
        }
        .onChange(of: endDateValue) { newValue in
            endDate = formatter.string(from: newValue)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            colHeader("Date", 110)
            colHeader("Product", 220)
            colHeader("QTY", 60)
            colHeader("Net Sales", 130)
            colHeader("Discount", 110)
            Spacer()
        }
        .padding(.horizontal, 4)
        .frame(height: 40)
        .background(Color.posSurfaceContainer)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
    }

    private func colHeader(_ title: String, _ width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.posTextPrimary)
            .frame(width: width, alignment: .leading)
    }

    private var reportBody: some View {
        Group {
            if viewModel.loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                            DailyReportRowView(row: row, isEven: index % 2 == 0)
                        }
                    }
                }
            }
        }
    }

    private var totalFooter: some View {
        let totals = viewModel.totals
        return HStack(spacing: 20) {
            Text("TOTAL")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.posAccent)
                .clipShape(Capsule())
            Text("QTY: \(totals.qty)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.posTextPrimary)
            Text("Net: \(CurrencyUtils.formatRp(totals.net))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.posPrimary)
            Text("Discount: \(CurrencyUtils.formatRp(totals.discount))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.posStatusVoid)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -2)
    }

    private var volumeSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("Order Volume")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.posAccentGradient)

            if let volume = viewModel.volume {
                HStack(spacing: 24) {
                    volumeBadge(title: "Total Orders", value: "\(volume.totalOrdersValue)", color: .posPrimary)
                    volumeBadge(title: "Peak Time", value: "\(volume.peakTimeOrdersValue)", color: .posSecondary)
                    volumeBadge(title: "Non Peak Time", value: "\(volume.nonPeakTimeOrdersValue)", color: .posBlueAction)
                    Spacer()
                }
                .padding(14)
                .background(Color.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private func volumeBadge(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.posTextSecondary)
            }
        }
    }
}

private struct DailyReportRowView: View {
    let row: DailyReportViewModel.Row
    let isEven: Bool

    var body: some View {
        HStack(spacing: 0) {
            cell(row.date, width: 110)
            cell(row.productName, width: 220)
            cell("\(row.quantity)", width: 60)
            cell(CurrencyUtils.formatRp(row.netSales), width: 130)
            cell(CurrencyUtils.formatRp(row.discount), width: 110)
            Spacer()
        }
        .font(.system(size: 13))
        .foregroundColor(.posTextPrimary)
        .padding(.horizontal, 4)
        .frame(height: 40)
        .background(isEven ? Color.white : Color.posRowOdd)
    }

    private func cell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
    }
}

#Preview {
    DailyReportView()
}
