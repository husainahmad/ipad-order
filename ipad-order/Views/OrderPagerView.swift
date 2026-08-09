import SwiftUI

struct OrderPagerView: View {
    @EnvironmentObject var formVM: OrderFormViewModel
    @EnvironmentObject var ordersVM: OrdersViewModel

    var body: some View {
        VStack(spacing: 0) {
            tabHeader
            TabView(selection: pageBinding) {
                OrdersView()
                    .tag(0)
                ForEach(formVM.tabs) { tab in
                    OrderFormView(tab: tab)
                        .tag(tab.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: formVM.selectedPage) { newValue in
                if newValue == 0 {
                    Task { await ordersVM.loadOrders() }
                }
            }
        }
        .alert(isPresented: $showRemoveConfirm) {
            Alert(title: Text("Close order"),
                  message: Text("Close this order? This will remove the order."),
                  primaryButton: .destructive(Text("Close")) {
                    if let id = confirmRemoveOrderId {
                        _ = formVM.removeTab(id)
                    }
                  },
                  secondaryButton: .cancel(Text("Cancel")))
        }
    }

    private var pageBinding: Binding<Int> {
        Binding(get: { formVM.selectedPage },
                set: { formVM.handlePageSelection($0) })
    }

    private var tabHeader: some View {
        ZStack {
            Color.posSurfaceContainer
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    tabChip(title: "Orders",
                            icon: "list.bullet.rectangle",
                            isSelected: formVM.selectedPage == 0) {
                        formVM.handlePageSelection(0)
                    }

                    ForEach(formVM.tabs) { tab in
                        tabChip(title: tab.label,
                                icon: "note.text",
                                isSelected: formVM.selectedPage == tab.id,
                                isCloseable: true) {
                            formVM.handlePageSelection(tab.id)
                        } onClose: {
                            confirmAndRemove(tab.id)
                        }
                    }

                    tabChip(title: "NEW ORDER",
                            icon: "plus",
                            isSelected: false,
                            highlighted: true) {
                        _ = formVM.createNewTab()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(height: 60)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func tabChip(title: String,
                         icon: String,
                         isSelected: Bool,
                         isCloseable: Bool = false,
                         highlighted: Bool = false,
                         action: @escaping () -> Void,
                         onClose: (() -> Void)? = nil) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(highlighted ? .white : (isSelected ? .white : .posTextSecondary))

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(highlighted ? .white : (isSelected ? .white : .posTextPrimary))

                if isCloseable {
                    Button(action: { onClose?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isSelected ? .white : .posGrayButton)
                            .frame(width: 26, height: 26)
                            .background(isSelected ? Color.white.opacity(0.2) : Color.posSurfaceContainerHigh)
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, isCloseable ? 8 : 14)
            .frame(height: 40)
            .background(highlighted
                        ? AnyShapeStyle(Color.posAccentGradient)
                        : (isSelected ? AnyShapeStyle(Color.posPrimaryGradient) : AnyShapeStyle(Color.posSurfaceContainerHigh)))
            .overlay(
                RoundedRectangle(cornerRadius: PosShape.cornerMedium)
                    .stroke(highlighted ? Color.clear : (isSelected ? Color.clear : Color.posOutlineVariant), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
            .shadow(color: (isSelected || highlighted) ? Color.black.opacity(0.2) : Color.clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func confirmAndRemove(_ id: Int) {
        confirmRemoveOrderId = id
        showRemoveConfirm = true
    }

    @State private var showRemoveConfirm = false
    @State private var confirmRemoveOrderId: Int?
}

#Preview {
    OrderPagerView()
        .environmentObject(OrderFormViewModel())
        .environmentObject(OrdersViewModel())
}
