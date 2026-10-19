import Foundation

public enum ExecutablePath {
    /// The path the launch agent should start, given the fully resolved (symlink-free)
    /// path of this binary.
    ///
    /// A Homebrew Cellar path names one version and disappears on `brew upgrade`, so it
    /// is replaced by the formula's `opt` link, which always points at the current one
    /// and, unlike `<prefix>/bin`, survives `brew unlink`.
    public static func stable(resolved path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        // <prefix>/Cellar/blankbar/<version>/bin/blankbar
        if parts.count >= 6,
           parts[parts.count - 5] == "Cellar",
           parts[parts.count - 4] == "blankbar",
           parts[parts.count - 2] == "bin",
           parts[parts.count - 1] == "blankbar" {
            let prefix = parts[..<(parts.count - 5)].joined(separator: "/")
            return prefix + "/opt/blankbar/bin/blankbar"
        }
        return path
    }

    /// `path` made absolute against `currentDirectory`, with `.` and `..` removed.
    public static func absolute(_ path: String, currentDirectory: String) -> String {
        let absolute = path.hasPrefix("/") ? path : currentDirectory + "/" + path
        return (absolute as NSString).standardizingPath
    }

    /// Every ancestor directory of an absolute path, from "/" down, then the path itself.
    public static func chain(_ path: String) -> [String] {
        var result = ["/"]
        var current = ""
        for part in path.split(separator: "/") {
            current += "/" + part
            result.append(current)
        }
        return result
    }
}

/// Ownership and mode of one file system entry, as returned by stat(2).
public struct FileOwnership: Equatable {
    public let path: String
    public let uid: UInt32
    public let gid: UInt32
    public let mode: UInt16
    public let isDirectory: Bool

    public init(path: String, uid: UInt32, gid: UInt32, mode: UInt16, isDirectory: Bool) {
        self.path = path
        self.uid = uid
        self.gid = gid
        self.mode = mode
        self.isDirectory = isDirectory
    }
}

public enum PathSafety {
    /// Groups whose members can already become root, so their write access adds no risk.
    public static let privilegedGroups: Set<UInt32> = [0, 80]   // wheel, admin

    /// Why another local user could replace the file the launch agent runs at every
    /// login, gaining code execution as this user; nil when no one else can.
    /// `entries` are the path and every ancestor directory. `trustedUIDs` are this user,
    /// root and administrators: anyone who could take over the account anyway.
    public static func problem(with entries: [FileOwnership], trustedUIDs: Set<UInt32>) -> String? {
        for entry in entries {
            let worldWritable = entry.mode & 0o002 != 0
            let sticky = entry.mode & 0o1000 != 0
            // A sticky world-writable directory (like /tmp) lets others create entries
            // but not replace ours, which the next entry's own check covers.
            if worldWritable && !(entry.isDirectory && sticky) {
                return "\(entry.path) is writable by every user"
            }
            if entry.mode & 0o020 != 0 && !privilegedGroups.contains(entry.gid) {
                return "\(entry.path) is writable by group \(entry.gid)"
            }
            if !trustedUIDs.contains(entry.uid) {
                return "\(entry.path) is owned by another user (uid \(entry.uid))"
            }
        }
        return nil
    }
}
