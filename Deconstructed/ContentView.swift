//
//  ContentView.swift
//  Deconstructed
//
//  Created by Cristian Díaz on 26.01.26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: DeconstructedDocument

    var body: some View {
        NavigationSplitView {
            // Sidebar - bundle structure
            List {
                if let contents = document.bundle.fileWrappers {
                    ForEach(contents.keys.sorted(), id: \.self) { key in
                        if let wrapper = contents[key] {
                            FileWrapperRow(name: key, wrapper: wrapper)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            // Main content area
            VStack(spacing: 16) {
                if let projectData = document.parsedProjectData {
                    GroupBox("Project Info") {
                        LabeledContent("Project ID", value: String(projectData.projectID))
                        LabeledContent("Scenes", value: "\(projectData.pathsToIds.count)")
                    }

                    if !projectData.pathsToIds.isEmpty {
                        GroupBox("Scene Paths") {
                            ForEach(Array(projectData.pathsToIds.keys.sorted()), id: \.self) { path in
                                LabeledContent(path, value: projectData.pathsToIds[path] ?? "")
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Project Data",
                        systemImage: "doc.questionmark",
                        description: Text("Could not parse ProjectData/main.json")
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct FileWrapperRow: View {
    let name: String
    let wrapper: FileWrapper

    var body: some View {
        if wrapper.isDirectory {
            DisclosureGroup {
                if let children = wrapper.fileWrappers {
                    ForEach(children.keys.sorted(), id: \.self) { childKey in
                        if let child = children[childKey] {
                            FileWrapperRow(name: childKey, wrapper: child)
                        }
                    }
                }
            } label: {
                Label(name, systemImage: folderIcon)
            }
        } else {
            Label(name, systemImage: fileIcon)
                .foregroundStyle(.secondary)
        }
    }

    private var folderIcon: String {
        if name.hasSuffix(".rkassets") {
            return "cube.fill"
        } else if name.hasSuffix(".realitycomposerpro") {
            return "shippingbox.fill"
        }
        return "folder.fill"
    }

    private var fileIcon: String {
        if name.hasSuffix(".json") || name.hasSuffix(".rcprojectdata") {
            return "doc.text.fill"
        } else if name.hasSuffix(".swift") {
            return "swift"
        } else if name.hasSuffix(".usda") || name.hasSuffix(".usd") {
            return "cube.transparent"
        }
        return "doc.fill"
    }
}

#Preview {
    ContentView(document: .constant(DeconstructedDocument()))
}
