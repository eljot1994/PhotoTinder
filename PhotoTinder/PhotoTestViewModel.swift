import SwiftUI
import Photos
import UIKit

class PhotoTestViewModel: ObservableObject {
    @Published var photos: [PhotoModel] = []
    @Published var currentIndex = 0
    @Published var offset = CGSize.zero
    @Published var decision: String? = nil

    @Published var history: [(asset: PHAsset, action: String?)] = []

    @Published var permissionDenied: Bool = false
    @Published var totalPhotosCount: Int = 0

    private let processedPhotosKey = "processedPhotos"
    @Published private(set) var processedPhotos: Set<String> = []

    init() {
        loadProcessedPhotos()
        loadAllPhotos()
    }

    private func loadProcessedPhotos() {
        if let saved = UserDefaults.standard.array(forKey: processedPhotosKey) as? [String] {
            processedPhotos = Set(saved)
        }
    }

    private func saveProcessedPhotos() {
        UserDefaults.standard.set(Array(processedPhotos), forKey: processedPhotosKey)
    }

    func currentPhoto() -> PhotoModel? {
        guard currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }

    func loadAllPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            self.permissionDenied = false
            let fetched = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            self.totalPhotosCount = fetched.count

            var result: [PhotoModel] = []

            fetched.enumerateObjects { asset, _, stop in
                if !self.processedPhotos.contains(asset.localIdentifier) {
                    result.append(PhotoModel(asset: asset))
                }
            }
            DispatchQueue.main.async {
                self.photos = result
                self.currentIndex = 0
            }

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.loadAllPhotos()
                    } else {
                        self.permissionDenied = true
                        self.photos = []
                        self.currentIndex = 0
                    }
                }
            }

        case .denied, .restricted:
            self.permissionDenied = true
            DispatchQueue.main.async {
                self.photos = []
                self.currentIndex = 0
            }

        @unknown default:
            self.permissionDenied = true
            DispatchQueue.main.async {
                self.photos = []
                self.currentIndex = 0
            }
        }
    }

    func handleSwipeEnd() {
        guard let current = currentPhoto() else { return }
        let asset = current.asset
        let threshold: CGFloat = 80
        let dir = offset
        var action: String?
        
        var feedbackGenerator: UIImpactFeedbackGenerator?

        if dir.width < -threshold {
            action = "Do kosza"
            addToTrashAlbum(asset: asset)
            feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy) // Średni nacisk dla odrzucenia
        } else if dir.width > threshold {
            action = "Zostaje"
            feedbackGenerator = UIImpactFeedbackGenerator(style: .light) // Lekki nacisk dla zachowania
        } else if dir.height < -threshold {
            action = "Ulubione"
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetChangeRequest(for: asset)
                req.isFavorite = true
            }, completionHandler: nil)
            feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        } else if dir.height > threshold {
            action = "Ukryte"
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetChangeRequest(for: asset)
                req.isHidden = true
            }, completionHandler: nil)
            feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        } else {
            withAnimation { offset = .zero }
            return
        }
        
        feedbackGenerator?.impactOccurred()
        feedbackGenerator = nil

        // Zachowujemy historię cofania
        history.append((asset: asset, action: action))
        processedPhotos.insert(asset.localIdentifier)
        saveProcessedPhotos()
        decision = action

        // 1. Płynne "odlecenie" zdjęcia
        withAnimation(.easeOut(duration: 0.2)) {
            offset = CGSize(width: offset.width * 3, height: offset.height * 3)
        }

        // 2. Usunięcie zdjęcia i reset offsetu po animacji
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.currentIndex < self.photos.count {
                self.photos.remove(at: self.currentIndex)
            }
            withAnimation {
                self.offset = .zero
                self.decision = nil
            }
        }
    }

    func undoLast() {
        guard let last = history.popLast() else { return }
        processedPhotos.remove(last.asset.localIdentifier)
        saveProcessedPhotos()

        photos.insert(PhotoModel(asset: last.asset), at: 0) // Wstawiamy zdjęcie na początek kolejki
        currentIndex = 0 // Ustawiamy bieżący indeks na 0, aby to zdjęcie było następne
        offset = .zero
        decision = nil
    }

    func resetProcessedPhotos() {
        processedPhotos.removeAll()
        saveProcessedPhotos()
        loadAllPhotos()
    }

    func addToTrashAlbum(asset: PHAsset) {
        let albumName = "Do kosza"
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let album = collections.firstObject {
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest(for: album)
                request?.addAssets([asset] as NSArray)
            })
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            }, completionHandler: { success, error in
                if success {
                    self.addToTrashAlbum(asset: asset)
                }
            })
        }
    }

    // Funkcja do cofania konkretnej akcji dla zdjęcia z historii
    func undoSpecificAction(for historyItem: (asset: PHAsset, action: String?), completion: @escaping (Bool) -> Void) {
        let historyAsset = historyItem.asset
        let action = historyItem.action

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: historyAsset)
            switch action {
            case "Ukryte":
                request.isHidden = false // Poprawka: Usunięto '?' - PHAssetChangeRequest jest non-optional
            case "Ulubione":
                request.isFavorite = false // Poprawka: Usunięto '?' - PHAssetChangeRequest jest non-optional
            case "Do kosza":
                break
            case "Zostaje", .none:
                break
            default:
                break
            }
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.processedPhotos.remove(historyAsset.localIdentifier)
                    self.saveProcessedPhotos()

                    if let indexInHistory = self.history.firstIndex(where: { $0.asset.localIdentifier == historyAsset.localIdentifier }) {
                        self.history.remove(at: indexInHistory)
                    }

                    self.photos.insert(PhotoModel(asset: historyAsset), at: 0)
                    self.currentIndex = 0

                    completion(true)
                } else {
                    print("Błąd cofania akcji dla zdjęcia \(historyAsset.localIdentifier): \(error?.localizedDescription ?? "Nieznany błąd")")
                    completion(false)
                }
            }
        }
    }

    var hasHistory: Bool {
        !history.isEmpty
    }

    // New computed properties for display in ContentView
    var currentPhotoNumberForDisplay: Int {
        if photos.isEmpty {
            return totalPhotosCount
        } else {
            return totalPhotosCount - photos.count + (currentIndex + 1)
        }
    }

    var progressValue: Double {
        if totalPhotosCount == 0 { return 0.0 }
        return Double(currentPhotoNumberForDisplay) / Double(totalPhotosCount)
    }
}
