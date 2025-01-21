//
//  VLESSProtocol.swift
//  vpnswiftui
//
//  Created by ellkaden on 14.01.2025.
//

import Foundation
import Network
import NetworkExtension

enum VLESSError: Error {
    case invalidConfiguration
    case connectionFailed
    case invalidResponse
}

struct VLESSConfiguration {
    let uuid: String
    let serverAddress: String
    let port: Int
    let path: String
    let wsHost: String
    
    static func parse(from urlString: String) throws -> VLESSConfiguration {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host,
              let uuid = components.user else {
            throw VPNError.invalidConfiguration
        }
        
        let port = components.port ?? 443
        let path = components.queryItems?.first(where: { $0.name == "path" })?.value ?? "/"
        let wsHost = components.queryItems?.first(where: { $0.name == "host" })?.value ?? host
        
        return VLESSConfiguration(
            uuid: uuid,
            serverAddress: host,
            port: port,
            path: path,
            wsHost: wsHost
        )
    }
}
