import Foundation
import Photos

// Główny typ filtra
enum PhotoFilterType: String, CaseIterable, Identifiable {
    case albums = "Albumy"
    case mediaTypes = "Typy multimediów"
    case categories = "Inne kategorie"
    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .albums: return "photo.on.rectangle.angled"
        case .mediaTypes: return "play.rectangle.on.rectangle"
        case .categories: return "square.grid.3x3.topleft.filled"
        }
    }
}

// Struktura reprezentująca pojedynczą opcję wyboru (np. album, kategoria)
struct PhotoSource: Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int
    let collection: PHAssetCollection? // Używane do pobierania zdjęć
    
    init(collection: PHAssetCollection) {
        self.id = collection.localIdentifier
        self.name = collection.localizedTitle ?? "Bez nazwy"
        self.collection = collection
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        self.count = PHAsset.fetchAssets(in: collection, options: fetchOptions).count
    }
}