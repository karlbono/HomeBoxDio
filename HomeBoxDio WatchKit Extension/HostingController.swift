//
//  HostingController.swift
//  HomeBoxDio WatchKit Extension
//
//  Created by Karl Bono on 07/01/2020.
//  Copyright © 2020 Karl Bono. All rights reserved.
//

import WatchKit
import Foundation
import SwiftUI

class HostingController: WKHostingController<ContentView> {
    override var body: ContentView {
        //return AnyView(ContentView().environmentObject(HomeBox()))
        return ContentView()
    }
}
