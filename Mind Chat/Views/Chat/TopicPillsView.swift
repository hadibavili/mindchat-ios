import SwiftUI

struct TopicPillsView: View {

    let topics: [ExtractedTopic]
    @State private var visibleCount = 0
    @State private var selectedTopicId: String?
    @State private var selectedTopicName: String?
    @State private var showTopicDetail = false

    private var totalThingsRemembered: Int {
        topics.reduce(0) { $0 + $1.factsAdded }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Summary pill
                if totalThingsRemembered > 0 {
                    SummaryPill(count: totalThingsRemembered)
                        .opacity(visibleCount > 0 ? 1 : 0)
                        .scaleEffect(visibleCount > 0 ? 1 : 0.8)
                        .animation(.spring(duration: 0.3), value: visibleCount)
                }

                // Topic pills with staggered animation
                ForEach(Array(topics.enumerated()), id: \.element.path) { idx, topic in
                    TopicPill(topic: topic) {
                        Task { await lookupAndShow(path: topic.path, name: topic.name) }
                    }
                    .opacity(visibleCount > idx + 1 ? 1 : 0)
                    .scaleEffect(visibleCount > idx + 1 ? 1 : 0.8)
                    .animation(
                        .spring(duration: 0.3).delay(Double(idx + 1) * 0.075),
                        value: visibleCount
                    )
                }
            }
        }
        .onAppear {
            // Trigger staggered appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                visibleCount = topics.count + 1
            }
        }
        .sheet(isPresented: $showTopicDetail) {
            if let topicId = selectedTopicId {
                NavigationStack {
                    TopicDetailView(topicId: topicId, title: selectedTopicName ?? "Topic")
                        .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: TopicWithStats.self) { topic in
                        TopicDetailView(topicId: topic.id, title: topic.name)
                    }
                }
            }
        }
    }

    private func lookupAndShow(path: String, name: String) async {
        guard let topicId = try? await TopicService.shared.lookupTopic(path: path) else { return }
        selectedTopicId   = topicId
        selectedTopicName = name
        showTopicDetail   = true
    }
}

// MARK: - Summary Pill

struct SummaryPill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
            Text(count == 1 ? "1 thing remembered" : "\(count) things remembered")
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Topic Pill

struct TopicPill: View {

    let topic: ExtractedTopic
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if topic.isNew {
                    Image(systemName: "plus")
                        .font(.caption2.bold())
                        .foregroundStyle(topic.isNew ? Color.accentColor : .secondary)
                }

                Text(topic.name)
                    .font(.caption.bold())

                if !topic.isNew && topic.factsAdded > 0 {
                    Text("+\(topic.factsAdded)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.mcBgHover)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                topic.isNew
                    ? Color.accentGreen.opacity(0.08)
                    : Color.mcBgSecondary
            )
            .foregroundStyle(topic.isNew ? Color.accentGreen : Color.mcTextSecondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
