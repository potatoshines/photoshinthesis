//
//  PlantAnimationView.swift
//  Photoshinthesis
//

import SwiftUI
import Lottie

struct PlantAnimationView: View {
    let progress: Double
    let celebrationTrigger: Int
    let onCelebrationFinished: () -> Void

    @State private var isCelebrating = false

    var body: some View {
        Group {
            if isCelebrating {
                LottieView(animation: .named("plant_growth"))
                    .playbackMode(.playing(.toProgress(1, loopMode: .playOnce)))
                    .animationDidFinish { _ in
                        isCelebrating = false
                        onCelebrationFinished()
                    }
            } else {
                LottieView(animation: .named("plant_growth"))
                    .currentProgress(progress)
            }
        }
        .frame(width: 160, height: 160)
        .onChange(of: celebrationTrigger) { _, _ in
            isCelebrating = true
        }
    }
}

#Preview {
    PlantAnimationView(progress: 0.5, celebrationTrigger: 0, onCelebrationFinished: {})
}
