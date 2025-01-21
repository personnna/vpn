//
//  PacketTunnelProvider.swift
//  vpnswiftui
//
//  Created by ellkaden on 14.01.2025.
//

import UIKit
import NetworkExtension
import Network
import Security

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var connection: NWConnection?
    private var vlessConfig: VLESSConfiguration?
    
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let configString = options?["config"] as? String,
              let config = try? VLESSConfiguration.parse(from: configString) else {
            completionHandler(VLESSError.invalidConfiguration)
            return
        }
        
        vlessConfig = config
        setupTunnel(completionHandler: completionHandler)
    }
    
    private func setupTunnel(completionHandler: @escaping (Error?) -> Void) {
        guard let config = vlessConfig else {
            completionHandler(VLESSError.invalidConfiguration)
            return
        }
        
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: config.serverAddress)
        tunnelNetworkSettings.mtu = 1500
        
        let ipv4Settings = NEIPv4Settings(addresses: ["192.168.1.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelNetworkSettings.ipv4Settings = ipv4Settings
        
        tunnelNetworkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { error in
            if let error = error {
                completionHandler(error)
                return
            }
            
            self.establishVLESSConnection(config: config, completionHandler: completionHandler)
        }
    }
    
    private func establishVLESSConnection(config: VLESSConfiguration, completionHandler: @escaping (Error?) -> Void) {
//        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(config.serverAddress),
//                                                 port: NWEndpoint.Port(integerLiteral: UInt16(config.port)))
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(config.serverAddress),
                                                 port: NWEndpoint.Port(integerLiteral: UInt16(config.port)))
                
        let parameters = NWParameters.tls
        
        let tlsOptions = NWProtocolTLS.Options()
                
        if #available(iOS 14.0, *) {
            sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, _, completionHandler in
                completionHandler(true)
            }, .main)
        }
        
        // ws
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        wsOptions.setAdditionalHeaders([
            ("Host", config.wsHost),
            ("User-Agent", "Mozilla/5.0"),
            ("Upgrade", "websocket"),
            ("Connection", "Upgrade")
        ])
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.handleConnectionReady(completionHandler: completionHandler)
            case .failed(let error):
                completionHandler(error)
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
    }
    
    
    private func handleConnectionReady(completionHandler: @escaping (Error?) -> Void) {
        guard let config = vlessConfig else { return }
        
        var header = Data()
        
        if let uuid = UUID(uuidString: config.uuid) {
                    withUnsafeBytes(of: uuid.uuid) { buffer in
                        header.append(contentsOf: buffer)
                    }
                }
        
        header.append(contentsOf: [0x00])
        header.append(contentsOf: [0x00])
        
        connection?.send(content: header, completion: .contentProcessed { error in
            if let error = error {
                completionHandler(error)
                return
            }
            
            completionHandler(nil)
            self.startReading()
        })
    }
    
    private func startReading() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] content, _, isComplete, error in
            if let error = error {
                self?.handleError(error)
                return
            }
            
            if let data = content {
                self?.handleIncomingData(data)
            }
            
            if !isComplete {
                self?.startReading()
            }
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
    }
    
    private func handleError(_ error: Error) {
        cancelTunnelWithError(error)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        connection?.cancel()
        completionHandler()
    }
    
}
