import SwiftUI

struct AudioRouterLogo: View {
    enum Size {
        case compact
        case regular

        var dimension: CGFloat {
            switch self {
            case .compact:
                return 34
            case .regular:
                return 56
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .compact:
                return 4
            case .regular:
                return 7
            }
        }
    }

    var size: Size = .regular

    var body: some View {
        let dimension = size.dimension

        ZStack {
            RoundedRectangle(cornerRadius: dimension * 0.22, style: .continuous)
                .fill(Color(red: 0.045, green: 0.055, blue: 0.065))
                .overlay {
                    RoundedRectangle(cornerRadius: dimension * 0.22, style: .continuous)
                        .stroke(Color(red: 0.20, green: 0.82, blue: 0.78), lineWidth: size.lineWidth)
                }

            Text("AU")
                .font(.system(size: dimension * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.28, green: 0.96, blue: 0.90))
                .tracking(-0.5)
        }
        .frame(width: dimension, height: dimension)
        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
        .accessibilityHidden(true)
    }
}
