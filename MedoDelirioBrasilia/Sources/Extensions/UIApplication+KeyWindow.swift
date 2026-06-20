import UIKit

extension UIApplication {

    var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap({ $0 as? UIWindowScene })?.windows
            .first(where: \.isKeyWindow)
    }

    /// The view controller at the top of the modal presentation stack, walking
    /// through any presented sheets/popovers from the key window's root.
    ///
    /// Use this — not `rootViewController` — when presenting UIKit controllers
    /// (e.g. a share sheet) while SwiftUI sheets are already on screen, since
    /// `present(_:animated:)` silently fails on a controller already presenting.
    var topMostViewController: UIViewController? {
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

}
