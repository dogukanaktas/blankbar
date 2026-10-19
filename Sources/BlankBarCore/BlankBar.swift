import Foundation

public enum BlankBar {
    /// Bumped on every release; CI checks that it matches the git tag.
    public static let version = "1.0.0"

    /// launchd label, also the name of the launch agent's plist file.
    public static let agentLabel = "io.github.dogukanaktas.blankbar"
}

/// sysexits(3) codes, so scripts can tell a usage error from an unsupported Mac.
public enum ExitCode: Int32 {
    case success = 0
    case failure = 1
    case usage = 64
    case unavailable = 69
    case software = 70
}
