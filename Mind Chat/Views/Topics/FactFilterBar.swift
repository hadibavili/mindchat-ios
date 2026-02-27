import SwiftUI

struct FactFilterBar: View {

    @ObservedObject var vm: TopicDetailViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Type tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TypeFilterPill(
                        label: "All (\(vm.facts.count))",
                        isSelected: vm.selectedType == nil
                    ) { vm.selectedType = nil }

                    ForEach(FactType.allCases) { type in
                        let count = vm.count(for: type)
                        TypeFilterPill(
                            label: "\(type.label) (\(count))",
                            isSelected: vm.selectedType == type
                        ) {
                            vm.selectedType = vm.selectedType == type ? nil : type
                        }
                    }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Picker("Sort", selection: $vm.sortOrder) {
                    ForEach(FactSortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Picker("Importance", selection: $vm.selectedImportance) {
                    Text("Any importance").tag(Optional<FactImportance>.none)
                    ForEach([FactImportance.high, .medium, .low], id: \.self) { imp in
                        Text(imp.label).tag(Optional(imp))
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

struct TypeFilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.mcBgSecondary)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
