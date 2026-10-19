import BlankBarCore
import Foundation

let agent = LaunchAgent()

let notRunningHint = """
    To see why, run: log show --info --last 5m --predicate 'subsystem == "\(BlankBar.agentLabel)"'
    If blankbar is switched off in Login Items (System Settings > General), switch it on and run 'blankbar install' again.
    """

func install() {
    let touchBar = requireTouchBar()
    let executable = installExecutable()

    // Darken first, so the bar is off even if the agent cannot be set up.
    guard touchBar.set(on: false) else {
        Output.fail("the Touch Bar refused to switch off", code: .software)
    }
    do {
        // Replace whatever is loaded: an earlier version, or a plist pointing elsewhere.
        try agent.bootout()
        try agent.writePlist(executable: executable)
        try agent.enable()
        try agent.bootstrap()
    } catch {
        Output.fail("the Touch Bar is off, but it will light up again after sleep: \(error)")
    }
    guard agent.waitUntilRunning(timeout: 5) else {
        Output.fail("the Touch Bar is off, but the background agent is not running, so it will light up again after sleep.\n\(notRunningHint)")
    }
    Output.print("""
        Touch Bar is off and will stay off after sleep and login.
        Turn it back on with 'blankbar on'. Remove everything with 'blankbar uninstall'.
        """)
}

/// The path the agent will start at every login. Refuses a path another local user
/// could replace, since that would let them run code as this user.
func installExecutable() -> String {
    let current = ExecutablePath.absolute(System.executablePath, currentDirectory: FileManager.default.currentDirectoryPath)
    guard let resolved = System.resolve(current) else {
        Output.fail("could not find the blankbar executable at \(current)")
    }
    // Prefer Homebrew's version-independent opt link, if it really leads to this binary.
    var executable = ExecutablePath.stable(resolved: resolved)
    if System.resolve(executable) != resolved {
        executable = resolved
    }

    let trusted = System.trustedUIDs
    for (path, followLast) in [(executable, false), (resolved, true)] {
        guard let chain = System.ownershipChain(path, followLast: followLast) else {
            Output.fail("could not check the permissions of \(path)")
        }
        if let problem = PathSafety.problem(with: chain, trustedUIDs: trusted) {
            Output.fail("""
                refusing to install: \(problem), so another user could replace blankbar and run code as you at every login.
                Install blankbar with Homebrew or 'make install', or fix the permissions, and run 'blankbar install' again.
                """)
        }
    }

    let temporary = ["/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/"]
    // Refused, not warned: once a temporary folder is cleaned, another user could
    // recreate the path and the agent would run their file at the next login.
    if temporary.contains(where: resolved.hasPrefix) {
        Output.fail("refusing to install from a temporary folder (\(resolved)). Install blankbar with Homebrew or 'make install' first.")
    }
    if resolved.contains("/.build/") {
        Output.warn("""
            the background agent will run blankbar from \(executable).
            If that file is moved or deleted, the Touch Bar will no longer be kept off.
            Install blankbar with Homebrew or 'make install' and run 'blankbar install' again.
            """)
    }
    return executable
}

func turnOff() {
    let touchBar = requireTouchBar()
    // Darken first, so the bar is off even if the agent cannot be resumed.
    guard touchBar.set(on: false) else {
        Output.fail("the Touch Bar refused to switch off", code: .software)
    }
    guard agent.isPresent else {
        Output.print("""
            Touch Bar is off until the next sleep or restart.
            Run 'blankbar install' to keep it off.
            """)
        return
    }
    guard agent.isInstalled else {
        Output.fail("the Touch Bar is off, but the background agent's file is missing. Run 'blankbar install' to repair it.")
    }
    do {
        try agent.enable()
        try agent.bootstrap()
    } catch {
        Output.fail("the Touch Bar is off, but it will light up again after sleep: \(error)")
    }
    if let executable = agent.installedExecutable, !FileManager.default.isExecutableFile(atPath: executable) {
        Output.fail("the Touch Bar is off, but the background agent points to \(executable), which no longer exists. Run 'blankbar install' to repair it.")
    }
    guard agent.waitUntilRunning(timeout: 5) else {
        Output.fail("the Touch Bar is off, but the background agent is not running, so it will light up again after sleep.\n\(notRunningHint)")
    }
    Output.print("Touch Bar is off and will stay off after sleep and login.")
}

func turnOn() {
    let touchBar = requireTouchBar()
    if agent.isPresent {
        do {
            // Stop the daemon first, or it switches the bar straight back off.
            try agent.disable()
            try agent.bootout()
        } catch {
            Output.fail("\(error)")
        }
    }
    guard touchBar.set(on: true) else {
        Output.fail("the Touch Bar refused to switch on", code: .software)
    }
    if agent.isInstalled {
        Output.print("Touch Bar is on. It will stay on, even after a restart, until you run 'blankbar off'.")
    } else {
        Output.print("Touch Bar is on.")
    }
}

func uninstall() {
    let wasPresent = agent.isPresent
    do {
        try agent.bootout()
        try agent.removePlist()
        // Clear the persistent override 'blankbar on' may have left in launchd.
        if agent.isDisabled { try agent.enable() }
    } catch {
        Output.fail("\(error)")
    }
    Output.print(wasPresent ? "Background agent removed." : "No background agent was installed.")

    // Light the bar again, but do not fail an uninstall on a Mac where that is impossible.
    if System.hasTouchBar {
        if let touchBar = try? TouchBar(), touchBar.set(on: true) {
            Output.print("Touch Bar is on.")
        } else {
            Output.warn("could not switch the Touch Bar on. Restarting the Mac will.")
        }
    }
    Output.print("To remove the blankbar command too: 'brew uninstall blankbar', or 'make uninstall' in the source folder.")
}

func status() {
    let model = System.model ?? "unknown"
    let panel: String
    if !Hardware.hasTouchBar(model: model) {
        panel = "none on this Mac (\(model))"
    } else if let touchBar = try? TouchBar() {
        panel = touchBar.isDark ? "off" : "on"
    } else {
        panel = "unknown (this macOS is not supported)"
    }

    let keepOff: String
    if !agent.isPresent {
        keepOff = "not installed (run 'blankbar install')"
    } else if !agent.isInstalled {
        keepOff = "agent file missing (run 'blankbar install' to repair)"
    } else if agent.isDisabled {
        keepOff = "paused (run 'blankbar off' to resume)"
    } else if let pid = agent.runningPID {
        keepOff = "active (pid \(pid))"
    } else if !Hardware.hasTouchBar(model: model) {
        keepOff = "installed but not needed on this Mac (run 'blankbar uninstall')"
    } else {
        keepOff = "installed but not running (run 'blankbar install' to repair)"
    }

    Output.print("""
        blankbar \(BlankBar.version)
        Touch Bar:  \(panel)
        Keep off:   \(keepOff)
        """)
    if let executable = agent.installedExecutable, !FileManager.default.isExecutableFile(atPath: executable) {
        Output.warn("the background agent points to \(executable), which no longer exists. Run 'blankbar install' again.")
    }
}

func runDaemon() -> Never {
    // Exit cleanly, not crash, when unsupported: the agent restarts only after a crash.
    guard System.hasTouchBar else {
        Output.fail("this Mac (\(System.model ?? "unknown")) does not have a Touch Bar", code: .unavailable)
    }
    do {
        Daemon(touchBar: try TouchBar()).run()
    } catch {
        Output.fail("this version of macOS does not provide the private interface blankbar uses (\(error))", code: .unavailable)
    }
}

switch Command.parse(Array(CommandLine.arguments.dropFirst())) {
case .failure(let error):
    FileHandle.standardError.write(Data("blankbar: error: \(error.message)\n\n\(Command.usage)\n".utf8))
    exit(ExitCode.usage.rawValue)
case .success(.help):
    Output.print(Command.usage)
case .success(.version):
    Output.print("blankbar \(BlankBar.version)")
case .success(let command):
    // The Touch Bar and the agent belong to the logged-in user; as root, launchctl would
    // target root's session and files could end up owned by root in the user's home.
    guard geteuid() != 0 else {
        Output.fail("do not run blankbar with sudo or as root; run it as yourself", code: .usage)
    }
    switch command {
    case .install: install()
    case .off: turnOff()
    case .on: turnOn()
    case .uninstall: uninstall()
    case .status: status()
    case .daemon: runDaemon()
    case .help, .version: break
    }
}
