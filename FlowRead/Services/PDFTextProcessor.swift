// PDFTextProcessor.swift
// FlowRead - PDF text extraction and processing

import Foundation
@preconcurrency import PDFKit

/// Processes PDF documents to extract text chunks for TTS
class PDFTextProcessor {
    
    /// Chunk mode for text splitting
    enum ChunkMode {
        case sentence
        case paragraph
    }
    
    private var chunkMode: ChunkMode = .sentence
    
    init(mode: ChunkMode = .sentence) {
        self.chunkMode = mode
    }
    
    /// Extract text chunks from PDF document
    func extractTextChunks(from document: PDFDocument) async throws -> [TextChunk] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var allChunks: [TextChunk] = []
                
                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    
                    let pageChunks = self.extractChunksFromPage(page, pageIndex: pageIndex)
                    allChunks.append(contentsOf: pageChunks)
                }
                
                continuation.resume(returning: allChunks)
            }
        }
    }
    
    /// Extract chunks from a single page
    private func extractChunksFromPage(_ page: PDFPage, pageIndex: Int) -> [TextChunk] {
        guard let pageText = page.string else { return [] }
        
        let cleanedText = cleanText(pageText)
        
        switch chunkMode {
        case .sentence:
            return splitIntoSentences(cleanedText, pageIndex: pageIndex)
        case .paragraph:
            return splitIntoParagraphs(cleanedText, pageIndex: pageIndex)
        }
    }
    
    /// Clean extracted text
    private func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove excessive whitespace while preserving paragraph breaks
        let lines = cleaned.components(separatedBy: "\n")
        let processedLines = lines.map { line -> String in
            // Collapse multiple spaces to single space
            let components = line.components(separatedBy: .whitespaces)
            return components.filter { !$0.isEmpty }.joined(separator: " ")
        }
        
        cleaned = processedLines.joined(separator: "\n")
        
        // Remove control characters except newlines and tabs
        cleaned = cleaned.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.subtracting(CharacterSet.newlines).contains(scalar)
        }.map(String.init).joined()
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Split text into sentences
    private func splitIntoSentences(_ text: String, pageIndex: Int) -> [TextChunk] {
        var chunks: [TextChunk] = []
        
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        
        // Variables for potential future use in advanced sentence joining
        _ = text.startIndex  // Placeholder for future range tracking
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .tokenType) { _, range in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !sentence.isEmpty {
                // Check if sentence is too long for TTS (split if > 200 chars)
                if sentence.count > 200 {
                    let subChunks = splitLongSentence(sentence, pageIndex: pageIndex)
                    chunks.append(contentsOf: subChunks)
                } else {
                    let chunk = TextChunk(
                        text: sentence,
                        pageIndex: pageIndex,
                        range: NSRange(range, in: text)
                    )
                    chunks.append(chunk)
                }
            }
            
            return true
        }
        
        // Fallback: if NLTagger didn't find sentences, use regex
        if chunks.isEmpty && !text.isEmpty {
            chunks = splitBySentenceEndings(text, pageIndex: pageIndex)
        }
        
        return chunks.filter { !$0.isEmpty }
    }
    
    /// Fallback sentence splitting using punctuation
    private func splitBySentenceEndings(_ text: String, pageIndex: Int) -> [TextChunk] {
        let pattern = #"[^.!?]+[.!?]+[\s]*"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        var chunks: [TextChunk] = []
        
        regex?.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
            guard let result = result, let swiftRange = Range(result.range, in: text) else { return }
            
            let sentence = String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                chunks.append(TextChunk(text: sentence, pageIndex: pageIndex, range: result.range))
            }
        }
        
        // If still no chunks, just return the whole text as one chunk
        if chunks.isEmpty && !text.isEmpty {
            chunks.append(TextChunk(text: text, pageIndex: pageIndex))
        }
        
        return chunks
    }
    
    /// Split long sentence into smaller chunks
    private func splitLongSentence(_ sentence: String, pageIndex: Int) -> [TextChunk] {
        var chunks: [TextChunk] = []
        
        // Split on commas, semicolons, or colons first
        let delimiters = CharacterSet(charactersIn: ",;:")
        let parts = sentence.components(separatedBy: delimiters)
        
        var currentChunk = ""
        
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if currentChunk.isEmpty {
                currentChunk = trimmed
            } else if (currentChunk + ", " + trimmed).count <= 200 {
                currentChunk += ", " + trimmed
            } else {
                chunks.append(TextChunk(text: currentChunk, pageIndex: pageIndex))
                currentChunk = trimmed
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(TextChunk(text: currentChunk, pageIndex: pageIndex))
        }
        
        return chunks
    }
    
    /// Split text into paragraphs
    private func splitIntoParagraphs(_ text: String, pageIndex: Int) -> [TextChunk] {
        let paragraphs = text.components(separatedBy: "\n\n")
        
        return paragraphs.compactMap { paragraph in
            let cleaned = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            
            // If paragraph is very long, split into sentences instead
            if cleaned.count > 500 {
                return nil // Will be handled by sentence mode
            }
            
            return TextChunk(text: cleaned, pageIndex: pageIndex)
        }
    }
    
    /// Set chunk mode
    func setMode(_ mode: ChunkMode) {
        self.chunkMode = mode
    }
    
    /// Get page content with chunks
    func getPageContent(from document: PDFDocument) async throws -> [PDFPageContent] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var pages: [PDFPageContent] = []
                
                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    
                    let chunks = self.extractChunksFromPage(page, pageIndex: pageIndex)
                    let content = PDFPageContent(pageIndex: pageIndex, chunks: chunks)
                    pages.append(content)
                }
                
                continuation.resume(returning: pages)
            }
        }
    }
}

import NaturalLanguage
