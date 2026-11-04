// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The island's calculator: reads what is typed, as LaTeX (`\frac{1}{2}`,
/// `\int_{2}^{3} x^2 dx`, with or without the backslash) or as a keyboard
/// calculator writes it (`1/2`, `3*4`, `2**10`, `7 % 3`), into one tree. The
/// same tree gives the answer and the TeX the page typesets, so what is shown
/// is always what was worked out. Pure, so every rule is testable.
enum NotchCalculatorEngine {
    indirect enum Node: Equatable {
        case number(Double, String)
        case variable(String)
        case constant(Constant)
        case negate(Node)
        case binary(Operator, Node, Node)
        case fraction(Node, Node)
        case root(Node, index: Node?)
        case function(Function, Node)
        case log(base: Node, Node)
        case absolute(Node)
        case factorial(Node)
        case group(Node)
        case integral(lower: Node, upper: Node, body: Node, variable: String)
        case series(product: Bool, variable: String, lower: Node, upper: Node, body: Node)
    }

    enum Operator: Equatable {
        case add, subtract, multiply, implicitMultiply, divide, modulo, power
    }

    enum Constant: String, CaseIterable {
        case pi, e, tau
    }

    enum Function: String, CaseIterable {
        case sin, cos, tan, sec, csc, cot, arcsin, arccos, arctan, sinh, cosh, tanh
        case ln, log, exp, sqrt, abs, floor, ceil
    }

    enum Failure: Error, Equatable {
        case empty, unexpected, unknown(String), notANumber
    }

    struct Result: Equatable {
        let tex: String
        let value: Double?
    }

    // MARK: - Entry

    /// The TeX to typeset and the answer, if it has one yet. Half-typed input
    /// still typesets as typed; only a whole expression has an answer.
    static func evaluate(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Result(tex: "", value: nil) }
        guard let tree = try? parse(trimmed) else { return Result(tex: fallbackTeX(trimmed), value: nil) }
        let value = try? number(tree, [:])
        return Result(tex: tex(tree), value: value.flatMap { $0.isFinite ? $0 : nil })
    }

    static func parse(_ input: String) throws -> Node {
        var parser = Parser(tokens: try tokenize(input))
        let tree = try parser.expression()
        guard parser.atEnd else { throw Failure.unexpected }
        return tree
    }

    /// The answer as the page shows it: whole numbers whole, others to ten
    /// significant figures, very large or small ones in scientific notation.
    static func format(_ value: Double) -> String {
        // Answers write their decimals with a point, as they are typed.
        let posix = Locale(identifier: "en_US_POSIX")
        if value == 0 { return "0" }
        let magnitude = abs(value)
        if magnitude < 1e15, abs(value - value.rounded()) < 1e-9 * max(1, magnitude) {
            return String(format: "%.0f", locale: posix, value.rounded())
        }
        if magnitude >= 1e15 || magnitude < 1e-6 {
            let text = String(format: "%.8e", locale: posix, value).lowercased()
            let parts = text.split(separator: "e")
            guard parts.count == 2 else { return text }
            var mantissa = String(parts[0])
            while mantissa.contains("."), mantissa.hasSuffix("0") { mantissa.removeLast() }
            if mantissa.hasSuffix(".") { mantissa.removeLast() }
            let exponent = Int(parts[1]) ?? 0
            return "\(mantissa)e\(exponent)"
        }
        var text = String(format: "%.10g", locale: posix, value)
        if text.contains("."), !text.contains("e") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }

    // MARK: - Tokens

    enum Token: Equatable {
        case number(Double, String)
        case name(String)
        case command(String)
        case symbol(String)
    }

    /// Names that read as one word, so `frac`, `sin` and `pi` work without
    /// a backslash; longest first, so `arcsin` is not `arc` and `sin`.
    private static let words: [String] = (["frac", "dfrac", "tfrac", "sqrt", "int", "sum", "prod", "left", "right",
                                           "cdot", "times", "div", "mod", "bmod", "infty", "operatorname"]
        + Function.allCases.map(\.rawValue) + Constant.allCases.map(\.rawValue))
        .sorted { $0.count > $1.count }

    static func tokenize(_ input: String) throws -> [Token] {
        let characters = Array(input)
        var tokens: [Token] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace { index += 1; continue }
            if character.isNumber || (character == "." && index + 1 < characters.count && characters[index + 1].isNumber) {
                var end = index
                while end < characters.count, characters[end].isNumber || characters[end] == "." { end += 1 }
                let text = String(characters[index..<end])
                guard let value = Double(text) else { throw Failure.unexpected }
                tokens.append(.number(value, text))
                index = end
                continue
            }
            if character == "\\" {
                var end = index + 1
                while end < characters.count, characters[end].isLetter { end += 1 }
                if end == index + 1 {
                    // `\,` `\;` `\!` and `\ ` are spacing; `\{` `\}` `\|` keep their sign.
                    if end < characters.count {
                        let next = characters[end]
                        if "{}|".contains(next) { tokens.append(.symbol(String(next))) }
                        index = end + 1
                    } else {
                        index = end
                    }
                    continue
                }
                tokens.append(.command(String(characters[(index + 1)..<end])))
                index = end
                continue
            }
            if character.isLetter {
                var end = index
                while end < characters.count, characters[end].isLetter { end += 1 }
                tokens += split(String(characters[index..<end]))
                index = end
                continue
            }
            if character == "*", index + 1 < characters.count, characters[index + 1] == "*" {
                tokens.append(.symbol("^"))
                index += 2
                continue
            }
            if "+-*/%^_(){}[]|!=,·×÷−".contains(character) {
                let mapped: String
                switch character {
                case "·", "×": mapped = "*"
                case "÷": mapped = "/"
                case "−": mapped = "-"
                default: mapped = String(character)
                }
                tokens.append(.symbol(mapped))
                index += 1
                continue
            }
            throw Failure.unexpected
        }
        return tokens
    }

    /// A run of letters typed without backslashes: the known words in it, and
    /// every other letter a variable of its own (`2xy` is 2·x·y).
    private static func split(_ run: String) -> [Token] {
        var tokens: [Token] = []
        var rest = Substring(run)
        while !rest.isEmpty {
            if let word = words.first(where: { rest.hasPrefix($0) }) {
                tokens.append(.command(word))
                rest = rest.dropFirst(word.count)
            } else {
                tokens.append(.name(String(rest.removeFirst())))
            }
        }
        return tokens
    }

    // MARK: - Parser

    private struct Parser {
        let tokens: [Token]
        var index = 0
        /// Inside an integral's body, `d` and a letter end it as its `dx`.
        var integralDepth = 0

        init(tokens: [Token]) { self.tokens = tokens }

        var atEnd: Bool { index >= tokens.count }
        var current: Token? { index < tokens.count ? tokens[index] : nil }

        mutating func take(_ symbol: String) -> Bool {
            guard current == .symbol(symbol) else { return false }
            index += 1
            return true
        }

        mutating func expect(_ symbol: String) throws {
            guard take(symbol) else { throw Failure.unexpected }
        }

        var atDifferential: Bool {
            guard integralDepth > 0, current == .name("d"), index + 1 < tokens.count,
                  case .name = tokens[index + 1] else { return false }
            return true
        }

        mutating func expression() throws -> Node {
            var left = try term()
            while true {
                if take("+") { left = .binary(.add, left, try term()) }
                else if take("-") { left = .binary(.subtract, left, try term()) }
                else { return left }
            }
        }

        mutating func term() throws -> Node {
            var left = try unary()
            while true {
                if take("*") { left = .binary(.multiply, left, try unary()) }
                else if take("/") { left = .binary(.divide, left, try unary()) }
                else if take("%") { left = .binary(.modulo, left, try unary()) }
                else if case .command(let name)? = current, ["cdot", "times"].contains(name) {
                    index += 1
                    left = .binary(.multiply, left, try unary())
                } else if case .command("div")? = current {
                    index += 1
                    left = .binary(.divide, left, try unary())
                } else if case .command(let name)? = current, ["mod", "bmod"].contains(name) {
                    index += 1
                    left = .binary(.modulo, left, try unary())
                } else if startsOperand {
                    left = .binary(.implicitMultiply, left, try power())
                } else {
                    return left
                }
            }
        }

        /// Whether the next token begins a factor written beside the last one,
        /// as in `2x`, `3(4)` or `2\pi`.
        var startsOperand: Bool {
            guard let current, !atDifferential else { return false }
            switch current {
            case .number, .name: return true
            case .command(let name):
                return !["cdot", "times", "div", "mod", "bmod", "right"].contains(name)
            case .symbol(let symbol): return ["(", "{", "["].contains(symbol)
            }
        }

        mutating func unary() throws -> Node {
            if take("-") { return .negate(try unary()) }
            if take("+") { return try unary() }
            return try power()
        }

        mutating func power() throws -> Node {
            let base = try postfix()
            guard take("^") else { return base }
            return .binary(.power, base, try exponent())
        }

        /// `^{…}`, or the one thing after `^`, which may carry its own sign.
        mutating func exponent() throws -> Node {
            if take("{") {
                let inner = try expression()
                try expect("}")
                return inner
            }
            return try unary()
        }

        mutating func postfix() throws -> Node {
            var node = try primary()
            while take("!") { node = .factorial(node) }
            return node
        }

        mutating func group(_ open: String, _ close: String) throws -> Node {
            let inner = try expression()
            try expect(close)
            return open == "{" ? inner : .group(inner)
        }

        /// `{…}` or the single token TeX allows in its place (`\frac12`).
        mutating func argument() throws -> Node {
            if take("{") {
                let inner = try expression()
                try expect("}")
                return inner
            }
            if case .number(let value, let text)? = current, text.count > 1, !text.contains(".") {
                // `\frac12` is ½: each digit is an argument of its own.
                let first = String(text.prefix(1))
                let rest = String(text.dropFirst())
                var remaining = tokens
                remaining[index] = .number(Double(rest) ?? value, rest)
                self = Parser(tokens: remaining, index: index, integralDepth: integralDepth)
                return .number(Double(first) ?? value, first)
            }
            return try postfix()
        }

        init(tokens: [Token], index: Int, integralDepth: Int) {
            self.tokens = tokens
            self.index = index
            self.integralDepth = integralDepth
        }

        mutating func primary() throws -> Node {
            guard let token = current else { throw Failure.unexpected }
            index += 1
            switch token {
            case .number(let value, let text):
                return .number(value, text)
            case .name(let name):
                return .variable(name)
            case .symbol("("): return try group("(", ")")
            case .symbol("["): return try group("[", "]")
            case .symbol("{"): return try group("{", "}")
            case .symbol("|"):
                let inner = try expression()
                try expect("|")
                return .absolute(inner)
            case .command(let name):
                return try command(name)
            default:
                throw Failure.unexpected
            }
        }

        mutating func command(_ name: String) throws -> Node {
            if let constant = Constant(rawValue: name) { return .constant(constant) }
            switch name {
            case "frac", "dfrac", "tfrac":
                let top = try argument()
                return .fraction(top, try argument())
            case "sqrt":
                var rootIndex: Node?
                if take("[") {
                    rootIndex = try expression()
                    try expect("]")
                }
                return .root(try argument(), index: rootIndex)
            case "left":
                if take("|") {
                    let inner = try expression()
                    try expectRight("|")
                    return .absolute(inner)
                }
                for (open, close) in [("(", ")"), ("[", "]"), ("{", "}")] where take(open) {
                    let inner = try expression()
                    try expectRight(close)
                    return .group(inner)
                }
                throw Failure.unexpected
            case "int":
                return try integral()
            case "sum", "prod":
                return try series(product: name == "prod")
            case "operatorname":
                guard take("{") else { throw Failure.unexpected }
                var word = ""
                while case .name(let letter)? = current { word += letter; index += 1 }
                while case .command(let part)? = current { word += part; index += 1 }
                try expect("}")
                return try command(word)
            default:
                guard let function = Function(rawValue: name) else { throw Failure.unknown(name) }
                if function == .log, take("_") {
                    let base = try argument()
                    return .log(base: base, try functionArgument())
                }
                if function == .sqrt { return .root(try functionArgument(), index: nil) }
                if function == .abs { return .absolute(try functionArgument()) }
                return .function(function, try functionArgument())
            }
        }

        mutating func expectRight(_ close: String) throws {
            guard current == .command("right") else { throw Failure.unexpected }
            index += 1
            try expect(close)
        }

        /// `\sin(x)`, `\sin{x}`, or as TeX reads `\sin 2x`: the factors that
        /// follow up to the next operator.
        mutating func functionArgument() throws -> Node {
            if current == .symbol("(") || current == .symbol("{") { return try power() }
            var node = try power()
            while startsOperand, !startsFunction { node = .binary(.implicitMultiply, node, try power()) }
            return node
        }

        var startsFunction: Bool {
            if case .command(let name)? = current { return Function(rawValue: name) != nil }
            return false
        }

        /// `\int_{a}^{b} body dx`: the bounds in either order, the variable
        /// from the `d` at the end (x when there is none).
        mutating func integral() throws -> Node {
            var lower: Node?
            var upper: Node?
            for _ in 0..<2 {
                if take("_") { lower = try argument() }
                else if take("^") { upper = try argument() }
            }
            guard let lower, let upper else { throw Failure.unexpected }
            integralDepth += 1
            let body = try expression()
            integralDepth -= 1
            var variable = "x"
            if current == .name("d"), index + 1 < tokens.count, case .name(let name) = tokens[index + 1] {
                variable = name
                index += 2
            }
            return .integral(lower: lower, upper: upper, body: body, variable: variable)
        }

        /// `\sum_{i=1}^{n} body`: the counter, its start and its end.
        mutating func series(product: Bool) throws -> Node {
            var variable = "i"
            var lower: Node?
            var upper: Node?
            for _ in 0..<2 {
                if take("_") {
                    let braced = take("{")
                    if case .name(let name)? = current, index + 1 < tokens.count, tokens[index + 1] == .symbol("=") {
                        variable = name
                        index += 2
                    }
                    lower = braced ? try expression() : try postfix()
                    if braced { try expect("}") }
                } else if take("^") {
                    upper = try argument()
                }
            }
            guard let lower, let upper else { throw Failure.unexpected }
            return .series(product: product, variable: variable, lower: lower, upper: upper, body: try functionArgument())
        }
    }

    // MARK: - Values

    static func number(_ node: Node, _ variables: [String: Double]) throws -> Double {
        switch node {
        case .number(let value, _): return value
        case .variable(let name):
            guard let value = variables[name] else { throw Failure.unknown(name) }
            return value
        case .constant(.pi): return .pi
        case .constant(.e): return M_E
        case .constant(.tau): return 2 * .pi
        case .negate(let inner): return -(try number(inner, variables))
        case .group(let inner): return try number(inner, variables)
        case .binary(let op, let left, let right):
            let a = try number(left, variables)
            let b = try number(right, variables)
            switch op {
            case .add: return a + b
            case .subtract: return a - b
            case .multiply, .implicitMultiply: return a * b
            case .divide: return a / b
            // The sign follows the divisor, as a calculator's modulo does.
            case .modulo:
                guard b != 0 else { return .nan }
                let r = a.truncatingRemainder(dividingBy: b)
                return r != 0 && (r < 0) != (b < 0) ? r + b : r
            case .power: return Foundation.pow(a, b)
            }
        case .fraction(let top, let bottom):
            return try number(top, variables) / number(bottom, variables)
        case .root(let radicand, let rootIndex):
            let x = try number(radicand, variables)
            guard let rootIndex else { return x.squareRoot() }
            let n = try number(rootIndex, variables)
            // An odd root of a negative number is real.
            if x < 0, n.rounded() == n, Int(n) % 2 != 0 { return -Foundation.pow(-x, 1 / n) }
            return Foundation.pow(x, 1 / n)
        case .function(let function, let argument):
            let x = try number(argument, variables)
            switch function {
            case .sin: return Foundation.sin(x)
            case .cos: return Foundation.cos(x)
            case .tan: return Foundation.tan(x)
            case .sec: return 1 / Foundation.cos(x)
            case .csc: return 1 / Foundation.sin(x)
            case .cot: return 1 / Foundation.tan(x)
            case .arcsin: return Foundation.asin(x)
            case .arccos: return Foundation.acos(x)
            case .arctan: return Foundation.atan(x)
            case .sinh: return Foundation.sinh(x)
            case .cosh: return Foundation.cosh(x)
            case .tanh: return Foundation.tanh(x)
            case .ln: return Foundation.log(x)
            case .log: return Foundation.log10(x)
            case .exp: return Foundation.exp(x)
            case .sqrt: return x.squareRoot()
            case .abs: return Swift.abs(x)
            case .floor: return x.rounded(.down)
            case .ceil: return x.rounded(.up)
            }
        case .log(let base, let argument):
            return Foundation.log(try number(argument, variables)) / Foundation.log(try number(base, variables))
        case .absolute(let inner): return Swift.abs(try number(inner, variables))
        case .factorial(let inner):
            let x = try number(inner, variables)
            guard x >= 0, x.rounded() == x, x <= 170 else { return Foundation.tgamma(x + 1) }
            return (1...max(1, Int(x))).reduce(1.0) { $0 * Double($1) }
        case .integral(let lower, let upper, let body, let variable):
            let a = try number(lower, variables)
            let b = try number(upper, variables)
            return try simpson(a, b) { x in
                var bound = variables
                bound[variable] = x
                return try number(body, bound)
            }
        case .series(let product, let variable, let lower, let upper, let body):
            let start = try number(lower, variables).rounded()
            let end = try number(upper, variables).rounded()
            guard end - start <= 1_000_000 else { throw Failure.notANumber }
            var total: Double = product ? 1 : 0
            guard start <= end else { return total }
            var bound = variables
            for counter in Int(start)...Int(end) {
                bound[variable] = Double(counter)
                let term = try number(body, bound)
                total = product ? total * term : total + term
            }
            return total
        }
    }

    /// Simpson's rule on enough slices that a smooth integrand is exact to
    /// the digits shown; a singularity at an end is stepped around.
    static func simpson(_ a: Double, _ b: Double, _ f: (Double) throws -> Double) throws -> Double {
        guard a.isFinite, b.isFinite else { throw Failure.notANumber }
        if a == b { return 0 }
        let slices = 2_000
        let width = (b - a) / Double(slices)
        func sample(_ x: Double) throws -> Double {
            let y = try f(x)
            if y.isFinite { return y }
            return try f(x + (x == b ? -1 : 1) * width * 1e-6)
        }
        var total = try sample(a) + sample(b)
        for step in 1..<slices {
            total += try sample(a + Double(step) * width) * (step % 2 == 0 ? 2 : 4)
        }
        return total * width / 3
    }

    // MARK: - TeX

    private static func precedence(_ node: Node) -> Int {
        switch node {
        case .binary(.add, _, _), .binary(.subtract, _, _): return 1
        case .binary(.multiply, _, _), .binary(.implicitMultiply, _, _), .binary(.modulo, _, _), .binary(.divide, _, _): return 2
        case .negate: return 3
        case .binary(.power, _, _): return 4
        case .integral, .series: return 0
        default: return 5
        }
    }

    private static func wrapped(_ node: Node, below level: Int) -> String {
        precedence(node) < level ? "\\left(\(tex(node))\\right)" : tex(node)
    }

    static func tex(_ node: Node) -> String {
        switch node {
        case .number(_, let text): return text
        case .variable(let name): return name
        case .constant(.pi): return "\\pi"
        case .constant(.e): return "e"
        case .constant(.tau): return "\\tau"
        case .negate(let inner): return "-" + wrapped(inner, below: 3)
        case .group(let inner): return "\\left(\(tex(inner))\\right)"
        case .binary(let op, let left, let right):
            switch op {
            case .add: return "\(tex(left)) + \(tex(right))"
            case .subtract: return "\(tex(left)) - \(wrapped(right, below: 2))"
            case .multiply: return "\(wrapped(left, below: 2)) \\cdot \(wrapped(right, below: 3))"
            case .implicitMultiply: return "\(wrapped(left, below: 2))\(wrapped(right, below: 3))"
            // A typed slash reads as a fraction, as it would be written.
            case .divide: return "\\frac{\(tex(left))}{\(tex(right))}"
            case .modulo: return "\(wrapped(left, below: 2)) \\bmod \(wrapped(right, below: 3))"
            case .power: return "{\(wrapped(left, below: 5))}^{\(tex(right))}"
            }
        case .fraction(let top, let bottom): return "\\frac{\(tex(top))}{\(tex(bottom))}"
        case .root(let radicand, let index):
            return index.map { "\\sqrt[\(tex($0))]{\(tex(radicand))}" } ?? "\\sqrt{\(tex(radicand))}"
        case .function(let function, let argument):
            let name = ["sec", "csc", "cot", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "sin", "cos", "tan",
                        "ln", "log", "exp"].contains(function.rawValue)
                ? "\\\(function.rawValue)" : "\\operatorname{\(function.rawValue)}"
            // Brackets typed around the argument are the function's own.
            if case .group(let inner) = argument { return "\(name)\\left(\(tex(inner))\\right)" }
            return "\(name)\\left(\(tex(argument))\\right)"
        case .log(let base, let argument): return "\\log_{\(tex(base))}\\left(\(tex(argument))\\right)"
        case .absolute(let inner): return "\\left|\(tex(inner))\\right|"
        case .factorial(let inner): return wrapped(inner, below: 5) + "!"
        case .integral(let lower, let upper, let body, let variable):
            return "\\int_{\(tex(lower))}^{\(tex(upper))} \(tex(body)) \\, d\(variable)"
        case .series(let product, let variable, let lower, let upper, let body):
            return "\\\(product ? "prod" : "sum")_{\(variable)=\(tex(lower))}^{\(tex(upper))} \(wrapped(body, below: 2))"
        }
    }

    /// What half-typed input typesets as: the words it knows given their
    /// backslash and `**` as a power, so the page follows the typing.
    static func fallbackTeX(_ input: String) -> String {
        guard let tokens = try? tokenize(input) else { return input }
        return tokens.map { token -> String in
            switch token {
            case .number(_, let text): return text
            case .name(let name): return name
            case .command(let name): return "\\" + name + " "
            case .symbol("*"): return "\\cdot "
            case .symbol("%"): return "\\% "
            case .symbol(let symbol): return symbol
            }
        }.joined()
    }
}
