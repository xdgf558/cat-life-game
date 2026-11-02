import SpriteKit
import UIKit

enum CatClip: String, CaseIterable {
    case expressions = "cat-expressions"
    case walk = "cat-walk"
    case rise = "cat-rise"
    case meal = "cat-meal"
    case play = "cat-play"
    case rest = "cat-rest"
    case step = "cat-step"
}

/// Atlas registration is computed once, not per animation frame. Cropping uses
/// SpriteKit UV rectangles; generated source images are not modified on disk.
@MainActor
final class CatSpriteLibrary {
    struct Frame {
        let texture: SKTexture
        let bounds: CGRect
        let groundCenter: CGFloat
        let groundY: CGFloat
        let frontPaw: CGPoint?
        let rearPaw: CGPoint?

        init(texture: SKTexture, bounds: CGRect, groundCenter: CGFloat,
             groundY: CGFloat? = nil, frontPaw: CGPoint? = nil, rearPaw: CGPoint? = nil) {
            self.texture = texture
            self.bounds = bounds
            self.groundCenter = groundCenter
            self.groundY = groundY ?? bounds.maxY
            self.frontPaw = frontPaw
            self.rearPaw = rearPaw
        }
    }

    struct Sequence {
        let frames: [Frame]
        let referenceHeight: CGFloat
        let heightRatio: CGFloat
    }

    private var cache: [CatClip: Sequence] = [:]

    func sequence(_ clip: CatClip) -> Sequence {
        if let cached = cache[clip] { return cached }
        let result: Sequence
        if let image = UIImage(named: clip.rawValue), let cgImage = image.cgImage,
           let frames = extract(cgImage: cgImage, name: clip.rawValue,
                                columns: clip == .rest ? 2 : 4, rows: clip == .rest ? 4 : 2,
                                rowCuts: clip == .rest ? [0, 0.285, 0.515, 0.725, 1] : nil) {
            let reference: CGFloat
            switch clip {
            case .expressions, .walk:
                let heights = frames.map { $0.bounds.height }.sorted()
                reference = heights[heights.count / 2]
            case .rise, .meal, .play, .rest, .step: reference = frames[0].bounds.height
            }
            let ratio: CGFloat = (clip == .walk || clip == .meal || clip == .play) ? 0.91 : 1
            result = Sequence(frames: frames, referenceHeight: reference, heightRatio: ratio)
        } else {
            // Existing art is a safe rendering fallback while atlases load into
            // the project. The old eating image is a satisfied seated pose.
            let name = clip == .meal ? "cat-eating" : "cat-idle"
            if let cgImage = UIImage(named: name)?.cgImage,
               let frames = extract(cgImage: cgImage, name: name, columns: 1, rows: 1) {
                result = Sequence(frames: frames, referenceHeight: frames[0].bounds.height, heightRatio: 1)
            } else {
                let texture = SKTexture(imageNamed: "cat-idle")
                let size = texture.size()
                result = Sequence(frames: [Frame(texture: texture, bounds: CGRect(origin: .zero, size: size),
                                                 groundCenter: size.width / 2)], referenceHeight: max(1, size.height), heightRatio: 1)
            }
        }
        cache[clip] = result
        return result
    }

    private func extract(cgImage: CGImage, name: String, columns: Int, rows: Int,
                         rowCuts: [CGFloat]? = nil) -> [Frame]? {
        let width = cgImage.width, height = cgImage.height
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let atlas = SKTexture(imageNamed: name)
        atlas.filteringMode = .linear
        var frames: [Frame] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let left = column * width / columns, right = (column + 1) * width / columns
                // The generated rest sheet is 2×4 but its transparent row gaps
                // are not exactly equidistant. Cut within those measured gaps
                // so a neighbouring stretch tail/paw never leaks into a frame.
                let top = rowCuts.map { Int($0[row] * CGFloat(height)) } ?? row * height / rows
                let bottom = rowCuts.map { Int($0[row + 1] * CGFloat(height)) } ?? (row + 1) * height / rows
                var minX = right, maxX = left, minY = bottom, maxY = top
                for y in top..<bottom {
                    for x in left..<right where bytes[y * bytesPerRow + x * 4 + 3] >= 128 {
                        minX = min(minX, x); maxX = max(maxX, x)
                        minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
                guard minX <= maxX, minY <= maxY else { return nil }
                // Use the lowest paw band, not the entire lower quarter: a
                // lowered cream muzzle must not pull the body's registration
                // sideways during eating. Exclude the far-right nose tip too.
                let footTop = max(minY, maxY - Int(Double(maxY - minY) * 0.10))
                let footLeft = minX + Int(Double(maxX - minX) * 0.10)
                let footRight = minX + Int(Double(maxX - minX) * 0.88)
                var weightedX = 0.0, weight = 0.0
                for y in footTop...maxY {
                    for x in footLeft...footRight {
                        let offset = y * bytesPerRow + x * 4
                        let red = Double(bytes[offset]), green = Double(bytes[offset + 1]), blue = Double(bytes[offset + 2])
                        guard bytes[offset + 3] >= 180, red > 100, green > red * 0.72, blue > green * 0.67 else { continue }
                        let amount = 1 + Double(y - footTop) / Double(max(1, maxY - footTop))
                        weightedX += Double(x) * amount
                        weight += amount
                    }
                }
                let groundCenter = weight > 8 ? CGFloat(weightedX / weight - Double(left)) : CGFloat(minX + maxX) / 2 - CGFloat(left)
                // Tiny padding retains the soft fur edge, without allowing
                // stray low-alpha pixels to move the registration point.
                minX = max(left, minX - 2); maxX = min(right - 1, maxX + 2)
                minY = max(top, minY - 2)
                let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
                let rect = CGRect(x: crop.minX / CGFloat(width), y: 1 - crop.maxY / CGFloat(height),
                                  width: crop.width / CGFloat(width), height: crop.height / CGFloat(height))
                let texture = SKTexture(rect: rect, in: atlas)
                texture.filteringMode = .linear
                frames.append(Frame(texture: texture,
                                    bounds: CGRect(x: crop.minX - CGFloat(left), y: crop.minY - CGFloat(top), width: crop.width, height: crop.height),
                                    groundCenter: groundCenter))
            }
        }
        if name == CatClip.walk.rawValue || name == CatClip.play.rawValue {
            // Extended or airborne paws are not a stable horizontal landmark.
            // Keep the body centered around the clip's median registration;
            // otherwise the leading paw can pull a pounce backward mid-air.
            let offsets = frames.map { $0.groundCenter - $0.bounds.midX }.sorted()
            let bodyOffset = offsets[offsets.count / 2]
            return frames.map {
                Frame(texture: $0.texture, bounds: $0.bounds,
                      groundCenter: $0.bounds.midX + bodyOffset)
            }
        }
        if name == CatClip.rest.rawValue {
            // A lying body's support is centered beneath the belly, not under
            // the bright front paws. Transition from standing registration;
            // frames 3...6 then share a stable body center while sleeping.
            let standingOffset = frames[0].groundCenter - frames[0].bounds.midX
            let weights: [CGFloat] = [1, 0.75, 0.45, 0, 0, 0, 0, 0.45]
            return frames.enumerated().map { index, frame in
                Frame(texture: frame.texture, bounds: frame.bounds,
                      groundCenter: frame.bounds.midX + standingOffset * weights[index])
            }
        }
        if name == CatClip.step.rawValue {
            // Measured in the 1774×887 source's 4×2 cells (top-left origin),
            // using alpha >= 180 across each visible paw's last three rows.
            // Frame 1 names the reaching paw; the other forepaw still supports
            // the body. Frames 2/3 keep the rear paw low; 5/6 keep it high.
            let front: [CGPoint] = [CGPoint(x: 261.4, y: 426), CGPoint(x: 390.0, y: 366),
                                    CGPoint(x: 318.3, y: 386), CGPoint(x: 321.0, y: 376),
                                    CGPoint(x: 272.1, y: 380), CGPoint(x: 323.1, y: 397),
                                    CGPoint(x: 289.0, y: 395), CGPoint(x: 275.7, y: 391)]
            let rear: [CGPoint] = [CGPoint(x: 87.2, y: 417), CGPoint(x: 106.3, y: 419),
                                   CGPoint(x: 106.5, y: 419), CGPoint(x: 118.0, y: 417),
                                   CGPoint(x: 100.1, y: 374), CGPoint(x: 94.0, y: 334),
                                   CGPoint(x: 105.3, y: 337), CGPoint(x: 95.3, y: 377)]
            let baselines: [CGFloat] = [426, 425, 419, 417, 380, 334, 337, 391]
            let bodyOffset = frames[0].groundCenter - frames[0].bounds.midX
            return frames.enumerated().map { index, frame in
                Frame(texture: frame.texture, bounds: frame.bounds,
                      groundCenter: frame.bounds.midX + bodyOffset,
                      groundY: baselines[index], frontPaw: front[index], rearPaw: rear[index])
            }
        }
        return frames
    }
}
