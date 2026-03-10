import SwiftUI

struct APIKeySettingsView: View {
    @State private var apiKey = ""
    @State private var hasKey = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let keychainService = KeychainService()

    var body: some View {
        Form {
            Section {
                if hasKey {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("API Key Configured")
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("No API Key")
                    }
                }
            }

            Section {
                SecureField("Enter API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()

                Button("Save Key") {
                    saveKey()
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                if hasKey {
                    Button("Remove Key", role: .destructive) {
                        removeKey()
                    }
                }
            } header: {
                Text("Claude API Key")
            } footer: {
                Text("Your API key is stored securely in the iOS Keychain. It is never sent anywhere except to the Anthropic API.")
            }
        }
        .navigationTitle("API Key")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkForKey()
        }
        .alert("API Key", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func checkForKey() {
        hasKey = (try? keychainService.retrieve(key: Constants.Keychain.claudeAPIKey)) != nil
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            try keychainService.save(key: Constants.Keychain.claudeAPIKey, value: trimmed)
            hasKey = true
            apiKey = ""
            alertMessage = "API key saved successfully."
            showAlert = true
        } catch {
            alertMessage = "Failed to save API key: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func removeKey() {
        do {
            try keychainService.delete(key: Constants.Keychain.claudeAPIKey)
            hasKey = false
            alertMessage = "API key removed."
            showAlert = true
        } catch {
            alertMessage = "Failed to remove API key: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
