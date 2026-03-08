import Foundation

@Observable
final class PushRegistrationStatus {

    static let shared = PushRegistrationStatus()

    enum State: Equatable {
        case unknown
        case checking
        case registered
        case failed(String)
    }

    private(set) var state: State = .unknown

    func refresh() {
        if AppPersistentMemory.shared.getLastSentPushToken() != nil {
            state = .registered
        }
    }

    func markChecking() { state = .checking }
    func markRegistered() { state = .registered }
    func markFailed(_ message: String) { state = .failed(message) }
}
