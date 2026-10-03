import Foundation
import Observation
import IOKit
import Darwin

/// The machine's own numbers for the status row: CPU and GPU temperature, memory and disk usage.
///
/// The temperatures come from the AppleVendor temperature sensors through `IOHID`, which needs no
/// privileges. macOS exposes them nowhere else: `powermetrics` wants the administrator password and
/// the SMC keys of Apple Silicon do not answer like they do on Intel.
@Observable
final class SystemStats {
    var cpuTemperature: Double?
    var gpuTemperature: Double?
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    var diskUsed: UInt64 = 0
    var diskTotal: UInt64 = 0
    /// The clock time, refreshed together with the rest: the top bar shows it in the box of today.
    var now = Date()

    var memoryFraction: Double {
        memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0
    }

    var diskFraction: Double {
        diskTotal > 0 ? Double(diskUsed) / Double(diskTotal) : 0
    }

    /// Reads now and then every few seconds, for as long as the caller lives: the row calls this from
    /// `.task`, which cancels it when the row goes away.
    func monitor(every seconds: Double = 3) async {
        while !Task.isCancelled {
            read()
            try? await Task.sleep(for: .seconds(seconds))
        }
    }

    func read() {
        let sensors = TemperatureSensors.read()
        cpuTemperature = sensors.cpu
        gpuTemperature = sensors.gpu
        now = Date()
        readMemory()
        readDisk()
    }

    // MARK: - Memory and disk

    private func readMemory() {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return }

        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        // What Activity Monitor shows as "Memory Used": anonymous pages, wired pages and the compressor.
        // File-backed pages are left out on purpose — they are the disk cache, which on this Mac grows
        // to tens of gigabytes after a build and would make the row meaningless.
        let pages = UInt64(statistics.internal_page_count)
            + UInt64(statistics.wire_count)
            + UInt64(statistics.compressor_page_count)
        memoryUsed = pages * UInt64(pageSize)
    }

    private func readDisk() {
        guard let attributes = try? FileManager.default
            .attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = (attributes[.systemSize] as? NSNumber)?.uint64Value,
              let free = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value,
              total > 0 else { return }
        diskTotal = total
        diskUsed = total > free ? total - free : 0
    }

    // MARK: - Text

    static func temperature(_ value: Double?) -> String {
        guard let value, value > 0, value < 130 else { return "–" }
        return "\(Int(value.rounded()))°C"
    }

    /// Which scale the byte sizes are shown in: memory is counted by 1024 (as Activity Monitor does),
    /// disks by 1000 (as Finder does).
    enum ByteStyle {
        case memory
        case file
    }

    /// Written by hand rather than with `ByteCountFormatter`, which has no `locale` in Swift and so
    /// would follow the system language — the interface is English.
    static func bytes(_ value: UInt64, style: ByteStyle) -> String {
        let step: Double = style == .memory ? 1024 : 1000
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var amount = Double(value)
        var unit = 0
        while amount >= step, unit < units.count - 1 {
            amount /= step
            unit += 1
        }
        let decimals = unit <= 1 || amount >= 100 ? 0 : 1
        return String(format: "%.\(decimals)f %@", amount, units[unit])
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

/// The Apple Silicon temperature sensors.
///
/// `PMU tdieN` are the CPU sensors and `PMU tdevN` the GPU ones — the same split `powermetrics`
/// prints as "CPU die temperature" and "GPU die temperature". Every value is the average of the
/// sensors of its group, ignoring the ones that answer with something impossible.
private enum TemperatureSensors {
    private typealias Client = CFTypeRef
    private typealias Service = CFTypeRef
    private typealias Event = CFTypeRef

    // Private IOKit entry points, resolved by name at launch.
    @_silgen_name("IOHIDEventSystemClientCreate")
    private static func createClient(_ allocator: CFAllocator?) -> Client?

    @_silgen_name("IOHIDEventSystemClientSetMatching")
    private static func setMatching(_ client: Client?, _ matching: CFDictionary?) -> Int32

    @_silgen_name("IOHIDEventSystemClientCopyServices")
    private static func copyServices(_ client: Client?) -> CFArray?

    @_silgen_name("IOHIDServiceClientCopyProperty")
    private static func copyProperty(_ service: Service?, _ key: CFString?) -> CFTypeRef?

    @_silgen_name("IOHIDServiceClientCopyEvent")
    private static func copyEvent(_ service: Service?, _ type: Int64,
                                 _ options: Int32, _ timestamp: Int64) -> Event?

    @_silgen_name("IOHIDEventGetFloatValue")
    private static func floatValue(_ event: Event?, _ field: Int32) -> Double

    private static let temperatureEvent: Int64 = 15
    private static let temperatureField = Int32(temperatureEvent << 16)

    static func read() -> (cpu: Double?, gpu: Double?) {
        guard let client = createClient(kCFAllocatorDefault) else { return (nil, nil) }
        // AppleVendor (0xff00) temperature sensor (usage 5).
        let matching: [String: Any] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]
        _ = setMatching(client, matching as CFDictionary)
        guard let services = copyServices(client) as? [Service] else { return (nil, nil) }

        var cpu: [Double] = []
        var gpu: [Double] = []
        for service in services {
            let name = copyProperty(service, "Product" as CFString) as? String ?? ""
            let group: String?
            if name.hasPrefix("PMU tdie") {
                group = "cpu"
            } else if name.hasPrefix("PMU tdev") {
                group = "gpu"
            } else {
                group = nil
            }
            guard let group, let event = copyEvent(service, temperatureEvent, 0, 0) else { continue }

            let value = floatValue(event, temperatureField)
            guard value > 1, value < 130 else { continue }
            if group == "cpu" { cpu.append(value) } else { gpu.append(value) }
        }

        func average(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        return (average(cpu), average(gpu))
    }
}