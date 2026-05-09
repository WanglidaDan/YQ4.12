import SwiftUI
import UIKit

enum StudioBackdropMode {
    case launch
    case auth
    case ambient
}

struct StudioBackdrop: View {
    let mode: StudioBackdropMode

    private var sourceImage: UIImage? {
        switch mode {
        case .launch:
            nil
        case .auth:
            UIImage(named: "LaunchBackdrop")
        case .ambient:
            UIImage(named: "StudioBackdrop")
        }
    }

    var body: some View {
        ZStack {
            switch mode {
            case .launch:
                launchBackdrop
            case .auth:
                primaryBackdrop
            case .ambient:
                ambientBackdrop
            }
        }
    }

    @ViewBuilder
    private var primaryBackdrop: some View {
        if let sourceImage {
            GeometryReader { proxy in
                let size = proxy.size
                let isAuth = mode == .auth

                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(isAuth ? 1.25 : 1.18)
                    .offset(
                        x: isAuth ? -size.width * 0.19 : size.width * 0.03,
                        y: isAuth ? -size.height * 0.06 : -size.height * 0.08
                    )
                    .blur(radius: isAuth ? 0 : 7)
                    .saturation(isAuth ? 0.96 : 0.82)
                    .contrast(isAuth ? 1.12 : 1.0)
                    .brightness(isAuth ? 0.035 : 0.0)
                    .overlay { baseGrade(isAuth: isAuth) }
                    .clipped()
            }
        } else {
            stylizedBackdrop
        }
    }

    private func baseGrade(isAuth: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: isAuth
                ? [
                    Color.black.opacity(0.48),
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.52)
                ]
                : [
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.52)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if isAuth {
                LinearGradient(
                    colors: [
                        Color(uiColor: UIColor(hex: "#06080B")).opacity(0.62),
                        Color(uiColor: UIColor(hex: "#12161B")).opacity(0.28),
                        .clear,
                        Color(uiColor: UIColor(hex: "#0C0F13")).opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.54), location: 0.0),
                        .init(color: Color.black.opacity(0.34), location: 0.14),
                        .init(color: Color(uiColor: UIColor(hex: "#1B2026")).opacity(0.16), location: 0.34),
                        .init(color: Color(uiColor: UIColor(hex: "#2B3037")).opacity(0.06), location: 0.58),
                        .init(color: Color.black.opacity(0.28), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.40),
                        .init(color: Color.black.opacity(0.08), location: 0.54),
                        .init(color: Color(uiColor: UIColor(hex: "#252A30")).opacity(0.18), location: 0.68),
                        .init(color: Color.black.opacity(0.54), location: 0.80),
                        .init(color: Color.black.opacity(0.74), location: 0.90),
                        .init(color: Color.black.opacity(0.80), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.40),
                        .clear,
                        Color.black.opacity(0.54)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var launchBackdrop: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    Color(uiColor: UIColor(hex: "#A8A39B")).opacity(0.26),
                    Color(uiColor: UIColor(hex: "#66615B")).opacity(0.12),
                    .clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 260
            )
            .offset(y: 200)

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.94), location: 0.0),
                    .init(color: Color.black.opacity(0.70), location: 0.34),
                    .init(color: Color(uiColor: UIColor(hex: "#45403B")).opacity(0.18), location: 0.66),
                    .init(color: Color(uiColor: UIColor(hex: "#A6A098")).opacity(0.26), location: 0.88),
                    .init(color: Color(uiColor: UIColor(hex: "#E0DDD6")).opacity(0.42), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    .clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var ambientBackdrop: some View {
        AppTheme.background
    }

    private var stylizedBackdrop: some View {
        ZStack {
            Color(uiColor: UIColor(hex: "#11161C"))

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 110, y: -180)

            LinearGradient(
                colors: [
                    Color(uiColor: UIColor(hex: "#0D1218")),
                    Color(uiColor: UIColor(hex: "#121821"))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
