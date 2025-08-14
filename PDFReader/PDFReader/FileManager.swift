import Foundation
import UIKit
import PDFKit

class PDFFileManager: ObservableObject {
    @Published var pdfFiles: [PDFFile] = []
    @Published var currentPDF: PDFFile?
    @Published var isLoading = false
    
    init() {
        loadPDFFiles()
    }
    
    func loadPDFFiles() {
        isLoading = true
        
        // Зареждаме PDF файлове от Documents директорията
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let pdfURLs = fileURLs.filter { $0.pathExtension.lowercased() == "pdf" }
            
            pdfFiles = pdfURLs.map { url in
                PDFFile(url: url, name: url.lastPathComponent)
            }
        } catch {
            print("Грешка при зареждане на PDF файлове: \(error)")
        }
        
        isLoading = false
    }
    
    func importPDF(from url: URL) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            loadPDFFiles()
        } catch {
            print("Грешка при импортиране на PDF: \(error)")
        }
    }
    
    func deletePDF(_ pdfFile: PDFFile) {
        do {
            try FileManager.default.removeItem(at: pdfFile.url)
            loadPDFFiles()
        } catch {
            print("Грешка при изтриване на PDF: \(error)")
        }
    }
    
    func selectPDF(_ pdfFile: PDFFile) {
        currentPDF = pdfFile
    }
}

struct PDFFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    
    var document: PDFDocument? {
        return PDFDocument(url: url)
    }
    
    var pageCount: Int {
        return document?.pageCount ?? 0
    }
    
    var fileSize: String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            print("Грешка при получаване на размера на файла: \(error)")
        }
        return "Неизвестен размер"
    }
    
    var creationDate: Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date
        } catch {
            print("Грешка при получаване на датата на създаване: \(error)")
            return nil
        }
    }
}