// AppLogger.swift
// FileTabOpenerM
//
// アプリケーションログ管理
// 保存先: ~/Library/Application Support/FileTabOpener/logs/app.log

import Foundation

final class AppLogger {

    enum Level: String {
        case info    = "INFO"
        case warning = "WARN"
        case error   = "ERROR"
    }

    static let shared = AppLogger()

    private let logURL: URL
    private let maxLogSize: Int = 1_048_576  // 1MB
    private let queue = DispatchQueue(label: "com.filetabopener.logger", qos: .utility)

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let logDir = appSupport
            .appendingPathComponent("FileTabOpener")
            .appendingPathComponent("logs")
        logURL = logDir.appendingPathComponent("app.log")

        // ログディレクトリ作成
        try? FileManager.default.createDirectory(
            at: logDir, withIntermediateDirectories: true
        )
    }

    // MARK: - 公開 API

    func info(_ message: String) {
        log(.info, message)
    }

    func warning(_ message: String) {
        log(.warning, message)
    }

    func error(_ message: String) {
        log(.error, message)
    }

    // MARK: - 内部

    private func log(_ level: Level, _ message: String) {
        queue.async { [self] in
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

            rotateIfNeeded()

            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    if let data = line.data(using: .utf8) {
                        handle.write(data)
                    }
                    handle.closeFile()
                }
            } else {
                try? line.data(using: .utf8)?.write(to: logURL)
            }

            #if DEBUG
            print(line, terminator: "")
            #endif
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let size = attrs[.size] as? Int,
              size > maxLogSize else { return }

        let backupURL = logURL.deletingLastPathComponent()
            .appendingPathComponent("app.log.1")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: logURL, to: backupURL)
    }
}

// MARK: - 便利グローバル関数

func logInfo(_ message: String) { AppLogger.shared.info(message) }
func logWarning(_ message: String) { AppLogger.shared.warning(message) }
func logError(_ message: String) { AppLogger.shared.error(message) }
