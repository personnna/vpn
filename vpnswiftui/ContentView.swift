//
//  ContentView.swift
//  vpnswiftui
//
//  Created by ellkaden on 14.01.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vpnManager = VPNManager()
    @State private var isConnecting = false
    
    private let vlessURL = "vless://iD--V2RAXX@fastlyipcloudflaretamiz.fast.hosting-ip.com:80/?type=ws&encryption=none&host=V2RAXX.IR&path=%2FTelegram%2CV2RAXX%2CTelegram%2CV2RAXX%3Fed%3D443#United States%20473%20/%20VlessKey.com%20/%20t.me/VlessVpnFree"
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Color.clear
                .overlay(
                    Image("worldMap")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .opacity(0.2)
                        .blur(radius: 1)
                )
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("VPN Status")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut, value: vpnManager.status)
                        
                        Text(statusText)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                }
                .padding(.top, 50)
                
                Spacer()
                
                Button(action: toggleConnection) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 160, height: 160)
                            .blur(radius: 20)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [statusColor.opacity(0.8), statusColor.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: statusColor.opacity(0.5), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "power")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Spacer()
                
                VStack(spacing: 15) {
                    Text("United States")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkerboard")
                            .foregroundColor(.green)
                        Text("Protected")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 30)
            }
            .padding()
        }
    }
    
    private var statusColor: Color {
        switch vpnManager.status {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        default:
            return .red
        }
    }
    
    private var statusText: String {
        switch vpnManager.status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnecting:
            return "Disconnecting..."
        default:
            return "Disconnected"
        }
    }
    
    private func toggleConnection() {
        if vpnManager.status == .connected {
            vpnManager.disconnect()
        } else {
            vpnManager.connect(withConfig: vlessURL)
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
