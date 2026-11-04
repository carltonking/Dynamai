// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The live editor draws Markdown the way Obsidian's Live Preview does: what
/// is hidden has to be exactly the syntax, never the text, and the source has
/// to come back wherever the caret is, or the caret would sit on characters
/// nobody can see.
enum ScratchpadLiveMarkdownTests {
    static func run(_ suite: TestSuite) {
        func visible(_ text: String, caret: Int?) -> String {
            let elements = ScratchpadLiveMarkdown.elements(in: text)
            let selections = caret.map { [NSRange(location: $0, length: 0)] } ?? []
            let hidden = ScratchpadLiveMarkdown.hiddenCharacters(in: elements, selections: selections)
            let units = Array(text.utf16).enumerated().filter { !hidden.contains($0.offset) }.map(\.element)
            return String(utf16CodeUnits: units, count: units.count)
        }
        func kinds(_ text: String) -> [ScratchpadLiveElement.Kind] {
            ScratchpadLiveMarkdown.elements(in: text).map(\.kind)
        }

        suite.run("scratchpad live markdown hides syntax away from the caret") {
            suite.expect(visible("# Title", caret: nil) == "Title", "heading marker hidden")
            suite.expect(visible("# Title", caret: 3) == "# Title", "heading source on its own line")
            suite.expect(visible("a **b** c", caret: 0) == "a b c", "bold markers hidden")
            suite.expect(visible("a **b** c", caret: 2) == "a **b** c", "bold source with the caret at its edge")
            suite.expect(visible("*i* and _j_", caret: nil) == "i and j", "both italics hidden")
            suite.expect(visible("~~x~~ ==y==", caret: nil) == "x y", "strikethrough and highlight")
            suite.expect(visible("`a*b*c`", caret: nil) == "a*b*c", "code span keeps its stars as text")
            suite.expect(visible("[site](https://example.com)", caret: nil) == "site", "link shows its text")
            suite.expect(visible("see [[Other note]]", caret: 0) == "see Other note", "wikilink drops brackets")
            suite.expect(visible("[[Other note|alias]]", caret: nil) == "alias", "wikilink alias replaces target")
            suite.expect(visible(#"\*not italic\*"#, caret: nil) == #"\*not italic\*"#, "escaped stars stay")
            suite.expect(visible("snake_case_name", caret: nil) == "snake_case_name", "intraword underscores stay")
        }

        suite.run("scratchpad live markdown nests marks") {
            suite.expect(visible("***both***", caret: nil) == "both", "bold italic hides all six stars")
            suite.expect(visible("**bold *and italic***", caret: nil) == "bold and italic",
                         "italic inside bold")
            let marks = kinds("***both***")
            suite.expect(marks.contains(.bold) && marks.contains(.italic), "bold italic is both")
        }

        suite.run("scratchpad live markdown lists and tasks") {
            suite.expect(visible("- [ ] buy milk", caret: nil) == "[ ] buy milk",
                         "task bullet hidden, box kept for its drawn checkbox")
            suite.expect(visible("- [ ] buy milk", caret: 0) == "- [ ] buy milk", "task source at its marker")
            suite.expect(visible("- [ ] buy milk", caret: 6) == "[ ] buy milk",
                         "caret in the task's text keeps the box drawn")
            suite.expect(kinds("- [x] done") == [.task(checked: true, box: 2)], "checked task names its box")
            suite.expect(kinds("  * item") == [.bullet], "indented bullet")
            suite.expect(kinds("---") == [.thematicBreak], "rule, not a bullet")
            suite.expect(kinds("> quoted") == [.quote], "quote")
            suite.expect(kinds("#tag and #2024") == [.tag], "a tag needs a non-digit")
        }

        suite.run("scratchpad live markdown blocks") {
            let fenced = "```swift\nlet a = **b**\n```\nafter **c**"
            let elements = ScratchpadLiveMarkdown.elements(in: fenced)
            suite.expect(elements.first?.kind == .codeBlock(language: "swift"), "fenced block found with its language")
            suite.expect(elements.filter { $0.kind == .bold }.count == 1, "no inline marks inside code")
            suite.expect(visible(fenced, caret: nil) == "\nlet a = **b**\n\nafter c",
                         "fences hidden while the caret is outside the block")
            suite.expect(kinds("```\nunclosed") == [.codeBlock(language: "")], "unclosed fence runs to the end")
            suite.expect(kinds("---\ntags: a\n---\n# H").first == .frontmatter, "frontmatter on the first line")
            suite.expect(!kinds("text\n---\nmore").contains(.frontmatter), "rule later is not frontmatter")
            suite.expect(kinds("###### six") == [.heading(level: 6)], "six levels")
            suite.expect(kinds("####### seven").isEmpty, "seven is a paragraph")
            suite.expect(kinds("#nospace") == [.tag], "no space is a tag, not a heading")
        }

        suite.run("scratchpad live markdown list indent") {
            func indent(_ text: String, _ caret: Int, outdent: Bool = false) -> (String, Int)? {
                guard let edit = ScratchpadLiveMarkdown.listIndentEdit(
                    in: text, selection: NSRange(location: caret, length: 0), outdent: outdent) else { return nil }
                return ((text as NSString).replacingCharacters(in: edit.range, with: edit.replacement),
                        edit.selection.location)
            }
            let nested = indent("- a\n- b", 7)
            suite.expect(nested?.0 == "- a\n\t- b" && nested?.1 == 8, "tab nests the item under the caret")
            let back = indent("- a\n\t- b", 8, outdent: true)
            suite.expect(back?.0 == "- a\n- b" && back?.1 == 7, "shift-tab un-nests it")
            suite.expect(indent("plain", 2) == nil, "tab outside a list is an ordinary tab")
            suite.expect(indent("- a", 3, outdent: true) == nil, "nothing to un-nest leaves the key alone")
            let spaces = indent("    1. x", 8, outdent: true)
            suite.expect(spaces?.0 == "1. x" && spaces?.1 == 4, "four spaces are one level")
        }

        // Code is coloured as Obsidian colours it, and a quote or `//` inside
        // a comment or string is that comment or string, not a new token.
        suite.run("scratchpad live markdown colours code") {
            func tokens(_ code: String, _ language: String) -> [(String, ScratchpadLiveMarkdown.CodeToken)] {
                let ns = code as NSString
                return ScratchpadLiveMarkdown.codeTokens(in: code, range: NSRange(location: 0, length: ns.length),
                                                         language: language)
                    .map { (ns.substring(with: $0.0), $0.1) }
            }
            func kind(_ word: String, in list: [(String, ScratchpadLiveMarkdown.CodeToken)]) -> ScratchpadLiveMarkdown.CodeToken? {
                list.first { $0.0 == word }?.1
            }
            let java = tokens("public static void main(String[] args) // the \"entry\"\nSystem.out.println(\"Hi // there\");", "java")
            suite.expect(kind("public", in: java) == .keyword && kind("static", in: java) == .keyword, "keywords")
            suite.expect(kind("void", in: java) == .type && kind("String", in: java) == .type, "types")
            suite.expect(kind("main", in: java) == .function && kind("println", in: java) == .function, "calls")
            suite.expect(kind("out", in: java) == .function && kind("System", in: java) == .function, "members")
            suite.expect(kind("// the \"entry\"", in: java) == .comment, "a line comment runs to its line's end")
            suite.expect(kind("\"Hi // there\"", in: java) == .string, "a // inside a string stays string")
            suite.expect(kind("args", in: java) == nil, "a plain name stays text")
            let python = tokens("def f(x): # note\n    return 42", "python")
            suite.expect(kind("# note", in: python) == .comment && kind("def", in: python) == .keyword
                    && kind("42", in: python) == .number, "a language picks its comment marker")
            suite.expect(kind("#include", in: tokens("#include <stdio.h>", "c")) == nil,
                   "# is not a comment in C")
            let open = tokens("x = \"unclosed\ny = 1", "js")
            suite.expect(kind("\"unclosed", in: open) == .string && kind("1", in: open) == .number,
                   "an open quote ends with its line")
        }

        suite.run("scratchpad live markdown keeps a hidden line start on its line") {
            let text = "- [ ] top\n\t- [ ] nested\n```js\ncode\n```"
            let hidden = ScratchpadLiveMarkdown.hiddenCharacters(in: ScratchpadLiveMarkdown.elements(in: text),
                                                                 selections: [])
            let leading = ScratchpadLiveMarkdown.lineStartingRuns(of: hidden, in: text)
            suite.expect(leading.contains(0) && leading.contains(1), "a top-level task's marker starts its line")
            suite.expect(!leading.contains(11), "a nested task's marker follows its tab")
            suite.expect(leading.contains(24) && leading.contains(28) && !leading.contains(30), "a hidden fence stops at its own line")
            suite.expect(hidden.isSuperset(of: leading), "only hidden characters are laid out this way")
        }

        // A wrapped list item continues under its text, not at the margin.
        suite.run("scratchpad live markdown hangs wrapped lines under their text") {
            func prefix(_ line: String) -> String? {
                let ns = line as NSString
                guard let range = ScratchpadLiveMarkdown.hangingIndentPrefix(
                    in: line, line: NSRange(location: 0, length: ns.length)) else { return nil }
                return ns.substring(with: range)
            }
            suite.expect(prefix("\t2. describe the product") == "\t2. ", "a nested numbered item hangs under its text")
            suite.expect(prefix("- item") == "- ", "a bullet hangs under its text")
            suite.expect(prefix("\t\t- [ ] task") == "\t\t- [ ] ", "a task hangs under its text, box included")
            suite.expect(prefix("> - quoted") == "> - ", "a quoted item hangs under its text")
            suite.expect(prefix("\tindented text") == "\t", "an indented line keeps its indent")
            suite.expect(prefix("plain text") == nil, "an ordinary line wraps at the margin")
            suite.expect(prefix("- ") == nil, "a marker with no text has nothing to hang")
        }
    }
}
