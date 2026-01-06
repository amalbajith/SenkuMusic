
import WidgetKit
import SwiftUI

// NOTE: Make sure to add 'WidgetData.swift' to the Widget Target as well!
// Use the File Inspector in Xcode to check the "SenkuWidget" target for WidgetData.swift.

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), data: .empty)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let data = fetchWidgetData()
        let entry = SimpleEntry(date: Date(), data: data)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
    
    private func fetchWidgetData() -> WidgetData {
        guard let userDefaults = UserDefaults(suiteName: WidgetKeys.appGroup) else {
            return .empty
        }
        
        if let data = userDefaults.data(forKey: WidgetKeys.data),
           let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) {
            return decoded
        }
        
        return .empty
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct SenkuWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            // Background
            GeometryReader { geometry in
                if let artworkData = entry.data.artworkData, let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(Color.black.opacity(0.4))
                } else {
                    Color(UIColor.systemGray6)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                
                HStack {
                    if entry.data.isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                
                Text(entry.data.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(entry.data.artist)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding()
        }
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 0) {
            // Artwork
            GeometryReader { geometry in
                if let artworkData = entry.data.artworkData, let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Color(UIColor.systemGray5)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 120)
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                if entry.data.isPlaying {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.accentColor)
                        Text("Now Playing")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(entry.data.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(entry.data.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(entry.data.album)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Lock Screen Views

struct AccessoryRectangularView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack {
            if let artworkData = entry.data.artworkData, let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(4)
            } else {
                Image(systemName: "music.note")
            }
            
            VStack(alignment: .leading) {
                Text(entry.data.title)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(entry.data.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

struct AccessoryCircularView: View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.data.isPlaying {
                Image(systemName: "waveform")
                    .font(.title2)
                    .widgetAccentable()
            } else {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .widgetAccentable()
            }
        }
    }
}

struct AccessoryInlineView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Text("\(entry.data.title) • \(entry.data.artist)")
    }
}

struct SenkuWidget: Widget {
    let kind: String = "SenkuWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                SenkuWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                SenkuWidgetEntryView(entry: entry)
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the currently playing song.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
