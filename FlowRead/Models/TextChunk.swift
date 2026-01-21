// TextChunk.swift
// FlowRead - Text chunk model for TTS processing

import Foundation
import PDFKit

/// Represents a chunk of text (sentence or paragraph) extracted from PDF
struct TextChunk: Identifiable, Equatable {
    let id: UUID
    let text: String
    let pageIndex: Int
    let range: NSRange
    let boundingRect: CGRect?
    
    init(text: String, pageIndex: Int, range: NSRange = NSRange(), boundingRect: CGRect? = nil) {
        self.id = UUID()
        self.text = text
        self.pageIndex = pageIndex
        self.range = range
        self.boundingRect = boundingRect
    }
    
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var wordCount: Int {
        text.split(separator: " ").count
    }
    
    /// Estimated duration in seconds based on average reading speed
    var estimatedDuration: TimeInterval {
        let wordsPerMinute: Double = 150
        return Double(wordCount) / wordsPerMinute * 60
    }
}

/// Represents a page in the PDF with its chunks
struct PDFPageContent: Identifiable {
    let id: Int
    let pageIndex: Int
    let chunks: [TextChunk]
    let fullText: String
    
    init(pageIndex: Int, chunks: [TextChunk]) {
        self.id = pageIndex
        self.pageIndex = pageIndex
        self.chunks = chunks
        self.fullText = chunks.map(\.text).joined(separator: " ")
    }
}
