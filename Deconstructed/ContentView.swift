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
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(DeconstructedDocument()))
}
