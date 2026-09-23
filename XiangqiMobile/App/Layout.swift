import SwiftUI

extension View {
    /// Caps content at a comfortable width and centers it.
    ///
    /// On iPhone the available width is always under the cap, so this is a
    /// no-op there. On iPad it stops cards, lists, and the board from
    /// stretching edge-to-edge across the much wider screen.
    func readableContentWidth(_ maxWidth: CGFloat = 680) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
