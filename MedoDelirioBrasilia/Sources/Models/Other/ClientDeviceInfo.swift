//
//  ClientDeviceInfo.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 08/06/22.
//

import Foundation

struct ClientDeviceInfo: Hashable, Codable {

    var installId: String
    var modelName: String
    var isWatchPaired: Bool?
}
