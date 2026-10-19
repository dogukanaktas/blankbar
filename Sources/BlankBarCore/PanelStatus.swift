import Foundation

/// Decodes the bit mask returned by DFRFoundation's private DFRGetStatus().
/// Observed values: 0x1 with the panel lit, 0x5 with it dark (macOS 15.5 and 26.5, M1).
public enum PanelStatus {
    public static let darkBit = 0x4

    public static func isDark(_ status: Int) -> Bool {
        status & darkBit != 0
    }
}

/// Parses `launchctl` output. Its format is not an API, so every parser here fails
/// soft: an unrecognised format reads as "not running" / "not disabled".
public enum LaunchctlOutput {
    /// The pid from `launchctl print gui/<uid>/<label>`, if the job is running.
    /// Only top-level keys (one tab deep) count: nested sections such as endpoints
    /// have `state` keys of their own.
    public static func runningPID(inPrint output: String) -> Int32? {
        var running = false
        var pid: Int32?
        for line in output.split(separator: "\n") where line.hasPrefix("\t") && !line.hasPrefix("\t\t") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "state = running" { running = true }
            if pid == nil, trimmed.hasPrefix("pid = ") {
                pid = Int32(trimmed.dropFirst("pid = ".count))
            }
        }
        return running ? pid : nil
    }

    /// Whether `launchctl print-disabled gui/<uid>` lists `label` as disabled.
    /// macOS 11 prints `"label" => true`, later versions `"label" => disabled`.
    public static func isDisabled(label: String, inPrintDisabled output: String) -> Bool {
        let quoted = "\"\(label)\""
        for line in output.split(separator: "\n") {
            guard let arrow = line.range(of: "=>") else { continue }
            let key = line[..<arrow.lowerBound].trimmingCharacters(in: .whitespaces)
            let value = line[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
            guard key == quoted else { continue }
            return value == "disabled" || value == "true"
        }
        return false
    }
}
