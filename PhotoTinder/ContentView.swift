import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var viewModel = PhotoTestViewModel()
    @State private var showMenu = false
    @State private var showingHistorySheet = false
    @State private var showingSourceSheet = false
    @State private var showingDestinationSheet = false
    
    @State private var showDestinationAlbums = false
    @State private var hoverAlbumId: String? = nil

    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    var body: some View {
        ZStack {
            Color.primary.opacity(0.05).ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    if viewModel.totalPhotosCount > 0 && !viewModel.permissionDenied {
                        Text("Zdjęcie \(viewModel.currentPhotoNumberForDisplay) z \(viewModel.totalPhotosCount)")
                            .font(.title2)
                            .padding(.leading, 10)
                    }
                    Spacer()
                    Button(action: { withAnimation { viewModel.undoLast() } }) {
                        Image(systemName: "arrow.left")
                            .font(.title)
                            .foregroundColor(viewModel.hasHistory ? .blue : .gray)
                    }
                    .disabled(!viewModel.hasHistory)
                    .padding(.trailing, 10)
                    Button(action: { withAnimation { showMenu.toggle() } }) {
                        Image(systemName: "ellipsis")
                            .font(.title)
                            .foregroundColor(.primary)
                            .padding()
                    }
                }
                .background(Color.clear)
                
                if viewModel.permissionDenied {
                    PermissionDeniedView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let current = viewModel.currentPhoto() {
                    PhotoAssetView(asset: current.asset)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(current.asset.localIdentifier)
                        .scaleEffect(viewModel.offset == .zero ? 1 : 1.05)
                        .offset(viewModel.offset)
                        .rotationEffect(.degrees(Double(viewModel.offset.width / 20)))
                        .gesture(dragGesture)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: viewModel.offset)
                        .overlay(swipeIconOverlay())
                        .transition(.opacity)
                } else {
                    Spacer()
                    Text("Brak zdjęć do przeglądania.")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
            }
            .overlay(alignment: .trailing) {
                if showDestinationAlbums && !viewModel.destinationAlbumIDs.isEmpty {
                    AlbumSelectionOverlay(viewModel: viewModel, hoverAlbumId: $hoverAlbumId)
                }
            }
        }
        .sheet(isPresented: $showingHistorySheet) { HistoryView(viewModel: viewModel) }
        .sheet(isPresented: $showingSourceSheet) { SourcePickerView(viewModel: viewModel) }
        .sheet(isPresented: $showingDestinationSheet) { DestinationAlbumPickerView(viewModel: viewModel) }
        .overlay(alignment: .topTrailing) {
            if showMenu {
                MenuContent(viewModel: viewModel, appTheme: $appTheme, showMenu: $showMenu, showingHistorySheet: $showingHistorySheet, showingSourceSheet: $showingSourceSheet, showingDestinationSheet: $showingDestinationSheet)
                    .background(Color(.systemBackground).opacity(0.9))
                    .ignoresSafeArea()
                    .transition(.move(edge: .top))
                    .zIndex(10)
            }
        }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                viewModel.offset = value.translation
                let filteredAlbums = viewModel.allAlbums.filter({ viewModel.destinationAlbumIDs.contains($0.localIdentifier) })
                let albumCount = filteredAlbums.count
                
                if value.translation.width > 10 && !viewModel.destinationAlbumIDs.isEmpty {
                    withAnimation { showDestinationAlbums = true }
                    
                    if albumCount > 0 {
                        let screenHeight = UIScreen.main.bounds.height
                        let sectionHeight = screenHeight / CGFloat(albumCount)
                        let albumIndex = Int(floor((value.location.y) / sectionHeight))
                        
                        if albumIndex >= 0 && albumIndex < albumCount {
                            hoverAlbumId = filteredAlbums[albumIndex].localIdentifier
                        } else {
                            hoverAlbumId = nil
                        }
                    }
                } else {
                    withAnimation {
                        showDestinationAlbums = false
                        hoverAlbumId = nil
                    }
                }
            }
            .onEnded { value in
                if showDestinationAlbums, let albumId = hoverAlbumId, let currentAsset = viewModel.currentPhoto()?.asset {
                    viewModel.addPhotoToAlbum(asset: currentAsset, albumId: albumId) { success in
                        if success {
                            viewModel.handlePhotoMoved(asset: currentAsset)
                        }
                        withAnimation {
                            viewModel.offset = .zero
                            showDestinationAlbums = false
                            hoverAlbumId = nil
                        }
                    }
                } else {
                    viewModel.handleSwipeEnd()
                    withAnimation {
                        showDestinationAlbums = false
                        hoverAlbumId = nil
                    }
                }
            }
    }
    
    @ViewBuilder
    func swipeIconOverlay() -> some View {
        let offset = viewModel.offset
        Group {
            if offset.width < -50 {
                Image(systemName: "trash.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.gray)
                    .padding()
                    .offset(x: -125)
            } else if offset.width > 50 && !showDestinationAlbums {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.green)
                    .padding()
                    .offset(x: 125)
            } else if offset.height < -50 {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.red)
                    .padding()
                    .offset(y: -125)
            } else if offset.height > 50 {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.blue)
                    .padding()
                    .offset(y: 125)
            }
        }
    }
}

struct AlbumSelectionOverlay: View {
    @ObservedObject var viewModel: PhotoTestViewModel
    @Binding var hoverAlbumId: String?

    var body: some View {
        let filteredAlbums = viewModel.allAlbums.filter({ viewModel.destinationAlbumIDs.contains($0.localIdentifier) })
        let albumCount = filteredAlbums.count

        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(filteredAlbums, id: \.localIdentifier) { album in
                    ZStack(alignment: .trailing) {
                        HStack(spacing: 2) {
                            Text(album.localizedTitle ?? "Bez nazwy")
                                .font(.headline)
                                .foregroundColor(hoverAlbumId == album.localIdentifier ? .white : .primary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    Capsule()
                                        .fill(hoverAlbumId == album.localIdentifier ? Color.blue : Color.gray.opacity(0.9))
                                )
                        }
                        .padding(.trailing, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(width: 250)
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Brak dostępu do zdjęć")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text("Aby korzystać z aplikacji, musisz zezwolić na dostęp do biblioteki zdjęć w ustawieniach systemowych.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Button("Otwórz Ustawienia") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .frame(maxWidth: 350, maxHeight: 600)
    }
}

struct MenuContent: View {
    @ObservedObject var viewModel: PhotoTestViewModel
    @Binding var appTheme: AppTheme
    @Binding var showMenu: Bool
    @Binding var showingHistorySheet: Bool
    @Binding var showingSourceSheet: Bool
    @Binding var showingDestinationSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
          
            

            VStack(spacing: 10) {
                MenuButton(title: "Resetuj", icon: "arrow.clockwise.circle.fill", color: .red) {
                    viewModel.resetProcessedPhotos()
                    withAnimation { showMenu = false }
                }
                MenuButton(title: "Historia", icon: "clock.fill", color: .blue) {
                    withAnimation { showMenu = false }
                    showingHistorySheet = true
                }
                MenuButton(title: "Wybierz źródło", icon: "folder.fill", color: .green) {
                    withAnimation { showMenu = false }
                    showingSourceSheet = true
                }
                MenuButton(title: "Wybierz albumy docelowe", icon: "photo.stack.fill", color: .purple) {
                    withAnimation { showMenu = false }
                    showingDestinationSheet = true
                }
                
                HStack {
                    Picker("Motyw", selection: $appTheme) {
                        ForEach(AppTheme.allCases.filter { $0 != .system }) { theme in
                            Text(theme.rawValue)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: .infinity)
                    
                    
                }
                
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.systemBackground).opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showMenu = false }
                }
        )
    }
}

private struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(12)
            .background(color)
            .cornerRadius(12)
            .shadow(radius: 5)
        }
    }
}
