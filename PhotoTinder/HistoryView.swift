import SwiftUI
import Photos

struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: PhotoTestViewModel

    @State private var selectedFilter: String = "Wszystkie" // Nowy stan dla wybranego filtru
    let filterOptions = ["Wszystkie", "Do kosza", "Zostaje", "Ulubione", "Ukryte"] // Opcje filtru

    var body: some View {
        NavigationView {
            VStack { // Dodajemy VStack, aby pomieścić Picker i Listę
                Picker("Filtr", selection: $selectedFilter) {
                    ForEach(filterOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // Elegancki wygląd filtru
                .padding(.horizontal)
                .padding(.top, 5)

                List {
                    // Zmieniamy, aby użyć filtrowanej listy zdjęć
                    if filteredHistory.isEmpty {
                        Text("Brak zdjęć w historii spełniających kryteria filtru.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(filteredHistory, id: \.asset.localIdentifier) { item in
                            HStack {
                                PhotoAssetView(asset: item.asset)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()

                                VStack(alignment: .leading) {
                                    // Wyświetlamy nazwę akcji zamiast "Zdjęcie nr X z sesji"
                                    Text(item.action ?? "Pozostawione") // Jeśli akcja była nil (np. dla "Zostaje"), wyświetl "Pozostawione"
                                        .font(.headline)
                                    // Tutaj można dodać ikonę akcji, jeśli chcesz
                                }
                                Spacer() // Spacer, aby zawartość była wyrównana
                            }
                            .padding(.vertical, 5)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) { // Dodajemy akcję przesunięcia
                                Button(role: .destructive) { // Używamy roli .destructive dla domyślnego czerwonego tła
                                    viewModel.undoSpecificAction(for: item) { success in
                                        if success {
                                            // Opcjonalnie: możesz dodać tu wizualne potwierdzenie dla użytkownika
                                            print("Akcja cofnięta pomyślnie dla zdjęcia: \(item.asset.localIdentifier)")
                                        } else {
                                            // Opcjonalnie: wyświetl alert w przypadku błędu
                                            print("Nie udało się cofnąć akcji dla zdjęcia: \(item.asset.localIdentifier)")
                                        }
                                    }
                                } label: {
                                    Label("Cofnij", systemImage: "arrow.uturn.backward.circle.fill")
                                }
                                .tint(.blue) // Nadpisujemy domyślny czerwony kolor na niebieski
                            }
                        }
                    }
                }
            }
            .navigationTitle("Historia Przesunięć")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
        }
    }

    // Właściwość obliczeniowa do filtrowania historii
    var filteredHistory: [(asset: PHAsset, action: String?)] {
        let reversedHistory = viewModel.history.reversed() // Zawsze pracujemy na odwróconej historii (najnowsze na górze)
        guard selectedFilter != "Wszystkie" else { return Array(reversedHistory) } // Jeśli "Wszystkie", zwróć całość

        // W przypadku akcji "Zostaje", szukamy akcji nil
        let targetAction = selectedFilter == "Zostaje" ? nil : selectedFilter

        return reversedHistory.filter { item in
            if selectedFilter == "Zostaje" {
                return item.action == nil // Szukamy elementów, gdzie akcja jest nil
            } else {
                return item.action == targetAction // Szukamy elementów, gdzie akcja pasuje do filtru
            }
        }
    }
}
