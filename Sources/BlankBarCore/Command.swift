import Foundation

public enum Command: Equatable {
    case off
    case on
    case install
    case uninstall
    case status
    /// The long-running process the launch agent starts. Not meant to be typed.
    case daemon
    case help
    case version

    public static func parse(_ arguments: [String]) -> Result<Command, UsageError> {
        guard let first = arguments.first else { return .success(.help) }
        let command: Command
        switch first {
        case "off": command = .off
        case "on": command = .on
        case "install": command = .install
        case "uninstall": command = .uninstall
        case "status": command = .status
        case "daemon": command = .daemon
        case "help", "-h", "--help": command = .help
        case "version", "-V", "--version": command = .version
        default: return .failure(UsageError("unknown command '\(first)'"))
        }
        guard arguments.count == 1 else {
            return .failure(UsageError("'\(first)' takes no arguments"))
        }
        return .success(command)
    }

    public static let usage = """
        Usage: blankbar <command>

        Turns the MacBook Pro Touch Bar off and keeps it off.

        Commands:
          install     Turn the Touch Bar off now and keep it off after sleep and login
          off         Turn the Touch Bar off (and resume keeping it off, if installed)
          on          Turn the Touch Bar on (and pause keeping it off until 'off')
          status      Show the Touch Bar and background agent state
          uninstall   Turn the Touch Bar on and remove the background agent
          help        Show this help
          version     Show the version
        """
}

public struct UsageError: Error, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
}
