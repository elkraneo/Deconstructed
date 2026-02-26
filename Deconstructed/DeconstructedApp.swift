//
//  DeconstructedApp.swift
//  Deconstructed
//
//  Created by Cristian Díaz on 26.01.26.
//

import AppKit
import ComposableArchitecture
import DeconstructedClients
import DeconstructedFeatures
import DeconstructedUI
import DeconstructedUSDInterop
import RCPDocument
import SwiftUI

@main
struct DeconstructedApp: App {
	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
	private let appStore = Store(initialState: AppFeature.State()) {
		AppFeature()
	}

	var body: some Scene {
		DocumentGroup(newDocument: DeconstructedDocument()) { file in
			ContentView(document: file.$document)
				.frame(minWidth: 800, minHeight: 600)
				.task(id: file.fileURL) {
					if let url = file.fileURL {
						file.document.documentURL = url
					}
				}
				.toolbar {
					ToolbarItem {
						Button("Add", systemImage: "plus") {}
							.disabled(true)
					}
				}
		}
		.commands {
			CommandGroup(replacing: .newItem) {
				Button("New Project...") {
					createNewProject()
				}
				.keyboardShortcut("n", modifiers: .command)
			}
			CommandMenu("Insert") {
				InsertMenuItems()
			}
			CommandMenu("Viewport") {
				ViewportMenuItems()
			}
		}

		Window("Welcome to Deconstructed", id: "welcome") {
			WelcomeWindowContent(store: appStore)
				.ignoresSafeArea(.all, edges: .top)
		}
		.windowStyle(.hiddenTitleBar)
		.windowResizability(.contentSize)
		.defaultPosition(.center)
		.commandsRemoved()
		.defaultLaunchBehavior(.presented)
	}

	private func createNewProject() {
		Task {
			await NewProjectCreator.shared.createNewProject()
		}
	}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		false
	}
}
