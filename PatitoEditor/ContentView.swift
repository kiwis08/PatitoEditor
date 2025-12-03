//
//  ContentView.swift
//  PatitoEditor
//
//  Created by Santiago Quihui on 03/12/25.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct ContentView: View {
    let patitoFileType = UTType(filenameExtension: "patito", conformingTo: .data)!
    
    @State private var sourceCode: String = ""
    @State private var outputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var currentFilePath: URL?
    @State private var showingSaveDialog = false
    @State private var showingOpenDialog = false
    
    var body: some View {
        HSplitView {
            // Editor Area
            VStack(alignment: .leading, spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: openFile) {
                        Label("Open", systemImage: "doc")
                    }
                    
                    Button(action: saveFile) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(sourceCode.isEmpty)
                    
                    Spacer()
                    
                    Text(currentFilePath?.lastPathComponent ?? "Untitled.patito")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: compile) {
                        Label("Compile", systemImage: "hammer")
                    }
                    .disabled(sourceCode.isEmpty || isProcessing)
                    
                    Button(action: compileAndRun) {
                        Label("Compile & Run", systemImage: "play.fill")
                    }
                    .disabled(sourceCode.isEmpty || isProcessing)
                    .keyboardShortcut("r", modifiers: .command)
                }
                .padding()
                .background(.background.opacity(0.8))
                
                Divider()
                
                // Code Editor
                TextEditor(text: $sourceCode)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
            }
            .frame(minWidth: 400)
            
            // Output Area
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Output")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: clearOutput) {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(outputText.isEmpty)
                }
                .padding()
                .background(.background.opacity(0.8))
                
                Divider()
                
                ScrollView {
                    Text(outputText.isEmpty ? "Output will appear here..." : outputText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(outputText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
            .frame(minWidth: 300)
        }
        .fileImporter(
            isPresented: $showingOpenDialog,
            allowedContentTypes: [patitoFileType],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .fileDialogMessage("Select a .patito file")
    }
    
    // MARK: - File Operations
    
    private func openFile() {
        showingOpenDialog = true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Request security-scoped access to the file
            guard url.startAccessingSecurityScopedResource() else {
                appendOutput("✗ Error: Unable to access file")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                sourceCode = content
                currentFilePath = url
                appendOutput("✓ Opened: \(url.lastPathComponent)")
            } catch {
                appendOutput("✗ Error opening file: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            appendOutput("✗ Error: \(error.localizedDescription)")
        }
    }
    
    private func saveFile() {
        if let url = currentFilePath {
            saveToURL(url)
        } else {
            saveFileAs()
        }
    }
    
    private func saveFileAs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "Untitled.patito"
        savePanel.message = "Save your Patito source code"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                saveToURL(url)
                currentFilePath = url
            }
        }
    }
    
    private func saveToURL(_ url: URL) {
        // Request security-scoped access if this is from a previous file open
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            try sourceCode.write(to: url, atomically: true, encoding: .utf8)
            appendOutput("✓ Saved: \(url.lastPathComponent)")
        } catch {
            appendOutput("✗ Error saving file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Compilation
    
    private func compile() {
        Task {
            clearOutput()
            await performCompilation(andRun: false)
        }
    }
    
    private func compileAndRun() {
        Task {
            clearOutput()
            await performCompilation(andRun: true)
        }
    }
    
    @MainActor
    private func performCompilation(andRun: Bool) async {
        isProcessing = true
        
        // Save source code to temporary file
        let tempSourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("temp_\(UUID().uuidString).patito")
        
        let compiledURL = tempSourceURL
            .deletingPathExtension()
            .appendingPathExtension("patitoc")
        
        do {
            try sourceCode.write(to: tempSourceURL, atomically: true, encoding: .utf8)
            
            appendOutput("\n--- Compiling ---")
            
            // Get the compiler path
            guard let compilerPath = Bundle.main.path(forResource: "PatitoCompiler", ofType: nil) else {
                appendOutput("✗ Error: PatitoCompiler not found in bundle")
                isProcessing = false
                return
            }
            
            // Run compiler
            let compileResult = await runProcess(
                executablePath: compilerPath,
                arguments: [tempSourceURL.path, "-c"]
            )
            
            if !compileResult.output.isEmpty {
                appendOutput(compileResult.output)
            }
            
            if compileResult.exitCode != 0 {
                appendOutput("✗ Compilation failed with exit code \(compileResult.exitCode)")
                isProcessing = false
                return
            }
            
            appendOutput("✓ Compilation successful!")
            
            // If compile and run, execute with VM
            if andRun {
                appendOutput("\n--- Running ---")
                
                guard let vmPath = Bundle.main.path(forResource: "PVM", ofType: nil) else {
                    appendOutput("✗ Error: PVM not found in bundle")
                    isProcessing = false
                    return
                }
                
                let runResult = await runProcess(
                    executablePath: vmPath,
                    arguments: [compiledURL.path]
                )
                
                if !runResult.output.isEmpty {
                    appendOutput(runResult.output)
                }
                
                if runResult.exitCode != 0 {
                    appendOutput("✗ Execution failed with exit code \(runResult.exitCode)")
                } else {
                    appendOutput("✓ Execution completed successfully")
                }
            }
            
            // Clean up temporary files
            try? FileManager.default.removeItem(at: tempSourceURL)
            try? FileManager.default.removeItem(at: compiledURL)
            
        } catch {
            appendOutput("✗ Error: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
    
    private func runProcess(executablePath: String, arguments: [String]) async -> (output: String, exitCode: Int32) {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            var outputData = Data()
            var errorData = Data()
            
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                outputData.append(handle.availableData)
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                errorData.append(handle.availableData)
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // Close the handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                var combinedOutput = ""
                
                if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                    combinedOutput += output
                }
                
                if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
                    if !combinedOutput.isEmpty {
                        combinedOutput += "\n"
                    }
                    combinedOutput += error
                }
                
                continuation.resume(returning: (combinedOutput, process.terminationStatus))
            } catch {
                continuation.resume(returning: ("Error running process: \(error.localizedDescription)", -1))
            }
        }
    }
    
    // MARK: - Output Management
    
    private func appendOutput(_ text: String) {
        if outputText.isEmpty {
            outputText = text
        } else {
            outputText += "\n" + text
        }
    }
    
    private func clearOutput() {
        outputText = ""
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 600)
}
