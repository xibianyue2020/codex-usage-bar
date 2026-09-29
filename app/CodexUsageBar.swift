import AppKit
import Darwin
import Foundation

private struct UsageWindow {
    let label: String
    let remaining: Int
    let resetAt: Date?
}

private struct UsageSnapshot {
    let windows: [UsageWindow]
    let fetchedAt: Date
}

@MainActor
private final class InstanceLock {
    private let fileDescriptor: Int32?

    init() {
        let supportDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexUsageBar", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        } catch {
            fileDescriptor = nil
            return
        }

        let lockURL = supportDirectory.appendingPathComponent("instance.lock")
        let descriptor = lockURL.path.withCString { Darwin.open($0, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR)) }
        guard descriptor >= 0 else {
            fileDescriptor = nil
            return
        }
        var fileLock = Darwin.flock()
        fileLock.l_type = Int16(F_WRLCK)
        fileLock.l_whence = Int16(SEEK_SET)
        fileLock.l_start = 0
        fileLock.l_len = 0
        guard Darwin.fcntl(descriptor, F_SETLK, &fileLock) != -1 else {
            Darwin.close(descriptor)
            fileDescriptor = nil
            return
        }
        fileDescriptor = descriptor
    }

    var isAcquired: Bool { fileDescriptor != nil }

    deinit {
        if let fileDescriptor {
            Darwin.close(fileDescriptor)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var instanceLock: InstanceLock?
    private var timer: Timer?
    private var snapshot: UsageSnapshot?
    private var lastError: String?
    private var isFetching = false
    private let codexCLI = ProcessInfo.processInfo.environment["CODEX_CLI"] ?? "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let lock = InstanceLock()
        guard lock.isAcquired else {
            NSApplication.shared.terminate(nil)
            return
        }
        instanceLock = lock

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = ""
        statusItem.button?.imagePosition = .imageOnly
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func refresh() {
        guard !isFetching else { return }
        isFetching = true
        let cli = codexCLI
        let delegate = self
        Task.detached(priority: .utility) {
            let result = Self.fetchUsage(codexCLI: cli)
            await MainActor.run {
                delegate.snapshot = result.snapshot
                delegate.lastError = result.error
                delegate.isFetching = false
                delegate.updateTitle()
                if let menu = delegate.statusItem.menu { delegate.rebuildMenu(menu) }
            }
        }
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        let fiveHour = snapshot?.windows.first(where: { $0.label == "5h" })?.remaining
        let weekly = snapshot?.windows.first(where: { $0.label == "周" })?.remaining
        button.image = Self.statusImage(fiveHour: fiveHour, weekly: weekly, isError: lastError != nil)
        button.toolTip = lastError ?? "5 小时剩余：\(fiveHour.map { "\($0)%" } ?? "—") · 周剩余：\(weekly.map { "\($0)%" } ?? "—")"
        button.setAccessibilityLabel(button.toolTip ?? "Codex 用量")
    }

    private static func statusImage(fiveHour: Int?, weekly: Int?, isError: Bool) -> NSImage {
        let labelFont = NSFont.systemFont(ofSize: 9, weight: .medium)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let segments: [(String, String, NSColor)] = [
            ("5h", fiveHour.map { "\($0)%" } ?? (isError ? "!" : "…"), .systemOrange),
            ("周", weekly.map { "\($0)%" } ?? (isError ? "!" : "…"), .systemBlue)
        ]
        let horizontalPadding: CGFloat = 6
        let textGap: CGFloat = 3
        let segmentGap: CGFloat = 4
        let segmentHeight: CGFloat = 18
        let widths = segments.map { label, value, _ in
            ceil((label as NSString).size(withAttributes: [.font: labelFont]).width
                 + textGap
                 + (value as NSString).size(withAttributes: [.font: valueFont]).width
                 + horizontalPadding * 2)
        }
        let imageSize = NSSize(width: widths.reduce(0, +) + segmentGap, height: 20)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        for (index, segment) in segments.enumerated() {
            let x = widths.prefix(index).reduce(0, +) + CGFloat(index) * segmentGap
            let rect = NSRect(x: x, y: (imageSize.height - segmentHeight) / 2, width: widths[index], height: segmentHeight)
            let color = segment.2
            color.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()

            let labelAttributes: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: color]
            let valueAttributes: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: color]
            let labelSize = (segment.0 as NSString).size(withAttributes: labelAttributes)
            let valueSize = (segment.1 as NSString).size(withAttributes: valueAttributes)
            let textY = rect.midY - max(labelSize.height, valueSize.height) / 2
            (segment.0 as NSString).draw(at: NSPoint(x: rect.minX + horizontalPadding, y: textY), withAttributes: labelAttributes)
            (segment.1 as NSString).draw(at: NSPoint(x: rect.minX + horizontalPadding + labelSize.width + textGap, y: textY), withAttributes: valueAttributes)
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        if let snapshot {
            for window in snapshot.windows {
                let reset = window.resetAt.map { Self.resetDescription($0) } ?? "重置时间未知"
                let item = NSMenuItem(title: "\(window.label) 剩余：\(window.remaining)%  ·  \(reset)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            let updated = NSMenuItem(title: "最近更新：\(Self.timeFormatter.string(from: snapshot.fetchedAt))", action: nil, keyEquivalent: "")
            updated.isEnabled = false
            menu.addItem(updated)
        } else {
            let item = NSMenuItem(title: lastError ?? "正在读取 Codex 用量…", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func refreshFromMenu() { refresh() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func resetDescription(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "HH:mm"
            return "重置 \(f.string(from: date))"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return "重置 \(f.string(from: date))"
    }

    nonisolated private static func fetchUsage(codexCLI: String) -> (snapshot: UsageSnapshot?, error: String?) {
        guard FileManager.default.isExecutableFile(atPath: codexCLI) else {
            return (nil, "找不到 Codex CLI，请重新安装或运行安装脚本")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexCLI)
        process.arguments = ["app-server", "--stdio"]
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            let requests: [[String: Any]] = [
                ["method": "initialize", "id": 1, "params": ["clientInfo": ["name": "codex-usage-bar", "title": "Codex Usage Bar", "version": "0.1.1"], "capabilities": NSNull()]],
                ["method": "initialized"],
                ["method": "account/rateLimits/read", "id": 2, "params": ["excludeResetCreditDetails": true]]
            ]
            for request in requests {
                let data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
                input.fileHandleForWriting.write(data)
                input.fileHandleForWriting.write(Data([0x0A]))
            }
            var pending = Data()
            var response: [String: Any]?
            while response == nil {
                let chunk = output.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                pending.append(chunk)
                while let newline = pending.firstIndex(of: 0x0A) {
                    let line = pending.prefix(upTo: newline)
                    pending.removeSubrange(...newline)
                    guard let value = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
                    if value["id"] as? Int == 2 {
                        response = value
                        break
                    }
                }
            }
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            guard let response else {
                let detail = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                return (nil, detail.isEmpty ? "Codex 暂未返回用量数据" : String(detail.prefix(160)))
            }
            if let error = response["error"] as? [String: Any] {
                return (nil, error["message"] as? String ?? "读取用量失败")
            }
            guard let result = response["result"] as? [String: Any] else { return (nil, "用量响应格式无法识别") }
            let snapshots: [[String: Any]]
            if let byID = result["rateLimitsByLimitId"] as? [String: [String: Any]], !byID.isEmpty {
                snapshots = Array(byID.values)
            } else if let legacy = result["rateLimits"] as? [String: Any] {
                snapshots = [legacy]
            } else {
                return (nil, "当前账户没有可用的用量窗口")
            }
            var windows: [UsageWindow] = []
            for quota in snapshots {
                for key in ["primary", "secondary"] {
                    guard let value = quota[key] as? [String: Any],
                          let used = value["usedPercent"] as? Double else { continue }
                    let minutes = value["windowDurationMins"] as? Int
                    let label: String
                    switch minutes {
                    case 300: label = "5h"
                    case 10080: label = "周"
                    case .some(let m): label = "\(m / 60)h"
                    default: label = key == "primary" ? "主要额度" : "次要额度"
                    }
                    let reset = (value["resetsAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
                    windows.append(UsageWindow(label: label, remaining: max(0, min(100, 100 - Int(used.rounded()))), resetAt: reset))
                }
            }
            return windows.isEmpty ? (nil, "账户响应中没有可识别的额度窗口") : (UsageSnapshot(windows: windows, fetchedAt: Date()), nil)
        } catch {
            process.terminate()
            return (nil, error.localizedDescription)
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
