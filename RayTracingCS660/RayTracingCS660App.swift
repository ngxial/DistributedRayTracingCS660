//
//  RayTracingCS660App.swift
//  RayTracingCS660
//
//  Created by ngxial on 2025/7/17.
//

import SwiftUI

@main
struct RayTracingCS660App: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewController: MetalViewController())
                .frame(width: 800, height: 600)
        }
    }
}
