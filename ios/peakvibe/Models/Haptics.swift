//
//  Haptics.swift
//  peakvibe
//
//  Created by hugo on 1/31/22.
//

import Foundation
import SwiftUI
import CoreHaptics

class Haptics : ObservableObject{
    var engine: CHHapticEngine!
    
    // Tokens to track whether app is in the foreground or the background:
    private var foregroundToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    
    @Published var engineNeedsStart = true
    private lazy var supportsHaptics: Bool = {
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }()
    
    func prepare() {
        guard supportsHaptics else { return }
        guard (engineNeedsStart) else { return }
        
        print("preparing haptic engine")
    
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            print("engine started")
            engineNeedsStart = false
            addObservers()
        } catch {
            fatalError("There was an error creating the engine: \(error.localizedDescription)")
        }
        
        // handle engine reset
        engine?.resetHandler = {
            do {
                print("handling haptic engine reset.")
                // Try restarting the engine.
                try self.engine?.start()
                self.engineNeedsStart = false
                        
                // Register any custom resources you had registered, using registerAudioResource.
                // Recreate all haptic pattern players you had created, using createPlayer.

            } catch {
                fatalError("Failed to restart the engine: \(error)")
            }
        }
        
        // The stopped handler alerts engine stoppage.
        engine?.stoppedHandler = { reason in
            print("Haptic engine stopped for reason: \(reason.rawValue)")
            
            switch reason {
            case .audioSessionInterrupt: print("Audio session interrupt")
            case .applicationSuspended: print("Application suspended")
            case .idleTimeout: print("Idle timeout")
            case .systemError: print("System error")
            case .notifyWhenFinished: print("Notify when Finished")
            case .engineDestroyed: print("engine destroyed")
            case .gameControllerDisconnect: print("Game controller disconnect")
            @unknown default:
                print("Unknown error")
            }
            DispatchQueue.main.async {
                self.engineNeedsStart = true
            }
        }
    }
    

    private func addObservers() {
        backgroundToken = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                                 object: nil,
                                                                 queue: nil)
        { _ in
            guard self.supportsHaptics else {
                return
            }
            // Stop the haptic engine.
            self.engine.stop(completionHandler: { error in
                if let error = error {
                    print("Haptic Engine Shutdown Error: \(error)")
                    return
                }
                DispatchQueue.main.async {
                    self.engineNeedsStart = true
                }
            })
        }
        foregroundToken = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                                 object: nil,
                                                                 queue: nil)
        { _ in
            guard self.supportsHaptics else {
                return
            }
            // Restart the haptic engine.
            self.engine.start(completionHandler: { error in
                if let error = error {
                    fatalError("Haptic Engine Startup Error: \(error)")
                }
                DispatchQueue.main.async {
                    self.engineNeedsStart = true
                }
            })
        }
    }
}

// abstract class for haptic players
class AudioPixelHapticPlayer: ObservableObject {
    var player: CHHapticAdvancedPatternPlayer! = nil
    internal var haptics: Haptics!
    
    internal var intensity: Float = 1.0
    internal var sharpness: Float = 1.0

    // takes a list of haptic events, plays them immediately, and handles any errors
    func startEvents(_ events: [CHHapticEvent]) -> Void {
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            self.player = try self.haptics.engine.makeAdvancedPlayer(with: pattern)
            self.player.completionHandler = { error in
//                print("haptic player completed.")
                if let error = error {
                    print("haptic error: \(error)")
                }
            }
            try self.player.start(atTime: CHHapticTimeImmediate)
        } catch let error {
            print("Pattern Player Creation Error: \(error)")
        }
    }
    
    // start the haptic player
    func start(with haptics: Haptics) { preconditionFailure("not implemented") }
    
    // update pixel value and sharpness
    func update(intensity: Float, sharpness: Float) { preconditionFailure("not implemented") }
    
    // stop immediately
    func stop() {
        do {
            try self.player?.stop(atTime: 0)
            self.player = nil
        } catch let error {
            print("Error stopping the haptic player: \(error)")
        }
    }
}


// a continuous haptic player that works via changes in intensity and sharpness
class ContinuousHapticPlayer : AudioPixelHapticPlayer {
    
    override func start(with haptics: Haptics) {
        self.haptics = haptics
        
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                    value: self.intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                    value: self.sharpness)
        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensityParam, sharpnessParam],
                                  relativeTime: 0, duration: 864000000)
         
        startEvents([event])
    }
    
    override func update(intensity: Float, sharpness: Float){
        self.intensity = intensity // the continuous haptic player just maps the value to intensity directly
        self.sharpness = sharpness
        if (self.player != nil){
            let intensityParam = CHHapticDynamicParameter(parameterID: .hapticIntensityControl,
                                                          value: self.intensity, relativeTime: 0)
            let sharpnessParam = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                                          value: self.sharpness, relativeTime: 0)
            
            // Send dynamic parameters to the haptic player.
            do {
                try self.player?.sendParameters([intensityParam, sharpnessParam], atTime: 0)
            } catch let error {
                print("Error updating player parameters: \(error)")
            }
        }
    }
}

// use me to send single transient taps every update() call
class TransientHapticPlayer : AudioPixelHapticPlayer {
    
    private func tap() {
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                    value: self.intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                    value: self.sharpness)
        
        
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensityParam, sharpnessParam],
                                  relativeTime: 0)
        
        startEvents([event])
    }
    
    
    override func start(with haptics: Haptics) {
        self.haptics = haptics
        self.tap()
    }
    
    override func update(intensity: Float, sharpness: Float) {
        self.intensity = intensity
        self.sharpness = sharpness
        if (self.haptics != nil){
            self.tap()
        }
    }
}


// a haptic player that sends a train of pulses at different frequencies,
// attempting to mimic frequency modulation
class PulseFMHapticPlayer : AudioPixelHapticPlayer {
    private var pulseTimer: DispatchSourceTimer? = nil
    private var frequency: Float = 1
    private var period: Int { get { Int(1 / self.frequency * 1000000) } }
    
    override func start(with haptics: Haptics) {
        self.haptics = haptics
        startPulseTimer()
    }
    
    func update(frequency: Float, intensity: Float, sharpness: Float) {
        self.frequency = frequency
        self.intensity = intensity
        self.sharpness = sharpness
    }
    
    func startPulseTimer() {
        guard pulseTimer == nil else { return }
        // play immediately
        self.playHapticTransient(intensity: self.intensity,
                                 sharpness: self.sharpness)
        
        // Create a timer to play subsequent transient patterns in succession.
        pulseTimer?.cancel()
        pulseTimer = DispatchSource.makeTimerSource(queue: .main)
        guard let timer = pulseTimer else {
            print("failed to create timer")
            return
        }
        timer.schedule(deadline: .now() + .microseconds(self.period))
        timer.setEventHandler() { [unowned self] in
            self.playHapticTransient(intensity: self.intensity,
                                     sharpness: self.sharpness)
            
            
            // schedule the next timer
            timer.schedule(deadline: .now() + .microseconds(self.period))
        }

        // Activate the timer.
        timer.resume()

    }


    // Play a haptic transient pattern at the given time, intensity, and sharpness.
    private func playHapticTransient(intensity: Float,
                                     sharpness: Float) {
        
        // Create an event (static) parameter to represent the haptic's intensity.
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                        value: intensity)
        
        // Create an event (static) parameter to represent the haptic's sharpness.
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                        value: sharpness)
        
        // Create an event to represent the transient haptic pattern.
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensityParameter, sharpnessParameter],
                                  relativeTime: 0)
        
        startEvents([event])
        
    }
    
    override func stop() {
        super.stop()
        // Stop the transient timer.
        pulseTimer?.cancel()
        pulseTimer = nil
    }

}




