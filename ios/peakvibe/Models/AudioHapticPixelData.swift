//
//  AudioHapticPixelData.swift
//  peakvibe
//
//  Created by hugo on 2/17/22.
//

import Foundation
import SwiftUI
import SwiftUIOSC
import DequeModule

// safe out-of-bounds indexing
extension Collection {

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
}

// a ring buffer-esque collection.
final class PixelCollection: ObservableObject, RandomAccessCollection {
    typealias Element = AudioHapticPixel
    
    private var pixels: Deque<AudioHapticPixel> = []
    @Published private var cursorPos: Int = 0
    @Published private var anchorPos: Int = 0
    
    // sets the new center of the ringbuffer,
    // and loads any necessary neighbor pixels
    func setAnchor(newPos: Int) {
        let leftBound = newPos - self.pixels.count / 2
        let rightBound = newPos + self.pixels.count / 2
        
        // load all pixels if we're moving a long distance
        let offset = abs(newPos - anchorPos)
        if offset == 0 {
            return
        }
        else if offset > self.pixels.count / 2 {
            loadAllPixels()
            anchorPos = newPos
            return
        }
        
        // load all pixels if we have no pixels
        guard let firstPix = self.pixels.first,
              let lastPix = self.pixels.last
        else {
            loadAllPixels()
            anchorPos = newPos
            return
        }
        
        // selectively load pixels if we're within bounds
        let pixRange = (firstPix.id...lastPix.id)
        if !pixRange.contains(leftBound) &&
            pixRange.contains(rightBound)
        {
            loadPixels(ids: (leftBound..<firstPix.id+1))
        } else if pixRange.contains(leftBound) &&
                !pixRange.contains(rightBound){
            loadPixels(ids: (lastPix.id..<rightBound+1))
        } else {
            // shouldn't reach here unless our buffer
            // gets smaller or has repeat pixels
            print("?!?!?!?!?!?!?!??!")
            loadAllPixels()
//            fatalError()
        }
        
        anchorPos = newPos
    }
    
    
    // sets an internal cursor, to update the OSC client
    func setCursor(newPos: Int) {
        if (newPos != cursorPos) {
            osc.send(newPos, at: "/set_cursor")
        }
        
        // finally, set
        cursorPos = newPos
    }

    let maxSize: Int = 256

    var startIndex: Int = 0
    var endIndex: Int {
        get {
            return pixels.last?.id ?? 0
        }
    }
    
    var last: AudioHapticPixel? {
        return pixels.last
    }
    
    var osc: OSC = .shared
    
    init() {
        for i in (0..<maxSize) {
            self.pixels.append(AudioHapticPixel(id: i, value: 0.0))
        }
        cursorPos = self.pixels.count / 2
        anchorPos = self.pixels.count / 2
    }
    
    subscript(position: Int) -> AudioHapticPixel {
        get {
            if let firstPix = pixels.first {
                var index = position - firstPix.id
                index = index.clamped(to: (0..<self.pixels.count))
                return pixels[index]
            } else {
                fatalError("list empty")
            }
            
        }
        set (newValue) {
            if let firstPix = pixels.first,
               let lastPix = pixels.last {
                if (newValue.id - lastPix.id) == 1 { // pix is directly after
                    pixels.append(newValue)
                    _ = pixels.popFirst()
                } else if (newValue.id - firstPix.id) == -1 { // pix is directly before
                    pixels.prepend(newValue)
                    _ = pixels.popLast()
                } else if ((firstPix.id...lastPix.id).contains(newValue.id)) { // pix is in range
                    let index = position - firstPix.id
                    pixels[index] = newValue
                } else { // pix is not directly before, after, or in range
                    
                    print("attempted out of range enqueue: \(newValue.id). [\(firstPix.id), \(lastPix.id)")
                    
                }
            }
        }
    }
    
    
    func loadAllPixels(_ completionHander: @escaping () -> Void = {}) {
        let start = cursorPos - self.pixels.count / 2
        let end = cursorPos + self.pixels.count / 2
        print("querying for pixels in range \(start), \(end)")
        // TODO: this is hacky
        // we want to replace the entire range of pixels, even if they're not adjacent
        // so set the start and end to what we want the to
            pixels[0] = AudioHapticPixel(id: start, value: 0)
            pixels[pixels.count-1] = AudioHapticPixel(id:end, value: 0)
            anchorPos = cursorPos
        // end of hacky stuf
        
        loadPixels(ids: start..<end, completionHander)
    }
    
    func loadPixels(ids: Range<Int>, _ completionHandler: @escaping () -> Void = {}) {
        // clamp to positive values for the id queries
        let ids: Range<Int> = (Swift.max(ids.lowerBound, 0)..<(Swift.max(ids.upperBound, 0)))
        
        osc.send(String.convert(
                    value: json(from: [ids.lowerBound, ids.upperBound])!),
                 at: "/pixels")
        osc.receive(on: "/pixels", { values in
            print("received pixels: \(values)")
            let pixelsStr: String = .convert(values: values)
            var newPixels: [AudioHapticPixel] = loadFromString(pixelsStr)
                                        ?? []
            
            guard !newPixels.isEmpty else { return }
            // check if we're appending to the left (we'll need to reverse if that's the case)
            if let firstPix = self.pixels.first,
               let newLast = newPixels.last{
                if newLast.id <= firstPix.id {
                    newPixels = newPixels.reversed()
                }
            }

            for pixel in newPixels {
                self[pixel.id] = pixel
            }
            
            completionHandler()
        })
    }
    
    func loadPixel(id: Int, completionHandler: @escaping () -> Void = {}) {
        let id = id.clamped(to: 0...Int.max)
        osc.send(Int.convert(value: id), at: "/pixel")
        osc.receive(on: "/pixel", { values in
            let pixelsStr: String = .convert(values: values)
            let newPixel: AudioHapticPixel = loadFromString(pixelsStr)
                                        ?? AudioHapticPixel.init(id: 0, value: 0)
            
            self[newPixel.id] = newPixel
            
            completionHandler()
        })
    }
}

func loadFromFile<T: Decodable>(_ filename: String) -> T {
    let data: Data

    guard let file = Bundle.main.url(forResource: filename, withExtension: nil)
    else {
        fatalError("Couldn't find \(filename) in main bundle.")
    }

    do {
        data = try Data(contentsOf: file)
    } catch {
        fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
    }

    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
    }
}


func loadFromString<T: Decodable>(_ json: String) -> T? {
    let data = Data(json.utf8)
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        print("Couldn't parse json string as \(T.self):\n\(error)")
        return nil
    }
}

func json(from object:Any) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
        return nil
    }
    return String(data: data, encoding: String.Encoding.utf8)
}

