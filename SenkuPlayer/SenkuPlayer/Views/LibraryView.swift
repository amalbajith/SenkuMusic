//
//  LibraryView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Segmented Control
                Picker("Library Section", selection: $selectedTab) {
                    Text("Songs").tag(0)
                    Text("Artists").tag(1)
                    Text("Albums").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                if library.isScanning {
                    ScanningView(progress: library.scanProgress)
                } else {
                    contentView
                }
            }
            .navigationTitle("Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    addButton
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
                #endif
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { urls in
                    library.importFiles(urls)
                }
            }
        }
    }
    
    private var addButton: some View {
        Button {
            showingFilePicker = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0:
            SongsListView(songs: filteredSongs, searchText: searchText)
        case 1:
            ArtistsListView(searchText: searchText)
        case 2:
            AlbumsListView(searchText: searchText)
        default:
            EmptyView()
        }
    }
    
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return library.songs
        } else {
            return library.searchSongs(query: searchText)
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(10)
    }
}

// MARK: - Scanning View
struct ScanningView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)
            
            Text("Importing Music...")
                .font(.headline)
            
            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LibraryView()
}
