import ApplicationServices
import CoreGraphics
import Darwin

// Makes one specific window the key window of its process and brings the
// process to the front with it, in a single WindowServer request.
//
// `NSRunningApplication.activate` cannot do this. Activation is asynchronous,
// and when it lands the application re-raises its own last key window. Chrome
// ignores accessibility writes to its main and focused window while it is
// inactive, so selecting a Chrome window behind another app brought forward
// whichever Chrome window was last key, even on another display.
//
// The SkyLight functions are private but have been stable for years; window
// switchers such as AltTab and Hammerspoon use the same sequence. They are
// resolved at runtime so a future macOS without them falls back to the public
// activation path instead of failing to launch.
enum WindowServerFocus {
    private typealias GetProcessForPIDFunction = @convention(c) (
        pid_t,
        UnsafeMutablePointer<ProcessSerialNumber>
    ) -> OSStatus
    private typealias SetFrontProcessFunction = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        CGWindowID,
        UInt32
    ) -> CGError
    private typealias PostEventRecordFunction = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        UnsafeMutablePointer<UInt8>
    ) -> CGError

    private struct Functions {
        let getProcessForPID: GetProcessForPIDFunction
        let setFrontProcess: SetFrontProcessFunction
        let postEventRecord: PostEventRecordFunction
    }

    // Fronts only the named window. The all-windows mode (0x100) would lift
    // every window of the application above other applications' windows.
    private static let userGeneratedFrontMode: UInt32 = 0x200

    private static let functions: Functions? = {
        guard
            let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
            let setFrontProcess = dlsym(skyLight, "_SLPSSetFrontProcessWithOptions"),
            let postEventRecord = dlsym(skyLight, "SLPSPostEventRecordTo"),
            // Deprecated but still exported; resolved here like the rest so the
            // build stays free of deprecation warnings.
            let getProcessForPID = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "GetProcessForPID")
        else {
            return nil
        }

        return Functions(
            getProcessForPID: unsafeBitCast(getProcessForPID, to: GetProcessForPIDFunction.self),
            setFrontProcess: unsafeBitCast(setFrontProcess, to: SetFrontProcessFunction.self),
            postEventRecord: unsafeBitCast(postEventRecord, to: PostEventRecordFunction.self)
        )
    }()

    /// Returns false when the WindowServer functions are missing or refuse the
    /// request, so the caller can fall back to public activation.
    static func bringToFront(windowID: CGWindowID, processIdentifier: pid_t) -> Bool {
        guard let functions else {
            return false
        }

        var processSerialNumber = ProcessSerialNumber()
        guard functions.getProcessForPID(processIdentifier, &processSerialNumber) == noErr else {
            return false
        }

        guard functions.setFrontProcess(&processSerialNumber, windowID, userGeneratedFrontMode) == .success else {
            return false
        }

        makeKeyWindow(windowID, processSerialNumber: &processSerialNumber, using: functions)
        return true
    }

    // Some applications only move key status on the event pair a click on the
    // window would produce, so post it as well.
    private static func makeKeyWindow(
        _ windowID: CGWindowID,
        processSerialNumber: inout ProcessSerialNumber,
        using functions: Functions
    ) {
        for eventKind: UInt8 in [0x01, 0x02] {
            var eventRecord = [UInt8](repeating: 0, count: 0xf8)
            eventRecord[0x04] = 0xf8
            eventRecord[0x08] = eventKind
            eventRecord[0x3a] = 0x10
            for offset in 0x20..<0x30 {
                eventRecord[offset] = 0xff
            }
            withUnsafeBytes(of: windowID) { windowIDBytes in
                eventRecord.replaceSubrange(0x3c..<0x40, with: windowIDBytes)
            }

            _ = eventRecord.withUnsafeMutableBufferPointer { buffer in
                functions.postEventRecord(&processSerialNumber, buffer.baseAddress!)
            }
        }
    }
}
