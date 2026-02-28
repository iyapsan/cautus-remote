import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import UniformTypeIdentifiers

public struct CautusRDPUtil {
    public static func savePNG(buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int, bpp: Int, path: String) -> Bool {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        let bytesPerRow = width * (bpp / 8)
        
        guard let context = CGContext(data: buffer,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else {
            return false
        }
        
        guard let cgImage = context.makeImage() else { return false }
        
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination)
    }
}
