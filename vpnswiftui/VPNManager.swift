//
//  VPNManager.swift
//  vpnswiftui
//
//  Created by ellkaden on 14.01.2025.
//

import UIKit
import NetworkExtension
import Network

enum VPNError: Error {
    case invalidConfiguration
    case loadPreferencesFailed
    case savePreferencesFailed
    case startTunnelFailed
}
 
class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .disconnected
    @Published private(set) var lastError: String?
    private let vpnManager = NEVPNManager.shared()
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVPNStatusChange),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        
        status = vpnManager.connection.status
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupVPNTunnel(configURL: String) {
        print("Setting up VPN tunnel...")
        
        vpnManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.lastError = "Failed to load preferences: \(error.localizedDescription)"
                return
            }
            
            guard let url = URL(string: configURL),
                  let components = URLComponents(string: configURL) else {
                self.lastError = "Invalid configuration URL"
                return
            }
            
            // IKEv2
            let protocolConfig = NEVPNProtocolIKEv2()
            
            protocolConfig.username = url.user ?? ""
            protocolConfig.remoteIdentifier = url.host
            protocolConfig.serverAddress = url.host ?? ""
            
            // Auth method
            protocolConfig.authenticationMethod = .none
            protocolConfig.useExtendedAuthentication = true
            
            // IKE
            protocolConfig.ikeSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
            protocolConfig.ikeSecurityAssociationParameters.integrityAlgorithm = .SHA384
            protocolConfig.ikeSecurityAssociationParameters.diffieHellmanGroup = .group20
            protocolConfig.ikeSecurityAssociationParameters.lifetimeMinutes = 1440
            
            protocolConfig.childSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
            protocolConfig.childSecurityAssociationParameters.integrityAlgorithm = .SHA384
            protocolConfig.childSecurityAssociationParameters.diffieHellmanGroup = .group20
            protocolConfig.childSecurityAssociationParameters.lifetimeMinutes = 1440
            
            var providerConfig: [String: Any] = [
                "serverAddress": url.host ?? "",
                "serverPort": url.port ?? 80,
                "uuid": url.user ?? ""
            ]
            
            if let queryItems = components.queryItems {
                for item in queryItems {
                    providerConfig[item.name] = item.value
                }
            }
            
            print("Final configuration:")
            providerConfig.forEach { key, value in
                print("- \(key): \(value)")
            }
            
            // VPN connection
            self.vpnManager.protocolConfiguration = protocolConfig
            self.vpnManager.localizedDescription = "VLESS VPN"
            self.vpnManager.isEnabled = true
            
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            self.vpnManager.onDemandRules = [connectRule]
            
            self.vpnManager.saveToPreferences { error in
                if let error = error {
                    self.lastError = "Failed to save preferences: \(error.localizedDescription)"
                    print("❌ Save error: \(error.localizedDescription)")
                    return
                }
                
                print("✅ Preferences saved successfully")
                
                do {
                    try self.vpnManager.connection.startVPNTunnel()
                    print("✅ VPN tunnel started")
                } catch {
                    self.lastError = "Failed to start VPN tunnel: \(error.localizedDescription)"
                    print("❌ Start tunnel error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func connect(withConfig configURL: String) {
        print("Validating configuration...")
        
        guard let url = URL(string: configURL) else {
            self.lastError = "Invalid configuration URL format"
            return
        }
        
        guard let host = url.host,
              let scheme = url.scheme,
              scheme == "vless" else {
            self.lastError = "Missing or invalid URL components"
            return
        }
        
        
        checkServerConnectionNW(host: host, port: UInt16(url.port ?? 80)) { isReachable in
            if !isReachable {
                DispatchQueue.main.async {
                    self.lastError = "Server unreachable"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.setupVPNTunnel(configURL: configURL)
            }
        }
    }
    
    private func checkServerConnectionNW(host: String, port: UInt16, completion: @escaping (Bool) -> Void) {
        print(" Checking server connection using Network framework...")
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)
        
        var didComplete = false
        
        connection.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                guard !didComplete else { return }
                
                switch state {
                case .ready:
                    print("✅ Server connection successful")
                    didComplete = true
                    connection.cancel()
                    completion(true)
                case .failed(let error):
                    print("❌ Server connection failed: \(error)")
                    didComplete = true
                    connection.cancel()
                    completion(false)
                case .cancelled:
                    if !didComplete {
                        didComplete = true
                        completion(false)
                    }
                default:
                    break
                }
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
            DispatchQueue.main.async {
                guard !didComplete else { return }
                print("Connection attempt timed out")
                didComplete = true
                connection.cancel()
                completion(false)
            }
        }
        
        connection.start(queue: .global())
    }
    
    func disconnect() {
        vpnManager.connection.stopVPNTunnel()
    }
    
    @objc private func handleVPNStatusChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        DispatchQueue.main.async {
            self.status = connection.status
            print("VPN Status changed to: \(connection.status)")
        }
    }
}


