import Cocoa
import Carbon
import InputMethodKit

// `MixedIME --register`：向系統登記這個輸入法（安裝時用一次）
if CommandLine.arguments.contains("--register") {
    let status = TISRegisterInputSource(Bundle.main.bundleURL as CFURL)
    print(status == noErr ? "registered" : "register failed: \(status)")
    exit(status == noErr ? 0 : 1)
}

let engine = Engine(zhPath: Bundle.main.path(forResource: "zh", ofType: "txt") ?? "",
                    enPath: Bundle.main.path(forResource: "en", ofType: "txt") ?? "")
let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "MixedBopomofo_Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
NSApplication.shared.run()
