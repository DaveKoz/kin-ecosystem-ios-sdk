//
//  FlowController.swift
//  KinEcosystem
//
//  Created by Corey Werner on 23/10/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import UIKit

class FlowController: NSObject {
    let keystoreProvider: KeystoreProvider
    let navigationController: UINavigationController
    
    init(keystoreProvider: KeystoreProvider, navigationController: UINavigationController) {
        self.keystoreProvider = keystoreProvider
        self.navigationController = navigationController
        super.init()
    }
    
    var entryViewController: UIViewController {
        fatalError("entryViewController() has not been implemented")
    }
    
    func syncNavigationBarColor(with viewController: UIViewController) {
        navigationController.navigationBar.tintColor = viewController.preferredStatusBarStyle.color
    }
}
