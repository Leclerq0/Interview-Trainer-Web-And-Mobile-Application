import SwiftUI

public struct RoleSetupView: View {
    @ObservedObject var viewModel: InterviewViewModel
    @State private var showServerConfig: Bool = false
    @FocusState private var isRoleFieldFocused: Bool

    private let presetRoles = [
        "iOS Developer (Swift)",
        "Backend Engineer (C++)",
        "Frontend Engineer (React)",
        "Systems Engineer (Rust/C++)"
    ]

    private let seniorityLevels = ["Junior", "Mid-Level", "Senior", "Lead"]

    private let availableTopics = [
        "Memory Management (ARC)",
        "Swift Concurrency & Actors",
        "LLVM & Architecture",
        "Data Structures & Algorithms",
        "Multi-threading & Mutexes",
        "Clean Architecture & VIPER"
    ]

    public var body: some View {
        ZStack {
            Color(red: 15/255, green: 23/255, blue: 42/255)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 8, height: 8)
                            Text("TEKNİK SİMÜLASYON v2.4")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.indigo)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.15))
                        .clipShape(Capsule())

                        Text("AI Interview Trainer")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Acımasız ve Öğretici Teknik Mülakat Simülasyonu")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)

                    if let error = viewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "wifi.exclamationmark")
                                    .foregroundColor(.red)
                                Text("Bağlantı Hatası")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.red)
                                Spacer()
                                Button(action: { viewModel.errorMessage = nil }) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(14)
                        .background(Color.red.opacity(0.18))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Hedef Rol / Pozisyon")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)

                            Text("(Hedeflediğiniz rolü / pozisyonu yazabilirsiniz)")
                                .font(.system(size: 12))
                                .foregroundColor(Color.gray.opacity(0.85))
                        }

                        HStack {
                            TextField("Örn: Senior iOS Architect", text: $viewModel.selectedRole)
                                .focused($isRoleFieldFocused)
                                .foregroundColor(.white)

                            if isRoleFieldFocused {
                                Button(action: {
                                    isRoleFieldFocused = false
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding()
                        .background(Color(red: 30/255, green: 41/255, blue: 59/255))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isRoleFieldFocused ? Color.indigo : Color.white.opacity(0.1), lineWidth: 1)
                        )

                        Text("Örnek Hedef Roller")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.top, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presetRoles, id: \.self) { role in
                                    Button(action: { viewModel.selectedRole = role }) {
                                        Text(role)
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                viewModel.selectedRole == role
                                                    ? Color.indigo.opacity(0.3)
                                                    : Color(red: 30/255, green: 41/255, blue: 59/255)
                                            )
                                            .foregroundColor(viewModel.selectedRole == role ? .indigo : .gray)
                                            .cornerRadius(20)
                                            .overlay(
                                                Capsule()
                                                    .stroke(viewModel.selectedRole == role ? Color.indigo : Color.clear, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Deneyim Seviyesi")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            ForEach(seniorityLevels, id: \.self) { level in
                                Button(action: { viewModel.selectedSeniority = level }) {
                                    Text(level)
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            viewModel.selectedSeniority == level
                                                ? LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                                                : LinearGradient(colors: [Color(red: 30/255, green: 41/255, blue: 59/255)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .foregroundColor(viewModel.selectedSeniority == level ? .white : .gray)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Odak Konuları")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("Çoklu Seçim")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }

                        VStack(spacing: 8) {
                            ForEach(availableTopics, id: \.self) { topic in
                                Button(action: {
                                    if viewModel.selectedTopics.contains(topic) {
                                        viewModel.selectedTopics.remove(topic)
                                    } else {
                                        viewModel.selectedTopics.insert(topic)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: viewModel.selectedTopics.contains(topic) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(viewModel.selectedTopics.contains(topic) ? .indigo : .gray)
                                        Text(topic)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 30/255, green: 41/255, blue: 59/255).opacity(0.8))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(viewModel.selectedTopics.contains(topic) ? Color.indigo.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Soru Sayısı: \(viewModel.maxTurns) Soru")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("~20-30 dk")
                                .font(.system(size: 12))
                                .foregroundColor(.indigo)
                        }

                        Stepper("", value: $viewModel.maxTurns, in: 2...8)
                            .labelsHidden()
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            withAnimation {
                                showServerConfig.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "network")
                                    .foregroundColor(.indigo)
                                Text("Sunucu Bağlantı Ayarı (Backend IP)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.indigo)
                                Spacer()
                                Image(systemName: showServerConfig ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }

                        if showServerConfig {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Backend API URL:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)

                                TextField(Config.apiBaseURL, text: $viewModel.serverURLString)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(10)
                                    .background(Color(red: 20/255, green: 28/255, blue: 42/255))
                                    .foregroundColor(.cyan)
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)

                                Text("• Varsayılan API URL: \(Config.apiBaseURL)\n• Proje ayarlarını değiştirmek için Config.swift dosyasını kullanabilirsiniz.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(Color(red: 30/255, green: 41/255, blue: 59/255))
                            .cornerRadius(10)
                        }
                    }

                    Button(action: {
                        isRoleFieldFocused = false
                        Task {
                            await viewModel.startInterview()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                            Text("Mülakata Başla")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [Color.indigo, Color.purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color.indigo.opacity(0.4), radius: 10, y: 4)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
