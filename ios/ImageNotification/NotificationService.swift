import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var currentDownloadTask: URLSessionDownloadTask?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    guard let bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    guard let imageURL = extractImageURL(from: bestAttemptContent.userInfo) else {
      contentHandler(bestAttemptContent)
      return
    }

    downloadAttachment(from: imageURL) { [weak self] attachment in
      guard let self else { return }

      if let attachment {
        bestAttemptContent.attachments = [attachment]
      }

      self.contentHandler?(bestAttemptContent)
      self.cleanup()
    }
  }

  override func serviceExtensionTimeWillExpire() {
    currentDownloadTask?.cancel()

    if let contentHandler, let bestAttemptContent {
      contentHandler(bestAttemptContent)
    }

    cleanup()
  }

  private func cleanup() {
    contentHandler = nil
    bestAttemptContent = nil
    currentDownloadTask = nil
  }

  private func extractImageURL(from userInfo: [AnyHashable: Any]) -> URL? {
    let directKeys = [
      "image_url",
      "image",
      "gcm.notification.image",
      "gcm.notification.imageUrl",
    ]

    for key in directKeys {
      if let value = userInfo[key] as? String,
         let url = normalizedURL(from: value) {
        return url
      }
    }

    if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
       let image = fcmOptions["image"] as? String,
       let url = normalizedURL(from: image) {
      return url
    }

    if let nestedData = userInfo["data"] as? [String: Any] {
      for key in directKeys {
        if let value = nestedData[key] as? String,
           let url = normalizedURL(from: value) {
          return url
        }
      }
    }

    return nil
  }

  private func normalizedURL(from value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
      return nil
    }

    guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
      return nil
    }

    return url
  }

  private func downloadAttachment(
    from url: URL,
    completion: @escaping (UNNotificationAttachment?) -> Void
  ) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 20
    configuration.timeoutIntervalForResource = 25

    let session = URLSession(configuration: configuration)
    currentDownloadTask = session.downloadTask(with: url) { temporaryURL, _, _ in
      defer {
        session.finishTasksAndInvalidate()
      }

      guard let temporaryURL else {
        completion(nil)
        return
      }

      let fileManager = FileManager.default
      let fileExtension = self.preferredExtension(from: url)
      let targetDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

      do {
        try fileManager.createDirectory(
          at: targetDirectory,
          withIntermediateDirectories: true
        )

        let targetURL = targetDirectory.appendingPathComponent("push-image\(fileExtension)")
        try? fileManager.removeItem(at: targetURL)
        try fileManager.moveItem(at: temporaryURL, to: targetURL)

        let attachment = try UNNotificationAttachment(
          identifier: "habito-push-image",
          url: targetURL
        )
        completion(attachment)
      } catch {
        completion(nil)
      }
    }

    currentDownloadTask?.resume()
  }

  private func preferredExtension(from url: URL) -> String {
    let pathExtension = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !pathExtension.isEmpty else {
      return ".jpg"
    }

    return ".\(pathExtension.lowercased())"
  }
}
