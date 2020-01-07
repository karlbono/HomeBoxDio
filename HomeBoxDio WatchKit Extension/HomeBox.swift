//
//  HomeBox.swift
//  HomeBoxDio WatchKit Extension
//
//  Created by Karl Bono on 07/01/2020.
//  Copyright © 2020 Karl Bono. All rights reserved.
//

import SwiftUI
import Combine

extension Dictionary {
    func percentEscaped() -> String {
        return map { (key, value) in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

struct HomeBoxDevice: Identifiable  {
    var id: Int = 0
    var deviceData: [String:String] = [:]
    var roomID: Int {
        get {
            return Int(deviceData["RAW$rid"] ?? "0") ?? 0
        }
    }
    var name: String {
        get {
            return deviceData["name"] ?? "Unknown device"
        }
    }
    var dimmerValue: Int = 0
}

struct HomeBoxRoom: Identifiable  {
    var id: Int = 0
    var name: String?
}

final class HomeBox: NSObject, ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    var ipAddress: String? {
        didSet {
            self.getAllDevices()
            self.getAllRooms()
            self.getName()
        }
    }
    
    var name : String = ""
    {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    var allDevices: [HomeBoxDevice] = []
    {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    var allRooms: [HomeBoxRoom] = []
    {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func getJSON(sendDo: String?, level: String?, cmd: String? = nil, devid: String? = nil, item: String? = nil, data: String? = nil, onSuccess processData: @escaping (String)->Void) {
        if let ipAddress = ipAddress {
            if let url = URL(string: "http://\(ipAddress)/cgi-bin/api.cgi") {
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpMethod = "POST"
                var parameters: [String: Any] = [:]
                if let sendDo = sendDo {
                    parameters["do"] = sendDo
                }
                if let level = level {
                    parameters["level"] = level
                }
                if let cmd = cmd {
                    parameters["cmd"] = cmd
                }
                if let devid = devid {
                    parameters["devid"] = devid
                }
                if let item = item {
                    parameters["item"] = item
                }
                if let data = data {
                    parameters["data"] = data
                }
                request.httpBody = parameters.percentEscaped().data(using: .utf8)
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data,
                        let response = response as? HTTPURLResponse,
                        error == nil else {                                              // check for fundamental networking error
                            print("error", error ?? "Unknown error")
                            return
                    }
                    
                    guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
                        print("statusCode should be 2xx, but is \(response.statusCode)")
                        print("response = \(response)")
                        return
                    }
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        processData(responseString)
                    }
                }
                
                task.resume()
            }
        }
    }
    
    func getAllDevices() {
        getJSON(sendDo: "getalldev", level: "front") { (response) in
            if let data = response.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                        if let jsonDeviceData = json["data"] as? Dictionary<String,Any> {
                            if let deviceDataString = jsonDeviceData["devices"] as? String {
                                let splits = deviceDataString.split(separator: "|")
                                var keyNames: [String] = []
                                if splits.count > 0 {
                                    // get the names of the keys
                                    let subSplits = splits[0].split(separator: ",")
                                    for keyNameAndType in subSplits {
                                        let index = keyNameAndType.firstIndex(of: ":") ?? keyNameAndType.endIndex
                                        keyNames.append(String(keyNameAndType[..<index]))
                                    }
                                }
                                for splitsIndex in 1..<splits.count {
                                    var device: [String:String] = [:]
                                    let subSplits = splits[splitsIndex].split(separator: ",")
                                    for (index, keyName) in keyNames.enumerated() {
                                        if subSplits.count > index {
                                            let valueForKeyName = String(subSplits[index])
                                            device[keyName] = valueForKeyName
                                            if keyName == "name" {
                                                device[keyName] = valueForKeyName.replacingOccurrences(of: "_", with: " ")
                                            }
                                        }
                                    }
                                    var hbDevice = HomeBoxDevice()
                                    hbDevice.deviceData = device
                                    hbDevice.id = splitsIndex - 1
                                    self.allDevices.append(hbDevice)
                                }
                                //print(self.allDevices)
                            }
                        }
                    }
                } catch let err {
                    print(err.localizedDescription)
                }
            }
        }
    }
    
    func getAllRooms() {
        getJSON(sendDo: "getrooms", level: "front") { (response) in
            if let data = response.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                        if let jsonDeviceData = json["data"] as? Dictionary<String,Any> {
                            if let roomsData = jsonDeviceData["rooms"] as? Array<Dictionary<String,Any>> {
                                for roomData in roomsData {
                                    if let roomID = roomData["rid"] as? Int {
                                        var hbr = HomeBoxRoom()
                                        hbr.id = roomID
                                        hbr.name = roomData["name"] as? String
                                        self.allRooms.append(hbr)
                                    }
                                }
                            }
                        }
                    }
                } catch let err {
                    print(err.localizedDescription)
                }
            }
        }
    }
    
    func getName() {
        getJSON(sendDo: "getconfig", level: "guest", item: "homename") { (response) in
            if let data = response.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                        if let jsonDeviceData = json["data"] as? Dictionary<String,Any> {
                            let nameUnd = jsonDeviceData["homename"] as? String ?? "Unknown Home"
                            self.name = nameUnd.replacingOccurrences(of: "_", with: " ")
                        }
                    }
                } catch let err {
                    print(err.localizedDescription)
                }
            }
        }
    }
    
    func sendCommandTo(deviceID: String?, command: String, data: String? = nil) {
        getJSON(sendDo: "sendcmd", level: "front", cmd: command, devid: deviceID, data: data) { (response) in
            if let data = response.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                        print(json)
                    }
                } catch let err {
                    print(err.localizedDescription)
                }
            }
        }
    }
}

