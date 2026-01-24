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
    
    /// Clean extracted text and join broken sentences
    private func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove control characters except newlines
        cleaned = cleaned.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.subtracting(CharacterSet.newlines).contains(scalar)
        }.map(String.init).joined()
        
        // Split into lines and intelligently join them
        let lines = cleaned.components(separatedBy: "\n")
        var joinedLines: [String] = []
        var currentParagraph = ""
        
        for line in lines {
            // Collapse multiple spaces to single space
            let trimmedLine = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            
            // Skip empty lines - they indicate paragraph breaks
            if trimmedLine.isEmpty {
                if !currentParagraph.isEmpty {
                    joinedLines.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                    currentParagraph = ""
                }
                continue
            }
            
            // CRITICAL: Check if this line is a standalone Roman numeral or chapter marker
            // These should NEVER be merged with other text
            if isStandaloneChapterMarker(trimmedLine) {
                // Save any pending paragraph first
                if !currentParagraph.isEmpty {
                    joinedLines.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                    currentParagraph = ""
                }
                // Add the chapter marker as its own paragraph
                joinedLines.append(trimmedLine)
                continue
            }
            
            // If current paragraph is empty, start a new one
            if currentParagraph.isEmpty {
                currentParagraph = trimmedLine
            } else {
                // Check if previous line ended with sentence-ending punctuation
                let lastChar = currentParagraph.last
                let endsWithSentenceEnd = lastChar == "." || lastChar == "?" || 
                                           lastChar == "!" || lastChar == ":"
                
                if endsWithSentenceEnd {
                    // Previous line was a complete sentence - could be same paragraph
                    // Join with space (same paragraph) unless this looks like a new section
                    if looksLikeNewSection(trimmedLine) {
                        // New section/chapter - save current and start fresh
                        joinedLines.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                        currentParagraph = trimmedLine
                    } else {
                        // Same paragraph, different sentence
                        currentParagraph += " " + trimmedLine
                    }
                } else {
                    // Previous line didn't end with punctuation - it's a broken sentence
                    // Join with space to continue the sentence
                    currentParagraph += " " + trimmedLine
                }
            }
        }
        
        // Don't forget the last paragraph
        if !currentParagraph.isEmpty {
            joinedLines.append(currentParagraph.trimmingCharacters(in: .whitespaces))
        }
        
        // Join paragraphs with double newline to preserve paragraph structure
        cleaned = joinedLines.joined(separator: "\n\n")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if a line is a standalone chapter/section marker that should NOT be merged
    /// This catches Roman numerals (I, II, III...), numeric chapters (1, 2, 3...), etc.
    private func isStandaloneChapterMarker(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must be relatively short (chapter markers are typically brief)
        guard trimmed.count <= 30 else { return false }
        
        // Roman numerals (uppercase and lowercase)
        let romanPattern = "^[IVXLCDM]+$|^[ivxlcdm]+$"
        if let regex = try? NSRegularExpression(pattern: romanPattern, options: []),
           regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            // Validate it's a proper Roman numeral sequence
            let upperTrimmed = trimmed.uppercased()
            let validRomanNumerals = Set(["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                                          "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX",
                                          "XXI", "XXII", "XXIII", "XXIV", "XXV", "XXX", "XL", "L", "C", "D", "M"])
            if validRomanNumerals.contains(upperTrimmed) {
                return true
            }
        }
        
        // Standalone numbers (1, 2, 3, etc.)
        if let _ = Int(trimmed), trimmed.count <= 3 {
            return true
        }
        
        // "Chapter X", "Part X", "Section X", "Book X" patterns
        let headerPatterns = ["^Chapter\\s+\\S+$", "^Part\\s+\\S+$", "^Section\\s+\\S+$", "^Book\\s+\\S+$",
                              "^CHAPTER\\s+\\S+$", "^PART\\s+\\S+$", "^SECTION\\s+\\S+$", "^BOOK\\s+\\S+$"]
        for pattern in headerPatterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Check if a line looks like a new section/chapter header
    private func looksLikeNewSection(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Use the standalone marker check
        if isStandaloneChapterMarker(trimmed) { return true }
        
        // All caps short line (likely a title)
        if trimmed.count < 50 && trimmed == trimmed.uppercased() && trimmed.contains(" ") {
            return true
        }
        
        return false
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
        
        // Post-process chunks to make them TTS-friendly
        chunks = postProcessChunksForTTS(chunks, pageIndex: pageIndex)
        
        return chunks.filter { !$0.isEmpty }
    }
    
    /// Post-process chunks to merge short fragments and handle special cases
    private func postProcessChunksForTTS(_ chunks: [TextChunk], pageIndex: Int) -> [TextChunk] {
        var result: [TextChunk] = []
        var pendingChunk: TextChunk? = nil
        
        // Minimum word count for a chunk to be considered standalone
        let minWordCount = 3
        
        for chunk in chunks {
            let text = chunk.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty chunks
            guard !text.isEmpty else { continue }
            
            // Check if this is a Roman numeral chapter header or single letter
            if isChapterHeader(text) {
                // Convert Roman numeral to "Chapter X" or skip entirely
                if let chapterText = transformChapterHeader(text) {
                    // If there's a pending chunk, add it first
                    if let pending = pendingChunk {
                        result.append(pending)
                        pendingChunk = nil
                    }
                    result.append(TextChunk(text: chapterText, pageIndex: pageIndex))
                }
                // If transform returns nil, skip this chunk entirely
                continue
            }
            
            // Count words in chunk
            let wordCount = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            
            // If chunk is too short, merge it with pending or next chunk
            if wordCount < minWordCount {
                if let pending = pendingChunk {
                    // Merge with pending chunk
                    let mergedText = pending.text + " " + text
                    pendingChunk = TextChunk(text: mergedText, pageIndex: pageIndex)
                } else {
                    // Start a new pending chunk
                    pendingChunk = chunk
                }
            } else {
                // Normal chunk - check if we have a pending chunk to merge
                if let pending = pendingChunk {
                    // Merge pending with current
                    let mergedText = pending.text + " " + text
                    result.append(TextChunk(text: mergedText, pageIndex: pageIndex))
                    pendingChunk = nil
                } else {
                    result.append(chunk)
                }
            }
        }
        
        // Don't forget any remaining pending chunk
        if let pending = pendingChunk {
            // If the pending chunk is too short to be meaningful, check word count
            let wordCount = pending.text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            if wordCount >= 2 || pending.text.count >= 10 {
                result.append(pending)
            }
            // Otherwise, just drop it - it's probably noise
        }
        
        return result
    }
    
    /// Check if text is a chapter/section header (Roman numeral, single letter, etc.)
    private func isChapterHeader(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common Roman numerals as standalone
        let romanNumerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                             "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX",
                             "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x"]
        
        if romanNumerals.contains(trimmed) {
            return true
        }
        
        // Single capital letter (could be a section marker)
        if trimmed.count == 1 && trimmed.first?.isLetter == true && trimmed.first?.isUppercase == true {
            return true
        }
        
        // "Chapter X", "Part X", "Section X" patterns
        let headerPatterns = ["^Chapter\\s+", "^Part\\s+", "^Section\\s+", "^Book\\s+"]
        for pattern in headerPatterns {
            if trimmed.range(of: pattern, options: .regularExpression, range: nil, locale: nil) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Transform chapter header for TTS or return nil to skip
    private func transformChapterHeader(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Roman numeral to spoken chapter number
        let romanMap: [String: Int] = [
            "I": 1, "II": 2, "III": 3, "IV": 4, "V": 5,
            "VI": 6, "VII": 7, "VIII": 8, "IX": 9, "X": 10,
            "XI": 11, "XII": 12, "XIII": 13, "XIV": 14, "XV": 15,
            "XVI": 16, "XVII": 17, "XVIII": 18, "XIX": 19, "XX": 20,
            "i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5,
            "vi": 6, "vii": 7, "viii": 8, "ix": 9, "x": 10
        ]
        
        if let chapterNum = romanMap[trimmed] {
            // Return "Chapter X" for TTS
            return "Chapter \(chapterNum)."
        }
        
        // Single letter - skip entirely (not useful for TTS)
        if trimmed.count == 1 {
            return nil
        }
        
        // Already a proper header like "Chapter 1" - keep as is
        if trimmed.lowercased().hasPrefix("chapter") || 
           trimmed.lowercased().hasPrefix("part") ||
           trimmed.lowercased().hasPrefix("section") {
            return trimmed
        }
        
        return nil
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
    
    /// Split long sentence into smaller chunks using natural break points
    /// Only called for sentences > 200 characters (TTS API limit)
    private func splitLongSentence(_ sentence: String, pageIndex: Int) -> [TextChunk] {
        let maxLength = 200
        var chunks: [TextChunk] = []
        var remainingText = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        
        while !remainingText.isEmpty {
            // If remaining text is under limit, we're done
            if remainingText.count <= maxLength {
                chunks.append(TextChunk(text: remainingText, pageIndex: pageIndex))
                break
            }
            
            // Find the best break point BEFORE maxLength
            let searchRange = String(remainingText.prefix(maxLength))
            
            // Try to find a break point
            if let (breakIndex, splitBefore) = findBestBreakPoint(in: searchRange) {
                let chunkEndIndex = remainingText.index(remainingText.startIndex, offsetBy: breakIndex)
                let chunk = String(remainingText[..<chunkEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !chunk.isEmpty {
                    chunks.append(TextChunk(text: chunk, pageIndex: pageIndex))
                }
                
                // Move past the break point
                remainingText = String(remainingText[chunkEndIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // If we split AFTER punctuation, remove any leading delimiters
                if !splitBefore {
                    remainingText = removeLeadingDelimiters(remainingText)
                }
            } else {
                // No natural break found - find last space to avoid cutting mid-word
                if let lastSpaceIndex = searchRange.lastIndex(of: " ") {
                    let breakOffset = searchRange.distance(from: searchRange.startIndex, to: lastSpaceIndex)
                    // Try to keep chunk at least 100 chars if possible
                    if breakOffset >= 100 {
                        let chunkEndIndex = remainingText.index(remainingText.startIndex, offsetBy: breakOffset)
                        let chunk = String(remainingText[..<chunkEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !chunk.isEmpty {
                            chunks.append(TextChunk(text: chunk, pageIndex: pageIndex))
                        }
                        
                        remainingText = String(remainingText[chunkEndIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        // Chunk would be too small, just take what we can
                        let chunk = String(remainingText.prefix(maxLength))
                        chunks.append(TextChunk(text: chunk, pageIndex: pageIndex))
                        remainingText = String(remainingText.dropFirst(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else {
                    // No space found - hard cut (extremely rare edge case)
                    let chunk = String(remainingText.prefix(maxLength))
                    chunks.append(TextChunk(text: chunk, pageIndex: pageIndex))
                    remainingText = String(remainingText.dropFirst(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return chunks
    }
    
    /// Find the best natural break point in the text for TTS
    /// Returns: (index, splitBefore) where splitBefore=true means split BEFORE the word, false means split AFTER punctuation
    private func findBestBreakPoint(in text: String) -> (Int, Bool)? {
        let minChunkSize = 50  // Minimum characters for a meaningful chunk
        
        // PRIORITY 1: Punctuation - split AFTER (punctuation stays with first chunk)
        // Find the LAST occurrence of any punctuation delimiter
        var lastPunctuationIndex: Int? = nil
        
        // Single-character delimiters
        let punctuationChars: [Character] = [",", ";", ":"]
        for char in punctuationChars {
            if let index = text.lastIndex(of: char) {
                let pos = text.distance(from: text.startIndex, to: index) + 1  // +1 to include the punctuation
                if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                    lastPunctuationIndex = pos
                }
            }
        }
        
        // Em-dash (—)
        if let range = text.range(of: "—", options: .backwards) {
            let pos = text.distance(from: text.startIndex, to: range.upperBound)
            if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                lastPunctuationIndex = pos
            }
        }
        
        // Double dash (--)
        if let range = text.range(of: "--", options: .backwards) {
            let pos = text.distance(from: text.startIndex, to: range.upperBound)
            if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                lastPunctuationIndex = pos
            }
        }
        
        // Closing parenthesis )
        if let index = text.lastIndex(of: ")") {
            let pos = text.distance(from: text.startIndex, to: index) + 1
            if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                lastPunctuationIndex = pos
            }
        }
        
        // Closing bracket ]
        if let index = text.lastIndex(of: "]") {
            let pos = text.distance(from: text.startIndex, to: index) + 1
            if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                lastPunctuationIndex = pos
            }
        }
        
        // Closing quotes (straight and curly)
        // Using Unicode: \u{201D} = " (right double quote), \u{2019} = ' (right single quote)
        let quotePatterns = ["\" ", "\u{201D} ", "' ", "\u{2019} "]  // Quote followed by space
        for pattern in quotePatterns {
            if let range = text.range(of: pattern, options: .backwards) {
                let pos = text.distance(from: text.startIndex, to: range.lowerBound) + 1  // Include the quote
                if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                    lastPunctuationIndex = pos
                }
            }
        }
        
        // Ellipsis (... or …)
        if let range = text.range(of: "...", options: .backwards) {
            let pos = text.distance(from: text.startIndex, to: range.upperBound)
            if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                lastPunctuationIndex = pos
            }
        }
        if let range = text.range(of: "…", options: .backwards) {
            let pos = text.distance(from: text.startIndex, to: range.upperBound)
            if lastPunctuationIndex == nil || pos > lastPunctuationIndex! {
                lastPunctuationIndex = pos
            }
        }
        
        // If we found punctuation at a good position, use it
        if let puncIndex = lastPunctuationIndex {
            if puncIndex >= minChunkSize && puncIndex < text.count - 5 {
                return (puncIndex, false)  // false = split AFTER punctuation
            }
        }
        
        // PRIORITY 2: Clause words - split BEFORE (word goes with second chunk)
        // Find the LAST occurrence of clause boundary words
        var lastClauseIndex: Int? = nil
        
        // Clause boundary words (with leading space to match word boundaries)
        let clauseWords = [
            // Relative pronouns
            " who ", " which ", " that ", " where ", " when ", " whose ", " whom ",
            // Subordinating conjunctions
            " because ", " although ", " while ", " since ", " unless ", " before ", " after ", " until ", " whereas ", " whenever ",
            // Coordinating conjunctions (at clause boundaries)
            " and ", " but ", " or ", " so ", " yet ", " nor ",
            // Prepositions that often start new phrases
            " without ", " through ", " despite ", " during ", " although ", " however "
        ]
        
        for word in clauseWords {
            if let range = text.range(of: word, options: [.backwards, .caseInsensitive]) {
                let pos = text.distance(from: text.startIndex, to: range.lowerBound)
                // Only consider if it's after minimum chunk size
                if pos >= minChunkSize {
                    if lastClauseIndex == nil || pos > lastClauseIndex! {
                        lastClauseIndex = pos
                    }
                }
            }
        }
        
        // If we found a clause word at a good position, use it
        if let clauseIndex = lastClauseIndex {
            if clauseIndex < text.count - 10 {  // Leave some content for next chunk
                return (clauseIndex, true)  // true = split BEFORE the word
            }
        }
        
        return nil
    }
    
    /// Remove leading delimiters and whitespace from text
    private func removeLeadingDelimiters(_ text: String) -> String {
        var result = text
        // Using Unicode: \u{2014} = — (em-dash), \u{201D} = " (right double quote), \u{2019} = ' (right single quote), \u{2026} = … (ellipsis)
        let delimiters: Set<Character> = [",", ";", ":", "\u{2014}", "-", ")", "]", "\"", "'", "\u{201D}", "\u{2019}", "\u{2026}"]
        
        while let first = result.first, delimiters.contains(first) || first.isWhitespace {
            result.removeFirst()
        }
        
        return result
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
