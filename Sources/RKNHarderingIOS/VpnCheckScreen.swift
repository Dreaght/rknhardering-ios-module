import SwiftUI

public struct VpnCheckScreen: View {
    @StateObject private var viewModel = VpnCheckViewModel()
    private let homeCountryCode: String

    public init(homeCountryCode: String = "RU") {
        self.homeCountryCode = homeCountryCode
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    runButton

                    if viewModel.isRunning {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }

                    if let result = viewModel.result {
                        categoryCard(title: "GeoIP", result: result.geoIP)
                        categoryCard(title: "Прямые признаки", result: result.directSigns)
                        categoryCard(title: "Косвенные признаки", result: result.indirectSigns)
                        verdictCard(verdict: result.verdict)
                    }
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("RKN Hardering")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text("Самопроверка на обнаружение VPN/Proxy")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var runButton: some View {
        Button {
            viewModel.runCheck(homeCountryCode: homeCountryCode)
        } label: {
            Text("Запустить проверку")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isRunning)
    }

    private func categoryCard(title: String, result: CategoryResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconName(detected: result.detected, needsReview: result.needsReview))
                    .foregroundStyle(statusColor(detected: result.detected, needsReview: result.needsReview))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(statusText(detected: result.detected, needsReview: result.needsReview))
                    .font(.subheadline)
                    .foregroundStyle(statusColor(detected: result.detected, needsReview: result.needsReview))
            }

            ForEach(Array(result.findings.enumerated()), id: \.offset) { _, finding in
                findingRow(finding)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.sRGB, white: 0.18, opacity: 1.0))
        )
    }

    private func findingRow(_ finding: Finding) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(finding.detected ? "⚠" : (finding.needsReview ? "?" : "✓"))
                .font(.body.weight(.bold))
                .foregroundStyle(findingColor(finding))
            Text(finding.description)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }

    private func verdictCard(verdict: Verdict) -> some View {
        let style = verdictStyle(verdict)

        return VStack(spacing: 8) {
            Image(systemName: style.icon)
                .font(.system(size: 36, weight: .bold))
            Text(style.title)
                .font(.title3.weight(.bold))
        }
        .foregroundStyle(style.foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(style.background)
        )
    }

    private func statusText(detected: Bool, needsReview: Bool) -> String {
        if detected { return "Обнаружено" }
        if needsReview { return "Требует проверки" }
        return "Чисто"
    }

    private func iconName(detected: Bool, needsReview: Bool) -> String {
        if detected { return "exclamationmark.triangle.fill" }
        if needsReview { return "questionmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    private func statusColor(detected: Bool, needsReview: Bool) -> Color {
        if detected { return .red }
        if needsReview { return .orange }
        return .green
    }

    private func findingColor(_ finding: Finding) -> Color {
        if finding.detected { return .red }
        if finding.needsReview { return .orange }
        return .green
    }

    private func verdictStyle(_ verdict: Verdict) -> (title: String, icon: String, foreground: Color, background: Color) {
        switch verdict {
        case .detected:
            return ("Обход выявлен", "xmark.octagon.fill", .red, .red.opacity(0.12))
        case .needsReview:
            return ("Требуется дополнительная проверка", "questionmark.circle.fill", .orange, .orange.opacity(0.12))
        case .notDetected:
            return ("Обход не выявлен", "checkmark.circle.fill", .green, .green.opacity(0.12))
        }
    }
}

#Preview {
    VpnCheckScreen()
}
