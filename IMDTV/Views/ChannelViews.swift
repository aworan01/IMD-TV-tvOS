import SwiftUI

struct LiveView: View {
    @Environment(\.imdPalette) private var palette
    @EnvironmentObject private var library: LibraryStore
    @State private var category = "All"
    var filtered: [Channel] { category == "All" ? library.channels : library.channels.filter { $0.category == category } }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Live TV").font(.title.bold())
                Spacer()
                Text(Date(), style: .time).font(.title3.monospacedDigit()).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(["All"] + library.categories, id: \.self) { item in
                    Button(item) { category = item }
                        .buttonStyle(.bordered).tint(category == item ? palette.accent : .gray)
                }}
            }
            ChannelGridView(title: category, channels: filtered)
        }.padding(.horizontal, 70).padding(.top, 28)
    }
}

struct ChannelGridView: View {
    @EnvironmentObject private var library: LibraryStore
    let title: String
    let channels: [Channel]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 28), count: 5)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(channels) { channel in ChannelCard(channel: channel).onTapGesture { library.selectedChannel = channel } }
            }.padding(.vertical, 22)
        }
    }
}

struct ChannelCard: View {
    @Environment(\.imdPalette) private var palette
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.isFocused) private var isFocused
    let channel: Channel

    var body: some View {
        Button { library.selectedChannel = channel } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: palette.radius).fill(palette.card)
                    AsyncImage(url: channel.logoURL) { image in image.resizable().scaledToFit() }
                        placeholder: { Image(systemName: "tv").font(.system(size: 54)).foregroundStyle(.secondary) }
                        .padding(24)
                }.aspectRatio(16/10, contentMode: .fit)
                Text(channel.name).font(.headline).lineLimit(1)
                Text(library.nowPlaying(on: channel)?.title ?? channel.category).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }.buttonStyle(.card)
        .contextMenu {
            Button { library.toggleFavourite(channel) } label: {
                Label(library.isFavourite(channel) ? "Remove Favourite" : "Add Favourite", systemImage: library.isFavourite(channel) ? "heart.slash" : "heart")
            }
        }
    }
}

