# 混打注音（mixed-bopomofo）

macOS 用的注音輸入法。打字時自動判斷中文和英文，**不用切換輸入法就能中英混打**。

```
按鍵：ji3ul4fm4 空白 meeting
結果：我要去 meeting
```

## 它怎麼判斷

注音鍵盤上每個鍵同時是一個注音符號和一個英文字母。輸入法邊打邊檢查：

- 按鍵還能組成合法的注音（`su3` = ㄋㄧˇ）→ 當中文。
- 組不出合法注音（`me` = ㄩㄍ，不可能）→ 整段改當英文。
- 中英都說得通（`up` + 空白 = ㄧㄣ「因」）→ 預設中文，按 ↓ 可以改成英文。
- 數字也一樣：`2026` 會判定成數字；`20` + 空白是「單」，按 ↓ 可以改成 20。

大部分英文單字打到第 2～3 個字母就會被判定出來。

## 安裝

需要 macOS 13 以上、Xcode 命令列工具（`xcode-select --install`）和 Python 3。

```bash
git clone https://github.com/ossas0001/mixed-bopomofo.git
```

```bash
cd mixed-bopomofo && ./build.sh install
```

`build.sh` 會從原始來源下載字庫（約 8 MB）、編譯，然後把輸入法裝到 `~/Library/Input Methods`。

接著啟用：

1. 系統設定 → 鍵盤 → 輸入方式 →「編輯…」→ 左下角「＋」→ 繁體中文 →「混打注音」→ 加入。
   找不到的話，登出再登入一次。
2. 在同一個畫面關掉「使用大寫鎖定鍵切換 ABC 輸入方式」，Caps Lock 才能照下表運作。

## 操作

| 按鍵 | 作用 |
|---|---|
| 直接打字 | 組得成注音就是中文，組不成就是英文 |
| 空白鍵 | 打注音時是一聲；注音打完時是空白 |
| Enter | 送出輸入區的字 |
| ← → | 在輸入區裡移動游標，Home／End 跳到最前／最後 |
| ↓ | 顯示游標左邊那個字的候選字 |
| 候選字視窗 | ↓／↑ 移動反白，Enter 選反白的字，1～9 直接選，← → 或空白鍵換頁，Esc 取消 |
| Backspace／Delete | 刪游標左邊／右邊的字 |
| Esc | 清空輸入區 |
| 單按 Shift | 切換「混打」和「純英文」模式，游標旁會顯示「中」或「英」 |
| Shift＋字母 | 大寫英文 |
| Control＋`, . ; ' [ ] / 1` | ，。；、「」？！（兩種模式都有效） |
| Control＋Shift＋`, . ; [ ] 9 0` | 《》：『』（） |
| Shift＋`, . / 1 ; ' [ ] 9 0` | ，。？！：、「」（）（混打模式） |
| Caps Lock | 只影響英文大小寫：混打模式下注音照打、英文變大寫；英文模式下打大寫，Shift＋字母打小寫 |

注意：一聲一定要按空白鍵，跟一般注音輸入法一樣。

## 開發

在終端機測試判斷規則，不用安裝（`␣` 代表空白鍵，`↓?` 列出候選字）：

```bash
swiftc -O Sources/Engine.swift Tests/main.swift -o build/enginetest && ./build/enginetest 'su3cl3' 'up␣↓?'
```

| 檔案 | 內容 |
|---|---|
| `Sources/Engine.swift` | 判斷中英文、選字的核心，不依賴 macOS 輸入法系統 |
| `Sources/App/` | 接上 InputMethodKit 的部分：按鍵處理、候選字視窗 |
| `tools/fetch_data.sh` | 下載字庫 |
| `tools/build_data.py` | 把字庫整理成輸入法用的格式 |

## 移除

先在系統設定的輸入方式裡移除「混打注音」，再刪掉 `~/Library/Input Methods/MixedIME.app`。

## 授權與資料來源

本專案的程式碼以 [MIT 授權](LICENSE) 釋出。

本專案**不包含**任何第三方字庫，安裝時才由 `tools/fetch_data.sh` 從下列來源下載到你的電腦，各自適用原本的授權：

| 資料 | 來源 | 授權 |
|---|---|---|
| 注音字詞與詞頻 | [McBopomofo 小麥注音](https://github.com/openvanilla/McBopomofo) | MIT |
| 英文字頻表 | [FrequencyWords](https://github.com/hermitdave/FrequencyWords)（資料源自 OpenSubtitles） | 內容為 CC BY-SA 4.0 |

如果你要散布編譯好的輸入法（裡面含有上述資料），請遵守這兩項授權的條件，包括標示來源，以及英文字頻表的「相同方式分享」。

## 聲明

這是個人的業餘專案，依現狀提供，不附任何保證，使用風險由使用者自行承擔。

本專案與 Apple、Microsoft 及任何輸入法或硬體廠商都沒有關係，也沒有得到它們的認可。macOS 是 Apple Inc. 的商標，Windows 是 Microsoft Corporation 的商標，文中提到只是為了說明相容性和操作習慣。
