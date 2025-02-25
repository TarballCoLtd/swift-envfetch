// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Darwin
import Darwin.Mach
import AppKit
import IOKit
import IOKit.graphics
import IOKit.ps
import MachO

public struct swiftenv {
    
    private init() { }
    
}

public extension swiftenv {
    
    static var swiftVersion: String? {
        let output = try? shell("swift", arguments: ["--version"])
        guard let output = output else { return nil }
        let versionFull = output.split(separator: "Apple Swift version ").last
        guard let versionFull = versionFull else { return nil }
        let version = versionFull.split(separator: " ").first
        guard let version = version else { return nil }
        return String(version).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static var swiftTriple: String? {
        let output = try? shell("swift", arguments: ["--version"])
        guard let output = output else { return nil }
        let target = output.split(separator: "Target: ").last
        guard let target = target else { return nil }
        return String(target).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func shell(_ command: String, arguments: [String] = []) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = nil
        try process.run()
        process.waitUntilExit()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 { throw EnvironmentFetchError.shellError }
        return output
    }
    
}

public extension swiftenv {
    
    static var kernelName: String? {
        var uts = utsname()
        uname(&uts)
        return String(bytes: Data(bytes: &uts.sysname, count: Int(_SYS_NAMELEN)), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }
    static var kernelVersion: String? {
        var uts = utsname()
        uname(&uts)
        return String(bytes: Data(bytes: &uts.release, count: Int(_SYS_NAMELEN)), encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }
    
    static var hostname: String? { Host.current().localizedName }
    
    static var uptime: String { String(forInterval: ProcessInfo.processInfo.systemUptime) }
    
    static var osName: String {
        #if os(macOS)
        "macOS"
        #else
        "unknown"
        #endif
    }
    static var osVersion: String { String(ProcessInfo.processInfo.operatingSystemVersionString.split(separator: "Version ").last ?? "unknown") }
    static var osVersionShort: String { "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.patchVersion)" }
    static var osArchitecture: String {
        #if arch(x86_64)
        "x86_64"
        #elseif arch(arm64)
        "arm64"
        #else
        "unknown"
        #endif
    }
    
}

public extension swiftenv {
    
    static var displays: [SystemDisplay] {
        let screens = NSScreen.screens as [NSScreen]
        var displayList: [SystemDisplay] = []
        for (index, screen) in screens.enumerated() {
            let resolution = screen.frame.size
            let refreshRate = screen.deviceDescription[NSDeviceDescriptionKey("NSDeviceRefreshRate")] as? Double
            let intRefreshRate = Int16(Float(refreshRate ?? -1))
            let uintRefreshRate: UInt16? = intRefreshRate > 0 ? UInt16(intRefreshRate) : nil
            displayList.append(SystemDisplay(width: UInt16(Float(resolution.width)), height: UInt16(Float(resolution.height)), refreshRate: uintRefreshRate, index: index))
        }
        return displayList
    }
    
}

public extension swiftenv {
    
    static var cpuName: String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpuName = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpuName, &size, nil, 0)
        let name = String(cString: cpuName)
        return name
    }
    static var cpuCores: Int {
        var cores: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.ncpu", &cores, &size, nil, 0)
        return cores
    }
    static var cpuFrequency: Double {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var freq: Double = 0
        size = MemoryLayout<Double>.size
        sysctlbyname("hw.cpufrequency", &freq, &size, nil, 0)
        freq = freq / 1_000_000_000
        return freq
    }
    
}

public extension swiftenv {
    
    static var gpus: [SystemGPU] { // TODO: fix on Apple Silicon
        var gpuInfos: [SystemGPU] = []
        let matching = IOServiceMatching("IOPCIDevice")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                if let model = IORegistryEntrySearchCFProperty(service, kIOServicePlane, "model" as CFString, nil, IOOptionBits(kIORegistryIterateRecursively)) as? String {
                    let integrated = model.contains("Intel") || model.contains("Apple")
                    gpuInfos.append(SystemGPU(name: model, integrated: integrated))
                }
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        return gpuInfos
    }
    
}

public extension swiftenv {
    
    static var physicalMemory: UInt64 { ProcessInfo.processInfo.physicalMemory }
    static var physicalMemoryString: String { ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory) }
    
    static var usedMemory: UInt64 {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var vmStats = vm_statistics64()
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &size)
            }
        }
        if result != KERN_SUCCESS {
            return 0
        }
        let used = UInt64(vmStats.active_count + vmStats.inactive_count + vmStats.wire_count) * 16384 // TODO: fix on Intel
        return used
    }
    static var usedMemoryString: String { ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory) }
    
}

public extension swiftenv {
    
    static var batteryLevel: Double? {
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef], let source = sources.first, let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
            let currentCapacity = description["Current Capacity"] as? Int
            let maxCapacity = description["Max Capacity"] as? Int
            let batteryLevel = currentCapacity != nil && maxCapacity != nil ? Double(currentCapacity!) / Double(maxCapacity!) : nil
            return batteryLevel
        }
        return nil
    }
    static var batteryLevelPercent: String? {
        guard let level = batteryLevel else { return nil }
        return "\(Int(level * 100))%"
    }
    static var charging: Bool? {
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef], let source = sources.first, let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
            return description["Is Charging"] as? Bool
        }
        return nil
    }
    
}

public struct SystemDisplay {
    
    let width: UInt16
    let height: UInt16
    let refreshRate: UInt16?
    let index: Int
    
}

public struct SystemGPU {
    
    let name: String
    let integrated: Bool
    
}

extension String {
    
    init(forInterval interval: TimeInterval) {
        let time = NSInteger(interval)
        let ms = Int((interval.truncatingRemainder(dividingBy: 1)) * 1000)
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        self.init(format: "%0.2dh:%0.2dm:%0.2ds", hours, minutes, seconds, ms)
    }
    
}

public enum EnvironmentFetchError: Error { case shellError }
