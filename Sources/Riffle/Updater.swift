import AppKit

// In-app updater backed by GitHub Releases. Riffle ships as an ad-hoc-signed
// app built from source, so there's no App Store / Sparkle appcast — instead we
// read the repo's "latest release", compare its tag against the bundled
// version, and (on request) download the attached .zip, swap it into place, and
// relaunch. No third-party dependency, in keeping with the rest of the app.
enum Updater {
    private static let owner = "aminaryan80"
    private static let repo = "riffle"

    private static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    // GitHub rejects API requests without a User-Agent.
    private static let userAgent = "Riffle-Updater"

    private static var isRunning = false

    // MARK: - Entry points

    /// Menu-driven check: always tells the user the outcome.
    static func checkForUpdates() {
        check(userInitiated: true)
    }

    /// Launch-time check: stays silent unless there's actually an update.
    static func checkForUpdatesInBackground() {
        check(userInitiated: false)
    }

    // MARK: - Check

    private static func check(userInitiated: Bool) {
        // Guard against overlapping runs (e.g. clicking the menu mid-download).
        guard !isRunning else {
            if userInitiated { NSApp.activate(ignoringOtherApps: true) }
            return
        }
        isRunning = true

        fetchLatestRelease { result in
            switch result {
            case .failure(let error):
                if userInitiated { presentError(error) }
                isRunning = false
            case .success(let release):
                guard isNewer(release.tagName, than: currentVersion) else {
                    if userInitiated { presentUpToDate() }
                    isRunning = false
                    return
                }
                guard let asset = zipAsset(in: release) else {
                    // A newer tag exists but has no installable .zip attached.
                    if userInitiated { presentManualUpdate(release) }
                    isRunning = false
                    return
                }
                // presentUpdatePrompt owns isRunning from here: it stays true
                // through a running download and is cleared on its completion.
                presentUpdatePrompt(release, asset: asset)
            }
        }
    }

    private static func fetchLatestRelease(_ completion: @escaping (Result<Release, Error>) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            let outcome: Result<Release, Error>
            if let error {
                outcome = .failure(error)
            } else if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                outcome = .failure(UpdaterError.noReleases)
            } else if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                outcome = .failure(UpdaterError.http(http.statusCode))
            } else if let data {
                do {
                    let release = try JSONDecoder().decode(Release.self, from: data)
                    outcome = .success(release)
                } catch {
                    outcome = .failure(error)
                }
            } else {
                outcome = .failure(UpdaterError.emptyResponse)
            }
            DispatchQueue.main.async { completion(outcome) }
        }.resume()
    }

    // MARK: - Prompts

    private static func presentUpdatePrompt(_ release: Release, asset: Asset) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Riffle \(release.displayVersion) is available"
        alert.informativeText = releaseSummary(release)
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Later")
        if release.htmlURL != nil {
            alert.addButton(withTitle: "Release Notes")
        }
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            SelfUpdate.download(asset: asset, version: release.displayVersion) { isRunning = false }
        case .alertThirdButtonReturn:
            if let urlString = release.htmlURL, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
            isRunning = false
        default:
            isRunning = false
        }
    }

    private static func presentManualUpdate(_ release: Release) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Riffle \(release.displayVersion) is available"
        alert.informativeText = "This release has no downloadable app attached, so it can't be "
            + "installed automatically. Open the release page to update manually."
        alert.addButton(withTitle: "Open Release Page")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn,
           let urlString = release.htmlURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private static func presentUpToDate() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "Riffle \(currentVersion) is the latest version."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func presentError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = (error as? UpdaterError)?.message ?? error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func releaseSummary(_ release: Release) -> String {
        var text = "You have \(currentVersion)."
        if let body = release.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            let trimmed = body.count > 500 ? String(body.prefix(500)) + "…" : body
            text += "\n\n" + trimmed
        }
        return text
    }

    // MARK: - Helpers

    private static func zipAsset(in release: Release) -> Asset? {
        release.assets.first { $0.name.lowercased().hasSuffix(".zip") }
    }

    /// Compares dotted version strings ("v1.2" > "1.1.9"), tolerating a leading
    /// "v" and differing component counts.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        components(candidate).lexicographicallyPrecedes(components(current)) == false
            && components(candidate) != components(current)
    }

    private static func components(_ version: String) -> [Int] {
        let cleaned = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        return cleaned.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}

// MARK: - Model

extension Updater {
    struct Release: Decodable {
        let tagName: String
        let name: String?
        let body: String?
        let htmlURL: String?
        let assets: [Asset]

        var displayVersion: String {
            name?.isEmpty == false ? name! : tagName
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name, body, assets
            case htmlURL = "html_url"
        }
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum UpdaterError: Error {
        case noReleases
        case http(Int)
        case emptyResponse

        var message: String {
            switch self {
            case .noReleases:
                return "No releases have been published yet."
            case .http(let code):
                return "GitHub returned an unexpected response (HTTP \(code))."
            case .emptyResponse:
                return "GitHub returned an empty response."
            }
        }
    }
}

// MARK: - Download & install

/// Downloads the release zip with a small progress HUD, then hands off to a
/// detached shell script that waits for this process to quit, swaps the app
/// bundle in place, and relaunches it.
private final class SelfUpdate: NSObject, URLSessionDownloadDelegate {
    private static var active: SelfUpdate?

    private let version: String
    private let onFinish: () -> Void
    private let progress = UpdateProgressWindowController()

    private init(version: String, onFinish: @escaping () -> Void) {
        self.version = version
        self.onFinish = onFinish
    }

    static func download(asset: Updater.Asset, version: String, onFinish: @escaping () -> Void) {
        guard let url = URL(string: asset.browserDownloadURL) else {
            onFinish()
            return
        }
        let updater = SelfUpdate(version: version, onFinish: onFinish)
        active = updater
        updater.start(url: url)
    }

    private func start(url: URL) {
        progress.show(title: "Downloading Riffle \(version)…")
        var request = URLRequest(url: url)
        request.setValue("Riffle-Updater", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        session.downloadTask(with: request).resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.progress.setProgress(fraction) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // The temp file is deleted when this callback returns, so move it first.
        let fileManager = FileManager.default
        let work = fileManager.temporaryDirectory.appendingPathComponent("riffle-update-\(UUID().uuidString)")
        let zipURL = work.appendingPathComponent("Riffle.zip")
        do {
            try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
            try fileManager.moveItem(at: location, to: zipURL)
            try install(zipURL: zipURL, in: work)
        } catch {
            DispatchQueue.main.async { self.fail(error) }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        DispatchQueue.main.async { self.fail(error) }
    }

    private func install(zipURL: URL, in work: URL) throws {
        DispatchQueue.main.async { self.progress.setIndeterminate(title: "Installing…") }

        let extractDir = work.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, extractDir.path])

        guard let newApp = firstApp(in: extractDir) else {
            throw NSError(domain: "Riffle", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The downloaded update didn't contain Riffle.app."])
        }

        let currentApp = Bundle.main.bundlePath
        let script = work.appendingPathComponent("swap.sh")
        try swapScript(currentApp: currentApp, newApp: newApp.path).write(to: script, atomically: true, encoding: .utf8)

        // Detach the swap so it outlives us, then quit so the bundle is free to
        // be replaced. The script relaunches the new copy.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        try process.run()

        DispatchQueue.main.async {
            self.progress.close()
            NSApp.terminate(nil)
        }
    }

    private func swapScript(currentApp: String, newApp: String) -> String {
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? "com.amin.riffle"
        // ad-hoc signatures change every build, so macOS treats the updated app
        // as a different binary and the old Accessibility grant goes stale
        // (toggle looks on but does nothing). Reset it so the relaunched app
        // re-prompts cleanly — same reasoning as install.sh.
        return """
        #!/bin/bash
        set -e
        APP_PATH=\(shellQuote(currentApp))
        NEW_APP=\(shellQuote(newApp))
        for _ in $(seq 1 100); do
          kill -0 \(pid) 2>/dev/null || break
          sleep 0.1
        done
        rm -rf "$APP_PATH"
        ditto "$NEW_APP" "$APP_PATH"
        xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
        tccutil reset Accessibility \(shellQuote(bundleID)) 2>/dev/null || true
        open "$APP_PATH"
        """
    }

    private func firstApp(in directory: URL) -> URL? {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        return contents?.first { $0.pathExtension == "app" }
    }

    private func run(_ launchPath: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Riffle", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(launchPath) failed (\(process.terminationStatus))."])
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func fail(_ error: Error) {
        progress.close()
        let alert = NSAlert()
        alert.messageText = "Update failed"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        onFinish()
        SelfUpdate.active = nil
    }
}

// MARK: - Progress HUD

private final class UpdateProgressWindowController {
    private var window: NSWindow?
    private var label: NSTextField?
    private var bar: NSProgressIndicator?

    func show(title: String) {
        let width: CGFloat = 320, height: CGFloat = 90
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Riffle"
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating

        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 20, y: 50, width: width - 40, height: 20)
        label.font = .systemFont(ofSize: 13)

        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 24, width: width - 40, height: 16))
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        bar.doubleValue = 0

        window.contentView?.addSubview(label)
        window.contentView?.addSubview(bar)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        self.label = label
        self.bar = bar
    }

    func setProgress(_ fraction: Double) {
        bar?.isIndeterminate = false
        bar?.doubleValue = fraction
    }

    func setIndeterminate(title: String) {
        label?.stringValue = title
        bar?.isIndeterminate = true
        bar?.startAnimation(nil)
    }

    func close() {
        bar?.stopAnimation(nil)
        window?.close()
        window = nil
    }
}
