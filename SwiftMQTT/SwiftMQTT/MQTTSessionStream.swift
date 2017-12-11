//
//  MQTTSessionStream.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

/*
OCI Changes:
    Bug Fix - do not MQTT connect until ports are ready
    Changed name of file to match primary class
    Propagate error object to delegate
    Make MQTTSessionStreamDelegate var weak
    MQTTSessionStream is now not recycled (RAII design pattern)
	Move the little bit of parsing out of this class. This only manages the stream.
    Always use dedicated queue for streams
*/

import Foundation

protocol MQTTSessionStreamDelegate: class {
    func mqttReady(_ ready: Bool, in stream: MQTTSessionStream)
    func mqttErrorOccurred(in stream: MQTTSessionStream, error: Error?)
	func mqttReceived(in stream: MQTTSessionStream, _ read: (_ buffer: UnsafeMutablePointer<UInt8>, _ maxLength: Int) -> Int)
}

class MQTTSessionStream: NSObject {
    
    private let inputStream: InputStream?
    private let outputStream: OutputStream?
    private weak var delegate: MQTTSessionStreamDelegate?
	private var sessionQueue: DispatchQueue
	
	private var inputReady = false
	private var outputReady = false
    
    init(host: String, port: UInt16, ssl: Bool, timeout: TimeInterval, delegate: MQTTSessionStreamDelegate?) {
        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: Int(port), inputStream: &inputStream, outputStream: &outputStream)
        
        var parts = host.components(separatedBy: ".")
        parts.insert("stream\(port)", at: 0)
        let label = parts.reversed().joined(separator: ".")
        
        self.sessionQueue = DispatchQueue(label: label, qos: .background, target: nil)
        self.delegate = delegate
        self.inputStream = inputStream
        self.outputStream = outputStream
        super.init()
        
        inputStream?.delegate = self
        outputStream?.delegate = self
        
        sessionQueue.async { [weak self] in
            let currentRunLoop = RunLoop.current
            inputStream?.schedule(in: currentRunLoop, forMode: .defaultRunLoopMode)
            outputStream?.schedule(in: currentRunLoop, forMode: .defaultRunLoopMode)
            inputStream?.open()
            outputStream?.open()
            if ssl {
                let securityLevel = StreamSocketSecurityLevel.negotiatedSSL.rawValue
                inputStream?.setProperty(securityLevel, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                outputStream?.setProperty(securityLevel, forKey: Stream.PropertyKey.socketSecurityLevelKey)
            }
			if timeout > 0 {
				DispatchQueue.global().asyncAfter(deadline: .now() +  timeout) {
					self?.connectTimeout()
				}
			}
            currentRunLoop.run()
        }
    }
    
    deinit {
        inputStream?.close()
        inputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
        outputStream?.close()
        outputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
    }
    
    func send(_ packet: MQTTPacket) -> Int {
        let networkPacket = packet.networkPacket()
        var bytes = [UInt8](repeating: 0, count: networkPacket.count)
        networkPacket.copyBytes(to: &bytes, count: networkPacket.count)
		if let outputStream = outputStream, outputReady {
			return outputStream.write(bytes, maxLength: networkPacket.count)
		}
        return -1
    }
	
	internal func connectTimeout() {
		if inputReady == false || outputReady == false {
			delegate?.mqttReady(false, in: self)
		}
	}
}

extension MQTTSessionStream: StreamDelegate {
    @objc
    internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            let wasReady = inputReady && outputReady
            if aStream == inputStream {
                inputReady = true
            }
            else if aStream == outputStream {
                // output almost ready
            }
            if !wasReady && inputReady && outputReady {
                delegate?.mqttReady(true, in: self)
            }
            break
        case Stream.Event.hasBytesAvailable:
            if aStream == inputStream {
                delegate?.mqttReceived(in: self, inputStream!.read)
            }
            break
        case Stream.Event.errorOccurred:
            delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)
            break
        case Stream.Event.endEncountered:
            delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)
            break
        case Stream.Event.hasSpaceAvailable:
            let wasReady = inputReady && outputReady
            if aStream == outputStream {
                outputReady = true
            }
            if !wasReady && inputReady && outputReady {
                delegate?.mqttReady(true, in: self)
            }
            break
        default:
            break
        }
    }
}
