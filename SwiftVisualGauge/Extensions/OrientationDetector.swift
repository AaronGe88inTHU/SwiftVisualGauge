//
//  OrientationDetector.swift
//  SwiftVisualGauge
//
//  Created by Aaron Ge on 2022/7/28.
//

import SwiftUI

struct OrientationDetector: ViewModifier {
    @Binding var orientation: UIDeviceOrientation
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                orientation = UIDevice.current.orientation
            }
    }
}


extension View{
    func detectOrientation(_ binding: Binding<UIDeviceOrientation>) -> some View {
        self.modifier(OrientationDetector(orientation: binding))
    }
}

