import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
	@Binding var document: PDFDocument?
	@Binding var currentPageIndex: Int
	var onPageChanged: ((Int) -> Void)?

	class Coordinator: NSObject, PDFViewDelegate {
		var parent: PDFKitView
		init(parent: PDFKitView) { self.parent = parent }

		func pdfViewPageChanged(_ pdfView: PDFView) {
			guard let page = pdfView.currentPage,
				  let doc = pdfView.document else { return }
			let index = doc.index(for: page)
			if parent.currentPageIndex != index {
				DispatchQueue.main.async {
					self.parent.currentPageIndex = index
					self.parent.onPageChanged?(index)
				}
			}
		}
	}

	func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

	func makeUIView(context: Context) -> PDFView {
		let pdfView = PDFView()
		pdfView.autoScales = true
		pdfView.displayMode = .singlePageContinuous
		pdfView.displayDirection = .vertical
		pdfView.displaysAsBook = false
		pdfView.backgroundColor = .systemBackground
		pdfView.delegate = context.coordinator
		return pdfView
	}

	func updateUIView(_ pdfView: PDFView, context: Context) {
		pdfView.document = document
		guard let doc = document,
			  currentPageIndex >= 0,
			  currentPageIndex < doc.pageCount,
			  let page = doc.page(at: currentPageIndex) else { return }
		pdfView.go(to: page)
	}
}