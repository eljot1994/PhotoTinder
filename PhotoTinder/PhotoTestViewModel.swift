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
    
    @Published var activeFilterType: PhotoFilterType = .albums
    @Published var albumSources: [PhotoSource] = []
    @Published var mediaTypeSources: [PhotoSource] = []
    @Published var categorySources: [PhotoSource] = []
    @Published var selectedSourceIDs: Set<String> = [] {
        didSet {
            loadAllPhotos()
        }
    }

    @Published var allAlbums: [PHAssetCollection] = []
    @Published var destinationAlbumIDs: Set<String> = []

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

            let albumFetchOptions = PHFetchOptions()
            let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumFetchOptions)
            var allAlbums: [PHAssetCollection] = []
            userAlbums.enumerateObjects { album, _, _ in
                allAlbums.append(album)
            }
            self.allAlbums = allAlbums
            self.albumSources = allAlbums.map { PhotoSource(collection: $0) }
            
            var fetchedAssets: PHFetchResult<PHAsset>
            
            if !selectedSourceIDs.isEmpty {
                let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: Array(selectedSourceIDs), options: nil)
                
                var assetsArray = [PHAsset]()
                collections.enumerateObjects { collection, _, _ in
                    let collectionAssets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                    collectionAssets.enumerateObjects { asset, _, _ in
                        assetsArray.append(asset)
                    }
                }
                
                let selectedAssetIDs = assetsArray.map { $0.localIdentifier }
                let finalFetchOptions = PHFetchOptions()
                finalFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                finalFetchOptions.predicate = NSPredicate(format: "localIdentifier IN %@", selectedAssetIDs)
                fetchedAssets = PHAsset.fetchAssets(with: finalFetchOptions)
                
            } else {
                fetchedAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            }

            self.totalPhotosCount = fetchedAssets.count

            var result: [PhotoModel] = []
            fetchedAssets.enumerateObjects { asset, _, stop in
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
            feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        } else if dir.width > threshold {
            action = "Zostaje"
            feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
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

        history.append((asset: asset, action: action))
        processedPhotos.insert(asset.localIdentifier)
        saveProcessedPhotos()
        decision = action

        withAnimation(.easeOut(duration: 0.2)) {
            offset = CGSize(width: offset.width * 3, height: offset.height * 3)
        }

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

    // Nowa metoda do obsługi zdjęcia przeniesionego do albumu
    func handlePhotoMoved(asset: PHAsset) {
        self.history.append((asset: asset, action: "Przeniesione do albumu"))
        self.processedPhotos.insert(asset.localIdentifier)
        self.saveProcessedPhotos()
        self.photos.remove(at: self.currentIndex)
    }

    func undoLast() {
        guard let last = history.popLast() else { return }
        processedPhotos.remove(last.asset.localIdentifier)
        saveProcessedPhotos()

        photos.insert(PhotoModel(asset: last.asset), at: 0)
        currentIndex = 0
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

    func undoSpecificAction(for historyItem: (asset: PHAsset, action: String?), completion: @escaping (Bool) -> Void) {
        let historyAsset = historyItem.asset
        let action = historyItem.action

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: historyAsset)
            switch action {
            case "Ukryte":
                request.isHidden = false
            case "Ulubione":
                request.isFavorite = false
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
    
    func photoCount(for album: PHAssetCollection) -> Int {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: album, options: fetchOptions).count
    }
    
    func addPhotoToAlbum(asset: PHAsset, albumId: String, completion: @escaping (Bool) -> Void) {
        guard let album = allAlbums.first(where: { $0.localIdentifier == albumId }) else {
            completion(false)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest(for: album)
            request?.addAssets([asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    var hasHistory: Bool {
        !history.isEmpty
    }

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
