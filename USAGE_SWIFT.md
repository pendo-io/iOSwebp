# Using PendoWebP in iOS Swift & SwiftUI

Complete guide for using PendoWebP (namespaced libwebp) in Swift and SwiftUI applications.

## Installation

### 1. Add to Podfile

```ruby
pod 'PendoWebP', :git => 'https://github.com/orendayan/pendowebp.git', :tag => 'v1.3.2'
```

### 2. Add Required post_install Hook

See [INSTALLATION.md](INSTALLATION.md) for the complete hook code.

### 3. Install

```bash
cd ios
pod install
```

## Swift Usage

### Import in Swift

```swift
import PendoWebP
```

### Create a Swift Wrapper

Since PendoWebP is a C library, create a Swift wrapper for easy use:

```swift
// PendoWebPEncoder.swift
import UIKit
import PendoWebP

class PendoWebPEncoder {
    
    /// Encode UIImage to WebP format
    /// - Parameters:
    ///   - image: The UIImage to encode
    ///   - quality: Quality factor (0.0 - 1.0)
    /// - Returns: WebP data or nil if encoding fails
    static func encode(_ image: UIImage, quality: Float = 0.85) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create RGBA bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        // Draw image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return nil }
        
        // Encode using PendoWebP (C function)
        var output: UnsafeMutablePointer<UInt8>?
        let qualityFactor = quality * 100.0
        
        let size = PNDWebPEncodeRGBA(
            pixelData.assumingMemoryBound(to: UInt8.self),
            Int32(width),
            Int32(height),
            Int32(width * 4),
            qualityFactor,
            &output
        )
        
        guard size > 0, let outputPointer = output else {
            if let ptr = output {
                PNDWebPFree(ptr)
            }
            return nil
        }
        
        // Convert to Data
        let webpData = Data(bytes: outputPointer, count: Int(size))
        
        // Free C memory
        PNDWebPFree(outputPointer)
        
        return webpData
    }
    
    /// Encode UIImage to WebP with lossless compression
    static func encodeLossless(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // ... create context and get pixelData (same as above) ...
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixelData = context.data else { return nil }
        
        // Lossless encoding
        var output: UnsafeMutablePointer<UInt8>?
        
        let size = PNDWebPEncodeLosslessRGBA(
            pixelData.assumingMemoryBound(to: UInt8.self),
            Int32(width),
            Int32(height),
            Int32(width * 4)
        )
        
        guard size > 0, let outputPointer = output else {
            if let ptr = output {
                PNDWebPFree(ptr)
            }
            return nil
        }
        
        let webpData = Data(bytes: outputPointer, count: Int(size))
        PNDWebPFree(outputPointer)
        
        return webpData
    }
    
    /// Decode WebP data to UIImage
    static func decode(_ webpData: Data) -> UIImage? {
        var width: Int32 = 0
        var height: Int32 = 0
        
        let rgba = webpData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UnsafeMutablePointer<UInt8>? in
            guard let baseAddress = bytes.baseAddress else { return nil }
            
            return PNDWebPDecodeRGBA(
                baseAddress.assumingMemoryBound(to: UInt8.self),
                bytes.count,
                &width,
                &height
            )
        }
        
        guard let rgba = rgba else { return nil }
        defer { PNDWebPFree(rgba) }
        
        // Create CGImage from RGBA data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: rgba,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: Int(width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
        let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Get WebP image dimensions without decoding
    static func getInfo(_ webpData: Data) -> CGSize? {
        var width: Int32 = 0
        var height: Int32 = 0
        
        let success = webpData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Int32 in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            
            return PNDWebPGetInfo(
                baseAddress.assumingMemoryBound(to: UInt8.self),
                bytes.count,
                &width,
                &height
            )
        }
        
        guard success != 0 else { return nil }
        return CGSize(width: Int(width), height: Int(height))
    }
}
```

## SwiftUI Usage

### Basic Image Encoder View

```swift
import SwiftUI

struct WebPEncoderView: View {
    @State private var selectedImage: UIImage?
    @State private var webpData: Data?
    @State private var quality: Double = 0.85
    @State private var isEncoding = false
    @State private var compressionRatio: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Image picker
            Button("Select Image") {
                // Show image picker
            }
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                
                // Quality slider
                VStack {
                    Text("Quality: \(Int(quality * 100))%")
                    Slider(value: $quality, in: 0.0...1.0)
                }
                .padding()
                
                // Encode button
                Button(action: encodeImage) {
                    if isEncoding {
                        ProgressView()
                    } else {
                        Text("Compress to WebP")
                    }
                }
                .disabled(isEncoding)
                .buttonStyle(.borderedProminent)
                
                if !compressionRatio.isEmpty {
                    Text(compressionRatio)
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
    
    private func encodeImage() {
        guard let image = selectedImage else { return }
        
        isEncoding = true
        
        Task {
            let originalSize = image.pngData()?.count ?? 0
            
            // Encode on background thread
            let webp = await encodeOnBackground(image: image, quality: Float(quality))
            
            await MainActor.run {
                webpData = webp
                isEncoding = false
                
                if let webp = webp {
                    let ratio = (1.0 - Double(webp.count) / Double(originalSize)) * 100
                    compressionRatio = String(format: "%.1f%% smaller", ratio)
                }
            }
        }
    }
    
    private func encodeOnBackground(image: UIImage, quality: Float) async -> Data? {
        await Task.detached {
            PendoWebPEncoder.encode(image, quality: quality)
        }.value
    }
}
```

### SwiftUI Image Loader with WebP Support

```swift
import SwiftUI

struct WebPImage: View {
    let webpData: Data
    @State private var uiImage: UIImage?
    
    var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                ProgressView()
            }
        }
        .onAppear {
            loadWebP()
        }
    }
    
    private func loadWebP() {
        Task {
            let image = await Task.detached {
                PendoWebPEncoder.decode(webpData)
            }.value
            
            await MainActor.run {
                uiImage = image
            }
        }
    }
}

// Usage:
// WebPImage(webpData: myWebPData)
```

### Complete SwiftUI Example App

```swift
import SwiftUI
import PhotosUI

@main
struct WebPConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var webpData: Data?
    @State private var quality: Double = 0.85
    @State private var isProcessing = false
    @State private var stats: CompressionStats?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Photo Picker
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label("Select Photo", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        await loadImage(from: newItem)
                    }
                }
                
                // Original Image
                if let image = originalImage {
                    GroupBox("Original") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                        
                        if let pngSize = image.pngData()?.count {
                            Text("Size: \(formatBytes(pngSize))")
                                .font(.caption)
                        }
                    }
                    
                    // Quality Control
                    GroupBox("Compression Settings") {
                        VStack {
                            Text("Quality: \(Int(quality * 100))%")
                            Slider(value: $quality, in: 0.5...1.0)
                            
                            Button(action: compressImage) {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Label("Compress to WebP", systemImage: "arrow.down.circle")
                                }
                            }
                            .disabled(isProcessing)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    // Results
                    if let stats = stats {
                        GroupBox("Results") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Original: \(formatBytes(stats.originalSize))")
                                Text("WebP: \(formatBytes(stats.webpSize))")
                                Text("Saved: \(formatBytes(stats.savedSize))")
                                    .foregroundColor(.green)
                                Text("Compression: \(String(format: "%.1f%%", stats.ratio))")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button(action: saveWebP) {
                            Label("Save WebP", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("WebP Converter")
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run {
                originalImage = image
                webpData = nil
                stats = nil
            }
        }
    }
    
    private func compressImage() {
        guard let image = originalImage else { return }
        
        isProcessing = true
        
        Task {
            let originalSize = image.pngData()?.count ?? 0
            
            // Encode on background
            let webp = await Task.detached(priority: .userInitiated) {
                PendoWebPEncoder.encode(image, quality: Float(quality))
            }.value
            
            await MainActor.run {
                webpData = webp
                isProcessing = false
                
                if let webp = webp {
                    let webpSize = webp.count
                    let saved = originalSize - webpSize
                    let ratio = (Double(saved) / Double(originalSize)) * 100
                    
                    stats = CompressionStats(
                        originalSize: originalSize,
                        webpSize: webpSize,
                        savedSize: saved,
                        ratio: ratio
                    )
                }
            }
        }
    }
    
    private func saveWebP() {
        guard let webpData = webpData else { return }
        
        // Save to Files app or Photos
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed.webp")
        
        do {
            try webpData.write(to: tempURL)
            // Show share sheet
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Error saving WebP: \(error)")
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct CompressionStats {
    let originalSize: Int
    let webpSize: Int
    let savedSize: Int
    let ratio: Double
}
```

## Modern Swift Async/Await Usage

```swift
import UIKit

class ImageCompressor {
    
    /// Compress image to WebP asynchronously
    static func compressToWebP(
        _ image: UIImage,
        quality: Float = 0.85
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard let webpData = PendoWebPEncoder.encode(image, quality: quality) else {
                throw CompressionError.encodingFailed
            }
            return webpData
        }.value
    }
    
    /// Compress multiple images in parallel
    static func compressBatch(
        _ images: [UIImage],
        quality: Float = 0.85
    ) async throws -> [Data] {
        try await withThrowingTaskGroup(of: Data.self) { group in
            for image in images {
                group.addTask {
                    try await compressToWebP(image, quality: quality)
                }
            }
            
            var results: [Data] = []
            for try await data in group {
                results.append(data)
            }
            return results
        }
    }
}

enum CompressionError: Error {
    case encodingFailed
    case decodingFailed
}

// Usage:
// let webpData = try await ImageCompressor.compressToWebP(myImage, quality: 0.85)
```

## SwiftUI Observable Pattern

```swift
import SwiftUI
import Observation

@Observable
class WebPCompressor {
    var isCompressing = false
    var originalImage: UIImage?
    var webpData: Data?
    var compressionRatio: Double = 0
    var error: String?
    
    @MainActor
    func compress(image: UIImage, quality: Float = 0.85) {
        originalImage = image
        isCompressing = true
        error = nil
        
        Task {
            do {
                let originalSize = image.pngData()?.count ?? 0
                
                let webp = try await Task.detached {
                    guard let data = PendoWebPEncoder.encode(image, quality: quality) else {
                        throw CompressionError.encodingFailed
                    }
                    return data
                }.value
                
                await MainActor.run {
                    webpData = webp
                    let ratio = (1.0 - Double(webp.count) / Double(originalSize)) * 100
                    compressionRatio = ratio
                    isCompressing = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCompressing = false
                }
            }
        }
    }
}

// In your SwiftUI view:
struct CompressorView: View {
    @State private var compressor = WebPCompressor()
    
    var body: some View {
        VStack {
            if compressor.isCompressing {
                ProgressView("Compressing...")
            }
            
            if compressor.compressionRatio > 0 {
                Text("\(String(format: "%.1f%%", compressor.compressionRatio)) smaller!")
                    .foregroundColor(.green)
            }
        }
    }
}
```

## Extension for UIImage

```swift
import UIKit

extension UIImage {
    
    /// Convert to WebP data
    func webPData(quality: Float = 0.85) -> Data? {
        return PendoWebPEncoder.encode(self, quality: quality)
    }
    
    /// Convert to lossless WebP
    func losslessWebPData() -> Data? {
        return PendoWebPEncoder.encodeLossless(self)
    }
    
    /// Create UIImage from WebP data
    static func fromWebP(_ data: Data) -> UIImage? {
        return PendoWebPEncoder.decode(data)
    }
    
    /// Save as WebP file
    func saveAsWebP(to url: URL, quality: Float = 0.85) throws {
        guard let webpData = webPData(quality: quality) else {
            throw NSError(domain: "WebP", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to encode WebP"
            ])
        }
        try webpData.write(to: url)
    }
}

// Usage:
// let webpData = myImage.webPData(quality: 0.85)
// myImage.saveAsWebP(to: fileURL, quality: 0.85)
// let image = UIImage.fromWebP(webpData)
```

## Combine Integration

```swift
import Combine
import UIKit

class WebPPublisher {
    
    static func encode(
        _ image: UIImage,
        quality: Float = 0.85
    ) -> AnyPublisher<Data, Error> {
        Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                if let webpData = PendoWebPEncoder.encode(image, quality: quality) {
                    promise(.success(webpData))
                } else {
                    promise(.failure(CompressionError.encodingFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// Usage with Combine:
// WebPPublisher.encode(myImage, quality: 0.85)
//     .sink(
//         receiveCompletion: { completion in
//             // Handle completion
//         },
//         receiveValue: { webpData in
//             // Use WebP data
//         }
//     )
//     .store(in: &cancellables)
```

## Complete SwiftUI Demo App

```swift
import SwiftUI
import PhotosUI

struct WebPDemoApp: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var compressor = ImageCompressor()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Image Selection
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Select Image", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .onChange(of: selectedItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                compressor.originalImage = image
                            }
                        }
                    }
                    
                    // Original Image
                    if let image = compressor.originalImage {
                        GroupBox("Original Image") {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 250)
                            
                            Text("Size: \(formatSize(image.pngData()?.count ?? 0))")
                                .font(.caption)
                        }
                        
                        // Compression Controls
                        GroupBox("Settings") {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Quality")
                                    Spacer()
                                    Text("\(Int(compressor.quality * 100))%")
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(value: $compressor.quality, in: 0.5...1.0)
                                
                                HStack(spacing: 16) {
                                    ForEach([0.6, 0.75, 0.85, 0.95], id: \.self) { preset in
                                        Button("\(Int(preset * 100))%") {
                                            compressor.quality = preset
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Compress Button
                        Button(action: {
                            Task {
                                await compressor.compress()
                            }
                        }) {
                            if compressor.isCompressing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Label("Compress to WebP", systemImage: "arrow.down.circle.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(compressor.isCompressing)
                        .controlSize(.large)
                        
                        // Results
                        if let webpData = compressor.webpData {
                            GroupBox("WebP Result") {
                                VStack(spacing: 12) {
                                    if let webpImage = UIImage.fromWebP(webpData) {
                                        Image(uiImage: webpImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 250)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("WebP Size: \(formatSize(webpData.count))")
                                        Text("Reduction: \(String(format: "%.1f%%", compressor.compressionRatio))")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    ShareLink(item: webpData, preview: SharePreview("Compressed Image")) {
                                        Label("Share WebP", systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("WebP Compressor")
        }
    }
    
    private func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

@Observable
class ImageCompressor {
    var originalImage: UIImage?
    var webpData: Data?
    var quality: Double = 0.85
    var isCompressing = false
    var compressionRatio: Double = 0
    
    @MainActor
    func compress() async {
        guard let image = originalImage else { return }
        
        isCompressing = true
        
        let originalSize = image.pngData()?.count ?? 0
        
        let webp = await Task.detached(priority: .userInitiated) {
            PendoWebPEncoder.encode(image, quality: Float(self.quality))
        }.value
        
        webpData = webp
        isCompressing = false
        
        if let webp = webp {
            compressionRatio = (1.0 - Double(webp.count) / Double(originalSize)) * 100
        }
    }
}
```

## Key Points for Swift

### 1. C Interop

```swift
// PendoWebP functions are C functions
// Use UnsafeMutablePointer for output parameters

var output: UnsafeMutablePointer<UInt8>?
let size = PNDWebPEncodeRGBA(..., &output)

// Always check and free
if let output = output {
    defer { PNDWebPFree(output) }
    // Use output...
}
```

### 2. Memory Safety

```swift
// Use defer for automatic cleanup
func encode() -> Data? {
    var output: UnsafeMutablePointer<UInt8>?
    let size = PNDWebPEncodeRGBA(..., &output)
    
    guard size > 0, let output = output else { return nil }
    defer { PNDWebPFree(output) }  // ← Always freed!
    
    return Data(bytes: output, count: Int(size))
}
```

### 3. Thread Safety

```swift
// WebP encoding is thread-safe
// Can be called from any thread/queue

DispatchQueue.global().async {
    let webpData = PendoWebPEncoder.encode(image, quality: 0.85)
    
    DispatchQueue.main.async {
        // Update UI
    }
}

// Or with modern async/await
Task.detached {
    let webpData = PendoWebPEncoder.encode(image, quality: 0.85)
    await MainActor.run {
        // Update UI
    }
}
```

## Type Conversions

### UIImage ←→ CGImage

```swift
// UIImage to CGImage
guard let cgImage = uiImage.cgImage else { return }

// CGImage to UIImage
let uiImage = UIImage(cgImage: cgImage)
```

### Data ←→ UnsafePointer

```swift
// Data to UnsafePointer (for decoding)
let rgba = webpData.withUnsafeBytes { bytes in
    PNDWebPDecodeRGBA(
        bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
        bytes.count,
        &width,
        &height
    )
}

// UnsafePointer to Data (for encoding result)
let data = Data(bytes: output, count: Int(size))
```

## Error Handling in Swift

```swift
enum WebPError: Error {
    case invalidImage
    case encodingFailed
    case decodingFailed
    case insufficientMemory
}

func encodeWebP(_ image: UIImage, quality: Float) throws -> Data {
    guard let cgImage = image.cgImage else {
        throw WebPError.invalidImage
    }
    
    // ... encoding logic ...
    
    guard size > 0, let output = output else {
        throw WebPError.encodingFailed
    }
    
    defer { PNDWebPFree(output) }
    return Data(bytes: output, count: Int(size))
}

// Usage:
do {
    let webpData = try encodeWebP(myImage, quality: 0.85)
} catch {
    print("Compression failed: \(error)")
}
```

## Performance Optimization

### Reusable Context Pool

```swift
class WebPContextPool {
    private let pool: [CGContext]
    private let semaphore: DispatchSemaphore
    
    init(maxSize: CGSize, poolSize: Int = 4) {
        var contexts: [CGContext] = []
        
        for _ in 0..<poolSize {
            if let context = CGContext(
                data: nil,
                width: Int(maxSize.width),
                height: Int(maxSize.height),
                bitsPerComponent: 8,
                bytesPerRow: Int(maxSize.width) * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                contexts.append(context)
            }
        }
        
        self.pool = contexts
        self.semaphore = DispatchSemaphore(value: poolSize)
    }
    
    func withContext<T>(_ block: (CGContext) -> T) -> T {
        semaphore.wait()
        defer { semaphore.signal() }
        
        let context = pool.randomElement()!
        return block(context)
    }
}
```

## Testing in Swift

```swift
import XCTest

class WebPEncoderTests: XCTestCase {
    
    func testEncoding() {
        // Create test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Encode
        let webpData = PendoWebPEncoder.encode(image, quality: 0.85)
        
        // Assert
        XCTAssertNotNil(webpData)
        XCTAssertGreaterThan(webpData!.count, 0)
    }
    
    func testQualityRange() {
        let image = /* test image */
        
        let low = PendoWebPEncoder.encode(image, quality: 0.6)
        let high = PendoWebPEncoder.encode(image, quality: 0.95)
        
        XCTAssertNotNil(low)
        XCTAssertNotNil(high)
        XCTAssertLessThan(low!.count, high!.count)  // Lower quality = smaller
    }
}
```

## Complete Symbol Reference

All functions with `Pendo_` prefix - see [RENAMED_SYMBOLS.txt](RENAMED_SYMBOLS.txt) for complete list.

**Most commonly used:**
- `PNDWebPEncodeRGBA` - Encode RGBA to WebP
- `PNDWebPEncodeLosslessRGBA` - Lossless encoding
- `PNDWebPDecodeRGBA` - Decode WebP to RGBA
- `PNDWebPGetInfo` - Get dimensions
- `PNDWebPFree` - Free memory
- `PNDWebPMalloc` - Allocate memory

## Resources

- Official libwebp API: https://developers.google.com/speed/webp/docs/api
- Just add `Pendo_` prefix to all function names!
- Installation: [INSTALLATION.md](INSTALLATION.md)
- Objective-C examples: [USAGE_OBJC.md](USAGE_OBJC.md)

---

**Remember:** All 107 functions have the `Pendo_` prefix to prevent conflicts! 🛡️


