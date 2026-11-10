import Foundation

/// 中英混打引擎：不依賴 macOS 輸入法系統，可以單獨在終端機測試。
final class Engine {
    // MARK: 鍵盤對應（標準大千注音）
    static let keyMap: [Character: String] = [
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ", "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ", "r": "ㄐ", "f": "ㄑ", "v": "ㄒ", "5": "ㄓ", "t": "ㄔ",
        "g": "ㄕ", "b": "ㄖ", "y": "ㄗ", "h": "ㄘ", "n": "ㄙ", "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ", "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ", "-": "ㄦ",
    ]
    static let toneMap: [Character: String] = ["3": "ˇ", "4": "ˋ", "6": "ˊ", "7": "˙", " ": ""]

    enum Seg {
        case syl(reading: String, raw: String)              // 一個注音音節，尚未選字
        case fixed(text: String, syls: [(String, String)])  // 使用者選好的字詞
        case eng(String)                                    // 英文／數字
        case lit(String)                                    // 空白、標點
    }

    struct Candidate {
        let text: String
        let sylCount: Int      // 取代最後幾個音節
        let isRaw: Bool        // true = 改回英文／數字
    }

    private var phrases: [String: [(text: String, score: Double)]] = [:]
    private var prefixes = Set<String>()     // 所有合法注音的開頭（不含聲調）
    private var englishRank: [String: Int] = [:]

    private(set) var segs: [Seg] = []
    private(set) var cur = ""                // 正在打、還沒定下來的按鍵
    var upperEnglish = false                 // Caps Lock 開啟時：英文一律轉大寫
    private func cased(_ s: String) -> String { upperEnglish ? s.uppercased() : s }
    private(set) var tail: [Seg] = []        // 游標右邊的內容（segs 是游標左邊）

    var isEmpty: Bool { segs.isEmpty && cur.isEmpty && tail.isEmpty }

    // MARK: 載入字庫
    init(zhPath: String, enPath: String) {
        if let data = try? String(contentsOfFile: zhPath, encoding: .utf8) {
            data.enumerateLines { line, _ in
                let p = line.split(separator: "\t")
                guard p.count == 3, let score = Double(p[2]) else { return }
                self.phrases[String(p[0]), default: []].append((String(p[1]), score))
            }
        }
        for key in phrases.keys {
            phrases[key]!.sort { $0.score > $1.score }
            guard !key.contains("-") else { continue }
            var s = ""
            for ch in key where !"ˇˋˊ˙".contains(ch) { s.append(ch); prefixes.insert(s) }
        }
        if let data = try? String(contentsOfFile: enPath, encoding: .utf8) {
            var i = 0
            data.enumerateLines { line, _ in self.englishRank[line] = i; i += 1 }
        }
    }

    // MARK: 判斷
    /// 把按鍵轉成注音符號；只要有一個鍵不是注音鍵就回傳 nil
    private func bopomofo(_ raw: String) -> String? {
        var s = ""
        for ch in raw { guard let b = Engine.keyMap[ch] else { return nil }; s += b }
        return s
    }

    /// 目前正在打的按鍵是不是還能當成注音
    var curIsBopomofo: Bool {
        guard !cur.isEmpty, let b = bopomofo(cur) else { return false }
        return prefixes.contains(b)
    }

    private func isCommonEnglish(_ w: String) -> Bool { (englishRank[w.lowercased()] ?? Int.max) < 5000 }

    // MARK: 輸入
    /// 一般按鍵（字母、數字、符號、空白）
    func type(_ ch: Character) {
        if cur.isEmpty {
            if ch == " " { segs.append(.lit(" ")) } else { cur = String(ch) }
            return
        }
        if curIsBopomofo {
            if let tone = Engine.toneMap[ch] {
                let reading = bopomofo(cur)! + tone
                // 合法音節 → 中文。例外：只對得到罕見字（如 no→㩙），而且是很常用的英文字 → 英文
                let rareButEnglish = (phrases[reading]?.first?.score ?? 0) < -7
                    && (englishRank[cur] ?? Int.max) < 5000
                if phrases[reading] != nil && !rareButEnglish {
                    segs.append(.syl(reading: reading, raw: cur + (ch == " " ? "" : String(ch))))
                    cur = ""
                    return
                }
            }
        }
        // 走到這裡表示目前是英文／數字，或這個鍵讓注音不成立
        if ch == " " {
            segs.append(.eng(cased(cur))); segs.append(.lit(" ")); cur = ""
        } else if cur.allSatisfy(\.isNumber) && !curIsBopomofo && !ch.isNumber {
            segs.append(.eng(cased(cur))); cur = String(ch)     // 數字後面接非數字：數字到此為止
        } else {
            cur.append(ch)
            if upperEnglish && !curIsBopomofo { cur = cur.uppercased() }
        }
    }

    /// 全形標點等直接插入的文字
    func insertLiteral(_ s: String) {
        if !cur.isEmpty { segs.append(.eng(cased(cur))); cur = "" }
        segs.append(.lit(s))
    }

    func backspace() {
        if !cur.isEmpty { cur.removeLast(); return }
        guard let last = segs.popLast() else { return }
        switch last {
        case .eng(let w): cur = String(w.dropLast())
        case .lit(let s): if s.count > 1 { segs.append(.lit(String(s.dropLast()))) }
        case .syl, .fixed: break
        }
    }

    /// Delete 鍵：刪掉游標右邊的一個字
    func deleteForward() {
        guard cur.isEmpty, !tail.isEmpty else { return }
        tail.removeFirst()
    }

    func clear() { segs = []; cur = ""; tail = [] }

    // MARK: 游標
    /// 把選過的詞拆成單字，游標才能一次移動一個字
    private func split(_ seg: Seg) -> [Seg] {
        guard case .fixed(let text, let syls) = seg, syls.count > 1, text.count == syls.count else { return [seg] }
        return zip(text, syls).map { .fixed(text: String($0), syls: [$1]) }
    }

    /// 正在打注音或英文時不能移動游標，回傳 false
    @discardableResult func moveLeft() -> Bool {
        guard cur.isEmpty, let last = segs.popLast() else { return false }
        var parts = split(last)
        tail.insert(parts.removeLast(), at: 0)
        segs.append(contentsOf: parts)
        return true
    }

    @discardableResult func moveRight() -> Bool {
        guard cur.isEmpty, !tail.isEmpty else { return false }
        var parts = split(tail.removeFirst())
        segs.append(parts.removeFirst())
        tail.insert(contentsOf: parts, at: 0)
        return true
    }

    func moveToStart() { while moveLeft() {} }
    func moveToEnd() { while moveRight() {} }

    // MARK: 選字
    /// 把連續的音節轉成最可能的中文，回傳每個音節對應的字
    private func convert(_ readings: [String]) -> [String] {
        let n = readings.count
        var best = [Double](repeating: -Double.infinity, count: n + 1)
        var back = [(Int, String)](repeating: (0, ""), count: n + 1)
        best[0] = 0
        for i in 1...n {
            for len in 1...min(i, 8) {
                let j = i - len
                let key = readings[j..<i].joined(separator: "-")
                let text: String, score: Double
                if let top = phrases[key]?.first { text = top.text; score = top.score }
                else if len == 1 { text = readings[j]; score = -20 }
                else { continue }
                if best[j] + score > best[i] { best[i] = best[j] + score; back[i] = (j, text) }
            }
        }
        var out = [String](repeating: "", count: n), i = n
        while i > 0 {
            let (j, text) = back[i]
            if text.count == i - j { for (k, ch) in text.enumerated() { out[j + k] = String(ch) } }
            else { out[j] = text }
            i = j
        }
        return out
    }

    /// 每一段各自顯示成什麼文字
    private func render(_ list: [Seg]) -> [String] {
        var out: [String] = [], run: [String] = []
        func flush() { if !run.isEmpty { out += convert(run); run = [] } }
        for seg in list {
            switch seg {
            case .syl(let reading, _): run.append(reading)
            case .fixed(let text, _): flush(); out.append(text)
            case .eng(let s), .lit(let s): flush(); out.append(s)
            }
        }
        flush()
        return out
    }

    /// 輸入區顯示的文字，以及游標在第幾個字後面（UTF-16 長度）
    var displayWithCursor: (text: String, cursor: Int) {
        let middle: [Seg] = cur.isEmpty ? [] : [.eng(curIsBopomofo ? bopomofo(cur)! : cur)]
        let parts = render(segs + middle + tail)
        let left = parts.prefix(segs.count + middle.count).joined()
        return (parts.joined(), left.utf16.count)
    }

    var display: String { displayWithCursor.text }

    /// 送出：還沒打完聲調的注音當成英文
    func commit() -> String {
        let text = render(segs + (cur.isEmpty ? [] : [.eng(cased(cur))]) + tail).joined()
        clear()
        return text
    }

    /// 結尾的連續音節（選過的字詞會拆回音節，可以重選）
    private func trailingSyllables() -> [(String, String)] {
        var out: [(String, String)] = []
        for seg in segs.reversed() {
            switch seg {
            case .syl(let reading, let raw): out.insert((reading, raw), at: 0)
            case .fixed(_, let syls): out.insert(contentsOf: syls, at: 0)
            default: return out
            }
            if out.count >= 8 { break }
        }
        return out
    }

    private static func fullWidth(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { UnicodeScalar($0.value + 0xFEE0)! }))
    }

    /// 按 ↓ 時列出的候選字（針對輸入區最後面的字詞）
    func candidates() -> [Candidate] {
        guard cur.isEmpty else { return [] }
        let syls = trailingSyllables()
        guard let last = syls.last else { return [] }
        var list: [Candidate] = [], seen = Set<String>()
        func add(_ c: Candidate) { if seen.insert(c.text).inserted { list.append(c) } }

        for len in stride(from: min(syls.count, 8), through: 1, by: -1) {
            let key = syls.suffix(len).map(\.0).joined(separator: "-")
            for p in phrases[key] ?? [] { add(Candidate(text: p.text, sylCount: len, isRaw: false)) }
        }
        // 英文／數字的還原選項：常用英文字或數字排在第 2 個，其他排最後
        let raw = last.1
        var raws = [Candidate(text: raw, sylCount: 1, isRaw: true)]
        if raw.allSatisfy(\.isNumber) { raws.append(Candidate(text: Engine.fullWidth(raw), sylCount: 1, isRaw: true)) }
        let prominent = raw.allSatisfy(\.isNumber) || isCommonEnglish(raw)
        list.insert(contentsOf: raws, at: prominent ? min(1, list.count) : list.count)
        return list
    }

    func select(_ c: Candidate) {
        var syls: [(String, String)] = []
        while syls.count < c.sylCount, let seg = segs.popLast() {
            switch seg {
            case .syl(let reading, let raw): syls.insert((reading, raw), at: 0)
            case .fixed(_, let s): syls.insert(contentsOf: s, at: 0)
            default: segs.append(seg); return
            }
        }
        // 拆開選過的詞時，多出來的音節放回去
        let extra = syls.count - c.sylCount
        for s in syls.prefix(max(extra, 0)) { segs.append(.syl(reading: s.0, raw: s.1)) }
        segs.append(c.isRaw ? .eng(c.text) : .fixed(text: c.text, syls: Array(syls.suffix(c.sylCount))))
    }
}
