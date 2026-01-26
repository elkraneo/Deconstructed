//
//  DeconstructedApp.swift
//  Deconstructed
//
//  Created by Cristian Díaz on 26.01.26.
//

import SwiftUI

@main
struct DeconstructedApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        DocumentGroup(newDocument: DeconstructedDocument()) { file in
            ContentView(document: file.$document)
                .frame(minWidth: 800, minHeight: 600)
        }

        Window("Welcome to Deconstructed", id: "welcome") {
            WelcomeWindowContent()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()
        .defaultLaunchBehavior(.presented)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Don't auto-create untitled document on launch
        false
    }
}

/// Wrapper to handle document environment actions
struct WelcomeWindowContent: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.newDocument) private var newDocument
    @Environment(\.openDocument) private var openDocument

    var body: some View {
        LaunchExperience(
            onNewProject: {
                dismissWindow(id: "welcome")
                newDocument(DeconstructedDocument())
            },
            onOpenProject: { url in
                dismissWindow(id: "welcome")
                Task {
                    try? await openDocument(at: url)
                }
            }
        )
    }
}
