import UIKit
import CoreImage
import Photos

enum FilmLab {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func process(_ image: UIImage, exposure: Double, grain: Double, filmIndex: Int, colorBalance: Double, saturation: Double) -> UIImage {
        guard var ciImage = CIImage(image: image) else { return image }
        let extent = ciImage.extent
        let filmFilters = ["CIPhotoEffectTransfer", "CIPhotoEffectProcess", "CIPhotoEffectInstant", "CIPhotoEffectNoir"]
        if let filter = CIFilter(name: filmFilters[max(0, min(filmIndex, filmFilters.count - 1))]) {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            if let output = filter.outputImage { ciImage = output }
        }
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(ciImage, forKey: kCIInputImageKey)
            controls.setValue(saturation, forKey: kCIInputSaturationKey)
            controls.setValue(1.08, forKey: kCIInputContrastKey)
            controls.setValue(0.015, forKey: kCIInputBrightnessKey)
            if let output = controls.outputImage { ciImage = output }
        }
        if let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(Float(exposure), forKey: kCIInputEVKey)
            if let output = filter.outputImage { ciImage = output }
        }
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(ciImage, forKey: kCIInputImageKey)
            let warmth = CGFloat(colorBalance) * 0.08
            matrix.setValue(CIVector(x: 1 + warmth, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 1 - warmth, w: 0), forKey: "inputBVector")
            if let output = matrix.outputImage { ciImage = output }
        }
        if let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(ciImage, forKey: kCIInputImageKey)
            vignette.setValue(0.65, forKey: kCIInputIntensityKey)
            vignette.setValue(max(1, extent.width * 0.75), forKey: kCIInputRadiusKey)
            if let output = vignette.outputImage { ciImage = output }
        }
        if grain > 0.001, let random = CIFilter(name: "CIRandomGenerator"), let matrix = CIFilter(name: "CIColorMatrix") {
            random.setDefaults()
            if let noise = random.outputImage?.cropped(to: extent) {
                matrix.setValue(noise, forKey: kCIInputImageKey)
                let strength = CGFloat(grain) * 0.11
                matrix.setValue(CIVector(x: strength, y: strength, z: strength, w: 0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: strength, y: strength, z: strength, w: 0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: strength, y: strength, z: strength, w: 0), forKey: "inputBVector")
                matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.20), forKey: "inputAVector")
                if let grainImage = matrix.outputImage?.cropped(to: extent), let composite = CIFilter(name: "CIOverlayBlendMode") {
                    composite.setValue(grainImage, forKey: kCIInputImageKey)
                    composite.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
                    if let output = composite.outputImage { ciImage = output }
                }
            }
        }
        guard let cgImage = context.createCGImage(ciImage.cropped(to: extent), from: extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    static func saveToPhotos(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { DispatchQueue.main.async { completion(false) }; return }
            PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAsset(from: image) }) { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        }
    }
}
