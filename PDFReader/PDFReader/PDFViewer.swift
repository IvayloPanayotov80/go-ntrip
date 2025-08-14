import SwiftUI
import PDFKit

struct PDFViewer: UIViewRepresentable {
    let pdfFile: PDFFile
    @ObservedObject var ttsManager: TextToSpeechManager
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true)
        pdfView.delegate = context.coordinator
        
        if let document = pdfFile.document {
            pdfView.document = document
            totalPages = document.pageCount
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = pdfFile.document {
            pdfView.document = document
            totalPages = document.pageCount
            
            // Отиваме на текущата страница
            if currentPage > 0 && currentPage <= document.pageCount {
                if let page = document.page(at: currentPage - 1) {
                    pdfView.go(to: page)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        let parent: PDFViewer
        
        init(_ parent: PDFViewer) {
            self.parent = parent
        }
        
        func pdfViewPageChanged(_ pdfView: PDFView) {
            if let currentPage = pdfView.currentPage,
               let document = pdfView.document {
                let pageIndex = document.index(for: currentPage)
                parent.currentPage = pageIndex + 1
                
                // Извличаме текста от текущата страница
                let extractedText = extractTextFromPage(currentPage)
                if !extractedText.isEmpty {
                    // Можем да запазим текста за четене
                    print("Извлечен текст от страница \(parent.currentPage): \(extractedText)")
                }
            }
        }
        
        private func extractTextFromPage(_ page: PDFPage) -> String {
            // Опитваме се да извлечем текста директно
            if let pageContent = page.string, !pageContent.isEmpty {
                return pageContent
            }
            
            // Ако няма директен текст, опитваме се да извлечем от annotations
            var extractedText = ""
            
            if let annotations = page.annotations {
                for annotation in annotations {
                    if let annotationText = annotation.contents, !annotationText.isEmpty {
                        extractedText += annotationText + " "
                    }
                }
            }
            
            // Ако все още няма текст, връщаме placeholder
            if extractedText.isEmpty {
                extractedText = "Текстът на тази страница не може да бъде извлечен автоматично. Можете да използвате OCR функционалността за сканирани документи."
            }
            
            return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

struct PDFViewerContainer: View {
    let pdfFile: PDFFile
    @StateObject private var ttsManager = TextToSpeechManager()
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var showingControls = false
    @State private var extractedText = ""
    
    var body: some View {
        ZStack {
            PDFViewer(
                pdfFile: pdfFile,
                ttsManager: ttsManager,
                currentPage: $currentPage,
                totalPages: $totalPages
            )
            .onTapGesture {
                withAnimation {
                    showingControls.toggle()
                }
            }
            
            if showingControls {
                VStack {
                    Spacer()
                    
                    // Контроли за четене
                    HStack(spacing: 20) {
                        Button(action: {
                            if ttsManager.isSpeaking {
                                ttsManager.stopSpeaking()
                            } else {
                                // Извличаме текста от текущата страница
                                if let document = pdfFile.document,
                                   let page = document.page(at: currentPage - 1) {
                                    let text = page.string ?? "Няма текст на тази страница."
                                    ttsManager.speak(text)
                                }
                            }
                        }) {
                            Image(systemName: ttsManager.isSpeaking ? "stop.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            if ttsManager.isSpeaking {
                                ttsManager.pauseSpeaking()
                            } else {
                                ttsManager.continueSpeaking()
                            }
                        }) {
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                        .disabled(!ttsManager.isSpeaking)
                        
                        // Навигация между страници
                        HStack(spacing: 10) {
                            Button(action: {
                                if currentPage > 1 {
                                    currentPage -= 1
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray)
                                    .clipShape(Circle())
                            }
                            .disabled(currentPage <= 1)
                            
                            Text("\(currentPage) / \(totalPages)")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.horizontal, 10)
                            
                            Button(action: {
                                if currentPage < totalPages {
                                    currentPage += 1
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray)
                                    .clipShape(Circle())
                            }
                            .disabled(currentPage >= totalPages)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(15)
                    .padding(.bottom, 50)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(pdfFile.name)
        .onAppear {
            // Зареждаме първата страница
            if let document = pdfFile.document {
                totalPages = document.pageCount
                currentPage = 1
            }
        }
    }
}