import Foundation

// 終端機測試程式：模擬按鍵，印出輸入區的變化。
// 特殊記號：␣=空白  ⌫=Backspace  ↓N=按↓後選第 N 個候選字  ↓?=只列出候選字
//          ⏎=Enter  其他全形標點=Shift+標點鍵

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent().path
let engine = Engine(zhPath: root + "/Resources/zh.txt", enPath: root + "/Resources/en.txt")

func run(_ title: String, _ keys: String) {
    engine.clear()
    var steps: [String] = [], committed = ""
    var chars = Array(keys)[...]
    while let ch = chars.popFirst() {
        switch ch {
        case "␣": engine.type(" ")
        case "⌫": engine.backspace()
        case "←": engine.moveLeft()
        case "→": engine.moveRight()
        case "⏎": committed += engine.commit()
        case "↓":
            let cands = engine.candidates()
            let pick = chars.popFirst()!
            let shown = cands.prefix(9).enumerated().map { "\($0 + 1).\($1.text)" }.joined(separator: " ")
            steps.append("[候選字 \(shown)]")
            if let n = pick.wholeNumberValue, n >= 1, n <= cands.count { engine.select(cands[n - 1]) } else { continue }
        default:
            if ch.isASCII { engine.type(ch) } else { engine.insertLiteral(String(ch)) }
        }
        if ch != "⏎" {
            var (t, c) = engine.displayWithCursor
            if "←→".contains(ch) || !engine.tail.isEmpty { t = String(decoding: Array(t.utf16.prefix(c)), as: UTF16.self) + "|" + String(decoding: Array(t.utf16.dropFirst(c)), as: UTF16.self) }
            steps.append(t.replacingOccurrences(of: " ", with: "␣"))
        }
    }
    committed += engine.commit()
    print("【\(title)】按鍵：\(keys)")
    print("  輸入區：" + steps.joined(separator: " → "))
    print("  送出：「\(committed)」\n")
}

if CommandLine.arguments.count > 2, CommandLine.arguments[1] == "conflicts" {
    // 列出「打完按空白會變成中文」的常用英文字
    let words = try! String(contentsOfFile: root + "/Resources/en.txt", encoding: .utf8).split(separator: "\n").prefix(Int(CommandLine.arguments[2])!)
    var hits: [String] = []
    for w in words {
        engine.clear()
        for ch in w { engine.type(ch) }
        engine.type(" ")
        if case .syl? = engine.segs.first { hits.append("\(w)→\(engine.display)") }
    }
    print(hits.joined(separator: "  "))
    exit(0)
}

for arg in CommandLine.arguments.dropFirst() { run("自訂", arg) }
if CommandLine.arguments.count > 1 { exit(0) }

run("1 一般中文", "su3cl3")
run("2 一聲按空白", "rup␣wu0␣")
run("3 中英混打", "ji3ul4fm4␣meeting")
run("4 英文接中文", "meeting␣ji3")
run("5 刪除後變回注音", "meeting⌫⌫⌫⌫⌫⌫")
run("6 go 沒有這個字→英文", "go␣")
run("6b 誰", "go6")
run("7 up 預設中文", "up␣")
run("7b up 按↓改英文", "up␣↓?")
run("7c up 選英文", "up␣↓2")
run("8 數字 2026", "2026")
run("8b 20 預設丹", "20␣")
run("8c 20 按↓改數字", "20␣↓2")
run("8d 2026年", "2026su06")
run("9 候選字", "su3cl3↓?")
run("9b 選別的字", "su3cl3↓2")
run("10 Shift+字母大寫", "iPhone␣cl3")
run("11 全形標點", "su3cl3，ji3g4hello！")
run("12 長句", "rup␣wu0␣ji3ul4fm4␣meeting␣5k4b/6")
run("13 沒打聲調就送出", "rup")
