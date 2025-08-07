//
//  AudioVisualizer.swift
//  AudioWaveFormVisualizer
//
//  Created by Doniyorbek Ibrokhimov on 29/07/25.
//

import SwiftUI
import Charts

struct AudioVisualizer: View {
    // 1. AudioWaveformMonitor shared instance
    @State var monitor = AudioWaveformMonitor.shared
    
    private let chartGradient = LinearGradient(
        gradient: Gradient(colors: [.blue, .purple, .red]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        chartContent
    }
    
    private var chartContent: some View {
        // 1. Chart
        Chart(monitor.downsampledMagnitudes.indices, id: \.self) { index in
            // 2. The LineMark
            AreaMark(
                // a. frequency bins adjusted by Constants.downsampleFactor to spread points apart
                x: .value("Frequency", index * AudioWaveformMonitor.Constants.downsampleFactor),
                
                // b. the magnitude (intensity) of each frequency
                y: .value("Magnitude", monitor.downsampledMagnitudes[index])
            )
            
            // 3. Smoothing the curves
            .interpolationMethod(.catmullRom)
            
            // The line style
            .lineStyle(StrokeStyle(lineWidth: 3))
            // The color
            .foregroundStyle(chartGradient)
        }
        .chartYScale(domain: 0...AudioWaveformMonitor.Constants.magnitudeLimit)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 300)
        .drawingGroup()
        // 3. Smoothing the curves
        .animation(.easeInOut, value: monitor.downsampledMagnitudes)
    }
}

#Preview {
    AudioVisualizer()
}
