import Testing
import Foundation
@testable import Processing

// MARK: - DiarizationMapping Tests

@Suite("DiarizationMapping")
struct DiarizationMappingTests {

    // Use String IDs for simplicity in tests
    typealias Interval = DiarizationMapping.TranscriptInterval<String>
    typealias Assignment = DiarizationMapping.SpeakerAssignment<String>
    typealias Segment = DiarizationMapping.SpeakerSegment

    // MARK: - computeOverlap

    @Suite("computeOverlap")
    struct ComputeOverlapTests {
        @Test func fullyOverlapping() {
            // Interval A fully contains B
            let overlap = DiarizationMapping.computeOverlap(
                aStart: 0, aEnd: 10, bStart: 2, bEnd: 8
            )
            #expect(overlap == 6.0)
        }

        @Test func partialOverlap() {
            let overlap = DiarizationMapping.computeOverlap(
                aStart: 0, aEnd: 5, bStart: 3, bEnd: 10
            )
            #expect(overlap == 2.0)
        }

        @Test func noOverlap() {
            let overlap = DiarizationMapping.computeOverlap(
                aStart: 0, aEnd: 5, bStart: 6, bEnd: 10
            )
            #expect(overlap == 0.0)
        }

        @Test func adjacentIntervals() {
            // Intervals touch at boundary but don't overlap
            let overlap = DiarizationMapping.computeOverlap(
                aStart: 0, aEnd: 5, bStart: 5, bEnd: 10
            )
            #expect(overlap == 0.0)
        }

        @Test func identicalIntervals() {
            let overlap = DiarizationMapping.computeOverlap(
                aStart: 2, aEnd: 7, bStart: 2, bEnd: 7
            )
            #expect(overlap == 5.0)
        }

        @Test func zeroLengthInterval() {
            let overlap = DiarizationMapping.computeOverlap(
                aStart: 5, aEnd: 5, bStart: 0, bEnd: 10
            )
            #expect(overlap == 0.0)
        }
    }

    // MARK: - Simple Overlap

    @Suite("Simple overlap mapping")
    struct SimpleOverlapTests {
        @Test func singleIntervalSingleSpeaker() {
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 5),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 5),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments.count == 1)
            #expect(result.assignments[0].speakerId == "spk_0")
            #expect(result.assignments[0].overlapSeconds == 5.0)
        }

        @Test func intervalPartiallyOverlapsSpeaker() {
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 2, endTimeSeconds: 7),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 5),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == "spk_0")
            #expect(result.assignments[0].overlapSeconds == 3.0)
        }

        @Test func multipleSpeakersOneWins() {
            // Transcript interval 0-10s
            // spk_0 covers 0-3s (3s overlap)
            // spk_1 covers 2-10s (8s overlap)
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 10),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 3),
                Segment(speakerId: "spk_1", startTimeSeconds: 2, endTimeSeconds: 10),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == "spk_1")
            #expect(result.assignments[0].overlapSeconds == 8.0)
        }
    }

    // MARK: - Tie Overlap

    @Suite("Tie overlap handling")
    struct TieOverlapTests {
        @Test func equalOverlapPicksLexicographicallySmaller() {
            // Both speakers have exactly 5s overlap with the transcript interval
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 10),
            ]
            let speakers = [
                Segment(speakerId: "spk_b", startTimeSeconds: 0, endTimeSeconds: 5),
                Segment(speakerId: "spk_a", startTimeSeconds: 5, endTimeSeconds: 10),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            // spk_a < spk_b lexicographically, so spk_a wins the tie
            #expect(result.assignments[0].speakerId == "spk_a")
            #expect(result.assignments[0].overlapSeconds == 5.0)
        }

        @Test func tieBreakingIsDeterministic() {
            // Run the same mapping multiple times to verify determinism
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 10),
            ]
            let speakers = [
                Segment(speakerId: "charlie", startTimeSeconds: 0, endTimeSeconds: 5),
                Segment(speakerId: "alpha", startTimeSeconds: 5, endTimeSeconds: 10),
                Segment(speakerId: "bravo", startTimeSeconds: 2, endTimeSeconds: 7),
            ]

            // All three overlap equally (5s each)
            var results: [String?] = []
            for _ in 0..<10 {
                let result = DiarizationMapping.mapSpeakers(
                    intervals: intervals, speakerSegments: speakers
                )
                results.append(result.assignments[0].speakerId)
            }

            // All results should be the same (deterministic)
            let allSame = results.allSatisfy { $0 == results[0] }
            #expect(allSame, "Tie-breaking must be deterministic across runs")
            #expect(results[0] == "alpha", "Lexicographically smallest speaker wins ties")
        }

        @Test func tieWithTwoSpeakersMultipleSegments() {
            // spk_0 has two segments adding to 4s overlap
            // spk_1 has one segment with 4s overlap
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 10),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 2),
                Segment(speakerId: "spk_0", startTimeSeconds: 8, endTimeSeconds: 10),
                Segment(speakerId: "spk_1", startTimeSeconds: 3, endTimeSeconds: 7),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            // Both have 4s total overlap; spk_0 < spk_1 lexicographically
            #expect(result.assignments[0].speakerId == "spk_0")
            #expect(result.assignments[0].overlapSeconds == 4.0)
        }
    }

    // MARK: - No Overlap

    @Suite("No overlap handling")
    struct NoOverlapTests {
        @Test func noSpeakerSegmentsReturnsNil() {
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 5),
            ]
            let speakers: [Segment] = []

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == nil)
            #expect(result.assignments[0].overlapSeconds == 0)
        }

        @Test func speakersBeforeTranscriptInterval() {
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 10, endTimeSeconds: 15),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 5),
                Segment(speakerId: "spk_1", startTimeSeconds: 5, endTimeSeconds: 9),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == nil)
            #expect(result.assignments[0].overlapSeconds == 0)
        }

        @Test func speakersAfterTranscriptInterval() {
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 5),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 10, endTimeSeconds: 15),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == nil)
        }

        @Test func mixOfOverlappingAndNonOverlapping() {
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 3),
                Interval(id: "seg2", startTimeSeconds: 5, endTimeSeconds: 8),
                Interval(id: "seg3", startTimeSeconds: 20, endTimeSeconds: 25),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 4),
                Segment(speakerId: "spk_1", startTimeSeconds: 4, endTimeSeconds: 9),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == "spk_0")
            #expect(result.assignments[1].speakerId == "spk_1")
            #expect(result.assignments[2].speakerId == nil, "No speaker segment covers 20-25s")
        }
    }

    // MARK: - Multiple Speakers

    @Suite("Multiple speakers")
    struct MultipleSpeakersTests {
        @Test func threeSpeakersAlternating() {
            let intervals = [
                Interval(id: "s1", startTimeSeconds: 0, endTimeSeconds: 3),
                Interval(id: "s2", startTimeSeconds: 3, endTimeSeconds: 6),
                Interval(id: "s3", startTimeSeconds: 6, endTimeSeconds: 9),
                Interval(id: "s4", startTimeSeconds: 9, endTimeSeconds: 12),
                Interval(id: "s5", startTimeSeconds: 12, endTimeSeconds: 15),
                Interval(id: "s6", startTimeSeconds: 15, endTimeSeconds: 18),
            ]
            let speakers = [
                Segment(speakerId: "alice", startTimeSeconds: 0, endTimeSeconds: 3),
                Segment(speakerId: "bob", startTimeSeconds: 3, endTimeSeconds: 6),
                Segment(speakerId: "carol", startTimeSeconds: 6, endTimeSeconds: 9),
                Segment(speakerId: "alice", startTimeSeconds: 9, endTimeSeconds: 12),
                Segment(speakerId: "bob", startTimeSeconds: 12, endTimeSeconds: 15),
                Segment(speakerId: "carol", startTimeSeconds: 15, endTimeSeconds: 18),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == "alice")
            #expect(result.assignments[1].speakerId == "bob")
            #expect(result.assignments[2].speakerId == "carol")
            #expect(result.assignments[3].speakerId == "alice")
            #expect(result.assignments[4].speakerId == "bob")
            #expect(result.assignments[5].speakerId == "carol")
        }

        @Test func overlappingSpeakerSegments() {
            // Speaker segments overlap each other (realistic diarization output)
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 5),
            ]
            let speakers = [
                // spk_0 has 3s overlap (0-3)
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 3),
                // spk_1 has 4s overlap (1-5)
                Segment(speakerId: "spk_1", startTimeSeconds: 1, endTimeSeconds: 5),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == "spk_1")
            #expect(result.assignments[0].overlapSeconds == 4.0)
        }

        @Test func sameSpeakerMultipleSegments() {
            // Same speaker has multiple segments that collectively win
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 10),
            ]
            let speakers = [
                // spk_0: 2s + 2s = 4s total overlap
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 2),
                Segment(speakerId: "spk_0", startTimeSeconds: 8, endTimeSeconds: 10),
                // spk_1: 3s total overlap
                Segment(speakerId: "spk_1", startTimeSeconds: 3, endTimeSeconds: 6),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == "spk_0")
            #expect(result.assignments[0].overlapSeconds == 4.0)
        }
    }

    // MARK: - Display Order

    @Suite("Display order")
    struct DisplayOrderTests {
        @Test func displayOrderByFirstAppearance() {
            let intervals = [
                Interval(id: "s1", startTimeSeconds: 0, endTimeSeconds: 3),
                Interval(id: "s2", startTimeSeconds: 3, endTimeSeconds: 6),
                Interval(id: "s3", startTimeSeconds: 6, endTimeSeconds: 9),
            ]
            let speakers = [
                Segment(speakerId: "bob", startTimeSeconds: 0, endTimeSeconds: 3),
                Segment(speakerId: "alice", startTimeSeconds: 3, endTimeSeconds: 6),
                Segment(speakerId: "bob", startTimeSeconds: 6, endTimeSeconds: 9),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            // bob appears first in assignments, so gets order 1
            #expect(result.displayOrders["bob"] == 1)
            #expect(result.displayOrders["alice"] == 2)
        }

        @Test func displayOrderExcludesNilSpeakers() {
            let intervals = [
                Interval(id: "s1", startTimeSeconds: 0, endTimeSeconds: 3),
                Interval(id: "s2", startTimeSeconds: 10, endTimeSeconds: 13),  // no overlap
                Interval(id: "s3", startTimeSeconds: 3, endTimeSeconds: 6),
            ]
            let speakers = [
                Segment(speakerId: "spk_1", startTimeSeconds: 0, endTimeSeconds: 3),
                Segment(speakerId: "spk_0", startTimeSeconds: 3, endTimeSeconds: 6),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[1].speakerId == nil, "Middle interval has no overlap")
            #expect(result.displayOrders.count == 2, "Only 2 speakers should have orders")
            #expect(result.displayOrders["spk_1"] == 1, "spk_1 appears first")
            #expect(result.displayOrders["spk_0"] == 2, "spk_0 appears second")
        }

        @Test func displayOrderDeterministicForSameInput() {
            let intervals = [
                Interval(id: "s1", startTimeSeconds: 0, endTimeSeconds: 5),
                Interval(id: "s2", startTimeSeconds: 5, endTimeSeconds: 10),
                Interval(id: "s3", startTimeSeconds: 10, endTimeSeconds: 15),
            ]
            let speakers = [
                Segment(speakerId: "spk_2", startTimeSeconds: 0, endTimeSeconds: 5),
                Segment(speakerId: "spk_0", startTimeSeconds: 5, endTimeSeconds: 10),
                Segment(speakerId: "spk_1", startTimeSeconds: 10, endTimeSeconds: 15),
            ]

            let result1 = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )
            let result2 = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result1.displayOrders == result2.displayOrders)
            #expect(result1.assignments == result2.assignments)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge cases")
    struct EdgeCaseTests {
        @Test func emptyIntervals() {
            let intervals: [Interval] = []
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 5),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments.isEmpty)
            #expect(result.displayOrders.isEmpty)
        }

        @Test func emptyBothInputs() {
            let result = DiarizationMapping.mapSpeakers(
                intervals: [Interval](), speakerSegments: [Segment]()
            )

            #expect(result.assignments.isEmpty)
            #expect(result.displayOrders.isEmpty)
        }

        @Test func veryShortOverlap() {
            // Transcript interval barely overlaps with a speaker segment
            let intervals = [
                Interval(id: "seg1", startTimeSeconds: 4.99, endTimeSeconds: 5.01),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 5.0),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments[0].speakerId == "spk_0")
            // Overlap = min(5.01, 5.0) - max(4.99, 0) = 5.0 - 4.99 = 0.01
            #expect(result.assignments[0].overlapSeconds > 0)
        }

        @Test func assignmentPreservesIntervalOrder() {
            let intervals = [
                Interval(id: "third", startTimeSeconds: 10, endTimeSeconds: 15),
                Interval(id: "first", startTimeSeconds: 0, endTimeSeconds: 5),
                Interval(id: "second", startTimeSeconds: 5, endTimeSeconds: 10),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 15),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            // Assignments should be in the same order as input intervals
            #expect(result.assignments[0].intervalId == "third")
            #expect(result.assignments[1].intervalId == "first")
            #expect(result.assignments[2].intervalId == "second")
        }
    }

    // MARK: - assignSpeaker (single interval)

    @Suite("assignSpeaker single interval")
    struct AssignSpeakerTests {
        @Test func singleSpeakerOverlap() {
            let interval = Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 5)
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 1, endTimeSeconds: 4),
            ]

            let assignment = DiarizationMapping.assignSpeaker(
                to: interval, from: speakers
            )

            #expect(assignment.speakerId == "spk_0")
            #expect(assignment.overlapSeconds == 3.0)
            #expect(assignment.intervalId == "seg1")
        }

        @Test func noOverlapReturnsNil() {
            let interval = Interval(id: "seg1", startTimeSeconds: 0, endTimeSeconds: 5)
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 10, endTimeSeconds: 15),
            ]

            let assignment = DiarizationMapping.assignSpeaker(
                to: interval, from: speakers
            )

            #expect(assignment.speakerId == nil)
            #expect(assignment.overlapSeconds == 0)
        }
    }

    // MARK: - findDominantSpeaker

    @Suite("findDominantSpeaker")
    struct FindDominantSpeakerTests {
        @Test func singleSpeaker() {
            let segments = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 10),
            ]
            #expect(DiarizationMapping.findDominantSpeaker(in: segments) == "spk_0")
        }

        @Test func longerSpeakerWins() {
            let segments = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 3),
                Segment(speakerId: "spk_1", startTimeSeconds: 3, endTimeSeconds: 10),
            ]
            #expect(DiarizationMapping.findDominantSpeaker(in: segments) == "spk_1")
        }

        @Test func dominantWithTieBreaksLexicographically() {
            let segments = [
                Segment(speakerId: "beta", startTimeSeconds: 0, endTimeSeconds: 5),
                Segment(speakerId: "alpha", startTimeSeconds: 5, endTimeSeconds: 10),
            ]
            // Both have 5s duration; alpha < beta lexicographically
            #expect(DiarizationMapping.findDominantSpeaker(in: segments) == "alpha")
        }

        @Test func emptySegments() {
            #expect(DiarizationMapping.findDominantSpeaker(in: []) == nil)
        }
    }

    // MARK: - assignDisplayOrders

    @Suite("assignDisplayOrders")
    struct AssignDisplayOrdersTests {
        @Test func ordersAssignedByDiscovery() {
            let orders = DiarizationMapping.assignDisplayOrders(
                speakerIds: ["c", "a", "b", "a", "c"]
            )
            #expect(orders == ["c": 1, "a": 2, "b": 3])
        }

        @Test func emptyInput() {
            let orders = DiarizationMapping.assignDisplayOrders(speakerIds: [])
            #expect(orders.isEmpty)
        }

        @Test func singleSpeaker() {
            let orders = DiarizationMapping.assignDisplayOrders(speakerIds: ["only"])
            #expect(orders == ["only": 1])
        }
    }

    // MARK: - Realistic Scenario

    @Suite("Realistic scenario")
    struct RealisticScenarioTests {
        @Test func twoSpeakerConversation() {
            // Simulate a realistic two-speaker conversation:
            // Person A speaks 0-3s, person B speaks 3-7s, A speaks 7-10s
            // Transcript segments are slightly misaligned (common in ASR output)
            let intervals = [
                Interval(id: "t1", startTimeSeconds: 0.1, endTimeSeconds: 2.8),
                Interval(id: "t2", startTimeSeconds: 3.2, endTimeSeconds: 6.9),
                Interval(id: "t3", startTimeSeconds: 7.1, endTimeSeconds: 9.8),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0.0, endTimeSeconds: 3.0),
                Segment(speakerId: "spk_1", startTimeSeconds: 3.0, endTimeSeconds: 7.0),
                Segment(speakerId: "spk_0", startTimeSeconds: 7.0, endTimeSeconds: 10.0),
            ]

            let result = DiarizationMapping.mapSpeakers(
                intervals: intervals, speakerSegments: speakers
            )

            #expect(result.assignments.count == 3)
            #expect(result.assignments[0].speakerId == "spk_0")
            #expect(result.assignments[1].speakerId == "spk_1")
            #expect(result.assignments[2].speakerId == "spk_0")

            // Display orders: spk_0 appears first
            #expect(result.displayOrders["spk_0"] == 1)
            #expect(result.displayOrders["spk_1"] == 2)
        }

        @Test func mappingIsReproducible() {
            // Verify that the same inputs always produce the same output
            let intervals = [
                Interval(id: "t1", startTimeSeconds: 0, endTimeSeconds: 5),
                Interval(id: "t2", startTimeSeconds: 5, endTimeSeconds: 10),
                Interval(id: "t3", startTimeSeconds: 10, endTimeSeconds: 15),
                Interval(id: "t4", startTimeSeconds: 15, endTimeSeconds: 20),
            ]
            let speakers = [
                Segment(speakerId: "spk_0", startTimeSeconds: 0, endTimeSeconds: 6),
                Segment(speakerId: "spk_1", startTimeSeconds: 4, endTimeSeconds: 12),
                Segment(speakerId: "spk_2", startTimeSeconds: 11, endTimeSeconds: 20),
            ]

            let results = (0..<5).map { _ in
                DiarizationMapping.mapSpeakers(
                    intervals: intervals, speakerSegments: speakers
                )
            }

            // All results should be identical
            for i in 1..<results.count {
                #expect(results[i].assignments == results[0].assignments)
                #expect(results[i].displayOrders == results[0].displayOrders)
            }
        }
    }
}
