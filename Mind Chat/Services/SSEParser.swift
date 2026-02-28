import Foundation

// MARK: - SSE Parser
//
// The server sends every event as a single line:
//   data: {"type":"token","content":"Hello"}\n
//
// Each data: line is a self-contained event — no blank-line separator.
// The event type is embedded as "type" inside the JSON payload.

struct SSEParser {

    static func parse(_ bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            // Run the byte loop in a plain (non-detached) Task so it inherits the
            // caller's task priority but does NOT hold the @MainActor lock.
            // AsyncThrowingStream's closure runs outside any actor context.
            Task {
                do {
                    var lineCount = 0
                    for try await line in bytes.lines {
                        lineCount += 1
                        // Log every raw line (trim to 120 chars to avoid log spam on long tokens)
                        let preview = line.count > 120 ? String(line.prefix(120)) + "…" : line
                        print("[SSEParser] line \(lineCount): \(preview)")

                        guard line.hasPrefix("data:") else { continue }

                        let payload = String(line.dropFirst("data:".count))
                            .trimmingCharacters(in: .whitespaces)

                        if payload == "[DONE]" {
                            print("[SSEParser] [DONE] received")
                            continuation.yield(.done)
                            continuation.finish()
                            return
                        }

                        if let event = parseJSON(payload) {
                            continuation.yield(event)
                            if case .done = event {
                                print("[SSEParser] done event parsed")
                                continuation.finish()
                                return
                            }
                        } else {
                            print("[SSEParser] WARNING — could not parse payload: \(payload.prefix(120))")
                        }
                    }
                    print("[SSEParser] bytes.lines exhausted after \(lineCount) lines")
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Parse a single data: payload

    private static func parseJSON(_ raw: String) -> SSEEvent? {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return nil }

        switch type {
        case "conversation_id":
            guard let id = json["id"] as? String else { return nil }
            return .conversationId(id)

        case "conversation_title":
            guard let title = json["title"] as? String else { return nil }
            return .conversationTitle(title)

        case "token":
            let content = json["content"] as? String ?? ""
            return .token(content)

        case "searching":
            return .searching

        case "search_complete":
            let query   = json["query"] as? String ?? ""
            let sources = (json["sources"] as? [[String: Any]] ?? []).compactMap { s -> SearchSource? in
                guard let title = s["title"] as? String, let url = s["url"] as? String else { return nil }
                return SearchSource(title: title, url: url)
            }
            return .searchComplete(query: query, sources: sources)

        case "extracting":
            return .extracting

        case "topics_extracted":
            let topics = (json["topics"] as? [[String: Any]] ?? []).compactMap { t -> ExtractedTopic? in
                guard let path = t["path"] as? String else { return nil }
                return ExtractedTopic(
                    path: path,
                    name: t["name"] as? String ?? path,
                    isNew: t["isNew"] as? Bool ?? false,
                    factsAdded: t["factsAdded"] as? Int ?? 0
                )
            }
            return .topicsExtracted(topics)

        case "done":
            return .done

        case "error":
            let msg = json["content"] as? String ?? json["message"] as? String ?? "Unknown error"
            return .error(msg)

        default:
            return nil
        }
    }
}
