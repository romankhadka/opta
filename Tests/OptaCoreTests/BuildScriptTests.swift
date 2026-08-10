import Foundation
import Testing

@Suite("Build script")
struct BuildScriptTests {
    @Test("local builds keep a stable designated requirement")
    func localBuildsKeepStableDesignatedRequirement() throws {
        let script = try String(contentsOfFile: "scripts/build_app.sh", encoding: .utf8)

        // A developer's build has to sign with the same identity every time, or
        // macOS drops the Accessibility and Input Monitoring grants on every
        // rebuild. That identity is the self-signed one the script maintains.
        #expect(script.contains("Opta Local Code Signing"))
        #expect(script.contains("create_signing_identity"))

        // The ad-hoc identity must stay reachable only through the explicit
        // override, never as the default a plain `./scripts/build_app.sh` takes.
        let adHocDefault = script.contains("SIGNING_IDENTITY=\"$ADHOC_IDENTITY\"")
        #expect(!adHocDefault)
    }

    @Test("a distribution identity is signed for notarisation")
    func distributionIdentityIsSignedForNotarisation() throws {
        let script = try String(contentsOfFile: "scripts/build_app.sh", encoding: .utf8)

        // Notarisation refuses a bundle without these two, so an override
        // identity has to carry them.
        #expect(script.contains("--options runtime"))
        #expect(script.contains("--timestamp"))
        #expect(script.contains("OPTA_SIGNING_IDENTITY"))
    }

    @Test("continuous integration never mints the local identity")
    func continuousIntegrationNeverMintsLocalIdentity() throws {
        // `security add-trusted-cert` asks the window server for authorisation
        // and blocks forever on a runner, so every workflow that builds the app
        // has to supply an identity instead of letting the script create one.
        for path in ["ci.yml", "release.yml"] {
            let workflow = try String(
                contentsOfFile: ".github/workflows/\(path)",
                encoding: .utf8
            )
            #expect(workflow.contains("OPTA_SIGNING_IDENTITY"))
        }
    }
}
