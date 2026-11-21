import SwiftUI

struct GuideView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var category = "All"
    private let rowHeight: CGFloat = 86

    var channels: [Channel] { Array((category == "All" ? library.channels : library.channels.filter { $0.category == category }).prefix(80)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TV Guide").font(.largeTitle.bold())
                Spacer()
                Menu(category) { Button("All") { category = "All" }; ForEach(library.categories, id: \.self) { value in Button(value) { category = value } } }
            }
            HStack(spacing: 0) {
                Text("Channel").frame(width: 310, alignment: .leading)
                TimelineHeader().frame(maxWidth: .infinity)
            }.foregroundStyle(.secondary)
            ScrollView(.vertical) {
                LazyVStack(spacing: 3) { ForEach(channels) { channel in GuideRow(channel: channel).frame(height: rowHeight) } }
            }
        }.padding(.horizontal, 64).padding(.top, 28)
    }
}

private struct TimelineHeader: View {
    var body: some View {
        HStack { ForEach(0..<4) { offset in
            Text(Date().addingTimeInterval(Double(offset) * 1800), format: .dateTime.hour().minute()).frame(maxWidth: .infinity, alignment: .leading)
        }}
    }
}

private struct GuideRow: View {
    @EnvironmentObject private var library: LibraryStore
    let channel: Channel
    var items: [Programme] { library.programmes.filter { $0.channelID == channel.epgID && $0.end > Date().addingTimeInterval(-1800) }.prefix(5).map { $0 } }
    var body: some View {
        HStack(spacing: 5) {
            Button { library.selectedChannel = channel } label: {
                HStack { AsyncImage(url: channel.logoURL) { $0.resizable().scaledToFit() } placeholder: { Image(systemName: "tv") }.frame(width: 70); Text(channel.name).lineLimit(1); Spacer() }
                    .padding(.horizontal, 12).frame(width: 310, maxHeight: .infinity)
            }.buttonStyle(.borderless).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            if items.isEmpty { Text("No guide information").foregroundStyle(.secondary).padding().frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12)) }
            else { ForEach(items) { item in
                Button { library.selectedChannel = channel } label: {
                    VStack(alignment: .leading) { Text(item.title).font(.headline).lineLimit(1); Text(item.start, style: .time).font(.caption).foregroundStyle(.secondary) }
                        .padding().frame(minWidth: 250, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }.buttonStyle(.borderless).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }}
        }
    }
}

