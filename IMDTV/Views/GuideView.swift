import SwiftUI

struct GuideView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var category = "All"

    private var channels: [Channel] {
        category == "All" ? library.channels : library.channels.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            List(channels) { channel in
                GuideChannelRow(channel: channel)
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("TV Guide")
            .toolbar {
                ToolbarItem {
                    Menu(category) {
                        Button("All Channels") { category = "All" }
                        ForEach(library.categories, id: \.self) { value in Button(value) { category = value } }
                    }
                }
            }
        }
    }
}

private struct GuideChannelRow: View {
    @EnvironmentObject private var library: LibraryStore
    let channel: Channel

    private var programmes: [Programme] {
        Array(library.programmes.filter { $0.channelID == channel.epgID && $0.end > Date().addingTimeInterval(-1800) }.prefix(8))
    }

    var body: some View {
        HStack(spacing: 18) {
            Button { library.selectedChannel = channel } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: channel.logoURL) { $0.resizable().scaledToFit() } placeholder: { Image(systemName: "tv") }
                        .frame(width: 64, height: 44)
                    Text(channel.name).font(.headline).lineLimit(2)
                    Spacer()
                }
                .frame(width: 260)
                .frame(minHeight: 74)
            }
            .buttonStyle(.bordered)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if programmes.isEmpty {
                        Button("No guide information") { library.selectedChannel = channel }
                            .buttonStyle(.bordered).disabled(true)
                    } else {
                        ForEach(programmes) { programme in
                            Button { library.selectedChannel = channel } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(programme.title).font(.headline).lineLimit(1)
                                    Text(programme.start, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(width: 270, alignment: .leading)
                                .frame(minHeight: 66, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .focusSection()
        }
        .padding(.vertical, 5)
    }
}
