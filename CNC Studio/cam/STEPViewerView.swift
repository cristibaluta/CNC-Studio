//
//  STEPViewerView.swift
//  MakeraStudio Lite
//
//  Created by Cristian Baluta on 19.08.2026.
//

//import SwiftUI
//import UniformTypeIdentifiers
//
//import OCCTSwift
////import OCCTSwiftIO
////import OCCTSwiftViewport
////import OCCTSwiftTools
//
//#if os(macOS)
//import AppKit
//#endif
//
//struct STEPViewerView: View {
//
//    @State private var document: Document?
//    @State private var modelURL: URL?
//    @State private var errorMessage: String?
//    @State private var isOpening = false
//
//    var body: some View {
//        VStack(spacing: 0) {
//
//            toolbar
//
//            Divider()
//
//            ZStack {
//                if document != nil {
//                    modelPlaceholder
//                } else {
//                    emptyState
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//        .frame(minWidth: 900, minHeight: 650)
//        .fileImporter(
//            isPresented: $isOpening,
//            allowedContentTypes: [
//                .init(filenameExtension: "step")!,
//                .init(filenameExtension: "stp")!
//            ],
//            allowsMultipleSelection: false
//        ) { result in
//            openResult(result)
//        }
//    }
//
//    // MARK: - Toolbar
//
//    private var toolbar: some View {
//        HStack(spacing: 10) {
//
//            Button {
//                isOpening = true
//            } label: {
//                Label("Open STEP", systemImage: "folder")
//            }
//
//            if let modelURL {
//                Text(modelURL.lastPathComponent)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//                    .lineLimit(1)
//            }
//
//            Spacer()
//
//            if let document {
//                Text("\(document.rootNodes.count) part(s)")
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
//        }
//        .padding(10)
//    }
//
//    // MARK: - Empty State
//
//    private var emptyState: some View {
//        VStack(spacing: 12) {
//            Image(systemName: "cube.transparent")
//                .font(.system(size: 48))
//                .foregroundStyle(.secondary)
//
//            Text("No STEP file loaded")
//                .font(.headline)
//
//            Button("Open STEP File") {
//                isOpening = true
//            }
//            .buttonStyle(.borderedProminent)
//
//            if let errorMessage {
//                Text(errorMessage)
//                    .font(.caption)
//                    .foregroundStyle(.red)
//                    .multilineTextAlignment(.center)
//                    .frame(maxWidth: 500)
//            }
//        }
//    }
//
//    // MARK: - Model
//
//    private var modelPlaceholder: some View {
//        VStack(spacing: 12) {
//            Image(systemName: "cube")
//                .font(.system(size: 50))
//
//            Text("STEP loaded")
//                .font(.headline)
//
//            Text(
//                "The OCCT model is loaded.\nNext we'll connect it to OCCTSwiftViewport."
//            )
//            .font(.caption)
//            .foregroundStyle(.secondary)
//            .multilineTextAlignment(.center)
//        }
//    }
//
//    // MARK: - Loading
//
//    private func openResult(
//        _ result: Result<[URL], Error>
//    ) {
//        switch result {
//
//        case .success(let urls):
//            guard let url = urls.first else {
//                return
//            }
//
//            loadSTEP(url)
//
//        case .failure(let error):
//            errorMessage = error.localizedDescription
//        }
//    }
//
//    private func loadSTEP(_ url: URL) {
//
//        errorMessage = nil
//        modelURL = url
//
//        do {
//            document = try Document.load(from: url)
//        } catch {
//            document = nil
//            errorMessage = error.localizedDescription
//        }
//    }
//}
