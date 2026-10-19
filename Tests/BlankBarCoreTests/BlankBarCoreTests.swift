@testable import BlankBarCore
import XCTest

final class CommandTests: XCTestCase {
    func testCommands() {
        XCTAssertEqual(Command.parse(["off"]), .success(.off))
        XCTAssertEqual(Command.parse(["on"]), .success(.on))
        XCTAssertEqual(Command.parse(["install"]), .success(.install))
        XCTAssertEqual(Command.parse(["uninstall"]), .success(.uninstall))
        XCTAssertEqual(Command.parse(["status"]), .success(.status))
        XCTAssertEqual(Command.parse(["daemon"]), .success(.daemon))
    }

    func testHelpAndVersionAliases() {
        XCTAssertEqual(Command.parse([]), .success(.help))
        for alias in ["help", "-h", "--help"] { XCTAssertEqual(Command.parse([alias]), .success(.help)) }
        for alias in ["version", "-V", "--version"] { XCTAssertEqual(Command.parse([alias]), .success(.version)) }
    }

    func testRejectsUnknownAndExtraArguments() {
        XCTAssertEqual(Command.parse(["of"]), .failure(UsageError("unknown command 'of'")))
        XCTAssertEqual(Command.parse(["OFF"]), .failure(UsageError("unknown command 'OFF'")))
        XCTAssertEqual(Command.parse(["off", "now"]), .failure(UsageError("'off' takes no arguments")))
        XCTAssertEqual(Command.parse([""]), .failure(UsageError("unknown command ''")))
        XCTAssertEqual(Command.parse(["foo", "bar"]), .failure(UsageError("unknown command 'foo'")))
    }
}

final class HardwareTests: XCTestCase {
    func testTouchBarModels() {
        XCTAssertTrue(Hardware.hasTouchBar(model: "MacBookPro17,1"))
        XCTAssertTrue(Hardware.hasTouchBar(model: "Mac14,7"))
        XCTAssertTrue(Hardware.hasTouchBar(model: "MacBookPro16,3"))
    }

    func testModelsWithoutTouchBar() {
        XCTAssertFalse(Hardware.hasTouchBar(model: "MacBookPro13,1"))
        XCTAssertFalse(Hardware.hasTouchBar(model: "MacBookPro14,1"))
        XCTAssertFalse(Hardware.hasTouchBar(model: "MacBookPro18,3"))
        XCTAssertFalse(Hardware.hasTouchBar(model: "MacBookAir10,1"))
        XCTAssertFalse(Hardware.hasTouchBar(model: ""))
    }
}

final class LaunchAgentPlistTests: XCTestCase {
    func testRoundTripsExecutable() throws {
        let data = try LaunchAgentPlist.make(label: "x.y", executable: "/opt/homebrew/bin/blankbar")
        XCTAssertEqual(LaunchAgentPlist.executable(in: data), "/opt/homebrew/bin/blankbar")
    }

    func testEscapesHostilePaths() throws {
        let path = "/Users/a b/<tools> & \"x\"/blankbar"
        let data = try LaunchAgentPlist.make(label: "x.y", executable: path)
        XCTAssertEqual(LaunchAgentPlist.executable(in: data), path)
    }

    func testContents() throws {
        let data = try LaunchAgentPlist.make(label: "x.y", executable: "/b")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["Label"] as? String, "x.y")
        XCTAssertEqual(plist["ProgramArguments"] as? [String], ["/b", "daemon"])
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["KeepAlive"] as? [String: Bool], ["Crashed": true])
        XCTAssertEqual(plist["ThrottleInterval"] as? Int, 30)
        XCTAssertEqual(plist["LimitLoadToSessionType"] as? String, "Aqua")
    }

    func testRejectsForeignData() {
        XCTAssertNil(LaunchAgentPlist.executable(in: Data("not a plist".utf8)))
        XCTAssertNil(LaunchAgentPlist.executable(in: Data()))
    }
}

final class ExecutablePathTests: XCTestCase {
    func testHomebrewCellarBecomesOptLink() {
        XCTAssertEqual(
            ExecutablePath.stable(resolved: "/opt/homebrew/Cellar/blankbar/1.0.0/bin/blankbar"),
            "/opt/homebrew/opt/blankbar/bin/blankbar")
        XCTAssertEqual(
            ExecutablePath.stable(resolved: "/usr/local/Cellar/blankbar/1.2.3_1/bin/blankbar"),
            "/usr/local/opt/blankbar/bin/blankbar")
    }

    func testOtherPathsAreKept() {
        XCTAssertEqual(ExecutablePath.stable(resolved: "/Users/me/.local/bin/blankbar"), "/Users/me/.local/bin/blankbar")
        XCTAssertEqual(
            ExecutablePath.stable(resolved: "/opt/homebrew/Cellar/other/1.0/bin/blankbar"),
            "/opt/homebrew/Cellar/other/1.0/bin/blankbar")
    }

    func testAbsolute() {
        XCTAssertEqual(ExecutablePath.absolute("./bin/blankbar", currentDirectory: "/Users/me"), "/Users/me/bin/blankbar")
        XCTAssertEqual(ExecutablePath.absolute("../x/blankbar", currentDirectory: "/Users/me/src"), "/Users/me/x/blankbar")
        XCTAssertEqual(ExecutablePath.absolute("/a/./b", currentDirectory: "/c"), "/a/b")
    }

    func testChain() {
        XCTAssertEqual(ExecutablePath.chain("/a/b/c"), ["/", "/a", "/a/b", "/a/b/c"])
        XCTAssertEqual(ExecutablePath.chain("/"), ["/"])
    }
}

final class PathSafetyTests: XCTestCase {
    let me: UInt32 = 501
    let other: UInt32 = 502
    var trusted: Set<UInt32> { [me, 0] }

    func entry(_ path: String, uid: UInt32 = 0, gid: UInt32 = 0, mode: UInt16, dir: Bool = true) -> FileOwnership {
        FileOwnership(path: path, uid: uid, gid: gid, mode: mode, isDirectory: dir)
    }

    func testOwnFilesAreSafe() {
        let chain = [entry("/", mode: 0o755), entry("/Users", mode: 0o755),
                     entry("/Users/me", uid: me, gid: 20, mode: 0o750),
                     entry("/Users/me/blankbar", uid: me, gid: 20, mode: 0o755, dir: false)]
        XCTAssertNil(PathSafety.problem(with: chain, trustedUIDs: trusted))
    }

    func testHomebrewAdminGroupWritableIsSafe() {
        let chain = [entry("/opt", mode: 0o755),
                     entry("/opt/homebrew", uid: me, gid: 80, mode: 0o775),
                     entry("/opt/homebrew/bin/blankbar", uid: me, gid: 80, mode: 0o755, dir: false)]
        XCTAssertNil(PathSafety.problem(with: chain, trustedUIDs: trusted))
    }

    func testWorldWritableIsUnsafe() {
        let chain = [entry("/Users/Shared", mode: 0o777), entry("/Users/Shared/blankbar", uid: me, mode: 0o755, dir: false)]
        XCTAssertEqual(PathSafety.problem(with: chain, trustedUIDs: trusted), "/Users/Shared is writable by every user")
    }

    func testStickyWorldWritableDirectoryDefersToChild() {
        let safe = [entry("/tmp", mode: 0o1777), entry("/tmp/blankbar", uid: me, mode: 0o755, dir: false)]
        XCTAssertNil(PathSafety.problem(with: safe, trustedUIDs: trusted))
        let unsafe = [entry("/tmp", mode: 0o1777), entry("/tmp/blankbar", uid: other, mode: 0o755, dir: false)]
        XCTAssertNotNil(PathSafety.problem(with: unsafe, trustedUIDs: trusted))
    }

    func testOrdinaryGroupWritableIsUnsafe() {
        let chain = [entry("/x", uid: me, gid: 20, mode: 0o775)]
        XCTAssertEqual(PathSafety.problem(with: chain, trustedUIDs: trusted), "/x is writable by group 20")
    }

    func testOtherOwnerIsUnsafeUnlessTrusted() {
        let chain = [entry("/x", uid: other, gid: 20, mode: 0o755)]
        XCTAssertNotNil(PathSafety.problem(with: chain, trustedUIDs: trusted))
        XCTAssertNil(PathSafety.problem(with: chain, trustedUIDs: [me, 0, other]))
    }
}

final class RateLimiterTests: XCTestCase {
    func testAllowsUpToLimitThenBlocks() {
        var limiter = RateLimiter(limit: 3, window: 60)
        for t in [1000.0, 1001, 1002] { XCTAssertTrue(limiter.allow(at: t)) }
        XCTAssertFalse(limiter.allow(at: 1010))
        XCTAssertEqual(limiter.delayUntilAllowed(at: 1010), 50)
    }

    func testWindowSlides() {
        var limiter = RateLimiter(limit: 2, window: 10)
        XCTAssertTrue(limiter.allow(at: 0))
        XCTAssertTrue(limiter.allow(at: 5))
        XCTAssertFalse(limiter.allow(at: 9))
        XCTAssertTrue(limiter.allow(at: 10))
        XCTAssertEqual(RateLimiter(limit: 1, window: 1).delayUntilAllowed(at: 0), 0)
    }
}

final class PanelStatusTests: XCTestCase {
    func testObservedValues() {
        XCTAssertFalse(PanelStatus.isDark(0x1))
        XCTAssertTrue(PanelStatus.isDark(0x5))
        XCTAssertFalse(PanelStatus.isDark(0x0))
    }
}

final class LaunchctlOutputTests: XCTestCase {
    func testRunningPID() {
        let running = """
            gui/501/x.y = {
            \tactive count = 1
            \tstate = running
            \tpid = 4242
            \tendpoints = {
            \t\tstate = active
            \t}
            }
            """
        XCTAssertEqual(LaunchctlOutput.runningPID(inPrint: running), 4242)
    }

    func testIgnoresNestedState() {
        let nested = "gui/501/x.y = {\n\tstate = waiting\n\tendpoints = {\n\t\tstate = running\n\t\tpid = 7\n\t}\n}"
        XCTAssertNil(LaunchctlOutput.runningPID(inPrint: nested))
    }

    func testNotRunning() {
        XCTAssertNil(LaunchctlOutput.runningPID(inPrint: "gui/501/x.y = {\n\tstate = spawn scheduled\n\truns = 3\n}"))
        XCTAssertNil(LaunchctlOutput.runningPID(inPrint: ""))
    }

    func testDisabled() {
        let output = """
            disabled services = {
            \t"com.other" => enabled
            \t"x.y" => disabled
            \t"x.y.z" => enabled
            }
            """
        XCTAssertTrue(LaunchctlOutput.isDisabled(label: "x.y", inPrintDisabled: output))
        XCTAssertFalse(LaunchctlOutput.isDisabled(label: "x.y.z", inPrintDisabled: output))
        XCTAssertFalse(LaunchctlOutput.isDisabled(label: "x", inPrintDisabled: output))
        XCTAssertTrue(LaunchctlOutput.isDisabled(label: "x.y", inPrintDisabled: "\t\"x.y\" => true"))
        XCTAssertFalse(LaunchctlOutput.isDisabled(label: "x.y", inPrintDisabled: ""))
    }
}
