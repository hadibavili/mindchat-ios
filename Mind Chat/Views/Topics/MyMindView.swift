import SwiftUI

// MARK: - My Mind View (Knowledge Dashboard)

struct MyMindView: View {

    @ObservedObject var topicsVM: TopicsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSearch = false
    @State private var appeared = false

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 28) {

                    // Hero header with stats
                    if topicsVM.totalTopics > 0 || topicsVM.totalFacts > 0 {
                        heroHeader
                    }

                    // Search button
                    searchButton

                    if topicsVM.isLoading && topicsVM.rootTopics.isEmpty {
                        SkeletonGrid()
                    } else if topicsVM.rootTopics.isEmpty {
                        emptyState
                    } else {
                        // Recently Updated
                        if let stats = topicsVM.stats, !stats.recentlyUpdated.isEmpty {
                            topicSection(
                                title: "Recently Updated",
                                icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                topics: stats.recentlyUpdated
                            )
                        }

                        // Most Knowledge
                        if let stats = topicsVM.stats, !stats.topByFactCount.isEmpty {
                            topicSection(
                                title: "Most Knowledge",
                                icon: "star.fill",
                                topics: stats.topByFactCount
                            )
                        }

                        // All Topics fallback (when stats aren't loaded yet)
                        if topicsVM.stats == nil {
                            allTopicsGrid
                        }

                        // Fact type breakdown
                        if let stats = topicsVM.stats {
                            factTypeBreakdown(stats.factsByType)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("My Mind")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: TopicWithStats.self) { topic in
                TopicDetailView(topicId: topic.id, title: topic.name)
                    .navigationDestination(for: TopicWithStats.self) { child in
                        TopicDetailView(topicId: child.id, title: child.name)
                    }
            }
            .navigationDestination(for: TopicTreeNode.self) { node in
                TopicDetailView(topicId: node.id, title: node.name)
                    .navigationDestination(for: TopicWithStats.self) { child in
                        TopicDetailView(topicId: child.id, title: child.name)
                    }
            }
            .refreshable { await topicsVM.refresh() }
            .sheet(isPresented: $showSearch) {
                NavigationStack {
                    MyMindSearchView()
                        .navigationTitle("Search")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showSearch = false }
                            }
                        }
                }
            }
            .onAppear {
                withAnimation(.mcGentle.delay(0.1)) { appeared = true }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(spacing: 14) {
            // Topics stat
            glassStatCard(
                icon: "folder.fill",
                iconColors: [Color.mcTextLink, Color.accentCyan],
                value: topicsVM.totalTopics,
                label: "Topics"
            )

            // Memories stat
            glassStatCard(
                icon: "brain.head.profile",
                iconColors: [Color.accentPurple, Color.accentPink],
                value: topicsVM.totalFacts,
                label: "Memories"
            )
        }
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func glassStatCard(icon: String, iconColors: [Color], value: Int, label: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: iconColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .monospacedDigit()

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Search Button

    private var searchButton: some View {
        Button {
            showSearch = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Search your knowledge...")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(CardPressStyle())
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    // MARK: - Topic Section (Recently Updated / Most Knowledge)

    private func topicSection(title: String, icon: String, topics: [TopicWithStats]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(topics.prefix(8).enumerated()), id: \.element.id) { index, topic in
                    NavigationLink(value: topic) {
                        MyMindTopicCard(topic: topic)
                    }
                    .buttonStyle(CardPressStyle())
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(
                        .spring(duration: 0.4).delay(Double(index) * 0.04),
                        value: topics.count
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - All Topics Grid (fallback)

    private var allTopicsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Topics")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(topicsVM.rootTopics.enumerated()), id: \.element.id) { index, topic in
                    NavigationLink(value: topic) {
                        TopicCardView(topic: topic)
                    }
                    .buttonStyle(CardPressStyle())
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(
                        .spring(duration: 0.4).delay(Double(index) * 0.04),
                        value: topicsVM.rootTopics.count
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Fact Type Breakdown

    private func factTypeBreakdown(_ counts: FactTypeCounts) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("By Type")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                factTypeRow("Facts", count: counts.fact, color: Color.factFact, icon: "lightbulb.fill", isFirst: true)
                factTypeRow("Preferences", count: counts.preference, color: Color.factPreference, icon: "heart.fill")
                factTypeRow("Goals", count: counts.goal, color: Color.factGoal, icon: "target")
                factTypeRow("Experiences", count: counts.experience, color: Color.factExperience, icon: "star.fill", isLast: true)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private func factTypeRow(_ label: String, count: Int, color: Color, icon: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(.subheadline)

                Spacer()

                Text("\(count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            if !isLast {
                Divider()
                    .padding(.leading, 58)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentPurple.opacity(0.12), Color.mcTextLink.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "brain")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentPurple, Color.mcTextLink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("Your mind is empty")
                    .font(.title3.bold())
                Text("Start a conversation and MindChat will automatically organize everything you share into topics and memories.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Come back anytime to browse what you know.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - My Mind Topic Card

struct MyMindTopicCard: View {

    let topic: TopicWithStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                TopicIconView(iconName: topic.icon ?? topic.name, size: 36)
                Spacer()
                if topic.factCount > 0 {
                    Text("\(topic.factCount)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.accentGreen.gradient)
                        )
                }
            }

            Text(topic.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if let summary = topic.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let updated = topic.updatedAt {
                Text(updated.relativeDisplay)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - My Mind Search View

struct MyMindSearchView: View {

    @StateObject private var vm = SearchViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search your knowledge...", text: $vm.query)
                    .autocorrectionDisabled()
                    .font(.system(size: 16))
                if !vm.query.isEmpty {
                    Button {
                        vm.query = ""
                        vm.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .onChange(of: vm.query) { _, q in vm.onQueryChanged(q) }

            if !vm.query.isEmpty {
                // Type filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        GlassFilterPill(label: "All", isSelected: vm.selectedType == nil) {
                            vm.selectedType = nil
                            Task { await vm.performSearch() }
                        }
                        ForEach(FactType.allCases) { type in
                            GlassFilterPill(label: type.label, isSelected: vm.selectedType == type) {
                                vm.selectedType = vm.selectedType == type ? nil : type
                                Task { await vm.performSearch() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Results
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if vm.isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.vertical, 40)
                        } else if vm.results.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(.tertiary)
                                Text("No results for \"\(vm.query)\"")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Topic results
                            let topicResults = vm.results.filter { $0.type == .topic }
                            if !topicResults.isEmpty {
                                Text("TOPICS")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 4)

                                VStack(spacing: 0) {
                                    ForEach(Array(topicResults.enumerated()), id: \.element.id) { index, result in
                                        NavigationLink {
                                            TopicDetailView(topicId: result.topicId, title: result.topicName)
                                        } label: {
                                            VStack(spacing: 0) {
                                                HStack(spacing: 12) {
                                                    TopicIconView(iconName: result.topicIcon ?? result.topicName, size: 28)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(result.topicName)
                                                            .font(.subheadline.weight(.medium))
                                                        Text(result.topicPath)
                                                            .font(.caption)
                                                            .foregroundStyle(.tertiary)
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundStyle(.quaternary)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)

                                                if index < topicResults.count - 1 {
                                                    Divider().padding(.leading, 56)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal, 16)
                            }

                            // Fact results grouped by topic
                            if !vm.groupedResults.isEmpty {
                                Text("MEMORIES")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, topicResults.isEmpty ? 4 : 12)

                                ForEach(vm.groupedResults) { group in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 10) {
                                            TopicIconView(iconName: group.topicIcon ?? group.topicName, size: 22)
                                            Text(group.topicName)
                                                .font(.footnote.weight(.semibold))
                                            Spacer()
                                            Text("\(group.facts.count)")
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(.tertiary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(.quaternary.opacity(0.3)))
                                        }

                                        ForEach(group.facts) { fact in
                                            HStack(alignment: .top, spacing: 10) {
                                                Circle()
                                                    .fill(Color.factTypeColor(fact.factType ?? .fact))
                                                    .frame(width: 6, height: 6)
                                                    .padding(.top, 6)
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(highlighted(text: fact.factContent ?? "", query: vm.query))
                                                        .font(.caption)
                                                        .lineLimit(2)
                                                    if let imp = fact.importance {
                                                        Text(imp.label)
                                                            .font(.caption2)
                                                            .foregroundStyle(.tertiary)
                                                    }
                                                }
                                            }
                                            .padding(.leading, 32)
                                        }
                                    }
                                    .padding(14)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                }
            } else {
                Spacer()
            }
        }
    }

    private func highlighted(text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lower = text.lowercased()
        let q = query.lowercased()
        var range = lower.startIndex..<lower.endIndex
        while let found = lower.range(of: q, options: .caseInsensitive, range: range) {
            if let attrRange = Range(found, in: attributed) {
                attributed[attrRange].backgroundColor = UIColor(Color.searchHighlight)
            }
            range = found.upperBound..<lower.endIndex
        }
        return attributed
    }
}

// MARK: - Glass Filter Pill

private struct GlassFilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.mcTextPrimary)
                    }
                }
                .glassEffect(isSelected ? .clear : .regular, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.mcSnappy, value: isSelected)
    }
}
