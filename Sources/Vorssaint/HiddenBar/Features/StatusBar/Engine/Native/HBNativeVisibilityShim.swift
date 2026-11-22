// SPDX-License-Identifier: MIT
// Hidden Bar, Copyright (c) 2019 Dwarves Foundation, (c) 2026 Console Labs.
// Ported into Dynamai: the Objective-C shim (HBNativeVisibilityShim.m)
// rewritten in Swift, since Dynamai builds no Objective-C. Same functions,
// same behavior; see LICENSE-HiddenBar.txt.

import Foundation

/// MenuBarClientCore's assessment-mode restriction, reached at runtime so a
/// macOS that changes or drops it makes hiding unavailable instead of
/// breaking the launch.
private enum HBNativeVisibility {
    static let frameworkPath = "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"
    static let configurationInit = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
    static let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
    static let invalidateSelector = NSSelectorFromString("invalidate")

    static var configurationClass: AnyClass? { NSClassFromString("MBAssessmentModeConfiguration") }
    static var assertionClass: AnyClass? { NSClassFromString("MBAssessmentModeAssertion") }

    static let isAvailable: Bool = {
        guard dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL) != nil,
              let configuration = configurationClass, let assertion = assertionClass else { return false }
        return class_respondsToSelector(configuration, configurationInit)
            && class_respondsToSelector(assertion, activateSelector)
            && class_respondsToSelector(assertion, invalidateSelector)
    }()

    typealias AllocFunction = @convention(c) (AnyClass, Selector) -> OpaquePointer?
    typealias ConfigurationInitFunction =
        @convention(c) (OpaquePointer, Selector, NSArray, NSArray) -> Unmanaged<NSObject>?
    typealias ActivateFunction =
        @convention(c) (NSObject, Selector, NSObject, @escaping @convention(block) (NSError?) -> Void) -> Void

    static func error(_ reason: String) -> NSError {
        NSError(domain: "HBNativeVisibility", code: 1, userInfo: [NSLocalizedDescriptionKey: reason])
    }
}

func HBNativeVisibilityIsAvailable() -> Bool {
    HBNativeVisibility.isAvailable
}

/// Keeps only these system items and apps visible. The completion runs on the
/// main queue with the held assertion, or the error. Both lists must be arrays:
/// the framework indexes into them.
func HBNativeVisibilityActivate(_ allowedSystemItems: [NSNumber],
                                _ allowedBundleIdentifiers: [String],
                                _ completion: @escaping (Any?, Error?) -> Void) {
    let finish: (Any?, Error?) -> Void = { assertion, error in
        DispatchQueue.main.async { completion(assertion, error) }
    }
    guard HBNativeVisibility.isAvailable,
          let configurationClass = HBNativeVisibility.configurationClass,
          let assertionClass = HBNativeVisibility.assertionClass as? NSObject.Type,
          let allocMethod = class_getClassMethod(configurationClass, NSSelectorFromString("alloc")),
          let initMethod = class_getInstanceMethod(configurationClass, HBNativeVisibility.configurationInit),
          let activateMethod = class_getInstanceMethod(assertionClass, HBNativeVisibility.activateSelector) else {
        return finish(nil, HBNativeVisibility.error("MenuBarClientCore is unavailable on this macOS"))
    }
    // alloc returns +1 and init consumes it, so the raw pointer is handed
    // straight through without Swift retaining it in between.
    let alloc = unsafeBitCast(method_getImplementation(allocMethod), to: HBNativeVisibility.AllocFunction.self)
    let initialize = unsafeBitCast(method_getImplementation(initMethod),
                                   to: HBNativeVisibility.ConfigurationInitFunction.self)
    guard let raw = alloc(configurationClass, NSSelectorFromString("alloc")),
          let configuration = initialize(raw, HBNativeVisibility.configurationInit,
                                         allowedSystemItems as NSArray,
                                         allowedBundleIdentifiers as NSArray)?.takeRetainedValue() else {
        return finish(nil, HBNativeVisibility.error("Could not create the visibility configuration"))
    }
    let assertion = assertionClass.init()
    let activate = unsafeBitCast(method_getImplementation(activateMethod), to: HBNativeVisibility.ActivateFunction.self)
    activate(assertion, HBNativeVisibility.activateSelector, configuration) { error in
        finish(error == nil ? assertion : nil, error)
    }
}

func HBNativeVisibilityInvalidate(_ assertion: Any) {
    guard let assertion = assertion as? NSObject,
          assertion.responds(to: HBNativeVisibility.invalidateSelector) else { return }
    assertion.perform(HBNativeVisibility.invalidateSelector)
}
