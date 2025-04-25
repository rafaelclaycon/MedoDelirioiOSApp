//
//  Opener.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 19/12/22.
//

import UIKit

class Opener {

    static func open(link: String) {
        guard link.isEmpty == false else { return }
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url)
    }

}
