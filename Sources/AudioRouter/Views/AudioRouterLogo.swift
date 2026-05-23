import SwiftUI

struct AudioRouterLogo: View {
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(.black.gradient)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(.teal, lineWidth: max(1.5, size * 0.055))
                }
            Text("AU")
                .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(.teal)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("AudioRouter")
    }
}
