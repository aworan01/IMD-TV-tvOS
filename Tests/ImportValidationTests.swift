import XCTest
@testable import IMDTV

final class ImportValidationTests: XCTestCase {
    func testOnlyAbsoluteWebURLsAreAccepted() {
        for value in ["", "   ", "playlist.m3u", "provider.example/list", "file:///tmp/list", "https://"] {
            XCTAssertNil(ImportValidation.webURL(value), value)
        }
        XCTAssertEqual(ImportValidation.webURL("  https://example.com/list?token=a%2Bb  ")?.absoluteString,
                       "https://example.com/list?token=a%2Bb")
    }

    func testBlankOptionalFieldsAreAbsent() throws {
        let payload = try XCTUnwrap(LocalImportServer.payload(from: form([
            "provider": "m3u", "name": "My TV", "playlistURL": "https://example.com/list.m3u",
            "serverURL": "", "epgURL": "", "playlistContent": ""
        ])))
        XCTAssertNil(payload.epgURL)
        XCTAssertNil(payload.serverURL)
        XCTAssertEqual(payload.playlistURL, "https://example.com/list.m3u")
    }

    func testUploadedFileAllowsBOMAndBlankLines() throws {
        let payload = try XCTUnwrap(LocalImportServer.payload(from: form([
            "provider": "m3u", "name": "Local", "playlistURL": "",
            "playlistContent": "\u{FEFF}\r\n #EXTM3U\n#EXTINF:-1,News\nhttps://example.com/live.m3u8\n"
        ])))
        XCTAssertTrue(payload.playlistContent?.hasPrefix("#EXTM3U") == true)
        XCTAssertNil(payload.playlistURL)
    }

    func testMissingSourceAndInvalidGuideAreRejected() {
        XCTAssertNil(LocalImportServer.payload(from: form(["name": "Empty", "playlistURL": ""])))
        XCTAssertNil(LocalImportServer.payload(from: form([
            "name": "TV", "playlistURL": "https://example.com/list", "epgURL": "guide.xml"
        ])))
    }

    func testXtreamDoesNotImportAStaleM3UFileAndPreservesCredentials() throws {
        let payload = try XCTUnwrap(LocalImportServer.payload(from: form([
            "provider": "xtream", "name": "TV", "serverURL": "https://example.com:8080",
            "username": "a+b", "password": "p&=+ word", "playlistContent": "#EXTM3U\nold"
        ])))
        XCTAssertEqual(payload.provider, .xtream)
        XCTAssertNil(payload.playlistContent)
        XCTAssertEqual(payload.username, "a+b")
        XCTAssertEqual(payload.password, "p&=+ word")
    }

    private func form(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics
        return Data(fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").utf8)
    }
}
