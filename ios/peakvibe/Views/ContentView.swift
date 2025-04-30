//
//  ContentView.swift
//  peakvibe
//
//  Created by hugo on 1/31/22.
//

import SwiftUI
import SwiftUIOSC

extension CGRect {
    var center: CGPoint { .init(x: midX, y: midY) }
}

struct OSCStatusBar : View {
    
    var body: some View {
        HStack{
            NavigationLink(destination: OSCSettingsView()) {
                Label("Network Settings", systemImage: "gear")
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var haptics: Haptics

    var body: some View {
        NavigationView{
            VStack {
                OSCStatusBar()
                Divider()
                PeakMeterView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 15.0, *) {
            ContentView()
                .previewInterfaceOrientation(.landscapeRight)
                .environmentObject(Haptics())
        } else {
            // Fallback on earlier versions
        }
    }
}
