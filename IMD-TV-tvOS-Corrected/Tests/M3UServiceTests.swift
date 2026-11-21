import XCTest
@testable import IMDTV

final class M3UServiceTests: XCTestCase {
    func testParsesChannelAndClearKey() {
        let input = """
        #EXTM3U
        #EXTINF:-1 tvg-id="bbc.one" tvg-logo="https://example.com/logo.png" group-title="News",BBC One
        #KODIPROP:inputstream.adaptive.license_key=001122:ffeedd
        https://example.com/live.m3u8
        """
        let channels = M3UService().parse(input)
        XCTAssertEqual(channels.count, 1)
        XCTAssertEqual(channels[0].name, "BBC One")
        XCTAssertEqual(channels[0].category, "News")
        XCTAssertEqual(channels[0].clearKey?.key, "ffeedd")
    }
}

