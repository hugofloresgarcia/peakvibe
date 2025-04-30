//
//  dB.swift
//  peakvibe
//
//  Created by hugo on 5/17/22.
//

import Foundation


protocol PeakToHapticIntensityMapper {
    // peaklevel should be a value between 0 - 1
    func map(_ level: Double) -> Double
}

func amp2db(_ amp: Double) -> Double {
    return (20 * log (amp) / log(10))
}

func db2amp(_ db: Double) -> Double {
    return pow(10, db / 20)
}

class dbSoundMapper : PeakToHapticIntensityMapper {
    
    // 1 is no compression, 2 cuts it by half, and so on.
    let ratio: Double = 5
    
    func map(_ level: Double) -> Double {
        let dbsoundrange: ClosedRange<Double> = (-90...0)
        let dbsound = amp2db(level).clamped(to: dbsoundrange)
        let dbtouch = dbsound / ratio
        let intensity = db2amp(dbtouch)
        return intensity
    }
}
