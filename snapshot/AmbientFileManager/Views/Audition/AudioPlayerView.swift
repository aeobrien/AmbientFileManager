import SwiftUI

struct AudioPlayerView: View {
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        if player.hasLoadedFile {
            VStack(spacing: 0) {
                Divider()
                playerContent
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
    }

    private var playerContent: some View {
        VStack(spacing: 6) {
            HStack {
                Text(player.currentSampleName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if let error = player.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            progressBar

            HStack(spacing: 12) {
                transportControls
                timeDisplay
                Spacer()
                trimControl
                pitchControls
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 4)
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(in: geo.size.width), height: 4)
            }
            .clipShape(Capsule())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        player.seek(to: fraction * player.duration)
                    }
            )
        }
        .frame(height: 4)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard player.duration > 0 else { return 0 }
        return max(0, min(totalWidth, CGFloat(player.currentTime / player.duration) * totalWidth))
    }

    private var transportControls: some View {
        HStack(spacing: 8) {
            Button { player.stop() } label: {
                Image(systemName: "stop.fill").font(.body)
            }
            .buttonStyle(.plain)
            .disabled(!player.isPlaying && !player.isPaused)

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
            }
            .buttonStyle(.plain)
        }
    }

    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Text(formatTime(player.currentTime))
            Text("/").foregroundStyle(.tertiary)
            Text(formatTime(player.duration))
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
    }

    private var trimControl: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.wave.2")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { player.trimDb },
                set: { player.setTrim($0) }
            ), in: -20...20, step: 0.5)
            .frame(width: 80)
            Text(trimLabel)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(player.trimDb == 0 ? .secondary : .primary)
                .frame(width: 45, alignment: .trailing)
                .onTapGesture { player.setTrim(0) }
        }
    }

    private var trimLabel: String {
        if player.trimDb == 0 {
            return "0 dB"
        }
        return String(format: "%+.1f dB", player.trimDb)
    }

    private var pitchControls: some View {
        HStack(spacing: 2) {
            Button {
                player.shiftPitch(by: -1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Text(pitchLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(player.semitoneOffset == 0 ? .secondary : .primary)
                .frame(width: 30, alignment: .center)
                .onTapGesture { player.resetPitch() }

            Button {
                player.shiftPitch(by: 1)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    private var pitchLabel: String {
        player.semitoneOffset > 0 ? "+\(player.semitoneOffset)" : "\(player.semitoneOffset)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        String(format: "%d:%02d", Int(time) / 60, Int(time) % 60)
    }
}
