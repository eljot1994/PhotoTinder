import Foundation
import SwiftUI
import Photos

struct PhotoModel: Identifiable {
    let id = UUID()
    let asset: PHAsset
}
