import SwiftUI

struct TopicDetailView: View {

    let topicId: String
    let title: String

    @StateObject private var vm: TopicDetailViewModel
    @State private var showMerge = false

    init(topicId: String, title: String) {
        self.topicId = topicId
        self.title   = title
        _vm = StateObject(wrappedValue: TopicDetailViewModel(topicId: topicId))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: []) {
                if let detail = vm.detail {
                    // Header
                    TopicHeaderView(topic: detail.topic)

                    // Subtopics
                    if !detail.children.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subtopics")
                                .font(.headline)
                                .padding(.horizontal)
                            let cols = [GridItem(.adaptive(minimum: 140), spacing: 10)]
                            LazyVGrid(columns: cols, spacing: 10) {
                                ForEach(detail.children) { child in
                                    NavigationLink(value: child) {
                                        SmallTopicCard(topic: child)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Knowledge
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Knowledge")
                            .font(.headline)
                            .padding(.horizontal)

                        FactFilterBar(vm: vm)

                        if vm.filteredFacts.isEmpty {
                            Text("Nothing saved here yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(vm.filteredFacts) { fact in
                                FactItemView(fact: fact, vm: vm)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Related
                    if let related = detail.relatedTopics, !related.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Topics")
                                .font(.headline)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(related) { rel in
                                        RelatedTopicPill(topic: rel)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Merge
                    Button {
                        showMerge = true
                    } label: {
                        Label("Move to another topic…", systemImage: "arrow.triangle.merge")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding()

                } else if vm.isLoading {
                    SkeletonView().frame(height: 300).padding()
                }

                if let err = vm.errorMessage {
                    Text(err).foregroundStyle(Color.accentRed).padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await vm.refresh() }
        .task { await vm.load() }
        .sheet(isPresented: $showMerge) {
            MergeTopicSheet(vm: vm)
        }
    }
}

// MARK: - Topic Header

struct TopicHeaderView: View {
    let topic: TopicWithStats
    var body: some View {
        VStack(spacing: 12) {
            TopicIconView(iconName: topic.icon ?? topic.name, size: 64)
            Text(topic.name).font(.title.bold())
            if let summary = topic.summary {
                Text(summary).font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            HStack(spacing: 16) {
                Label("\(topic.factCount) facts", systemImage: "brain")
                if let sub = topic.subtopicCount {
                    Label("\(sub) subtopics", systemImage: "folder")
                }
            }
            .font(.caption).foregroundStyle(Color.mcTextSecondary)
            if let updated = topic.updatedAt {
                Text(updated.shortFormatted).font(.caption2).foregroundStyle(Color.mcTextTertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Small Topic Card

struct SmallTopicCard: View {
    let topic: TopicWithStats
    var body: some View {
        HStack {
            TopicIconView(iconName: topic.icon ?? topic.name, size: 28)
            VStack(alignment: .leading) {
                Text(topic.name).font(.caption.bold()).lineLimit(1)
                Text("\(topic.factCount) facts").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Related Topic Pill

struct RelatedTopicPill: View {
    let topic: RelatedTopic
    var body: some View {
        HStack(spacing: 6) {
            TopicIconView(iconName: topic.icon ?? topic.name, size: 20)
            Text(topic.name).font(.caption.bold())
            if let rel = topic.relation {
                Text("· \(rel)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.mcBgSecondary)
        .clipShape(Capsule())
    }
}
