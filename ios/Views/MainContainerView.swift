import SwiftUI

public struct MainContainerView: View {
    @StateObject private var viewModel = InterviewViewModel()
    @State private var hasPassedWelcome: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            if !hasPassedWelcome {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasPassedWelcome = true
                    }
                }
                .transition(.opacity)
            } else {
                switch viewModel.state {
                case .setup:
                    RoleSetupView(viewModel: viewModel)
                        .transition(.opacity)

                case .inProgress, .evaluatingAnswer:
                    ActiveInterviewView(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))

                case .completed:
                    ReportView(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))

                case .error(let message):
                    ZStack {
                        Color(red: 15/255, green: 23/255, blue: 42/255)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.orange)

                            Text("Bir Hata Oluştu")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text(message)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            Button(action: { viewModel.reset() }) {
                                Text("Tekrar Dene")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasPassedWelcome)
        .animation(.easeInOut(duration: 0.35), value: viewModel.state)
    }
}
