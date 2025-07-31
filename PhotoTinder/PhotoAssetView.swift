import SwiftUI
import Photos

struct PhotoAssetView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .onAppear { loadImage() }
            }
        }
    }

    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 800, height: 800),
            contentMode: .aspectFit,
            options: options
        ) { img, _ in
            self.image = img
        }
    }
}
