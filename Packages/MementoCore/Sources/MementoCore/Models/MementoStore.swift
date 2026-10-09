import SwiftData

public enum MementoStore {
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Entry.self, TagMark.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: config)
    }
}
