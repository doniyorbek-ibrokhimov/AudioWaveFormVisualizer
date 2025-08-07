//
//  AudioWaveformMonitor.swift
//  AudioWaveFormVisualizer
//
//  Created by Doniyorbek Ibrokhimov on 29/07/25.
//


import SwiftUI
import AVFoundation
import Accelerate
import Charts
import LiveKit

@Observable
final class AudioWaveformMonitor {
    
    // 2. Shared instance of the class
    static let shared = AudioWaveformMonitor()
    
    // 4. Store the results 
    @MainActor
    var fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    
    // 5. Pick a subset of fftMagnitudes at regular intervals according to the downsampleFacto
    @MainActor
    var downsampledMagnitudes: [Float] {
        fftMagnitudes.lazy.enumerated().compactMap { index, value in
            index.isMultiple(of: Constants.downsampleFactor) ? value : nil
        }
    }
    
    var audioStream: AsyncStream<[Float]>.Continuation?
   
    private init() {}
    
    func startMonitoring() async {
        // 3. Set the FFT configuration
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(self.bufferSize), .FORWARD)
        
        // 3. Retrieving the data from the audioStream
        for await floatData in streamAudio() {
            // 4. For each buffer, compute the FFT on background thread
            let magnitudes = await self.performFFT(data: floatData)
            
            // 5. Update UI properties on main thread
            await MainActor.run {
                self.fftMagnitudes = magnitudes
            }
        }
    }
    
    private func streamAudio() -> AsyncStream<[Float]> {
        AsyncStream<[Float]> { continuation in
            self.audioStream = continuation
        }
    }
    
    func stopMonitoring() async {
        // 3. Reset the fftMagnitudes array to all zeros, to clear the visualization
        await MainActor.run {
            fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
        }
        
        // 4. Release the FFT setup free system memory
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
            fftSetup = nil
        }
    }
    
    func performFFT(data: [Float]) async -> [Float] {
        // Check the configuration
        guard let setup = fftSetup else {
            return [Float](repeating: 0, count: Constants.sampleAmount)
        }
        
        // 1. Copy of the audio samples as float
        var realIn = data
        // 2. The imaginary part
        var imagIn = [Float](repeating: 0, count: bufferSize)
        
        // 3. The transformed values of the real data
        var realOut = [Float](repeating: 0, count: bufferSize)
        // The transformed values of the imaginary data
        var imagOut = [Float](repeating: 0, count: bufferSize)
        
        // Property storing computed magnitudes
        var magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
        
        // 1. Nested loops to safely access all data
        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                            // 2. Execute the Discrete Fourier Transform (DFT)
                        vDSP_DFT_Execute(setup, realInPtr.baseAddress!, imagInPtr.baseAddress!, realOutPtr.baseAddress!, imagOutPtr.baseAddress!)
                        
                        
                        // 3. Hold the DFT output
                        var complex = DSPSplitComplex(realp: realOutPtr.baseAddress!, imagp: imagOutPtr.baseAddress!)
                        // 4. Compute and save the magnitude of each frequency component
                        vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(Constants.sampleAmount))
                        
                    }
                }
            }
        }
        
        return magnitudes.map { min($0, Constants.magnitudeLimit) }
    }
    
    // 1. The configuration parameter for the FFT
    private let bufferSize = 480
    // 2. The FFT configuration
    private var fftSetup: OpaquePointer?
}

extension AudioWaveformMonitor {
    enum Constants {
        // a. Amount of frequency bins to keep after performing the FFT
        static let sampleAmount: Int = 100
        // b. Reduce the number of plotted points
        static let downsampleFactor = 20
        // c. Handle high spikes distortion in the chart
        static let magnitudeLimit: Float = 1
    }
}

extension AudioWaveformMonitor: AudioRenderer {
    func render(pcmBuffer: AVAudioPCMBuffer) {
        let data = pcmBuffer.convert(toCommonFormat: .pcmFormatFloat32)
        let channelData = data?.floatChannelData?[0]
        let frameCount = Int(data?.frameLength ?? 0)
        
        if let channelData {
            let floatData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            audioStream?.yield(floatData)
        }
    }
}
