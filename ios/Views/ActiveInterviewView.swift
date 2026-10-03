import SwiftUI

public struct ActiveInterviewView: View {
    @ObservedObject var viewModel: InterviewViewModel
    @State private var textAnswerInput: String = ""
    @State private var isTextMode: Bool = false
    @FocusState private var isTextInputFocused: Bool

    public var body: some View {
        ZStack {
            Color(red: 15/255, green: 23/255, blue: 42/255)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SORU \(viewModel.currentTurn) / \(viewModel.maxTurns)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.indigo)

                        ProgressView(value: Double(viewModel.currentTurn), total: Double(viewModel.maxTurns))
                            .tint(.indigo)
                            .frame(width: 140)
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            await viewModel.finishInterview()
                        }
                    }) {
                        Text("Bitir")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 44, height: 44)
                                        .shadow(color: Color.indigo.opacity(0.4), radius: 8)

                                    Image(systemName: "eyeglasses")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Acımasız Profesör")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("AI Staff Technical Interviewer")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }

                            Text(viewModel.currentQuestion)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .lineSpacing(5)
                        }
                        .padding(18)
                        .background(Color(red: 30/255, green: 41/255, blue: 59/255))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.indigo.opacity(0.1), radius: 10)

                        if let lastFeedback = viewModel.lastFeedback {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.bubble.fill")
                                        .foregroundColor(.yellow)
                                    Text("Önceki Cevabına Eleştiri")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.yellow)
                                }

                                Text(lastFeedback)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                            }
                            .padding(14)
                            .background(Color.yellow.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                            )
                        }

                        if let transcribed = viewModel.lastTranscribedText {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Söyledikleriniz (Son Tur):")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.gray)
                                Text(transcribed)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }

                        if let error = viewModel.errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { viewModel.errorMessage = nil }) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.18))
                            .cornerRadius(10)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isTextMode.toggle()
                                if !isTextMode {
                                    isTextInputFocused = false
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isTextMode ? "mic.fill" : "keyboard")
                                Text(isTextMode ? "Sesli Yanıta Geç" : "Metinle Yanıtla")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.indigo)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.indigo.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 24)

                    if isTextMode {
                        HStack(alignment: .bottom, spacing: 10) {
                            HStack(alignment: .bottom, spacing: 8) {
                                TextField("Teknik cevabınızı buraya yazın...", text: $textAnswerInput, axis: .vertical)
                                    .focused($isTextInputFocused)
                                    .lineLimit(1...5)
                                    .foregroundColor(.white)

                                if isTextInputFocused {
                                    Button(action: {
                                        isTextInputFocused = false
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(12)
                            .background(Color(red: 30/255, green: 41/255, blue: 59/255))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isTextInputFocused ? Color.indigo : Color.white.opacity(0.1), lineWidth: 1)
                            )

                            Button(action: {
                                guard !textAnswerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                isTextInputFocused = false
                                let ans = textAnswerInput
                                textAnswerInput = ""
                                Task {
                                    await viewModel.submitTextAnswer(ans)
                                }
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.indigo)
                            }
                            .disabled(textAnswerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    } else {
                        if viewModel.audioManager.isRecording {
                            HStack(spacing: 4) {
                                ForEach(0..<15, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .bottom, endPoint: .top))
                                        .frame(
                                            width: 4,
                                            height: max(6, CGFloat(viewModel.audioManager.audioLevel * 60) * CGFloat.random(in: 0.5...1.2))
                                        )
                                        .animation(.easeInOut(duration: 0.08), value: viewModel.audioManager.audioLevel)
                                }
                            }
                            .frame(height: 40)

                            Text(String(format: "Kayıt: %.1fs • Bitirmek için dokunun", viewModel.audioManager.recordingDuration))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.cyan)
                        }

                        Button(action: {
                            Task {
                                await viewModel.toggleRecording()
                            }
                        }) {
                            ZStack {
                                if viewModel.audioManager.isRecording {
                                    Circle()
                                        .fill(Color.red.opacity(0.35))
                                        .frame(width: 96, height: 96)
                                        .scaleEffect(1.2)
                                        .animation(.easeInOut(duration: 0.6).repeatForever(), value: viewModel.audioManager.isRecording)
                                }

                                Circle()
                                    .fill(
                                        viewModel.audioManager.isRecording
                                            ? LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 76, height: 76)
                                    .shadow(color: Color.indigo.opacity(0.4), radius: 10, y: 4)

                                Image(systemName: viewModel.audioManager.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                        }

                        Text(viewModel.audioManager.isRecording ? "Kaydı Durdur ve Gönder" : "Konuşmak için Dokun")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 28)
                .padding(.top, 8)
                .background(Color(red: 24/255, green: 32/255, blue: 47/255))
            }

            if viewModel.state == .evaluatingAnswer {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)

                    Text("Profesör cevabınızı analiz ediyor...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Kavramsal doğruluk, terminoloji ve teknik derinlik inceleniyor.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(28)
                .background(Color(red: 30/255, green: 41/255, blue: 59/255))
                .cornerRadius(18)
                .shadow(radius: 20)
            }
        }
        .task {
            _ = await viewModel.audioManager.requestPermission()
        }
    }
}
