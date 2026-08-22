import SwiftUI

/// Advanced Settings → Custom AI Gateway (PRODUCT_SPEC §64).
struct CustomGatewaySettingsView: View {
    @State private var endpointText = CustomGatewayStore.endpointURL()?.absoluteString ?? ""
    @State private var tokenText = ""
    @State private var useForScans = CustomGatewayStore.isEnabled()
    @State private var hasSavedToken = CustomGatewayStore.hasToken()
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section {
                Text("Connect an HTTPS endpoint you control that implements Project Plate’s meal-analysis contract. Your upstream AI provider credentials stay on your server — never paste an OpenAI (or other) API key into this app.")
                    .font(Typography.supporting)
                    .foregroundStyle(Color.textSecondary)
            }

            Section("Endpoint") {
                TextField("https://gateway.example.com", text: $endpointText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField(hasSavedToken ? "Token saved — enter to replace" : "Gateway bearer token", text: $tokenText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("Use for meal scans", isOn: $useForScans)
            }

            Section {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isWorking)

                Button("Test connection") {
                    Task { await test() }
                }
                .disabled(isWorking)

                Button("Disconnect", role: .destructive) {
                    disconnect()
                }
                .disabled(isWorking)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Color.statusError)
                }
            }
            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .navigationTitle("Custom gateway")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        defer { isWorking = false }

        switch CustomGatewayStore.validatedURL(from: endpointText, allowHTTPInDebug: true) {
        case .failure(let error):
            errorMessage = error.localizedDescription
            return
        case .success(let url):
            CustomGatewayStore.setEndpointURLString(url.absoluteString)
        }

        if !tokenText.isEmpty {
            do {
                try CustomGatewayStore.saveToken(tokenText)
                tokenText = ""
                hasSavedToken = true
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        CustomGatewayStore.setEnabled(useForScans)
        statusMessage = useForScans
            ? "Saved. Meal scans will use your gateway when cloud AI consent is accepted."
            : "Saved. Toggle “Use for meal scans” when you’re ready."
    }

    private func test() async {
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        defer { isWorking = false }

        let url: URL
        switch CustomGatewayStore.validatedURL(from: endpointText, allowHTTPInDebug: true) {
        case .failure(let error):
            errorMessage = error.localizedDescription
            return
        case .success(let validated):
            url = validated
        }

        let token = tokenText.isEmpty ? CustomGatewayStore.loadToken() : tokenText
        do {
            try await ManagedCloudVisionProvider.testConnection(baseURL: url, token: token)
            statusMessage = "Gateway reachable."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disconnect() {
        CustomGatewayStore.disconnect()
        endpointText = ""
        tokenText = ""
        useForScans = false
        hasSavedToken = false
        statusMessage = "Custom gateway disconnected. Scans fall back to the managed backend or on-device mock."
        errorMessage = nil
    }
}

#if !LEGACY_BUILD
#Preview {
    NavigationStack {
        CustomGatewaySettingsView()
            .environment(\.appEnvironment, .preview)
    }
#endif
}
