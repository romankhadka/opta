import Foundation
import Testing

@Suite("Build script")
struct BuildScriptTests {
    @Test("release app uses a stable designated requirement")
    func releaseAppUsesStableDesignatedRequirement() throws {
        let script = try String(contentsOfFile: "scripts/build_app.sh", encoding: .utf8)

        #expect(script.contains("Opta Local Code Signing"))
        #expect(!script.contains("codesign --force --deep --sign -"))
        #expect(!script.contains("--sign -"))
    }
}
