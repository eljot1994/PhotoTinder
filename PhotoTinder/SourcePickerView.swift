import SwiftUI
import Photos

struct SourcePickerView: View {
    @ObservedObject var viewModel: PhotoTestViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                // Przełącznik między głównymi typami filtrów
                Picker("Filtr", selection: $viewModel.activeFilterType) {
                    ForEach(PhotoFilterType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Lista opcji dla wybranego typu filtra
                List {
                    // Przycisk "Wyczyść filtry / Pokaż wszystko"
                    clearFilterButton

                    // Dynamicznie wyświetlana lista na podstawie wybranego filtra
                    switch viewModel.activeFilterType {
                    case .albums:
                        sourceListView(for: viewModel.albumSources)
                    case .mediaTypes:
                        // Obecnie brak implementacji, ale struktura jest gotowa
                        Text("Brak typów multimediów do wyświetlenia.")
                            .foregroundColor(.gray)
                    case .categories:
                        // Obecnie brak implementacji, ale struktura jest gotowa
                        Text("Brak kategorii do wyświetlenia.")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Wybierz źródło")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gotowe") {
                        dismiss()
                    }
                }
            }
        }
    }

    // Widok dla przycisku czyszczącego filtry
    private var clearFilterButton: some View {
        Button(action: {
            viewModel.selectedSourceIDs.removeAll()
        }) {
            HStack {
                Text("Wszystkie zdjęcia")
                    .font(.headline)
                Spacer()
                if viewModel.selectedSourceIDs.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .foregroundColor(.primary)
    }

    // Widok dla listy źródeł, reużywalny dla każdej kategorii
    @ViewBuilder
    private func sourceListView(for sources: [PhotoSource]) -> some View {
        ForEach(sources) { source in
            Button(action: {
                toggleSelection(for: source.id)
            }) {
                HStack {
                    Text(source.name)
                    Spacer()
                    Text("\(source.count)")
                        .foregroundColor(.gray)
                    
                    if viewModel.selectedSourceIDs.contains(source.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    // Logika przełączania zaznaczenia
    private func toggleSelection(for id: String) {
        if viewModel.selectedSourceIDs.contains(id) {
            viewModel.selectedSourceIDs.remove(id)
        } else {
            viewModel.selectedSourceIDs.insert(id)
        }
    }
}
