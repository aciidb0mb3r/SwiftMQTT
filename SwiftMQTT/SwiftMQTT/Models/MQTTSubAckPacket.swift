//
//  MQTTSubAckPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTSubAckPacket: MQTTPacket {
    
    let messageID: UInt16
    
    init(header: MQTTPacketFixedHeader, networkData: Data) {
        let buffer = (networkData as NSData).bytes.bindMemory(to: UInt8.self, capacity: networkData.count)
        messageID = (UInt16(buffer[0]) * UInt16(256)) + UInt16(buffer[1])
        super.init(header: header)
    }
}
