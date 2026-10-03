import SwiftUI

public struct ReportView: View {
    @ObservedObject var viewModel: InterviewViewModel

    public var body: some View {
        ZStack {
            Color(red: 15/255, green: 23/255, blue: 42/255)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("MÜLAKAT TAMAMLANDI")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())

                        Text("Performans Karnesi")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(viewModel.selectedRole) • \(viewModel.selectedSeniority)")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)

                    if let report = viewModel.finalReport {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 14)
                                    .frame(width: 140, height: 140)

                                Circle()
                                    .trim(from: 0.0, to: CGFloat(report.overallScore) / 100.0)
                                    .stroke(
                                        LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 140, height: 140)

                                VStack(spacing: 2) {
                                    Text("\(report.overallScore)")
                                        .font(.system(size: 40, weight: .black))
                                        .foregroundColor(.white)
                                    Text("/ 100")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.top, 8)

                            Text(report.performanceLevel)
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.indigo.opacity(0.2))
                                .foregroundColor(.indigo)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.indigo.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color(red: 30/255, green: 41/255, blue: 59/255))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "quote.opening")
                                    .foregroundColor(.indigo)
                                Text("Mülakatçı Özeti")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text(report.summary)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color(red: 30/255, green: 41/255, blue: 59/255))
                        .cornerRadius(16)

                        if !report.strengths.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Güçlü Yönler")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }

                                ForEach(report.strengths, id: \.self) { strength in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.green)
                                            .fontWeight(.bold)
                                        Text(strength)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.green.opacity(0.07))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
                            )
                        }

                        if !report.criticalWeaknesses.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "xmark.octagon.fill")
                                        .foregroundColor(.rose)
                                    Text("Kritik Eksikler & Yanılgılar")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }

                                ForEach(report.criticalWeaknesses, id: \.self) { weakness in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.rose)
                                            .fontWeight(.bold)
                                        Text(weakness)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.red.opacity(0.07))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }

                        if !report.recommendedTopics.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.cyan)
                                    Text("Önerilen Çalışma Konuları")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }

                                ForEach(report.recommendedTopics, id: \.self) { topic in
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.right.circle")
                                            .foregroundColor(.cyan)
                                            .font(.system(size: 12))
                                        Text(topic)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.cyan.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }

                    VStack(spacing: 12) {
                        Button(action: {
                            viewModel.reset()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Yeni Mülakat Başlat")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Color.indigo.opacity(0.4), radius: 8, y: 4)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private extension Color {
    static let rose = Color(red: 244/255, green: 63/255, blue: 94/255)
}
