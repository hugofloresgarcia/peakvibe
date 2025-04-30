//
//  PeakMeterView.swift
//  peakvibe
//
//  Created by hugo on 5/4/22.
//

import Foundation
import SwiftUI
import SwiftUIOSC

func mapRanges(_ r1: ClosedRange<Float>, _ r2: ClosedRange<Float>, to: Float) -> Float {
  let num = (to - r1.lowerBound) * (r2.upperBound - r2.lowerBound)
  let denom = r1.upperBound - r1.lowerBound
 
  return r2.lowerBound + num / denom
}

struct PeakMeterView : View {
    var osc: OSC = .shared
    @State var level: Double = 0.1
    
    //TODO: add a UI for this
    @State var alertThreshold: Double = -0.1 // in dB
    
    @EnvironmentObject var haptics: Haptics
    var hapMapper = dbSoundMapper()
    var player = TransientHapticPlayer()
    @State var isClipping: Bool = false
    

    var body: some View {
        HStack(alignment: .center) {
            Text("Alert Threshold (dB)")
            Slider(value: $alertThreshold, in: -60.0...0.0, step: 1.5)
                .accessibilityValue(String(format: "%.2f dB", alertThreshold) )
                
        }
        .accessibilityElement(children: .combine)
            
        GeometryReader { geo in
            VStack {
                Text("dB: \(amp2db(level))")
                
                AudioHapticPixelView(pixel:
                    AudioHapticPixel(id: 0, value: CGFloat(hapMapper.map(level))))
                .frame(width: geo.size.width * 0.25)
                .position(x: geo.frame(in: .local).midX,
                          y: geo.frame(in: .local).midY)
                .onAppear {
                    // let the controller know what out new mode is
                    osc.send("meter", at: "/set_mode")
                    
                    // handle receive any peaks
                    osc.receive(on: "/peak") { values in
                        // get the level from the read values
                        level = .convert(values: values)
                        
                        guard !isClipping else {
                            print("will not play peak, clipping.")
                            return
                        }
                    
                        // if we're clipping, play the clip alert
                        if (level > db2amp(alertThreshold)) {
                            clipAlert(1)
                            return
                        }
                        
                        // map level to intensity
                        let intensity = hapMapper.map(level)
                        print("intensity is \(intensity)")
    //                    level = Double(intensity)
                        
                        // update player params
                        self.player.update(intensity: Float(intensity),
                                           sharpness: 0.6)
                        
                        // start player if needed
                        if (self.player.player == nil) {
                            self.player.start(with: haptics)
                        }
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Peak Meter: \(Int(amp2db(level + 1e-5))) dB")
    }
    
    func clipAlert(_ dur: TimeInterval) {
        isClipping = true
        let player = ContinuousHapticPlayer()
        player.update(intensity: 1.0, sharpness: 1.0)
        player.start(with: haptics)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            player.stop()
            isClipping = false
        }
    }
}
