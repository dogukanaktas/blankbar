import Foundation

/// Allows at most `limit` events in any sliding `window`. Guards the daemon against
/// fighting the system in a tight loop if a macOS change makes "off" never stick.
///
/// Times are seconds on a monotonic clock that keeps counting during sleep
/// (CLOCK_MONOTONIC), so neither a clock change nor sleep keeps old events alive.
public struct RateLimiter {
    public let limit: Int
    public let window: TimeInterval
    private var events: [TimeInterval] = []

    public init(limit: Int, window: TimeInterval) {
        precondition(limit > 0 && window > 0)
        self.limit = limit
        self.window = window
    }

    /// Records an event at `now` and returns true, or returns false when over the limit.
    public mutating func allow(at now: TimeInterval) -> Bool {
        events.removeAll { now - $0 >= window }
        guard events.count < limit else { return false }
        events.append(now)
        return true
    }

    /// Seconds until the next event will be allowed; 0 if it is allowed now.
    public func delayUntilAllowed(at now: TimeInterval) -> TimeInterval {
        let recent = events.filter { now - $0 < window }
        guard recent.count >= limit, let oldest = recent.first else { return 0 }
        return oldest + window - now
    }
}
