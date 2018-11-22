//
//  Core.swift
//  KinEcosystem
//
//  Created by Elazar Yifrach on 04/03/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//


@available(iOS 9.0, *)
class Core {
    let network: EcosystemNet
    let data: EcosystemData
    let blockchain: Blockchain
    let environment: Environment
    
    init(environment: Environment, network: EcosystemNet, data: EcosystemData, blockchain: Blockchain) throws {
        self.network = network
        self.data = data
        self.blockchain = blockchain
        self.environment = environment
    }
}

func synced(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    defer {
        objc_sync_exit(lock)
    }
    closure()
}
