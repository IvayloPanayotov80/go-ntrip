import Foundation
import AVFoundation
import PDFKit
import Combine
import UIKit

final class PDFReaderViewModel: NSObject, ObservableObject {
	@Published var document: PDFDocument?
	@Published var currentPageIndex: Int = 0
	@Published var isSpeaking: Bool = false
	@Published var isPaused: Bool = false
	@Published var availableVoices: [AVSpeechSynthesisVoice] = []
	@Published var selectedVoice: AVSpeechSynthesisVoice?
	@Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
	@Published var speechPitch: Float = 1.0

	private let synthesizer = AVSpeechSynthesizer()
	private var cancellables = Set<AnyCancellable>()
	private var shouldContinueAcrossPages: Bool = false

	override init() {
		super.init()
		synthesizer.delegate = self
		configureAudioSession()
		refreshVoices()
	}

	private func configureAudioSession() {
		let session = AVAudioSession.sharedInstance()
		try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
		try? session.setActive(true, options: [])
	}

	func refreshVoices() {
		let voices = AVSpeechSynthesisVoice.speechVoices()
		let bulgarian = voices.filter { $0.language.lowercased().hasPrefix("bg") }
		DispatchQueue.main.async {
			self.availableVoices = bulgarian
			if self.selectedVoice == nil {
				self.selectedVoice = bulgarian.first ?? AVSpeechSynthesisVoice(language: "bg-BG")
			}
		}
	}

	func open(url: URL) {
		if let doc = PDFDocument(url: url) {
			DispatchQueue.main.async {
				self.document = doc
				self.currentPageIndex = 0
			}
		}
	}

	func readFromCurrentPage() {
		guard !isSpeaking else { return }
		guard let doc = document else { return }
		shouldContinueAcrossPages = true
		speakPage(at: currentPageIndex, in: doc)
	}

	func pauseOrResume() {
		guard synthesizer.isSpeaking else { return }
		if synthesizer.isPaused {
			synthesizer.continueSpeaking()
			isPaused = false
		} else {
			synthesizer.pauseSpeaking(at: .immediate)
			isPaused = true
		}
	}

	func stop() {
		shouldContinueAcrossPages = false
		synthesizer.stopSpeaking(at: .immediate)
		isSpeaking = false
		isPaused = false
	}

	private func speakPage(at index: Int, in doc: PDFDocument) {
		guard index >= 0, index < doc.pageCount else { return }
		guard let page = doc.page(at: index) else { return }
		let text = page.attributedString?.string ?? page.string ?? ""
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			advanceToNextPageAndMaybeSpeak(in: doc)
			return
		}
		let utterance = AVSpeechUtterance(string: trimmed)
		if let selectedVoice = selectedVoice {
			utterance.voice = selectedVoice
		} else if let bg = AVSpeechSynthesisVoice(language: "bg-BG") {
			utterance.voice = bg
		}
		utterance.rate = speechRate
		utterance.pitchMultiplier = speechPitch
		isSpeaking = true
		synthesizer.speak(utterance)
	}

	private func advanceToNextPageAndMaybeSpeak(in doc: PDFDocument) {
		currentPageIndex = min(currentPageIndex + 1, doc.pageCount - 1)
		if shouldContinueAcrossPages {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				self.speakPage(at: self.currentPageIndex, in: doc)
			}
		}
	}
}

extension PDFReaderViewModel: AVSpeechSynthesizerDelegate {
	func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
		DispatchQueue.main.async {
			self.isSpeaking = false
			guard self.shouldContinueAcrossPages, let doc = self.document else { return }
			self.advanceToNextPageAndMaybeSpeak(in: doc)
		}
	}

	func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
		DispatchQueue.main.async {
			self.isSpeaking = false
		}
	}
}