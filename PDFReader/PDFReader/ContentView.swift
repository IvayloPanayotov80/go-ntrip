import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var fileManager = PDFFileManager()
    @StateObject private var ttsManager = TextToSpeechManager()
    @State private var showingDocumentPicker = false
    @State private var showingSettings = false
    @State private var searchText = ""
    
    var filteredPDFFiles: [PDFFile] {
        if searchText.isEmpty {
            return fileManager.pdfFiles
        } else {
            return fileManager.pdfFiles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if fileManager.isLoading {
                    ProgressView("Зареждане на файлове...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredPDFFiles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(NSLocalizedString("Няма PDF файлове", comment: "No PDF files message"))
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text(NSLocalizedString("Добавете PDF файлове за да започнете четенето", comment: "Add PDF files instruction"))
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingDocumentPicker = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text(NSLocalizedString("Добави PDF", comment: "Add PDF button"))
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredPDFFiles) { pdfFile in
                            PDFFileRow(pdfFile: pdfFile, fileManager: fileManager)
                        }
                        .onDelete(perform: deletePDFFiles)
                    }
                    .searchable(text: $searchText, prompt: NSLocalizedString("Търси PDF файлове", comment: "Search PDF files"))
                }
            }
            .navigationTitle("PDF Четец")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(fileManager: fileManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(ttsManager: ttsManager)
        }
    }
    
    private func deletePDFFiles(offsets: IndexSet) {
        for index in offsets {
            let pdfFile = filteredPDFFiles[index]
            fileManager.deletePDF(pdfFile)
        }
    }
}

struct PDFFileRow: View {
    let pdfFile: PDFFile
    let fileManager: PDFFileManager
    
    var body: some View {
        NavigationLink(destination: PDFViewerContainer(pdfFile: pdfFile)) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pdfFile.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack {
                        Text("\(pdfFile.pageCount) \(NSLocalizedString("страници", comment: "pages"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(pdfFile.fileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let creationDate = pdfFile.creationDate {
                        Text(creationDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let fileManager: PDFFileManager
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                parent.fileManager.importPDF(from: url)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var ttsManager: TextToSpeechManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Гласове") {
                    Picker("Избери глас", selection: $ttsManager.currentVoice) {
                        ForEach(ttsManager.availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))")
                                .tag(voice as AVSpeechSynthesisVoice?)
                        }
                    }
                }
                
                Section("Скорост на четене") {
                    VStack {
                        HStack {
                            Text("Бавно")
                            Spacer()
                            Text("Бързо")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Slider(value: $ttsManager.speechRate, in: 0.1...1.0, step: 0.1)
                    }
                    
                    Text("Скорост: \(String(format: "%.1f", ttsManager.speechRate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Тон") {
                    VStack {
                        HStack {
                            Text("Нисък")
                            Spacer()
                            Text("Висок")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Slider(value: $ttsManager.pitchMultiplier, in: 0.5...2.0, step: 0.1)
                    }
                    
                    Text("Тон: \(String(format: "%.1f", ttsManager.pitchMultiplier))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Сила на звука") {
                    VStack {
                        HStack {
                            Text("Тихо")
                            Spacer()
                            Text("Гласно")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Slider(value: $ttsManager.volume, in: 0.0...1.0, step: 0.1)
                    }
                    
                    Text("Сила: \(String(format: "%.1f", ttsManager.volume))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Тест") {
                    Button("Тествай настройките") {
                        ttsManager.speak("Това е тест на настройките за четене на български език.")
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}