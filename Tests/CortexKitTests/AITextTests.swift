import Testing
@testable import CortexAI

@Suite("AIText")
struct AITextTests {
    @Test func stripsLanguageFence() {
        let input = "```sql\nSELECT 1;\n```"
        #expect(AIText.stripFences(input) == "SELECT 1;")
    }

    @Test func stripsBareFence() {
        #expect(AIText.stripFences("```\nhello\n```") == "hello")
    }

    @Test func leavesUnfencedTextAlone() {
        #expect(AIText.stripFences("  plain text  ") == "plain text")
    }

    @Test func firstMeaningfulLineSkipsBlanksAndFences() {
        let raw = "\n```\nfeat: add thing\n```\n"
        #expect(AIText.firstMeaningfulLine(raw) == "feat: add thing")
    }

    @Test func firstMeaningfulLineStripsQuotes() {
        #expect(AIText.firstMeaningfulLine("\"fix: bug\"") == "fix: bug")
    }

    @Test func truncatedAddsMarkerWhenOverLimit() {
        let out = AIText.truncated(String(repeating: "x", count: 50), to: 10)
        #expect(out.hasPrefix("xxxxxxxxxx"))
        #expect(out.contains("truncated"))
    }

    @Test func truncatedLeavesShortTextUntouched() {
        #expect(AIText.truncated("short", to: 100) == "short")
    }
}

@Suite("AICLI")
struct AICLITests {
    @Test func claudeArguments() {
        #expect(AICLI.claude.arguments(for: "hi") == ["-p", "hi"])
    }

    @Test func codexArgumentsAreQuiet() {
        #expect(AICLI.codex.arguments(for: "hi") == ["exec", "-q", "hi"])
    }

    @Test func allCasesHaveInstallHints() {
        for cli in AICLI.allCases {
            #expect(!cli.installHint.isEmpty)
            #expect(!cli.displayName.isEmpty)
        }
    }
}
