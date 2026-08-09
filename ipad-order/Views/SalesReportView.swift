import SwiftUI

struct SalesReportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SalesReportViewModel()

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
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                Text("Sales Report")
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
            colHeader("Category", 180)
            colHeader("Product", 220)
            colHeader("QTY", 60)
            colHeader("Gross Sales", 130)
            colHeader("Discount", 110)
            colHeader("Net Sales", 130)
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
                            SalesReportRowView(row: row, isEven: index % 2 == 0)
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
            Text("Gross: \(CurrencyUtils.formatRp(totals.gross))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.posTextPrimary)
            Text("Discount: \(CurrencyUtils.formatRp(totals.discount))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.posStatusVoid)
            Text("Net: \(CurrencyUtils.formatRp(totals.net))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.posPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -2)
    }
}

private struct SalesReportRowView: View {
    let row: SalesReportRow
    let isEven: Bool

    var body: some View {
        HStack(spacing: 0) {
            cell(row.categoryNameValue, width: 180)
            cell(row.productNameValue, width: 220)
            cell("\(row.quantityValue)", width: 60)
            cell(CurrencyUtils.formatRp(row.grossSalesValue), width: 130)
            cell(CurrencyUtils.formatRp(row.discountValue), width: 110)
            cell(CurrencyUtils.formatRp(row.netSalesValue), width: 130)
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
    SalesReportView()
}
