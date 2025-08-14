import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AVFoundation
import UIKit

struct ContentView: View {
	@StateObject private var viewModel = PDFReaderViewModel()
	@State private var isImporterPresented = false

	var body: some View {
		NavigationView {
			VStack(spacing: 0) {
				if viewModel.document != nil {
					controlsBar
				}

				PDFKitView(document: $viewModel.document, currentPageIndex: $viewModel.currentPageIndex, onPageChanged: { _ in })
					.background(Color(UIColor.systemBackground))

				bottomControls
			}
			.navigationTitle("PDF Четец")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						isImporterPresented = true
					} label: {
						Image(systemName: "folder")
					}
					.accessibilityLabel("Отвори PDF")
				}
			}
		}
		.fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.pdf]) { result in
			switch result {
			case .success(let url):
				let targetURL = copyToDocuments(url: url)
				viewModel.open(url: targetURL ?? url)
			case .failure:
				break
			}
		}
	}

	private var controlsBar: some View {
		HStack {
			Button {
				goToPreviousPage()
			} label: {
				Image(systemName: "chevron.left")
			}
			.disabled(viewModel.currentPageIndex <= 0)

			Text("Стр. \(viewModel.currentPageIndex + 1) / \(viewModel.document?.pageCount ?? 0)")
				.font(.subheadline)
				.frame(maxWidth: .infinity)

			Button {
				goToNextPage()
			} label: {
				Image(systemName: "chevron.right")
			}
			.disabled((viewModel.document?.pageCount ?? 0) == 0 || viewModel.currentPageIndex >= (viewModel.document?.pageCount ?? 1) - 1)
		}
		.padding([.horizontal, .top])
	}

	private var bottomControls: some View {
		VStack(spacing: 12) {
			HStack {
				Button {
					if viewModel.isSpeaking {
						viewModel.pauseOrResume()
					} else {
						viewModel.readFromCurrentPage()
					}
				} label: {
					Image(systemName: viewModel.isSpeaking ? (viewModel.isPaused ? "play.fill" : "pause.fill") : "play.fill")
						.font(.title2)
				}

				Button {
					viewModel.stop()
				} label: {
					Image(systemName: "stop.fill")
						.font(.title2)
				}
				Spacer()
				voicePicker
			}
			.padding(.horizontal)

			HStack {
				Text("Скорост")
				Slider(value: Binding(get: {
					Double(viewModel.speechRate)
				}, set: { newValue in
					viewModel.speechRate = Float(newValue)
				}), in: 0.3...0.6)
			}
			.padding(.horizontal)

			HStack {
				Text("Височина")
				Slider(value: Binding(get: {
					Double(viewModel.speechPitch)
				}, set: { newValue in
					viewModel.speechPitch = Float(newValue)
				}), in: 0.8...1.2)
			}
			.padding([.horizontal, .bottom])
		}
	}

	private var voicePicker: some View {
		Menu {
			if viewModel.availableVoices.isEmpty {
				Text("Няма налични български гласове").foregroundColor(.secondary)
				Button("Отвори настройки за гласове") {
					if let url = URL(string: UIApplication.openSettingsURLString) {
						UIApplication.shared.open(url)
					}
				}
			} else {
				ForEach(viewModel.availableVoices, id: \.identifier) { voice in
					Button {
						viewModel.selectedVoice = voice
					} label: {
						HStack {
							Text("\(voice.name) (\(voice.language))")
							if viewModel.selectedVoice?.identifier == voice.identifier {
								Image(systemName: "checkmark")
							}
						}
					}
				}
			}
		} label: {
			HStack {
				Image(systemName: "speaker.wave.2.fill")
				Text(viewModel.selectedVoice?.name ?? "Глас")
			}
		}
	}

	private func goToPreviousPage() {
		guard viewModel.document != nil else { return }
		viewModel.currentPageIndex = max(viewModel.currentPageIndex - 1, 0)
	}

	private func goToNextPage() {
		guard let doc = viewModel.document else { return }
		viewModel.currentPageIndex = min(viewModel.currentPageIndex + 1, doc.pageCount - 1)
	}

	private func copyToDocuments(url: URL) -> URL? {
		do {
			let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
			let target = docs.appendingPathComponent(url.lastPathComponent)
			if FileManager.default.fileExists(atPath: target.path) {
				try FileManager.default.removeItem(at: target)
			}
			try FileManager.default.copyItem(at: url, to: target)
			return target
		} catch {
			return nil
		}
	}
}