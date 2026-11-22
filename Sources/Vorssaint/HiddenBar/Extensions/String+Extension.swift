//
//  String+Extension.swift
//  Hidden Bar
//
//  Created by Licardo on 2020/3/9.
//  Copyright © 2020 Console Labs. All rights reserved.
//

import Foundation

extension String {
    
    // localize
    var localized: String {
        // Inside Dynamai, Hidden Bar's words are a table of their own.
        return NSLocalizedString(self, tableName: "HiddenBar", comment: self)
    }
}
