import Foundation

/// Διανυσματική αναζήτηση με cosine similarity (512-dim).
/// HONESTY: Δεν φορτώνει πραγματικά βάρη MobileCLIP — μόνο pseudo-embeddings / index scaffolding.
public actor MobileCLIPVectorSearchEngine {
    
    public struct VectorDocument: Identifiable, Sendable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let relativeMediaPath: String?
        public let textualContext: String
        public let embedding: [Float] // 512-dim L2-normalized vector
        
        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            relativeMediaPath: String? = nil,
            textualContext: String,
            embedding: [Float]
        ) {
            self.id = id
            self.timestamp = timestamp
            self.relativeMediaPath = relativeMediaPath
            self.textualContext = textualContext
            self.embedding = embedding
        }
    }
    
    public struct SearchResult: Identifiable, Sendable {
        public let id: UUID
        public let document: VectorDocument
        public let similarityScore: Float // 0.0 ... 1.0
        
        public init(document: VectorDocument, similarityScore: Float) {
            self.id = document.id
            self.document = document
            self.similarityScore = similarityScore
        }
    }
    
    private var index: [VectorDocument] = []
    private let vectorDimension: Int = 512
    
    public init() {}
    
    /// Προσθήκη νέου εγγράφου στον τοπικό διανυσματικό δείκτη
    public func insert(document: VectorDocument) {
        guard document.embedding.count == vectorDimension else { return }
        index.append(document)
    }
    
    /// Μαζική φόρτωση εγγράφων
    public func loadIndex(documents: [VectorDocument]) {
        self.index = documents.filter { $0.embedding.count == vectorDimension }
    }
    
    /// Εξαγωγή όλων των εγγράφων
    public func getAllDocuments() -> [VectorDocument] {
        return index
    }
    
    /// Υπολογισμός Cosine Similarity μεταξύ δύο διανυσμάτων
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        if denominator < 1e-7 { return 0.0 }
        return max(0.0, min(1.0, dotProduct / denominator))
    }
    
    /// Αναζήτηση των top-K πιο συναφών εγγραφών βάσει query vector
    public func search(queryVector: [Float], topK: Int = 5, minThreshold: Float = 0.35) -> [SearchResult] {
        guard queryVector.count == vectorDimension else { return [] }
        
        var scoredResults: [SearchResult] = []
        for doc in index {
            let score = Self.cosineSimilarity(queryVector, doc.embedding)
            if score >= minThreshold {
                scoredResults.append(SearchResult(document: doc, similarityScore: score))
            }
        }
        
        return scoredResults
            .sorted(by: { $0.similarityScore > $1.similarityScore })
            .prefix(topK)
            .map { $0 }
    }
    
    /// Προσομοίωση παραγωγής MobileCLIP embedding από κείμενο/αντικείμενο (Deterministic Token Embedding)
    public static func generatePseudoEmbedding(for text: String) -> [Float] {
        var vector = [Float](repeating: 0.0, count: 512)
        let hash = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).utf8
        var seed: UInt32 = 2166136261
        for byte in hash {
            seed = (seed ^ UInt32(byte)).multipliedReportingOverflow(by: 16777619).partialValue
        }
        
        // FNV-1a pseudo-random generation for stable vector representation
        for i in 0..<512 {
            seed = (seed.multipliedReportingOverflow(by: 1103515245).partialValue &+ 12345) & 0x7fffffff
            let val = Float(seed % 2000) / 1000.0 - 1.0
            vector[i] = val
        }
        
        // L2 Normalize
        var sumSquares: Float = 0.0
        for val in vector { sumSquares += val * val }
        let norm = sqrt(sumSquares)
        if norm > 1e-6 {
            for i in 0..<512 { vector[i] /= norm }
        }
        
        return vector
    }
}
