import TVServices

final class TopShelfProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        let item = TVTopShelfSectionedItem(identifier: "open-live")
        item.title = "Open Live TV"
        item.displayAction = TVTopShelfAction(url: URL(string: "imdtv://live")!)
        let section = TVTopShelfItemCollection(items: [item])
        section.title = "IMD TV"
        completionHandler(TVTopShelfSectionedContent(sections: [section]))
    }
}

