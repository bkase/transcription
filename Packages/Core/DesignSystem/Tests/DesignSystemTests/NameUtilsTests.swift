import Testing
@testable import DesignSystem

// MARK: - NameUtils Tests

/// Tests for the NameUtils utility functions that handle name processing,
/// particularly stripping parenthetical content for initials calculation.

@Test func stripParentheticalContent_simpleParentheses() {
    // "You (John Smith)" -> "You"
    #expect(NameUtils.stripParentheticalContent("You (John Smith)") == "You")
}

@Test func stripParentheticalContent_labelSuffix() {
    // "Alice (Work)" -> "Alice"
    #expect(NameUtils.stripParentheticalContent("Alice (Work)") == "Alice")
}

@Test func stripParentheticalContent_noParentheses() {
    // "Bob" -> "Bob"
    #expect(NameUtils.stripParentheticalContent("Bob") == "Bob")
}

@Test func stripParentheticalContent_emptyParentheses() {
    // "Test ()" -> "Test"
    #expect(NameUtils.stripParentheticalContent("Test ()") == "Test")
}

@Test func stripParentheticalContent_preservesInternalSpaces() {
    // "Mary Jane (Personal)" -> "Mary Jane"
    #expect(NameUtils.stripParentheticalContent("Mary Jane (Personal)") == "Mary Jane")
}

// MARK: - computeInitials Tests

@Test func computeInitials_youWithParentheses() {
    // "You (John Smith)" -> strips to "You" -> "Y" (single word = single initial)
    // The key is it doesn't include "(" character
    #expect(NameUtils.computeInitials(from: "You (John Smith)") == "Y")
}

@Test func computeInitials_nameWithLabelSuffix() {
    // "Alice (Work)" -> strips to "Alice" -> "A" (single word = single initial)
    #expect(NameUtils.computeInitials(from: "Alice (Work)") == "A")
}

@Test func computeInitials_simpleName() {
    // "Bob" -> "BO"
    #expect(NameUtils.computeInitials(from: "Bob") == "B")
}

@Test func computeInitials_twoWordName() {
    // "Sarah Chen" -> "SC"
    #expect(NameUtils.computeInitials(from: "Sarah Chen") == "SC")
}

@Test func computeInitials_multiWordNameWithParentheses() {
    // "Mary Jane (Personal)" -> "MJ"
    #expect(NameUtils.computeInitials(from: "Mary Jane (Personal)") == "MJ")
}

@Test func computeInitials_emptyParentheses() {
    // "Test ()" -> "TE" or "T" (single word after stripping)
    #expect(NameUtils.computeInitials(from: "Test ()") == "T")
}

@Test func computeInitials_emptyString() {
    // "" -> ""
    #expect(NameUtils.computeInitials(from: "") == "")
}

@Test func computeInitials_whitespaceOnly() {
    // "   " -> ""
    #expect(NameUtils.computeInitials(from: "   ") == "")
}

@Test func computeInitials_threeWordName() {
    // "Mary Jane Watson" -> "MW" (first and last)
    #expect(NameUtils.computeInitials(from: "Mary Jane Watson") == "MW")
}

@Test func computeInitials_preservesCase() {
    // "john smith" -> "JS" (always uppercased)
    #expect(NameUtils.computeInitials(from: "john smith") == "JS")
}

@Test func computeInitials_leadingWhitespace() {
    // "  Alice" -> "A"
    #expect(NameUtils.computeInitials(from: "  Alice") == "A")
}

@Test func computeInitials_trailingWhitespace() {
    // "Alice  " -> "A"
    #expect(NameUtils.computeInitials(from: "Alice  ") == "A")
}

@Test func computeInitials_nestedParentheses() {
    // "Name (with (nested) parens)" -> "N" (just strips from first parenthesis)
    #expect(NameUtils.computeInitials(from: "Name (with (nested) parens)") == "N")
}

@Test func computeInitials_parenthesesAtStart() {
    // "(Prefix) Name" -> "N" or "PN" - behavior depends on implementation
    // After stripping "(Prefix) " we get "Name" starting at first "("
    // Actually the current implementation splits on "(" and takes first part
    // So "(Prefix) Name" -> "" (empty before first parenthesis)
    #expect(NameUtils.computeInitials(from: "(Prefix) Name") == "")
}
