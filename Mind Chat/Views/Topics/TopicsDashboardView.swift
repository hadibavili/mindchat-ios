import SwiftUI

struct TopicsDashboardView: View {

    @StateObject private var vm = TopicsViewModel()
    @Environment(\.dismiss) private var dismiss
    let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Stats header
                    if vm.totalTopics > 0 || vm.totalFacts > 0 {
                        HStack(spacing: 12) {
                            StatPill(label: "Topics", value: vm.totalTopics, icon: "folder.fill")
                            StatPill(label: "Facts",  value: vm.totalFacts,  icon: "brain")
                        }
                        .padding(.horizontal)
                    }

                    // Search
                    KnowledgeSearchView()
                        .padding(.horizontal)

                    if vm.isLoading && vm.rootTopics.isEmpty {
                        SkeletonGrid()
                    } else if let error = vm.errorMessage {
                        // Error state with retry
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.accentOrange)
                            Text("Couldn't load topics")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await vm.load() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                    } else if vm.rootTopics.isEmpty {
                        TopicsEmptyState()
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(vm.rootTopics.enumerated()), id: \.element.id) { index, topic in
                                NavigationLink(value: topic) {
                                    TopicCardView(topic: topic)
                                }
                                .buttonStyle(CardPressStyle())
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .animation(
                                    .spring(duration: 0.4).delay(Double(index) * 0.05),
                                    value: vm.rootTopics.count
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Knowledge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: TopicTreeNode.self) { node in
                TopicDetailView(topicId: node.id, title: node.name)
            }
            .navigationDestination(for: TopicWithStats.self) { topic in
                TopicDetailView(topicId: topic.id, title: topic.name)
            }
            .refreshable { await vm.refresh() }
            .task { await vm.load() }
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: Int
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)").font(.headline.bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.mcBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty State

struct TopicsEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.opacity(0.5))
            Text("No memories yet")
                .font(.title3.bold())
            Text("Start a conversation and MindChat will automatically extract and organise your knowledge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                ForEach(["Facts", "Preferences", "Goals"], id: \.self) { pill in
                    Text(pill)
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skeleton Grid

struct SkeletonGrid: View {
    let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonView()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal)
    }
}
