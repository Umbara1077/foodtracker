import SwiftUI

@MainActor
@Observable
final class FoodSearchViewModel {
    private let nutritionRepository: any NutritionRepository

    var query = ""
    var results: [NutritionCandidate] = []
    var isSearching = false
    var errorMessage: String?

    init(nutritionRepository: any NutritionRepository) {
        self.nutritionRepository = nutritionRepository
    }

    func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            results = []
            return
        }
        isSearching = true
        errorMessage = nil
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == text else {
                isSearching = false
                return
            }
            results = try await nutritionRepository.search(
                NutritionSearchQuery(text: text, brand: nil, preparation: nil, locale: .current)
            )
        } catch {
            errorMessage = "Search failed."
        }
        isSearching = false
    }
}

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: FoodSearchViewModel?
    @State private var selectedFood: NutritionFood?
    var onSaved: (() -> Void)?

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    searchContent(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Search foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedFood) { food in
                FoodEditorSheet(food: food) {
                    onSaved?()
                    dismiss()
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = FoodSearchViewModel(nutritionRepository: environment.nutritionRepository)
            }
        }
    }

    @ViewBuilder
    private func searchContent(_ viewModel: FoodSearchViewModel) -> some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                TextField("Search foods", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.query) { _, _ in
                        Task { await viewModel.search() }
                    }
            }

            if viewModel.isSearching {
                Section {
                    ProgressView("Searching…")
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(Color.statusError)
                }
            }

            if !viewModel.results.isEmpty {
                Section("Results") {
                    ForEach(viewModel.results) { candidate in
                        Button {
                            selectedFood = candidate.food
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.food.name)
                                    .foregroundStyle(Color.textPrimary)
                                    .font(Typography.body.weight(.semibold))
                                HStack {
                                    Text(sourceText(candidate.food))
                                    if let serving = candidate.food.serving {
                                        Text("· \(serving.label) (\(Int(serving.grams))g)")
                                    }
                                    Text("· \(Int(candidate.food.per100g.calories)) kcal/100g")
                                }
                                .font(Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
            } else if viewModel.query.count >= 2 && !viewModel.isSearching {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try a simpler food name, like “chicken” or “rice”.")
                )
            }
        }
    }

    private func sourceText(_ food: NutritionFood) -> String {
        switch food.source {
        case .usdaShapedFixture: "USDA-shaped"
        case .usdaFoodDataCentral: "USDA"
        case .openFoodFacts: "OFF"
        case .userCustom: "Custom"
        case .aiEstimate: "Estimate"
        case .nutritionLabelOCR: "Label"
        case .restaurantCatalog: "Restaurant"
        }
    }
}
