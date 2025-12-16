//
//  Nust7.swift
//  GreenVPN
//
//  Created by sister on 2025/12/16.
//

import Foundation
import NetworkExtension
import os
import CommonCrypto
import Dispatch
import CryptoKit
import Network

class Nust7 {
    var connection: NWConnection? = nil
    var queue: DispatchQueue?
    
    var domain = ""
    var ip =  ""
    var serverPort = "80"
    var serverAddress = ""
    var sniHost = ""
    
    var country =  ""
    var language =  ""
    var package =  ""
    var version =  ""
    var key = ""
    
    var path = "/conn"
    var isChunked = false
    var isUseTls = false
    var cf = false
    var wildcard = false
    
    var cf_key = ""
    var cf_len = ""
    var cf_len_int = 128
    
    var buffer: Data = Data()
    let monitor = NWPathMonitor()
    
    var logServer = ""
    var uuid = ""
    
    var headers  = [
        "User-Agent": "Kotlin HTTP Client",
        "Content-Type": "application/json"
    ]
    
    var res_headers = [String: String]()
    var parseHeaders = [String: String]()
    var headerBuffer = Data()
    
    var isParsingHeader = true
    var expectedContentLength = 0
    var headerEnd = "\r\n\r\n".data(using: .ascii)!
    let chunkEnd = "\r\n".data(using: .ascii)!
    
    var reasserting = false
    var loadNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var packetFlow: NEPacketTunnelFlow
  
    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }
    
    func setupWithTlsTCPConnection() {
        os_log("hellovpn  setupWithTlsTCPConfuseConnection: %{public}@", log: OSLog.default, type: .error, "setupWithTlsTCPConnection")
        
        self.isChunked = true
        self.isUseTls = true
        self.cf = false
        self.wildcard = false
        self.path = ""
        self.ip = "64.176.43.209"
        self.domain = "hp.com"
        self.serverPort = "49155"
        self.country = "sg"
        self.language = "zh-Hans-SG"
        self.package = "com.green.fire.vpn.bird.fly"
        self.version = "1.0.0"
        self.key = "3e027e48ec6f5a9c705dfe17bed37201"
        self.uuid = "F169946F-2966-4C54-B284-283550D09B5E"
        self.cf_key = "hfor1"
        self.cf_len = "32"
        self.cf_len_int = Int(self.cf_len) ?? 0
        
        self.sniHost = self.wildcard ? "\(generateRandomPrefix()).\(self.domain)" : self.domain
        self.serverAddress = self.ip.isEmpty ? self.sniHost : self.ip
        
        if !self.cf && !self.isUseTls {
            headers["Host"] = self.sniHost
        }
        
        os_log("hellovpn setupWithTlsTCPConnection self.sniHost: %{public}@", log: OSLog.default, type: .error, self.sniHost)
        
        let parameters = isUseTls ? createTLSParameters(allowInsecure: true, queue: DispatchQueue(label: "dunnwang"), sniHost: self.sniHost) : NWParameters.tcp
        guard let port = NWEndpoint.Port(self.serverPort) else {
            return
        }
        
        os_log("hellovpn setupWithTlsTCPConnection self.sniHost: %{public}@", log: OSLog.default, type: .error, self.sniHost)
        
        let endpointHost = NWEndpoint.Host(self.serverAddress)
        connection = NWConnection(host: endpointHost, port: port, using: parameters)
        
        os_log("hellovpn setupWithTlsTCPConnection serverAddress: %{public}@", log: OSLog.default, type: .error, serverAddress)
        
        self.queue = .global()
        self.connection?.stateUpdateHandler = self.onStateDidChange(to:)
        self.connection?.start(queue: self.queue!)
    }

    private func generateRandomPrefix(length: Int = 5) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
    
    
    func createTLSParameters(allowInsecure: Bool, queue: DispatchQueue, sniHost: String) -> NWParameters {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, sniHost)
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var error: CFError?
            
            let isValidTrust = SecTrustEvaluateWithError(trust, &error)
            let shouldComplete = isValidTrust || allowInsecure
            sec_protocol_verify_complete(shouldComplete)
            
        }, queue)
        return NWParameters(tls: options)
    }

    
    func onStateDidChange(to state: NWConnection.State) {
        switch state {
        case .setup:
            os_log("hellovpn onStateDidChange setup: %{public}@", log: OSLog.default, type: .error, "setup")
            break
        case .waiting(_):
            os_log("hellovpn onStateDidChange waiting: %{public}@", log: OSLog.default, type: .error, "waiting")
            break
        case .preparing:
            os_log("hellovpn onStateDidChange preparing: %{public}@", log: OSLog.default, type: .error, "preparing")
//            getNutsIP()
            break
        case .ready:
            os_log("hellovpn onStateDidChange ready: %{public}@", log: OSLog.default, type: .error, "ready")
            getNutsIP()
        case .failed(_):
            os_log("hellovpn onStateDidChange failed: %{public}@", log: OSLog.default, type: .error, "failed")
            break
        case .cancelled:
            os_log("hellovpn onStateDidChange cancelled: %{public}@", log: OSLog.default, type: .error, "cancelled")
            break
        @unknown default:
            os_log("hellovpn onStateDidChange default: %{public}@", log: OSLog.default, type: .error, "default")
            break
        }
    }
    
    func getNutsIP() {
        os_log("hellovpn setupWithTlsTCPConnection getNutsIP: %{public}@", log: OSLog.default, type: .error, "start")
        let  data = encryptDataWithCommonCrypto(packageName: self.package,
                                               version: self.version,
                                               SDK: "7.0",
                                               country: self.country,
                                               language: self.language,
                                               keyString: self.key)
      
        let confuseData = encryptConfuseData(data: data!, key: self.cf_key.data(using: .utf8)!, cf_len_int: UInt8(self.cf_len_int))
        let contentLength = isChunked ? 0 : confuseData.count
        initializePostRequest(path: self.path,
                              headers: headers,
                              contentLength: contentLength,
                              chunked: isChunked,
                              data: confuseData)
        os_log("hellovpn setupWithTlsTCPConnection getNutsIP: %{public}@", log: OSLog.default, type: .error, "end")
    }
    func initializePostRequest(path: String, headers: [String: String], contentLength: Int, chunked: Bool, data: Data) {
        var requestString = "POST \(path) HTTP/1.1\r\n"
        headers.forEach { (key, value) in
            requestString += "\(key): \(value)\r\n"
        }
        if chunked {
            requestString += "Transfer-Encoding: chunked\r\n"
        } else {
            requestString += "Content-Length: \(contentLength)\r\n"
        }
        requestString += "\r\n"
        guard let requestData = requestString.data(using: .utf8) else {
            os_log("hellovpn initializePostRequest requestData: %{public}@", log: OSLog.default, type: .error, "nil")
            return
        }
        self.connection?.send(content: requestData, completion: .contentProcessed({ [self] error in
            if error != nil {
                os_log("hellovpn initializePostRequest error: %{public}@", log: OSLog.default, type: .error, "error")
                return
            }
            os_log("hellonuts : %{public}@", log: OSLog.default, type: .error,"successful initializePostRequest")
            sendBinaryChunk(chunk: data, chunked: isChunked)
        }))
    }
    
    func sendBinaryChunk(chunk: Data, chunked: Bool = true, host: String = "gstatic.com", headers: [String: String] = [:]) {
        var requestData = Data()

        if chunked {
            let chunkSizeHex = String(chunk.count, radix: 16)
            let chunkHeader = "\(chunkSizeHex)\r\n".data(using: .utf8)!
            let chunkFooter = "\r\n".data(using: .utf8)!

            requestData.append(chunkHeader)
            requestData.append(chunk)
            requestData.append(chunkFooter)
        } else {
            requestData.append(chunk)
        }

        self.connection?.send(content: requestData, completion: .contentProcessed({ [self] error in
            if error != nil {
                return
            }
            receiveHeader()
        }))
    }
    
    func receiveHeader() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, context, isComplete, error in
            self.handle(data: data, context: context, isComplete: isComplete, error: error)
        }
    }
    
    private func handle(data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?) {
        if let data = data, !data.isEmpty {
            
            
            headerBuffer.append(data)
            if let headersString = extractHeaders(from: headerBuffer) {
                parseHeaders(headersString)
            } else {
                receiveHeader()
            }
        }
    }

    private func extractHeaders(from data: Data) -> String? {
        if let headersRange = data.range(of: "\r\n\r\n".data(using: .utf8)!) {
            let headersData = data.subdata(in: 0..<headersRange.lowerBound)
            if let headersString = String(data: headersData, encoding: .utf8) {
                return headersString
            }
        }
        return nil
    }

    private func parseHeaders(_ headersString: String) {

        let headerLines = headersString.split(separator: "\r\n")
        for line in headerLines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                res_headers[key] = value
            }
        }
        
        if let accessFromIP = res_headers["X-Access-From"] {
            os_log("hellovpn Headers ip: %{public}@", log: OSLog.default, type: .error, accessFromIP)
           
            setupPacketTunnelNetworkSettings(intranetIP: accessFromIP)
        }
       
    }
    
    func setupPacketTunnelNetworkSettings(intranetIP: String) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.0.1")
        settings.mtu = 1400
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        settings.ipv4Settings = {
            let settings = NEIPv4Settings(addresses: [intranetIP], subnetMasks: ["255.255.0.0"])
            settings.includedRoutes = [NEIPv4Route.default()]
            return settings
        }()
        
        self.loadNetworkSettings?(settings) { error in
           if error != nil {
               return
           }
            self.tcpToTun()
            self.tunToTCP()
                   
        }
       
    }
    
    func tunToTCP() {
        self.packetFlow.readPackets { [weak self] (packets: [Data], protocols: [NSNumber]) in
            guard let self = self else { return }
            var requestData = Data()
            for packet in packets {
                let confusePacket = encryptConfuseData(data: packet, key: self.cf_key.data(using: .utf8)!, cf_len_int: UInt8(self.cf_len_int))
                let contentLength = confusePacket.count
                if isChunked {
                    let chunkSizeHex = String(contentLength, radix: 16)
                    let chunkHeader = "\(chunkSizeHex)\r\n".data(using: .utf8)!
                    let chunkFooter = "\r\n".data(using: .utf8)!
                    requestData.append(chunkHeader)
                    requestData.append( confusePacket)
                    requestData.append(chunkFooter)
                } else {
                    
                    var requestString = "POST \(path) HTTP/1.1\r\n"
                    headers.forEach { (key, value) in
                        requestString += "\(key): \(value)\r\n"
                    }
                    requestString += "Content-Length: \(contentLength)\r\n"
                    requestString += "\r\n"
                    requestData = requestString.data(using: .utf8)!
                    requestData.append( confusePacket)
                    
                }
                self.connection?.send(content: requestData, completion: .contentProcessed({  error in
                    if error != nil {
                        return
                    }
                    
                }))
            }
            
            self.tunToTCP()
        }
    }

    
    func tcpToTun() {
        self.connection?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.buffer.append(data)
                if isChunked {
                    self.processChunkedPacket()
                } else {
                    self.processHttpPacket()
                }
            }

            self.tcpToTun()
        }
    }
    
    func processChunkedPacket() {
        var currentIndex = buffer.startIndex
        
        if buffer.count >= 2 && buffer[currentIndex] == 0x0D && buffer[currentIndex + 1] == 0x0A {
            currentIndex += 2
        }
        
        while currentIndex < buffer.count {
            guard let sizeRange = buffer.range(of: Data("\r\n".utf8), options: [], in: currentIndex..<buffer.count),
                  let chunkSizeString = String(data: buffer.subdata(in: currentIndex..<sizeRange.lowerBound), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let chunkSize = Int(chunkSizeString, radix: 16) else {
                break
            }
            
            if chunkSize == 0 {
                let endIndex = sizeRange.upperBound + 2
                if endIndex <= buffer.count {
                    buffer.removeSubrange(buffer.startIndex..<endIndex)
                }
                break
            }
            
            let chunkStartIndex = sizeRange.upperBound
            let chunkEndIndex = chunkStartIndex + chunkSize
            guard chunkEndIndex <= buffer.count else {
                break
            }
            
            let chunkData = buffer.subdata(in: chunkStartIndex..<chunkEndIndex)
            let unConfuseChunkData = decryptData(data: chunkData, key: self.cf_key.data(using: .utf8)!)
          
            let protocolNumber = AF_INET as NSNumber
            self.packetFlow.writePackets([unConfuseChunkData], withProtocols: [protocolNumber])
            currentIndex = chunkEndIndex
            if currentIndex + 2 > buffer.count {
                break
            }
            
            if buffer[currentIndex] == 0x0D && buffer[currentIndex + 1] == 0x0A {
                currentIndex += 2
            } else {
                break
            }
        }
        
        buffer.removeSubrange(buffer.startIndex..<currentIndex)
    }

    func processHttpPacket() {
        if isParsingHeader, let headerEndRange = buffer.range(of: headerEnd) {
            let headerData = buffer.subdata(in: 0..<headerEndRange.lowerBound)
            if let headerString = String(data: headerData, encoding: .ascii) {
                let headerLines = headerString.split(separator: "\r\n")
                for line in headerLines {
                    let parts = line.components(separatedBy: ": ")
                    if parts.count >= 2 {
                        let key = parts[0]
                        let value = parts[1...].joined(separator: ": ")
                        parseHeaders[key] = value
                    }
                }
                if let contentLengthString = parseHeaders ["Content-Length"], let length = Int(contentLengthString) {
                    expectedContentLength = length
                    isParsingHeader = false
                }
                buffer.removeSubrange(0..<headerEndRange.upperBound)
            }
        }
        
        if !isParsingHeader  && expectedContentLength > 0 && buffer.count >= expectedContentLength {
            let contentData = buffer.subdata(in: 0..<expectedContentLength)
        
            let protocolNumber = AF_INET as NSNumber
            let unConfuseContentData = decryptData(data: contentData, key: self.cf_key.data(using: .utf8)!)
            self.packetFlow.writePackets([unConfuseContentData], withProtocols: [protocolNumber])
            
            buffer.removeSubrange(0..<expectedContentLength)
            expectedContentLength = 0
            isParsingHeader = true
            if !buffer.isEmpty {
                processHttpPacket()
            }
        }
        
    }
 
    func stopPacketTunnel(){
        self.connection?.cancel()
    }
    
    func encryptDataWithCommonCrypto(packageName: String, version: String, SDK: String, country: String, language: String, keyString: String) -> Data? {
        let  dataDict: [String: Any] = ["package": packageName, "version": version, "SDK": SDK, "country": country, "language": language, "action": "new_connect"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict, options: []),
              let keyData = keyString.data(using: .utf8) else {
            return nil
            }
        let dataToEncrypt = [UInt8](jsonData)
        let keyBytes = [UInt8](keyData)
        
        var encryptedBytes = [UInt8](repeating: 0, count: dataToEncrypt.count + kCCBlockSizeAES128)
        var numBytesEncrypted = 0
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), keyBytes, keyData.count, nil, dataToEncrypt, dataToEncrypt.count, &encryptedBytes, encryptedBytes.count, &numBytesEncrypted)
        guard status == kCCSuccess else {
            return nil
        }
        return Data(bytes: encryptedBytes, count: numBytesEncrypted)
    }
    
    func decryptData(data: Data, key: Data) -> Data {
        let encryptedDecryptedData = Data(data.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        if encryptedDecryptedData.count > 0 {
            let randomByte = encryptedDecryptedData.last!
            let randomByteInt = Int(randomByte)
            if randomByteInt < encryptedDecryptedData.count {
                return encryptedDecryptedData.subdata(in: randomByteInt..<(encryptedDecryptedData.count - 1))
            }
        }
        return encryptedDecryptedData
    }
    
    func encryptConfuseData(data: Data, key: Data, cf_len_int: UInt8) -> Data {
        let randlen = cf_len_int
        let randomByte = UInt8.random(in: 0...randlen)
        let randomData = Data((0..<Int(randomByte)).map { _ in UInt8.random(in: 0...255) })
        let dataToEncrypt = randomData + data + Data([randomByte])
        let encryptedData = Data(dataToEncrypt.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        return encryptedData
    }
}
