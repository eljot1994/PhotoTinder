import SwiftUI
import Photos

struct DestinationAlbumPickerView: View {
    @ObservedObject var viewModel: PhotoTestViewModel
    @Environment(\.dismiss) var dismiss

    // Używamy lokalnej kopii, aby zmiany były zatwierdzane dopiero po naciśnięciu "Gotowe"
    @State private var selectedIDs: Set<String>

    init(viewModel: PhotoTestViewModel) {
        self.viewModel = viewModel
        self._selectedIDs = State(initialValue: viewModel.destinationAlbumIDs)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.allAlbums.filter { $0.canPerform(.addContent) }, id: \.localIdentifier) { album in
                    Button(action: {
                        toggleSelection(for: album.localIdentifier)
                    }) {
                        HStack {
                            Text(album.localizedTitle ?? "Bez nazwy")
                            Spacer()
                            Text("\(viewModel.photoCount(for: album))")
                                .foregroundColor(.gray)
                            
                            if selectedIDs.contains(album.localIdentifier) {
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
            .navigationTitle("Wybierz albumy docelowe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gotowe") {
                        // Zapisz zmiany do ViewModelu i zamknij widok
                        viewModel.destinationAlbumIDs = selectedIDs
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleSelection(for id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}
