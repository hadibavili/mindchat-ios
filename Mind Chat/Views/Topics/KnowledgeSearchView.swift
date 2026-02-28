import SwiftUI

struct KnowledgeSearchView: View {

    @StateObject private var vm = SearchViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Try \"favorite food\" or \"work goals\"...", text: $vm.query)
                    .autocorrectionDisabled()
                if !vm.query.isEmpty {
                    Button {
                        vm.query   = ""
                        vm.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.mcBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: vm.query) { _, q in vm.onQueryChanged(q) }

            if !vm.query.isEmpty {
                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TypeFilterPill(label: "All", isSelected: vm.selectedType == nil) {
                            vm.selectedType = nil
                            Task { await vm.performSearch() }
                        }
                        ForEach(FactType.allCases) { type in
                            TypeFilterPill(label: type.label, isSelected: vm.selectedType == type) {
                                vm.selectedType = vm.selectedType == type ? nil : type
                                Task { await vm.performSearch() }
                            }
                        }
                    }
                }

                // Results
                if vm.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding()
                } else if vm.results.isEmpty {
                    Text("No results for \"\(vm.query)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(vm.groupedResults) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TopicIconView(iconName: group.topicIcon ?? group.topicName, size: 20)
                                Text(group.topicName).font(.subheadline.bold())
                                Spacer()
                                Text("\(group.facts.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(group.facts) { result in
                                Text(highlighted(text: result.factContent ?? "", query: vm.query))
                                    .font(.caption)
                                    .padding(.leading, 26)
                                    .lineLimit(2)
                            }
                        }
                        .padding(10)
                        .background(Color.mcBgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func highlighted(text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lower = text.lowercased()
        let q     = query.lowercased()
        var range = lower.startIndex..<lower.endIndex
        while let found = lower.range(of: q, options: .caseInsensitive, range: range) {
            if let attrRange = Range(found, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow.withAlphaComponent(0.4)
            }
            range = found.upperBound..<lower.endIndex
        }
        return attributed
    }
}
