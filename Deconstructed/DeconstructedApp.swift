//
//  DeconstructedApp.swift
//  Deconstructed
//
//  Created by Cristian Díaz on 26.01.26.
//

import SwiftUI

@main
struct DeconstructedApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: DeconstructedDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
