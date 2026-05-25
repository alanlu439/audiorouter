import SwiftUI

struct AudioRouterLogo: View {
    var size: CGFloat = 38

    var body: some View {
        let cornerRadius = size * 0.22
        let borderWidth = max(2, (size * 0.06).rounded(.toNearestOrAwayFromZero))
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape
                .fill(.black.gradient)
                .overlay {
                    shape
                        .strokeBorder(.teal, lineWidth: borderWidth)
                }
            Text("AU")
                .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(.teal)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("AudioRouter")
    }
}
