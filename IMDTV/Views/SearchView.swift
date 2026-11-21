import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var query = ""
    var results: [Channel] {
        query.isEmpty ? [] : library.channels.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Search").font(.largeTitle.bold())
            TextField("Channels or categories", text: $query).textFieldStyle(.plain).padding(22).glassPanel()
            if query.isEmpty { ContentUnavailableView("Search your library", systemImage: "magnifyingglass", description: Text("Use the remote or dictation to find a channel.")) }
            else if results.isEmpty { ContentUnavailableView.search(text: query) }
            else { ChannelGridView(title: "Results", channels: results) }
        }.padding(.horizontal, 70).padding(.top, 28)
    }
}

