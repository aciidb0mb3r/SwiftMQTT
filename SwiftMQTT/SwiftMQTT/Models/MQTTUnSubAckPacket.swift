//
//  MQTTUnSubAckPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTUnSubAckPacket: MQTTPacket {
    
    let messageID: UInt16
    
    init?(header: MQTTPacketFixedHeader, networkData: Data) {
        if networkData.count >= 2 {
            messageID = (UInt16(networkData[0]) * UInt16(256)) + UInt16(networkData[1])
            super.init(header: header)
        } else {
            return nil
        }        
    }
}
