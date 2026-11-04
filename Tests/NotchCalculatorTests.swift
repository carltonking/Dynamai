// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Carbon.HIToolbox
import Foundation

/// The island's calculator reads LaTeX and keyboard arithmetic alike, and the
/// answer it shows is the value of the very tree it typesets.
enum NotchCalculatorTests {
    static func run(_ suite: TestSuite) {
        typealias Engine = NotchCalculatorEngine
        func value(_ input: String) -> Double? { Engine.evaluate(input).value }
        func close(_ input: String, _ expected: Double, _ message: String) {
            guard let got = value(input) else { suite.expect(false, "\(message): no answer for \(input)"); return }
            suite.expectClose(got, expected, message)
        }

        suite.run("calculator keyboard arithmetic") {
            close("1/2", 0.5, "slash divides")
            close("3*4", 12, "star multiplies")
            close("2**10", 1024, "two stars raise to a power")
            close("2^10", 1024, "a caret raises to a power")
            close("7 % 3", 1, "percent is the remainder")
            close("-7 % 3", 2, "a remainder takes the divisor's sign")
            close("1 + 2 * 3", 7, "multiplication binds tighter than addition")
            close("(1 + 2) * 3", 9, "parentheses group")
            close("2**3**2", 512, "powers group from the right")
            close("-2**2", -4, "a minus sign applies after the power")
            close("2^-1", 0.5, "an exponent can carry its own sign")
            close("10 - 4 - 3", 3, "subtraction runs left to right")
            close("5!", 120, "an exclamation mark is a factorial")
            close("|-3|", 3, "bars are an absolute value")
        }

        suite.run("calculator LaTeX") {
            close("\\frac{1}{2}", 0.5, "a fraction")
            close("frac{1}{2}", 0.5, "a fraction typed without its backslash")
            close("\\frac12", 0.5, "TeX's one-digit fraction")
            close("\\sqrt{16}", 4, "a square root")
            close("\\sqrt[3]{27}", 3, "a cube root")
            close("\\sqrt[3]{-8}", -2, "an odd root of a negative number is real")
            close("2\\pi", 2 * .pi, "a number beside pi multiplies it")
            close("\\sin(\\pi/2)", 1, "sine")
            close("\\cos 0", 1, "a function's argument without brackets")
            close("\\ln e", 1, "natural logarithm")
            close("\\log_{2}{8}", 3, "a logarithm in another base")
            close("3 \\cdot 4 \\times 2", 24, "cdot and times multiply")
            close("8 \\div 2", 4, "div divides")
            close("\\left(1+2\\right)^2", 9, "left and right brackets")
            close("\\int_{2}^{3} x^2 dx", 19.0 / 3, "a definite integral")
            close("int_{0}^{1}2tdt", 1, "an integral typed without backslashes, in its own variable")
            close("\\int_0^\\pi \\sin x \\, dx", 2, "TeX spacing in an integral")
            close("\\sum_{i=1}^{10} i", 55, "a sum")
            close("\\prod_{k=1}^{5} k", 120, "a product")
            close("2(3)(4)", 24, "brackets side by side multiply")
        }

        suite.run("calculator while typing") {
            let partial = Engine.evaluate("\\frac{1}{")
            suite.expect(partial.value == nil && !partial.tex.isEmpty,
                         "half a fraction has no answer yet but still typesets as typed")
            suite.expect(Engine.evaluate("x + 1").value == nil, "a free variable has no answer")
            suite.expect(Engine.evaluate("1/0").value == nil, "dividing by zero has no answer")
            suite.expect(Engine.evaluate("   ").tex.isEmpty && Engine.evaluate("").value == nil, "nothing typed shows nothing")
            suite.expect(Engine.evaluate("\\alpha + 1").value == nil, "an unknown command has no answer")
        }

        suite.run("calculator opens from its shortcut") {
            suite.expect(GlobalShortcut.calculatorDefault == GlobalShortcut(keyCode: Int64(kVK_ANSI_D), modifiers: [.command, .shift])
                         && Defaults.registeredDefaults[DefaultsKey.notchCalculatorShortcut] as? String
                            == GlobalShortcut.calculatorDefault.storageValue
                         && Defaults.registeredDefaults[DefaultsKey.notchCalculatorShortcutEnabled] as? Bool == true
                         && GlobalShortcutRole.calculator.feature == .notch,
                         "Shift-Command-D opens the island's calculator by default")
            suite.expect(GlobalShortcut.calculatorDefault != GlobalShortcut.agentChatDefault
                         && GlobalShortcut.calculatorDefault != GlobalShortcut.shelfDefault,
                         "the calculator's shortcut is no other default's")
            suite.expect(NotchModule.calculator.shortcutKey == "=" && !NotchModule.calculator.isAgentChat
                         && NotchModule.calculator.isAvailable(),
                         "inside the island Option-Command-= opens it, and it is its own page")
            let service = (try? String(contentsOfFile: "Sources/Vorssaint/Services/Notch/NotchService.swift",
                                       encoding: .utf8)) ?? ""
            suite.expect(service.contains("calculatorHotkey.onPress = { [weak self] in self?.showCalculator(toggle: true) }")
                         && service.contains("        syncCalculatorShortcut()\n")
                         && service.contains("agentHotkey.unregister()\n        calculatorHotkey.unregister()"),
                         "the shortcut is held with the island's preferences and released when the island stops")
        }

        suite.run("calculator shows answers and TeX") {
            suite.expect(Engine.format(0.5) == "0.5" && Engine.format(12) == "12" && Engine.format(1.0 / 3) == "0.3333333333",
                         "answers drop trailing zeros and keep ten figures")
            suite.expect(Engine.format(-2) == "-2" && Engine.format(2e20) == "2e20" && Engine.format(0) == "0",
                         "whole, very large and zero answers read plainly")
            suite.expect(Engine.evaluate("1/2").tex == "\\frac{1}{2}", "a typed slash is typeset as a fraction")
            suite.expect(Engine.evaluate("2**3").tex == "{2}^{3}", "two stars are typeset as a power")
            suite.expect(Engine.evaluate("3*4").tex == "3 \\cdot 4", "a star is typeset as a dot")
            suite.expect(Engine.evaluate("7 % 3").tex == "7 \\bmod 3", "percent is typeset as mod")
            suite.expect(Engine.evaluate("(1+2)*3").tex == "\\left(1 + 2\\right) \\cdot 3", "grouping is kept")
        }
    }
}
