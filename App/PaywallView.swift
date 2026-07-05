import SwiftUI

struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("SIMMER PRO")
                .font(Theme.font(20, weight: .bold))
                .kerning(4)
                .padding(.top, 32)

            VStack(alignment: .leading, spacing: 14) {
                feature("timer", "Run every burner at once — unlimited timers")
                feature("bolt.badge.clock", "All of them grouped in the Dynamic Island")
                feature("bookmark", "Save your go-to timers as presets")
                feature("arrow.clockwise", "Restart finished timers without rebuilding them")
                feature("heart", "Support an indie developer")
            }
            .padding(.vertical, 8)

            Text("PAY ONCE. YOURS FOREVER.\nNO SUBSCRIPTION. NO ACCOUNT.")
                .font(Theme.font(11, weight: .semibold))
                .foregroundStyle(Theme.faded)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await pro.purchase()
                    if pro.isPro { dismiss() }
                }
            } label: {
                Text("UNLOCK FOR \(pro.displayPrice)")
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink))
            }

            if let error = pro.purchaseError {
                Text(error)
                    .font(Theme.font(11))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Restore Purchase") {
                Task {
                    await pro.restore()
                    if pro.isPro { dismiss() }
                }
            }
            .font(Theme.font(12))
            .foregroundStyle(Theme.faded)

            Spacer()
        }
        .padding(24)
        .background(Theme.cream)
        .tint(Theme.ink)
        .presentationDetents([.medium, .large])
        // 启动时 currentEntitlements 可能还没就绪(TestFlight 更新后首启常见),
        // 弹 paywall 时重查一次,已购则直接放行,不让老用户再看到解锁页
        .task {
            await pro.refresh()
            if pro.isPro { dismiss() }
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24)
            Text(text).font(Theme.font(14))
        }
        .foregroundStyle(Theme.ink)
    }
}
