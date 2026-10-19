import Foundation

public enum LaunchAgentPlist {
    /// The launch agent definition. Serialized with PropertyListSerialization so any
    /// path, including one with spaces, quotes or `&`, is escaped correctly.
    public static func make(label: String, executable: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable, "daemon"],
            "RunAtLoad": true,
            // Restart only after a crash. A clean exit (unsupported Mac) or a binary that
            // no longer exists (removed without 'blankbar uninstall') must not loop.
            "KeepAlive": ["Crashed": true],
            // If a future macOS makes it crash at launch, retry at most twice a minute.
            "ThrottleInterval": 30,
            // Only in a logged-in GUI session: the Touch Bar belongs to the console user.
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    /// The executable a plist starts, or nil when the data is not one of ours.
    public static func executable(in data: Data) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let arguments = plist["ProgramArguments"] as? [String] else { return nil }
        return arguments.first
    }
}
