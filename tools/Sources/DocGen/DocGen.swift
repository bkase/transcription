import ArgumentParser
import Foundation

@main
struct DocGen: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate documentation from schema definitions"
    )

    @Option(name: .shortAndLong, help: "Input Persistence directory containing Persistence.swift")
    var input: String = "schema"

    @Option(name: .shortAndLong, help: "Output documentation directory")
    var output: String = "docs"

    func run() throws {
        print("DocGen: Generating docs from \(input) to \(output)")

        // Locate Persistence.swift
        let inputURL = URL(fileURLWithPath: input)
        let persistenceFile = inputURL.appendingPathComponent("Persistence.swift")

        guard FileManager.default.fileExists(atPath: persistenceFile.path) else {
            throw DocGenError.fileNotFound(persistenceFile.path)
        }

        // Read and parse the file
        let content = try String(contentsOf: persistenceFile, encoding: .utf8)
        let schema = try SchemaParser.parse(content)

        // Ensure output directory exists
        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        // Generate SCHEMA.md
        let schemaDoc = SchemaDocGenerator.generate(schema)
        let schemaPath = outputURL.appendingPathComponent("SCHEMA.md")
        try schemaDoc.write(to: schemaPath, atomically: true, encoding: .utf8)
        print("Generated: \(schemaPath.path)")

        // Generate EXPORT_FORMAT.md
        let exportDoc = ExportFormatDocGenerator.generate(schema)
        let exportPath = outputURL.appendingPathComponent("EXPORT_FORMAT.md")
        try exportDoc.write(to: exportPath, atomically: true, encoding: .utf8)
        print("Generated: \(exportPath.path)")
    }
}

enum DocGenError: Error, LocalizedError {
    case fileNotFound(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

// MARK: - Schema Types

struct Schema {
    var migrations: [Migration]
}

struct Migration {
    var name: String
    var tables: [Table]
    var indexes: [Index]
    var ftsTable: FTSTable?
    var triggers: [Trigger]
}

struct Table {
    var name: String
    var columns: [Column]
}

struct Column {
    var name: String
    var type: String
    var isPrimaryKey: Bool
    var isNotNull: Bool
    var defaultValue: String?
    var references: Reference?
}

struct Reference {
    var table: String
    var onDelete: String?
}

struct Index {
    var name: String
    var table: String
    var columns: [String]
}

struct FTSTable {
    var name: String
    var columns: [String]
    var unindexedColumns: [String]
}

struct Trigger {
    var name: String
    var event: String
    var table: String
    var description: String
}

// MARK: - Schema Parser

enum SchemaParser {
    static func parse(_ content: String) throws -> Schema {
        var migrations: [Migration] = []
        let lines = content.components(separatedBy: .newlines)

        var currentMigration: Migration?
        var inMigration = false
        var braceDepth = 0
        var currentTable: Table?
        var inTable = false
        var tableContent = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect migration registration
            if trimmed.contains("registerMigration(") {
                if let name = extractMigrationName(from: trimmed) {
                    if let existing = currentMigration {
                        migrations.append(existing)
                    }
                    currentMigration = Migration(name: name, tables: [], indexes: [], ftsTable: nil, triggers: [])
                    inMigration = true
                    braceDepth = 0
                }
            }

            // Track brace depth for migration scope
            if inMigration {
                braceDepth += line.filter { $0 == "{" }.count
                braceDepth -= line.filter { $0 == "}" }.count

                // Parse table creation
                if trimmed.contains("db.create(table:") {
                    if let tableName = extractTableName(from: trimmed) {
                        currentTable = Table(name: tableName, columns: [])
                        inTable = true
                        tableContent = ""
                    }
                }

                if inTable {
                    tableContent += line + "\n"
                    // Check if table definition ends
                    if trimmed == "}" && tableContent.contains("t.column") {
                        if var table = currentTable {
                            table.columns = parseColumns(from: tableContent)
                            currentMigration?.tables.append(table)
                        }
                        currentTable = nil
                        inTable = false
                        tableContent = ""
                    }
                }

                // Parse index creation
                if trimmed.contains("db.create(index:") {
                    if let index = parseIndex(from: line) {
                        currentMigration?.indexes.append(index)
                    }
                }

                // Parse FTS5 table
                if trimmed.contains("CREATE VIRTUAL TABLE") && trimmed.contains("fts5") {
                    if let fts = parseFTSTable(from: content, startingWith: "CREATE VIRTUAL TABLE") {
                        currentMigration?.ftsTable = fts
                    }
                }

                // Parse triggers
                if trimmed.contains("CREATE TRIGGER") {
                    if let trigger = parseTrigger(from: content, triggerPrefix: trimmed) {
                        currentMigration?.triggers.append(trigger)
                    }
                }

                if braceDepth <= 0 && trimmed == "}" {
                    inMigration = false
                }
            }
        }

        if let existing = currentMigration {
            migrations.append(existing)
        }

        return Schema(migrations: migrations)
    }

    private static func extractMigrationName(from line: String) -> String? {
        // Pattern: registerMigration("v1_initial_schema")
        if let start = line.range(of: "\""),
           let end = line.range(of: "\"", range: start.upperBound..<line.endIndex) {
            return String(line[start.upperBound..<end.lowerBound])
        }
        return nil
    }

    private static func extractTableName(from line: String) -> String? {
        // Pattern: db.create(table: "sessions")
        if let start = line.range(of: "table: \""),
           let end = line.range(of: "\"", range: start.upperBound..<line.endIndex) {
            return String(line[start.upperBound..<end.lowerBound])
        }
        return nil
    }

    private static func parseColumns(from tableContent: String) -> [Column] {
        var columns: [Column] = []
        let lines = tableContent.components(separatedBy: .newlines)

        var currentColumnDef = ""
        var inColumnDef = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Start of a column definition
            if trimmed.contains("t.column(") {
                // If we were already in a column def, parse the previous one
                if inColumnDef && !currentColumnDef.isEmpty {
                    if let column = parseColumn(from: currentColumnDef) {
                        columns.append(column)
                    }
                }
                inColumnDef = true
                currentColumnDef = trimmed
            } else if inColumnDef {
                // Continue collecting multi-line column definition
                if trimmed == "}" {
                    // End of table - parse the last column
                    if !currentColumnDef.isEmpty {
                        if let column = parseColumn(from: currentColumnDef) {
                            columns.append(column)
                        }
                    }
                    inColumnDef = false
                    currentColumnDef = ""
                } else {
                    // Continuation line (like .references(...))
                    currentColumnDef += " " + trimmed
                }
            }
        }

        return columns
    }

    private static func parseColumn(from definition: String) -> Column? {
        guard definition.contains("t.column(") else { return nil }

        // Extract column name
        guard let nameStart = definition.range(of: "\""),
              let nameEnd = definition.range(of: "\"", range: nameStart.upperBound..<definition.endIndex) else {
            return nil
        }
        let name = String(definition[nameStart.upperBound..<nameEnd.lowerBound])

        // Extract type
        var type = "unknown"
        if definition.contains(".text") { type = "TEXT" }
        else if definition.contains(".integer") { type = "INTEGER" }
        else if definition.contains(".double") { type = "REAL" }
        else if definition.contains(".datetime") { type = "DATETIME" }
        else if definition.contains(".boolean") { type = "BOOLEAN" }
        else if definition.contains(".blob") { type = "BLOB" }

        // Check constraints
        let isPrimaryKey = definition.contains(".primaryKey()")
        let isNotNull = definition.contains(".notNull()")

        // Extract default value
        var defaultValue: String?
        if let defaultStart = definition.range(of: ".defaults(to: ") {
            let afterDefault = definition[defaultStart.upperBound...]
            if let defaultEnd = afterDefault.firstIndex(of: ")") {
                defaultValue = String(afterDefault[..<defaultEnd])
            }
        }

        // Extract reference
        var reference: Reference?
        if let refStart = definition.range(of: ".references(\"") {
            let afterRef = definition[refStart.upperBound...]
            if let refEnd = afterRef.firstIndex(of: "\"") {
                let refTable = String(afterRef[..<refEnd])
                var onDelete: String?
                if definition.contains("onDelete: .cascade") {
                    onDelete = "CASCADE"
                } else if definition.contains("onDelete: .setNull") {
                    onDelete = "SET NULL"
                }
                reference = Reference(table: refTable, onDelete: onDelete)
            }
        }

        return Column(
            name: name,
            type: type,
            isPrimaryKey: isPrimaryKey,
            isNotNull: isNotNull || isPrimaryKey,
            defaultValue: defaultValue,
            references: reference
        )
    }

    private static func parseIndex(from line: String) -> Index? {
        // Pattern: try db.create(index: "idx_sessions_startedAt", on: "sessions", columns: ["startedAt"])
        guard let nameStart = line.range(of: "index: \""),
              let nameEnd = line.range(of: "\"", range: nameStart.upperBound..<line.endIndex) else {
            return nil
        }
        let name = String(line[nameStart.upperBound..<nameEnd.lowerBound])

        guard let tableStart = line.range(of: "on: \""),
              let tableEnd = line.range(of: "\"", range: tableStart.upperBound..<line.endIndex) else {
            return nil
        }
        let table = String(line[tableStart.upperBound..<tableEnd.lowerBound])

        // Extract columns
        var columns: [String] = []
        if let colStart = line.range(of: "columns: [") {
            let afterCols = line[colStart.upperBound...]
            if let colEnd = afterCols.firstIndex(of: "]") {
                let colString = afterCols[..<colEnd]
                // Parse column names from ["col1", "col2"]
                var current = ""
                var inQuote = false
                for char in colString {
                    if char == "\"" {
                        if inQuote {
                            columns.append(current)
                            current = ""
                        }
                        inQuote = !inQuote
                    } else if inQuote {
                        current.append(char)
                    }
                }
            }
        }

        return Index(name: name, table: table, columns: columns)
    }

    private static func parseFTSTable(from content: String, startingWith prefix: String) -> FTSTable? {
        // Find the FTS CREATE statement
        guard let ftsStart = content.range(of: "CREATE VIRTUAL TABLE") else { return nil }
        let afterStart = content[ftsStart.lowerBound...]

        // Find table name
        var tableName = ""
        if let nameMatch = afterStart.range(of: "CREATE VIRTUAL TABLE ") {
            let afterName = afterStart[nameMatch.upperBound...]
            if let space = afterName.firstIndex(of: " ") {
                tableName = String(afterName[..<space])
            }
        }

        // Find columns in USING fts5(...)
        var columns: [String] = []
        var unindexed: [String] = []

        if let fts5Start = afterStart.range(of: "fts5("),
           let fts5End = afterStart.range(of: ")", range: fts5Start.upperBound..<afterStart.endIndex) {
            let colDef = String(afterStart[fts5Start.upperBound..<fts5End.lowerBound])
            let parts = colDef.components(separatedBy: ",")
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                // Check for UNINDEXED
                if trimmed.contains("UNINDEXED") {
                    let colName = trimmed.replacingOccurrences(of: " UNINDEXED", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    columns.append(colName)
                    unindexed.append(colName)
                } else {
                    columns.append(trimmed)
                }
            }
        }

        return FTSTable(name: tableName, columns: columns, unindexedColumns: unindexed)
    }

    private static func parseTrigger(from content: String, triggerPrefix: String) -> Trigger? {
        // Extract trigger name from prefix
        let parts = triggerPrefix.components(separatedBy: " ")
        guard parts.count >= 3 else { return nil }

        let name = parts[2] // CREATE TRIGGER <name>

        // Determine event type
        var event = "UNKNOWN"
        var table = ""
        if triggerPrefix.contains("AFTER INSERT") {
            event = "AFTER INSERT"
        } else if triggerPrefix.contains("AFTER DELETE") {
            event = "AFTER DELETE"
        } else if triggerPrefix.contains("AFTER UPDATE") {
            event = "AFTER UPDATE"
        }

        // Extract table name
        if let onMatch = triggerPrefix.range(of: " ON ") {
            let afterOn = triggerPrefix[onMatch.upperBound...]
            if let space = afterOn.firstIndex(of: " ") {
                table = String(afterOn[..<space])
            } else {
                table = String(afterOn)
            }
        }

        var description = "Keeps FTS index in sync"
        if event.contains("INSERT") {
            description = "Inserts new record into FTS index"
        } else if event.contains("DELETE") {
            description = "Removes record from FTS index"
        } else if event.contains("UPDATE") {
            description = "Updates record in FTS index"
        }

        return Trigger(name: name, event: event, table: table, description: description)
    }
}

// MARK: - Schema Doc Generator

enum SchemaDocGenerator {
    static func generate(_ schema: Schema) -> String {
        var output = """
        # Database Schema

        This document is auto-generated from migrations in `Persistence.swift`.

        ## Overview

        """

        // List all tables
        let allTables = schema.migrations.flatMap { $0.tables }
        output += "The database contains \(allTables.count) tables:\n\n"
        for table in allTables {
            output += "- [`\(table.name)`](#\(table.name))\n"
        }

        // FTS tables
        let ftsTables = schema.migrations.compactMap { $0.ftsTable }
        if !ftsTables.isEmpty {
            output += "\nFull-text search tables:\n\n"
            for fts in ftsTables {
                output += "- [`\(fts.name)`](#\(fts.name)) (FTS5)\n"
            }
        }

        output += "\n---\n\n"

        // Document each migration
        for migration in schema.migrations {
            output += "## Migration: `\(migration.name)`\n\n"

            // Tables
            for table in migration.tables {
                output += "### \(table.name)\n\n"
                output += "| Column | Type | Constraints | Default | References |\n"
                output += "|--------|------|-------------|---------|------------|\n"

                for col in table.columns {
                    var constraints: [String] = []
                    if col.isPrimaryKey { constraints.append("PRIMARY KEY") }
                    if col.isNotNull && !col.isPrimaryKey { constraints.append("NOT NULL") }

                    let constraintStr = constraints.isEmpty ? "-" : constraints.joined(separator: ", ")
                    let defaultStr = col.defaultValue ?? "-"
                    var refStr = "-"
                    if let ref = col.references {
                        refStr = "`\(ref.table)`"
                        if let onDelete = ref.onDelete {
                            refStr += " (ON DELETE \(onDelete))"
                        }
                    }

                    output += "| `\(col.name)` | \(col.type) | \(constraintStr) | \(defaultStr) | \(refStr) |\n"
                }
                output += "\n"
            }

            // Indexes
            if !migration.indexes.isEmpty {
                output += "### Indexes\n\n"
                output += "| Index Name | Table | Columns |\n"
                output += "|------------|-------|--------|\n"
                for index in migration.indexes {
                    let cols = index.columns.map { "`\($0)`" }.joined(separator: ", ")
                    output += "| `\(index.name)` | `\(index.table)` | \(cols) |\n"
                }
                output += "\n"
            }

            // FTS Table
            if let fts = migration.ftsTable {
                output += "### \(fts.name) (FTS5 Virtual Table)\n\n"
                output += "Full-text search table for transcript search.\n\n"
                output += "| Column | Indexed |\n"
                output += "|--------|--------|\n"
                for col in fts.columns {
                    let indexed = fts.unindexedColumns.contains(col) ? "No (UNINDEXED)" : "Yes"
                    output += "| `\(col)` | \(indexed) |\n"
                }
                output += "\n"
            }

            // Triggers
            if !migration.triggers.isEmpty {
                output += "### Triggers\n\n"
                output += "| Trigger | Event | Table | Description |\n"
                output += "|---------|-------|-------|-------------|\n"
                for trigger in migration.triggers {
                    output += "| `\(trigger.name)` | \(trigger.event) | `\(trigger.table)` | \(trigger.description) |\n"
                }
                output += "\n"
            }
        }

        // Entity Relationship Description
        output += """
        ---

        ## Entity Relationships

        ```
        sessions 1--* speaker_tracks     (sessionId -> sessions.id, CASCADE)
        sessions 1--* transcript_segments (sessionId -> sessions.id, CASCADE)
        sessions 1--* speaker_segments   (sessionId -> sessions.id, CASCADE)
        people   1--* speaker_tracks     (personId -> people.id, SET NULL)
        ```

        - A **session** contains multiple **speaker tracks**, **transcript segments**, and **speaker segments**
        - Deleting a session cascades to delete all related tracks and segments
        - **People** can be assigned to **speaker tracks**; deleting a person sets the reference to NULL

        """

        return output
    }
}

// MARK: - Export Format Doc Generator

enum ExportFormatDocGenerator {
    static func generate(_ schema: Schema) -> String {
        let allTables = schema.migrations.flatMap { $0.tables }

        var output = """
        # Export Format

        This document describes the export formats available for session data.

        ## JSON Export

        Sessions can be exported as JSON with the following structure:

        ```json
        {
          "version": "1.0",
          "exportedAt": "2026-01-25T00:00:00Z",
          "session": {
            "id": "session-uuid",
            "startedAt": "2026-01-25T00:00:00Z",
            "endedAt": "2026-01-25T00:30:00Z",
            "title": "Meeting Title",
            "durationMs": 1800000,
            "speakerCount": 2,
            "speakers": [
              {
                "machineSpeakerId": "speaker-0",
                "displayOrder": 1,
                "person": {
                  "id": "person-uuid",
                  "name": "Alice"
                }
              }
            ],
            "transcript": [
              {
                "id": "segment-uuid",
                "startMs": 0,
                "endMs": 5000,
                "text": "Hello, how are you?",
                "speakerId": "speaker-0",
                "confidence": 0.95
              }
            ]
          }
        }
        ```

        ## Markdown Export

        Sessions can be exported as readable Markdown:

        ```markdown
        # Meeting Title

        **Date:** January 25, 2026
        **Duration:** 30 minutes
        **Speakers:** Alice, Bob

        ---

        ## Transcript

        **[00:00] Alice:** Hello, how are you?

        **[00:05] Bob:** I'm doing well, thanks!
        ```

        ## VTT (Web Video Text Tracks) Export

        For video subtitle compatibility:

        ```vtt
        WEBVTT

        00:00:00.000 --> 00:00:05.000
        <v Alice>Hello, how are you?

        00:00:05.000 --> 00:00:10.000
        <v Bob>I'm doing well, thanks!
        ```

        ## Database Tables Used

        Export functionality reads from the following tables:

        """

        for table in allTables {
            output += "- `\(table.name)`"
            let colNames = table.columns.map { $0.name }.joined(separator: ", ")
            output += ": \(colNames)\n"
        }

        return output
    }
}
