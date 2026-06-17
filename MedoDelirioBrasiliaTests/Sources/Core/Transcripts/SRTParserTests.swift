//
//  SRTParserTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 17/06/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct SRTParserTests {

    // MARK: - parse

    @Test
    func parse_withSingleValidCue_shouldReturnOneCue() {
        let content = """
        1
        00:00:01,000 --> 00:00:04,000
        Hello world
        """

        let cues = SRTParser.parse(content)

        #expect(cues.count == 1)
        #expect(cues[0].index == 1)
        #expect(cues[0].startTime == 1.0)
        #expect(cues[0].endTime == 4.0)
        #expect(cues[0].text == "Hello world")
    }

    @Test
    func parse_withMultipleCues_shouldReturnAllInOrder() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        First

        2
        00:00:03,000 --> 00:00:04,000
        Second
        """

        let cues = SRTParser.parse(content)

        #expect(cues.count == 2)
        #expect(cues[0].text == "First")
        #expect(cues[1].text == "Second")
    }

    @Test
    func parse_withCRLFLineEndings_shouldParseCorrectly() {
        let content = "1\r\n00:00:01,000 --> 00:00:02,000\r\nWindows line endings"

        let cues = SRTParser.parse(content)

        #expect(cues.count == 1)
        #expect(cues[0].text == "Windows line endings")
    }

    @Test
    func parse_withMultiLineCueText_shouldJoinLines() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        Line one
        Line two
        """

        let cues = SRTParser.parse(content)

        #expect(cues.count == 1)
        #expect(cues[0].text == "Line one\nLine two")
    }

    @Test
    func parse_withHoursMinutesAndMillis_shouldComputeTimeInterval() {
        let content = """
        1
        01:02:03,500 --> 01:02:04,000
        Timed
        """

        let cues = SRTParser.parse(content)

        // 1h + 2m + 3s + 500ms = 3600 + 120 + 3 + 0.5
        #expect(cues[0].startTime == 3723.5)
    }

    @Test
    func parse_withEmptyString_shouldReturnNoCues() {
        #expect(SRTParser.parse("").isEmpty)
    }

    @Test
    func parse_withNonNumericIndex_shouldSkipBlock() {
        let content = """
        not-a-number
        00:00:01,000 --> 00:00:02,000
        Ignored
        """

        #expect(SRTParser.parse(content).isEmpty)
    }

    @Test
    func parse_withMalformedTimestamp_shouldSkipBlock() {
        let content = """
        1
        00:00:01 --> 00:00:02
        No millis separator
        """

        #expect(SRTParser.parse(content).isEmpty)
    }

    @Test
    func parse_withMissingTextLine_shouldSkipBlock() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        """

        #expect(SRTParser.parse(content).isEmpty)
    }

    @Test
    func parse_withValidAndInvalidBlocks_shouldKeepOnlyValid() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        Valid

        garbage block

        2
        00:00:03,000 --> 00:00:04,000
        Also valid
        """

        let cues = SRTParser.parse(content)

        #expect(cues.count == 2)
        #expect(cues.map(\.text) == ["Valid", "Also valid"])
    }

    // MARK: - plainText

    @Test
    func plainText_shouldJoinCueTextWithSpaces() {
        let content = """
        1
        00:00:01,000 --> 00:00:02,000
        First

        2
        00:00:03,000 --> 00:00:04,000
        Second
        """

        #expect(SRTParser.plainText(from: content) == "First Second")
    }

    @Test
    func plainText_withEmptyContent_shouldReturnEmptyString() {
        #expect(SRTParser.plainText(from: "").isEmpty)
    }
}
