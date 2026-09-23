//
//  ContentView.swift
//  NewVPN
//
//  主界面占位
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("侧边导航")
        } detail: {
            VStack(spacing: 16) {
                Image(systemName: "network")
                    .font(.largeTitle)
                Text("NewVPN")
                    .font(.title)
                Text("iOS 原生代理客户端")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("主控首页")
        }
    }
}

#Preview {
    ContentView()
}
