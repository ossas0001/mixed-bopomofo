import Cocoa
import InputMethodKit

private let noRange = NSRange(location: NSNotFound, length: NSNotFound)
private let pageSize = 9

/// Shift＋鍵 → 全形標點（比對的是按下 Shift 之後的字元）
private let punctuation: [Character: String] = [
    "<": "，", ">": "。", "?": "？", "!": "！", ":": "：", "\"": "、",
    "{": "「", "}": "」", "(": "（", ")": "）",
]

/// Control＋標點鍵 → 全形標點（跟 Windows 微軟注音一樣；有按 Shift 的話比對的是 Shift 之後的字元）
private let controlPunctuation: [Character: String] = [
    ",": "，", ".": "。", ";": "；", "'": "、", "[": "「", "]": "」", "/": "？", "1": "！", "\\": "、",
    "<": "《", ">": "》", ":": "：", "\"": "＂", "{": "『", "}": "』", "?": "？", "!": "！", "(": "（", ")": "）",
]

@objc(MixedInputController)
final class MixedInputController: IMKInputController {
    // 這些狀態所有視窗共用
    private static var englishMode = false
    private static var shiftAlone = false
    private static let candidatePanel = FloatingPanel()
    private static let modePanel = FloatingPanel()
    private static var cands: [Engine.Candidate] = []
    private static var highlight = 0          // 目前反白的是第幾個候選字（從 0 算，跨頁）
    private static var page: Int { highlight / pageSize }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    // MARK: 按鍵入口
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event else { return false }
        let flags = event.modifierFlags.intersection([.shift, .control, .option, .command, .capsLock])

        if event.type == .flagsChanged {
            handleShiftTap(event, flags: flags)
            return false
        }
        guard event.type == .keyDown else { return false }
        Self.shiftAlone = false

        if !flags.intersection([.command, .control, .option]).isEmpty {
            if flags.subtracting([.shift, .capsLock]) == .control,
               let key = event.charactersIgnoringModifiers?.first, let mark = controlPunctuation[key] {
                Self.candidatePanel.hide()
                if engine.isEmpty { insert(mark) } else { engine.insertLiteral(mark); refresh() }
                return true
            }
            commit()
            return false
        }
        let shift = flags.contains(.shift)
        let chars = event.characters ?? ""

        // Caps Lock 只影響英文的大小寫，中／英模式只由 Shift 決定
        let caps = flags.contains(.capsLock)
        if Self.englishMode {                     // 英文模式：跟一般鍵盤一樣；Caps Lock 開啟時 Shift＋字母打小寫
            guard caps, chars.count == 1, let ch = chars.first, ch.isLetter, ch.isASCII else { return false }
            insert(shift ? chars.lowercased() : chars.uppercased())
            return true
        }
        engine.upperEnglish = caps && !shift      // 混打模式＋Caps Lock：注音照打，判定成英文的部分變大寫

        if Self.candidatePanel.isVisible, handleCandidateKey(event, chars: chars) { return true }

        switch event.keyCode {
        case 36, 76:                              // Return / Enter
            guard !engine.isEmpty else { return false }
            commit(); return true
        case 51:                                  // Backspace
            guard !engine.isEmpty else { return false }
            engine.backspace(); refresh(); return true
        case 53:                                  // Esc
            guard !engine.isEmpty else { return false }
            engine.clear(); refresh(); return true
        case 125:                                 // ↓
            guard !engine.isEmpty else { return false }
            showCandidates(); return true
        case 123, 124, 115, 119:                  // ← → Home End：在輸入區裡移動游標
            guard !engine.isEmpty else { return false }
            switch event.keyCode {
            case 123: if !engine.moveLeft() { NSSound.beep() }
            case 124: if !engine.moveRight() { NSSound.beep() }
            case 115: engine.moveToStart()
            default: engine.moveToEnd()
            }
            refresh(); return true
        case 117:                                 // Delete：刪游標右邊的字
            guard !engine.isEmpty else { return false }
            engine.deleteForward(); refresh(); return true
        case 126, 48:                             // ↑ Tab：輸入中不讓游標亂跑
            return !engine.isEmpty
        default: break
        }

        guard chars.count == 1, let typed = chars.first, typed.isASCII, typed == " " || !typed.isWhitespace,
              let ascii = typed.asciiValue, ascii >= 32, ascii < 127 else { return false }
        // Caps Lock 開啟時系統送來的是大寫字母，先還原成小寫才能當注音鍵
        let ch = caps && typed.isLetter ? Character(typed.lowercased()) : typed

        if event.modifierFlags.contains(.numericPad) {      // 數字鍵盤：一律當數字
            guard !engine.isEmpty else { return false }
            engine.insertLiteral(chars)
        } else if shift, let mark = punctuation[ch] {
            if engine.isEmpty { insert(mark); return true }
            engine.insertLiteral(mark)
        } else if engine.isEmpty && !(ch.isLetter || ch.isNumber || Engine.keyMap[ch] != nil) {
            return false                                    // 空白鍵、其他符號：沒在輸入時照常打出
        } else {
            engine.type(ch)
        }
        refresh()
        return true
    }

    // MARK: 單按 Shift 切換中／英
    private func handleShiftTap(_ event: NSEvent, flags: NSEvent.ModifierFlags) {
        let isShiftKey = event.keyCode == 56 || event.keyCode == 60
        if isShiftKey && flags.subtracting(.capsLock) == .shift {
            Self.shiftAlone = true                           // Shift 剛按下
        } else if isShiftKey && Self.shiftAlone && flags.subtracting(.capsLock).isEmpty {
            Self.shiftAlone = false                          // Shift 放開，中間沒按別的鍵
            commit()
            Self.englishMode.toggle()
            showMode()
        } else {
            Self.shiftAlone = false
        }
    }

    private func showMode() {
        let text = NSAttributedString(string: Self.englishMode ? "英" : "中", attributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: NSColor.labelColor,
        ])
        Self.modePanel.show(text, near: cursorRect(), autoHide: 1)
    }

    // MARK: 候選字
    private func showCandidates() {
        Self.cands = engine.candidates()
        Self.highlight = 0
        guard !Self.cands.isEmpty else { NSSound.beep(); return }
        drawCandidates()
    }

    private func drawCandidates() {
        let start = Self.page * pageSize
        let items = Self.cands[start..<min(start + pageSize, Self.cands.count)]
        let pages = (Self.cands.count + pageSize - 1) / pageSize
        let text = NSMutableAttributedString()
        let num: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                                                  .foregroundColor: NSColor.secondaryLabelColor]
        let word: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.labelColor]
        for (i, c) in items.enumerated() {
            let line = NSMutableAttributedString(string: " \(i + 1)  ", attributes: num)
            line.append(NSAttributedString(string: c.text + " \n", attributes: word))
            if start + i == Self.highlight {       // 反白目前選到的那一個
                line.addAttributes([.backgroundColor: NSColor.selectedContentBackgroundColor,
                                    .foregroundColor: NSColor.white], range: NSRange(location: 0, length: line.length - 1))
            }
            text.append(line)
        }
        text.append(NSAttributedString(string: pages > 1 ? " \(Self.page + 1)/\(pages)  ← → 換頁" : " Enter 選字", attributes: num))
        Self.candidatePanel.show(text, near: cursorRect())
    }

    /// 候選字視窗開著時的按鍵。回傳 false 表示這個鍵沒被用掉，交回一般流程處理
    private func handleCandidateKey(_ event: NSEvent, chars: String) -> Bool {
        let count = Self.cands.count
        switch event.keyCode {
        case 125: Self.highlight = (Self.highlight + 1) % count; drawCandidates(); return true            // ↓：下一個
        case 126: Self.highlight = (Self.highlight + count - 1) % count; drawCandidates(); return true    // ↑：上一個
        case 124, 49, 121:                                                                               // → 空白 PageDown：下一頁
            let next = (Self.page + 1) * pageSize
            Self.highlight = next < count ? next : 0
            drawCandidates(); return true
        case 123, 116:                                                                                   // ← PageUp：上一頁
            Self.highlight = Self.page > 0 ? (Self.page - 1) * pageSize : ((count - 1) / pageSize) * pageSize
            drawCandidates(); return true
        case 53, 51: Self.candidatePanel.hide(); return true                                             // Esc / Backspace：關掉
        case 36, 76: pick(Self.highlight % pageSize); return true                                        // Enter：選反白的
        default: break
        }
        if let n = chars.first?.wholeNumberValue, chars.count == 1, n >= 1 {
            pick(n - 1)
            return true
        }
        Self.candidatePanel.hide()
        return false
    }

    private func pick(_ indexOnPage: Int) {
        let i = Self.page * pageSize + indexOnPage
        guard i < Self.cands.count else { NSSound.beep(); return }
        engine.select(Self.cands[i])
        Self.candidatePanel.hide()
        refresh()
    }

    // MARK: 跟打字的 app 溝通
    private func cursorRect() -> NSRect {
        var rect = NSRect.zero
        let cursor = max(engine.displayWithCursor.cursor - 1, 0)      // 候選字視窗跟著游標左邊那個字
        _ = client()?.attributes(forCharacterIndex: cursor, lineHeightRectangle: &rect)
        return rect
    }

    /// 更新輸入區（有底線、還沒送出的文字）
    private func refresh() {
        let (text, cursor) = engine.displayWithCursor
        let marked = NSAttributedString(string: text, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        client()?.setMarkedText(marked, selectionRange: NSRange(location: cursor, length: 0), replacementRange: noRange)
    }

    private func insert(_ text: String) {
        client()?.insertText(text, replacementRange: noRange)
    }

    private func commit() {
        Self.candidatePanel.hide()
        guard !engine.isEmpty else { return }
        insert(engine.commit())
    }

    override func commitComposition(_ sender: Any!) { commit() }

    override func deactivateServer(_ sender: Any!) {
        commit()
        Self.modePanel.hide()
        super.deactivateServer(sender)
    }
}
