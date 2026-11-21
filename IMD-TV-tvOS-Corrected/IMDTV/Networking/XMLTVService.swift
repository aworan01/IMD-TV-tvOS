import Foundation

final class XMLTVService: NSObject, XMLParserDelegate {
    private var programmes: [Programme] = []
    private var currentElement = ""
    private var text = ""
    private var channel = ""
    private var start: Date?
    private var end: Date?
    private var title = ""
    private var subtitle: String?
    private var detail: String?

    func load(url: URL) async throws -> [Programme] {
        let (data, _) = try await URLSession.shared.data(from: url)
        programmes = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { throw parser.parserError ?? ImportError.invalidResponse }
        return programmes
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName; text = ""
        if elementName == "programme" {
            channel = attributeDict["channel"] ?? ""
            start = parseDate(attributeDict["start"]); end = parseDate(attributeDict["stop"])
            title = ""; subtitle = nil; detail = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "title" { title = value }
        else if elementName == "sub-title" { subtitle = value }
        else if elementName == "desc" { detail = value }
        else if elementName == "programme", let start, let end {
            programmes.append(Programme(id: "\(channel)|\(start.timeIntervalSince1970)", channelID: channel,
                                         title: title, subtitle: subtitle, description: detail, start: start, end: end))
        }
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyyMMddHHmmss Z", "yyyyMMddHHmmss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: String(raw.prefix(format.contains("Z") ? 20 : 14))) { return date }
        }
        return nil
    }
}

