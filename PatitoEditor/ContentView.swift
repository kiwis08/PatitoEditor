//
//  ContentView.swift
//  PatitoEditor
//
//  Created by Santiago Quihui on 03/12/25.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct ContentView: View {
    @State private var sourceCode: String = ""
    @State private var outputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var currentFilePath: URL?
    @State private var showingSaveDialog = false
    @State private var showingOpenDialog = false
    @State private var documentToExport: PatitoDocument?
    
    private var backgroundColorView: some View {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .textBackgroundColor)
        #endif
    }
    
    var body: some View {
        HSplitView {
            // Editor Area
            VStack(alignment: .leading, spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    // File Operations Group
                    HStack(spacing: 8) {
                        Button(action: openFile) {
                            Label("Open", systemImage: "doc.text")
                        }
                        .buttonStyle(ToolbarButtonStyle())
                        
                        Button(action: saveFile) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(ToolbarButtonStyle())
                        .disabled(sourceCode.isEmpty)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // File Info
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(currentFilePath?.lastPathComponent ?? "Untitled.patito")
                            .font(.system(.body, design: .monospaced, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.tint.opacity(0.1))
                    )
                    
                    Spacer()
                    
                    // Compilation Actions Group
                    HStack(spacing: 8) {
                        Button(action: compile) {
                            HStack(spacing: 6) {
                                if isProcessing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "hammer.fill")
                                }
                                Text("Compile")
                            }
                        }
                        .buttonStyle(ActionButtonStyle(color: .orange))
                        .disabled(sourceCode.isEmpty || isProcessing)
                        
                        Button(action: compileAndRun) {
                            HStack(spacing: 6) {
                                if isProcessing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text("Run")
                            }
                        }
                        .buttonStyle(ActionButtonStyle(color: .green))
                        .disabled(sourceCode.isEmpty || isProcessing)
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                
                Divider()
                
                // Code Editor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $sourceCode)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(16)
                    
                    if sourceCode.isEmpty {
                        Text("// Start coding in Patito...")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(24)
                            .allowsHitTesting(false)
                    }
                }
                .background(backgroundColorView)
            }
            .frame(minWidth: 450)
            
            // Output Area
            VStack(alignment: .leading, spacing: 0) {
                // Output Header
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Console Output")
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    if !outputText.isEmpty {
                        Text("\(outputText.components(separatedBy: "\n").count) lines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: clearOutput) {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    .disabled(outputText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                
                Divider()
                
                // Output Content
                ScrollView {
                    if outputText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            
                            Text("No output yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("Compile or run your code to see results")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        AttributedOutputText(text: outputText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
                .background(backgroundColorView)
            }
            .frame(minWidth: 350)
        }
        .fileImporter(
            isPresented: $showingOpenDialog,
            allowedContentTypes: PatitoDocument.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .fileExporter(
            isPresented: $showingSaveDialog,
            document: documentToExport,
            contentType: .plainText,
            defaultFilename: "Untitled.patito"
        ) { result in
            handleFileExport(result)
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
    
    private func handleFileExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            currentFilePath = url
            appendOutput("✓ Saved: \(url.lastPathComponent)")
        case .failure(let error):
            appendOutput("✗ Error saving file: \(error.localizedDescription)")
        }
        documentToExport = nil
    }
    
    private func saveFile() {
        documentToExport = PatitoDocument(content: sourceCode)
        showingSaveDialog = true
    }
    
    private func saveFileAs() {
        documentToExport = PatitoDocument(content: sourceCode)
        showingSaveDialog = true
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

// MARK: - Custom Button Styles

struct PatitoDocument: FileDocument {
    static private let patitoFileType = UTType(filenameExtension: "patito", conformingTo: .data)!
    static var readableContentTypes: [UTType] { [.plainText, patitoFileType] }
    
    var content: String
    
    init(content: String = "") {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            content = string
        } else {
            content = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(configuration.isPressed ? 0.3 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(color.opacity(0.4), lineWidth: 1)
            )
            .foregroundStyle(color)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Attributed Output Text View

struct AttributedOutputText: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 8) {
                    // Line number indicator (optional, only for output sections)
                    if line.hasPrefix("---") {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tint)
                            .padding(.top, 4)
                    } else if !line.isEmpty {
                        Circle()
                            .fill(lineColor(for: line))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                    }
                    
                    Text(line.isEmpty ? " " : line)
                        .font(.system(size: 13, weight: lineWeight(for: line), design: .monospaced))
                        .foregroundStyle(lineColor(for: line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func lineColor(for line: String) -> Color {
        if line.hasPrefix("✓") {
            return .green
        } else if line.hasPrefix("✗") || line.contains("failed") || line.contains("Error") {
            return .red
        } else if line.hasPrefix("---") {
            return .blue
        } else {
            return .primary
        }
    }
    
    private func lineWeight(for line: String) -> Font.Weight {
        if line.hasPrefix("✓") || line.hasPrefix("✗") || line.hasPrefix("---") {
            return .semibold
        } else {
            return .regular
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 600)
}
