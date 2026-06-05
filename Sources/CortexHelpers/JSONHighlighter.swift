import SwiftUI
import CortexUI

/// Tokenizes a JSON string into an `AttributedString` with semantic, on-brand
/// colors — so JSON looks the same in cell inspectors, document cards and value
/// viewers across every Cortex app. Hand-rolled (no `JSONSerialization` pass for
/// coloring) so it survives partial/invalid JSON gracefully.
public enum JSONHighlighter {
    public static func highlight(_ json: String) -> AttributedString {
        var out = AttributedString()
        let chars = Array(json)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                let end = stringEnd(chars, from: i)
                let token = String(chars[i...end])
                var k = end + 1
                while k < chars.count, chars[k].isWhitespace { k += 1 }
                let isKey = k < chars.count && chars[k] == ":"
                out += span(token, color: isKey ? keyColor : stringColor)
                i = end + 1
            } else if c == "-" || c.isNumber {
                var j = i
                while j < chars.count,
                      chars[j] == "-" || chars[j] == "+" || chars[j] == "." ||
                      chars[j] == "e" || chars[j] == "E" || chars[j].isNumber {
                    j += 1
                }
                out += span(String(chars[i..<j]), color: numberColor)
                i = j
            } else if c.isLetter, let kw = matchKeyword(chars, at: i) {
                out += span(kw, color: keywordColor)
                i += kw.count
            } else if "{}[]:,".contains(c) {
                out += span(String(c), color: punctColor)
                i += 1
            } else {
                out += span(String(c), color: textColor)
                i += 1
            }
        }
        return out
    }

    /// `i` points at the opening quote; returns the closing quote index (or the
    /// last index if unterminated), honoring backslash escapes.
    private static func stringEnd(_ chars: [Character], from i: Int) -> Int {
        var j = i + 1
        while j < chars.count {
            if chars[j] == "\\" && j + 1 < chars.count { j += 2; continue }
            if chars[j] == "\"" { return j }
            j += 1
        }
        return chars.count - 1
    }

    private static func matchKeyword(_ chars: [Character], at i: Int) -> String? {
        for kw in ["true", "false", "null"] {
            let kc = Array(kw)
            guard i + kc.count <= chars.count,
                  Array(chars[i..<(i + kc.count)]) == kc else { continue }
            let next = i + kc.count
            let bounded = next == chars.count || !(chars[next].isLetter || chars[next].isNumber || chars[next] == "_")
            if bounded { return kw }
        }
        return nil
    }

    private static func span(_ s: String, color: Color) -> AttributedString {
        var a = AttributedString(s)
        a.foregroundColor = color
        return a
    }

    // MARK: - Theme colors (brand-derived)

    private static var keyColor: Color { Brand.palette[0] }                            // violet
    private static var stringColor: Color { Color(red: 0.45, green: 0.82, blue: 0.50) } // green
    private static var numberColor: Color { Color(red: 0.99, green: 0.60, blue: 0.36) } // coral
    private static var keywordColor: Color { Brand.palette[1] }                        // cyan
    private static var punctColor: Color { .white.opacity(0.55) }
    private static var textColor: Color { .white.opacity(0.85) }

    // MARK: - JSON utilities

    /// `true` when the text decodes as a JSON object or array. Cheap; used to
    /// decide whether to offer a "Pretty" view.
    public static func isJSON(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("{") || t.hasPrefix("[") else { return false }
        guard let data = t.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Pretty-printed (sorted-key) JSON if `text` is valid JSON, else unchanged.
    public static func prettyPrint(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let out = try? JSONSerialization.data(withJSONObject: obj,
                                                    options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: out, encoding: .utf8) else { return text }
        return s
    }
}
