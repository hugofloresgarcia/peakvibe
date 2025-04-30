//
//  AudioHapticPixelView.swift
//  peakvibe
//
//  Created by hugo on 2/17/22.
//

import SwiftUI


struct AudioHapticPixelView : View {
    var pixel: AudioHapticPixel
    @EnvironmentObject var haptics: Haptics

    var body: some View {
        GeometryReader{ geo in
            VStack(alignment: .center){
                Spacer()
                RoundedRectangle(cornerRadius: 40)
                    .fill(LinearGradient(gradient: Gradient(
                        colors: [Color(hex: 0xD72638),
                                 Color(hex: 0x3F88C5)]),
                        startPoint: .top,
                        endPoint: .bottom))
                    .frame(width: geo.size.width,
                           height: CGFloat(pixel.value) * geo.size.height)
                Spacer()
            }
        }
    }
}
