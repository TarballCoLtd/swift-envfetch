//
//  main.swift
//  swift-envfetch
//
//  Created by Alyxandra Ferrari on 2/24/2025.
//

import EnvironmentFetch

struct Entrypoint {
    
    static func main() {
        
        print("Swift \(swiftenv.swiftVersion!)")
        print("Kernel: \(swiftenv.kernelName!) \(swiftenv.kernelVersion!)")
        print("Hostname: \(swiftenv.hostname!)")
        print("Uptime: \(swiftenv.uptime)")
        print("OS: \(swiftenv.osName) \(swiftenv.osVersion) \(swiftenv.osArchitecture)")
        print("CPU: \(swiftenv.cpuName) (\(swiftenv.cpuCores)) @ \(swiftenv.cpuFrequency) GHz")
        print("GPUs: \(swiftenv.gpus)")
        print("Memory: \(swiftenv.usedMemoryString) / \(swiftenv.physicalMemoryString)")
        print("Battery: \(swiftenv.batteryLevelPercent!)")
        print("Battery Charging: \(swiftenv.charging!)")
        
    }
    
}

Entrypoint.main()
