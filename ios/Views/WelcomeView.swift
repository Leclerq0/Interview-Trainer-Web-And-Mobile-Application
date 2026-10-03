import SwiftUI

public struct WelcomeView: View {
    public let onStart: () -> Void

    public init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    public var body: some View {
        ZStack {
            Color(red: 15/255, green: 23/255, blue: 42/255)
                .ignoresSafeArea()

            VStack {
                Circle()
                    .fill(Color.indigo.opacity(0.18))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(y: -40)
                Spacer()
            }

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.indigo, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .shadow(color: Color.indigo.opacity(0.5), radius: 20, y: 8)

                        Image(systemName: "eyeglasses")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("AI TEKNİK MÜLAKATÇI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.indigo)
                            .tracking(1.2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.indigo.opacity(0.15))
                    .clipShape(Capsule())
                }

                VStack(spacing: 12) {
                    Text("AI Interview Trainer'a\nHoş Geldiniz")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("Acımasız, öğretici ve teknik derinliğe odaklanan yapay zeka mülakat simülasyonu.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    featureRow(icon: "bolt.shield.fill", title: "Dinamik Sorular", desc: "Rol ve kıdem seviyenize göre üretilen sorular.")
                    featureRow(icon: "waveform", title: "Sesli & Yazılı Simülasyon", desc: "Doğal konuşma akışıyla soruları sesli cevaplama.")
                    featureRow(icon: "chart.bar.doc.horizontal.fill", title: "Detaylı Karne Raporu", desc: "Puanlama, iyi yönler ve çalışılacak konular.")
                }
                .padding(.horizontal, 20)

                Spacer()

                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Text("Başla")
                            .font(.system(size: 17, weight: .bold))

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.indigo.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.indigo)
                .frame(width: 32, height: 32)
                .background(Color.indigo.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(red: 30/255, green: 41/255, blue: 59/255).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
