//
//  FilterOption.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/02/26.
//

import Foundation

protocol FilterOption: Identifiable, Equatable {
    var displayName: String { get }
    var symbol: String { get }
}
