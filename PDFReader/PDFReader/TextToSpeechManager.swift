import Foundation
import AVFoundation
import Speech

class TextToSpeechManager: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var currentVoice: AVSpeechSynthesisVoice?
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    @Published var speechRate: Float = 0.5
    @Published var pitchMultiplier: Float = 1.0
    @Published var volume: Float = 1.0
    
    override init() {
        super.init()
        synthesizer.delegate = self
        loadAvailableVoices()
    }
    
    private func loadAvailableVoices() {
        // Зареждаме всички налични гласове
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Търсим български гласове първо
        if let bulgarianVoice = availableVoices.first(where: { $0.language.starts(with: "bg") }) {
            currentVoice = bulgarianVoice
            print("Намерен български глас: \(bulgarianVoice.name)")
        } else {
            // Ако няма български, търсим други славянски езици
            let slavicLanguages = ["ru", "pl", "cs", "sk", "hr", "sl", "sr"]
            for lang in slavicLanguages {
                if let slavicVoice = availableVoices.first(where: { $0.language.starts(with: lang) }) {
                    currentVoice = slavicVoice
                    print("Използва се славянски глас: \(slavicVoice.name) (\(slavicVoice.language))")
                    break
                }
            }
            
            // Ако няма славянски, използваме английски
            if currentVoice == nil {
                currentVoice = availableVoices.first(where: { $0.language.starts(with: "en") }) ?? availableVoices.first
                print("Използва се английски глас: \(currentVoice?.name ?? "Неизвестен")")
            }
        }
        
        // Принтираме всички налични гласове за дебъгване
        print("Налични гласове:")
        for voice in availableVoices.prefix(10) {
            print("- \(voice.name) (\(voice.language))")
        }
    }
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Спираме текущото четене
        stopSpeaking()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volume
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    func pauseSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    func continueSpeaking() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    func setVoice(_ voice: AVSpeechSynthesisVoice) {
        currentVoice = voice
    }
    
    func setSpeechRate(_ rate: Float) {
        speechRate = rate
    }
    
    func setPitchMultiplier(_ pitch: Float) {
        pitchMultiplier = pitch
    }
    
    func setVolume(_ vol: Float) {
        volume = vol
    }
    
    // Функция за извличане на текст от PDF страница
    func extractTextFromPDFPage(_ pdfPage: CGPDFPage) -> String {
        guard let pageRef = pdfPage else { return "" }
        
        let pageRect = pageRef.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            context.cgContext.drawPDFPage(pageRef)
        }
        
        // Тук бихме могли да използваме Vision framework за OCR
        // За сега връщаме празен string, тъй като извличането на текст от PDF е сложно
        return "Текст от PDF страницата ще бъде извлечен тук."
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
}