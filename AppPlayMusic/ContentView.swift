import SwiftUI
import Foundation
import AVKit
struct LyricLine {
    var text: String
    var time: Double
}

class LyricViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var lyricLines: [LyricLine] = []
    
    private var player: AVPlayer?
     private var timeObserver: Any?

    let lyricsXMLURL = URL(string: "https://storage.googleapis.com/ikara-storage/ikara/lyrics.xml")!
    func playPauseAudio() {
        if isPlaying {
            pauseAudio()
        } else {
            if player == nil {
                let url = URL(string: "https://storage.googleapis.com/ikara-storage/tmp/beat.mp3")!
                let playerItem = AVPlayerItem(url: url)
                player = AVPlayer(playerItem: playerItem)
                player?.play()
                observePlayerTime()
                observePlayerDuration()
            } else {
                player?.play()
            }
        }
        isPlaying.toggle()
    }
    func loadLyrics() {
        let task = URLSession.shared.dataTask(with: lyricsXMLURL) { data, response, error in
            guard let data = data else {
                print("No data received: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            DispatchQueue.main.async {
                let parser = XMLParser(data: data)
                parser.delegate = self
                parser.parse()
            }
        }
        task.resume()
    }
    private func observePlayerDuration() {
        guard let playerItem = player?.currentItem else { return }
        playerItem.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                let duration = playerItem.asset.duration
                let durationSeconds = CMTimeGetSeconds(duration)
                if durationSeconds.isFinite && durationSeconds > 0 {
                    self?.duration = durationSeconds
                }
            }
        }
    }
    private func updateProgress() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { time in
            self.currentTime = time.seconds
        }
    }

    
    private func pauseAudio() {
        player?.pause()
    }
    
    private func observePlayerTime() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
    

    
    func seek(to time: Double) {
        let targetTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: targetTime)
    }
}

extension LyricViewModel: XMLParserDelegate {
    func parserDidStartDocument(_ parser: XMLParser) {
        print("Started parsing document")
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Error parsing XML: \(parseError.localizedDescription)")
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "i", let timeString = attributeDict["va"], let time = Double(timeString) {
            let newLine = LyricLine(text: "", time: time)
            self.lyricLines.append(newLine)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !lyricLines.isEmpty {
            var lastLine = lyricLines.removeLast()
            lastLine.text += string.trimmingCharacters(in: .whitespacesAndNewlines)
            lyricLines.append(lastLine)
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        print("Finished parsing document")
    }
}


struct ContentView: View {
    @StateObject private var viewModel = LyricViewModel()
    @State private var isPlaying = false
    private var timeObserver: Any?

    var body: some View {
        ZStack {
            Color.pink
                .ignoresSafeArea(.all)
            VStack {
                if viewModel.lyricLines.isEmpty {
                    // Hiển thị màn hình tải dữ liệu
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    // Hiển thị các dòng lời bài hát trong ScrollView
                    Spacer()
                        .frame(height: 100)
                    ScrollView() {
                        VStack {
                            ForEach(viewModel.lyricLines.indices, id: \.self) { index in
                                HStack {
                                    Text(viewModel.lyricLines[index].text)
                                        .foregroundColor(viewModel.currentTime >= viewModel.lyricLines[index].time ? .blue : .black)
                                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTime)
                                }
                                .frame(width: 100)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                    Spacer()
                    if viewModel.duration > 0 {
                        HStack(alignment: .center) {
                            Text("\((0 + viewModel.currentTime) / 60 )")
                            Slider(value: $viewModel.currentTime, in: 0...viewModel.duration, step: 1, onEditingChanged: { editing in
                                if !editing {
                                    viewModel.seek(to: viewModel.currentTime)
                                }
                            })
                            .padding(.horizontal)
                            .accentColor(.blue)
                            Text("\((viewModel.duration - viewModel.currentTime) / 60 )")
                        }
                    } else {
                        ProgressView()
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        viewModel.playPauseAudio()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                    }
                    .padding()
                }
            }
            .onAppear {
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
                } catch {
                    print("Setting category to AVAudioSessionCategoryPlayback failed.")
                }
                self.viewModel.loadLyrics()
            }
        }
    }

}


