//
//  peakvibeApp.swift
//  peakvibe
//
//  Created by hugo on 1/31/22.
//

import SwiftUI
import SwiftUIOSC
//
//public func print(_ object: Any...) {
////    #if DEBUGGING
////    for item in object {
////        Swift.print(item)
////    }
////    #endif
//}

@main
struct peakvibeApp: App {
    @StateObject var haptics = Haptics()
    @ObservedObject var osc: OSC = .shared
    
    var body: some Scene {
        
        WindowGroup {
            ContentView()
                .environmentObject(haptics)
                .onAppear(perform: {
                    haptics.prepare()
                    // handle pings
                    osc.receive(on: "/ping") { values in
                        // acknowledge the ping
                        osc.send(true, at: "/ping_ack")
                    }
                })
        }
    }
}

