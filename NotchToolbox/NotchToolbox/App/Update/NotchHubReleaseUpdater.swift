import AppKit
import CryptoKit
import Foundation

/// Direct builds use NotchHub releases; no upstream Maccy/EasyNotch feed is consulted.
@MainActor final class NotchHubReleaseUpdater {
    struct Asset: Decodable { let name: String; let browser_download_url: URL }
    struct Release: Decodable { let tag_name: String; let body: String?; let assets: [Asset] }
    struct Prepared { let application: URL; let version: String; let notes: String }
    private(set) var prepared: Prepared?
    static let latestURL = URL(string: "https://api.github.com/repos/Wangxmian/NotchHub/releases/latest")!
    static func newer(_ tag: String, than current: String) -> Bool {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "v")).compare(current, options: .numeric) == .orderedDescending
    }
    func check() async throws -> Release {
        var request = URLRequest(url: Self.latestURL); request.timeoutInterval = 30
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NotchHub", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Release.self, from: data)
    }
    func prepare(_ release: Release, phase: @escaping (UpdatePhase) -> Void) async throws -> Prepared {
        guard let asset = release.assets.first(where: { $0.name.hasSuffix("-arm64.dmg") }),
              let checks = release.assets.first(where: { $0.name.hasSuffix("SHA256SUMS.txt") }),
              [asset, checks].allSatisfy({ $0.browser_download_url.scheme == "https" && $0.browser_download_url.host == "github.com" }) else { throw CocoaError(.fileReadCorruptFile) }
        phase(.downloading(fraction: nil))
        let (checksumData, response) = try await URLSession.shared.data(from: checks.browser_download_url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let line = String(data: checksumData, encoding: .utf8)?.split(separator: "\n").first(where: { $0.split(whereSeparator: \.isWhitespace).last.map(String.init) == asset.name }),
              let expected = line.split(whereSeparator: \.isWhitespace).first else { throw CocoaError(.fileReadCorruptFile) }
        let (download, downloadResponse) = try await URLSession.shared.download(from: asset.browser_download_url)
        guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let bytes = try Data(contentsOf: download, options: .mappedIfSafe)
        let actual = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw CocoaError(.fileReadCorruptFile) }
        try Task.checkCancellation()
        let scratch = FileManager.default.temporaryDirectory.appending(path: "NotchHub-update-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let disk = scratch.appending(path: "NotchHub.dmg")
        try FileManager.default.moveItem(at: download, to: disk)
        let mount = scratch.appending(path: "mount", directoryHint: .isDirectory)
        phase(.extracting(fraction: nil))
        let application = scratch.appending(path: "NotchHub.app")
        do {
            try await Task.detached {
                try Self.run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-mountpoint", mount.path, disk.path])
                defer { try? Self.run("/usr/bin/hdiutil", ["detach", mount.path]) }
                let source = mount.appending(path: "NotchHub.app")
                guard let bundle = Bundle(url: source), bundle.bundleIdentifier == "io.github.Wangxmian.NotchHub" else { throw CocoaError(.fileReadCorruptFile) }
                try Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", source.path])
                try Self.run("/usr/bin/ditto", [source.path, application.path])
            }.value
            try Task.checkCancellation()
            guard let bundle = Bundle(url: application),
                  bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v")) else { throw CocoaError(.fileReadCorruptFile) }
            let value = Prepared(application: application, version: release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v")), notes: release.body ?? "")
            prepared = value; return value
        } catch { try? FileManager.default.removeItem(at: scratch); throw error }
    }
    func install() throws {
        guard let prepared else { throw CocoaError(.fileNoSuchFile) }
        let current = Bundle.main.bundleURL
        guard current.pathExtension == "app", current.lastPathComponent == "NotchHub.app" else { throw CocoaError(.featureUnsupported) }
        let parent = current.deletingLastPathComponent()
        let staged = parent.appending(path: ".NotchHub-update-\(UUID()).app")
        let backup = parent.appending(path: ".NotchHub-before-update-\(UUID()).app")
        try Self.run("/usr/bin/ditto", [prepared.application.path, staged.path])
        try Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", staged.path])
        let script = prepared.application.deletingLastPathComponent().appending(path: "install.sh")
        let content = """
        #!/bin/bash
        set -eu
        parent_pid="$1"; target="$2"; staged="$3"; backup="$4"
        for ((i=0; i<120; i++)); do
          if ! kill -0 "$parent_pid" 2>/dev/null; then break; fi
          sleep 0.5
        done
        if kill -0 "$parent_pid" 2>/dev/null; then exit 1; fi
        mv "$target" "$backup"
        if mv "$staged" "$target"; then
          if /usr/bin/open "$target"; then exit 0; fi
        fi
        if [ -e "$target" ]; then mv "$target" "$staged"; fi
        mv "$backup" "$target"
        /usr/bin/open "$target"
        """
        try content.write(to: script, atomically: true, encoding: .utf8)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), current.path, staged.path, backup.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
        UserDefaults.standard.set(prepared.version, forKey: "NotchHub.pendingUpdatedVersion")
        NSApp.terminate(nil)
    }
    nonisolated private static func run(_ executable: String, _ args: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = args
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
