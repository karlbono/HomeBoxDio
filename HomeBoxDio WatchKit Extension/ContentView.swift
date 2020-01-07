//
//  ContentView.swift
//  HomeBoxDio WatchKit Extension
//
//  Created by Karl Bono on 07/01/2020.
//  Copyright © 2020 Karl Bono. All rights reserved.
//

import SwiftUI
import Combine

struct RoomsView: View {
    @EnvironmentObject private var homeBox: HomeBox
    
    var body: some View {
            List {
                ForEach(homeBox.allRooms) { room in
                    NavigationLink(destination: DevicesView(room: room)) {
                        Text(room.name ?? "No Name")
                    }
                }
            }
    }
}

struct DevicesView: View {
    @EnvironmentObject private var homeBox: HomeBox
    var room: HomeBoxRoom
    
    var body: some View {
        List {
            ForEach(self.homeBox.allDevices) { device in
                if device.roomID == self.room.id {
                    NavigationLink(destination: OnOffView(room: self.room, device: device)) {
                    Text(device.name)
                    }
                }
            }
        }
    }
}

struct OnOffView: View {
    @EnvironmentObject private var homeBox: HomeBox
    var room: HomeBoxRoom
    var device: HomeBoxDevice
    
    var body: some View {
        VStack {
            Text(room.name ?? "No Name")
                .font(.system(size: 24))
            Text(device.name)
            HStack {
                Button(action: {self.homeBox.sendCommandTo(deviceID: self.device.deviceData["id"], command: "1")}) {
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                Button(action: {self.homeBox.sendCommandTo(deviceID: self.device.deviceData["id"], command: "2")}) {
                Image(systemName: "bolt.slash.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Color.red)
                    .cornerRadius(10)
                }
            }
        }
    }
}



struct ContentView: View {
    @ObservedObject private var homeBox = HomeBox()
    
    init() {
        self.homeBox.ipAddress = "192.168.123.13"
    }
    
    var body: some View {
        VStack {
            Text(homeBox.name)
            RoomsView()
            .environmentObject(homeBox)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
