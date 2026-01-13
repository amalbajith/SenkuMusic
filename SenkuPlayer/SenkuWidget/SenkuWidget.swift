
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

// MARK: - Widget Views

// MARK: - Widget Views

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        // CONTENT ONLY (Background moved to containerBackground)
        VStack(alignment: .leading, spacing: 2) {
            // Status Indicator (Top)
            HStack {
                Spacer()
                if entry.data.isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            // Text Info
            Text(entry.data.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(entry.data.artist)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding(14)
        .widgetBackground(entry.data) // Apply background helper
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        GeometryReader { geo in
            // CONTENT ONLY
            HStack(spacing: 16) {
                // Artwork Box
                if let artworkData = entry.data.artworkData, let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.height - 32, height: geo.size.height - 32)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                } else {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .frame(width: geo.size.height - 32, height: geo.size.height - 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Info Column
                VStack(alignment: .leading, spacing: 4) {
                    if entry.data.isPlaying {
                        Label("Now Playing", systemImage: "beats.headphones")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .textCase(.uppercase)
                            .padding(.bottom, 2)
                    }
                    
                    Text(entry.data.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(entry.data.artist)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    
                    if !entry.data.album.isEmpty {
                        Text(entry.data.album)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .padding(.top, 2)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .widgetBackground(entry.data)
    }
}

// Helper to apply background conditionally based on iOS version
extension View {
    func widgetBackground(_ data: WidgetData) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(for: .widget) {
                WidgetBackgroundView(data: data)
            }
        } else {
            return background(WidgetBackgroundView(data: data))
        }
    }
}

struct WidgetBackgroundView: View {
    let data: WidgetData
    
    var body: some View {
        ZStack {
            if let artworkData = data.artworkData, let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 40)
                    .overlay(Color.black.opacity(0.4))
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemIndigo), Color(UIColor.systemPurple)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
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
