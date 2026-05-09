import { useRef, useState } from 'react';
import {
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  AudioWaveformView,
  type AudioWaveformPlayerStateEvent,
  type AudioWaveformSeekEvent,
  type AudioWaveformTimeUpdateEvent,
  type AudioWaveformViewRef,
} from 'react-native-waveform-player';

const REMOTE_AUDIO =
  'https://drive.usercontent.google.com/download?id=1duTfDMYYEjDWsX0InDgw7szUk46erecg&export=download';

export default function App() {
  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle="dark-content" backgroundColor="#F8FAFC" />
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        <Text style={styles.title}>react-native-waveform-player</Text>
        <Text style={styles.subtitle}>
          Native Fabric audio-message UI — Swift + Kotlin
        </Text>

        <Demo title="1. Default look (uncontrolled)">
          <AudioWaveformView
            source={{ uri: REMOTE_AUDIO }}
            style={styles.waveform}
          />
        </Demo>

        <Demo title="2. Themed + count-down + custom speeds">
          <AudioWaveformView
            source={{ uri: REMOTE_AUDIO }}
            style={styles.waveform}
            containerBackgroundColor="#0F172A"
            containerBorderRadius={20}
            playedBarColor="#22D3EE"
            unplayedBarColor="rgba(34, 211, 238, 0.35)"
            playButtonColor="#22D3EE"
            timeColor="#A5F3FC"
            timeMode="count-down"
            speedColor="#0F172A"
            speedBackgroundColor="#22D3EE"
            speeds={[1, 1.5, 2]}
            defaultSpeed={1.5}
            barWidth={4}
            barGap={3}
          />
        </Demo>

        <ControlledDemo />

        <ImperativeDemo />

        <SamplesDemo />

        <Demo title="6. Hide everything (visualiser only)">
          <AudioWaveformView
            source={{ uri: REMOTE_AUDIO }}
            style={styles.waveform}
            showPlayButton={false}
            showTime={false}
            showSpeedControl={false}
            showBackground={false}
            playedBarColor="#0F172A"
            unplayedBarColor="rgba(15, 23, 42, 0.25)"
          />
        </Demo>

        <Demo title="7. Background playback (playInBackground)">
          <Text style={styles.subtle}>
            Press play, then send the app to the background. Audio keeps playing
            thanks to `playInBackground`. iOS additionally requires the host app
            to enable the Audio Background Mode (already set in this example's
            Info.plist).
          </Text>
          <AudioWaveformView
            source={{ uri: REMOTE_AUDIO }}
            style={styles.waveform}
            playInBackground
            containerBackgroundColor="#1E293B"
          />
        </Demo>

        <EventLogDemo />
      </ScrollView>
    </SafeAreaView>
  );
}

function Demo({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.card}>
      <Text style={styles.cardTitle}>{title}</Text>
      {children}
    </View>
  );
}

function ControlledDemo() {
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const cycle = (current: number) => {
    const speeds = [0.5, 1, 1.5, 2];
    const next = speeds.find((s) => s > current + 0.001);
    return next ?? speeds[0]!;
  };
  return (
    <Demo title="3. Controlled component">
      <Text style={styles.subtle}>
        Parent owns playing + speed; tapping the native UI fires events but does
        not mutate state until you do.
      </Text>
      <AudioWaveformView
        source={{ uri: REMOTE_AUDIO }}
        style={styles.waveform}
        playing={playing}
        speed={speed}
        onPlayerStateChange={(e) => {
          if (e.isPlaying !== playing) setPlaying(e.isPlaying);
          if (e.speed !== speed) setSpeed(e.speed);
        }}
      />
      <View style={styles.row}>
        <Btn
          label={playing ? 'Pause' : 'Play'}
          onPress={() => setPlaying((p) => !p)}
        />
        <Btn label={`${speed}x`} onPress={() => setSpeed((s) => cycle(s))} />
      </View>
    </Demo>
  );
}

function ImperativeDemo() {
  const ref = useRef<AudioWaveformViewRef>(null);
  return (
    <Demo title="4. Imperative ref API">
      <AudioWaveformView
        ref={ref}
        source={{ uri: REMOTE_AUDIO }}
        style={styles.waveform}
        containerBackgroundColor="#7C3AED"
      />
      <View style={styles.row}>
        <Btn label="Play" onPress={() => ref.current?.play()} />
        <Btn label="Pause" onPress={() => ref.current?.pause()} />
        <Btn label="Toggle" onPress={() => ref.current?.toggle()} />
        <Btn label="0:00" onPress={() => ref.current?.seekTo(0)} />
        <Btn label="2x" onPress={() => ref.current?.setSpeed(2)} />
      </View>
    </Demo>
  );
}

const STATIC_SAMPLES: number[] = Array.from({ length: 64 }, (_, i) => {
  const x = i / 64;
  return 0.25 + 0.7 * Math.abs(Math.sin(x * Math.PI * 4));
});

function SamplesDemo() {
  return (
    <Demo title="5. Pre-computed samples (instant render)">
      <Text style={styles.subtle}>
        When `samples` is provided the native decode step is skipped — useful
        when you've already pre-computed peaks server-side.
      </Text>
      <AudioWaveformView
        source={{ uri: REMOTE_AUDIO }}
        samples={STATIC_SAMPLES}
        style={styles.waveform}
        containerBackgroundColor="#16A34A"
      />
    </Demo>
  );
}

function EventLogDemo() {
  const [lines, setLines] = useState<string[]>([]);
  const log = (entry: string) => {
    setLines((prev) => [entry, ...prev].slice(0, 6));
  };
  return (
    <Demo title="8. Event log">
      <AudioWaveformView
        source={{ uri: REMOTE_AUDIO }}
        style={styles.waveform}
        containerBackgroundColor="#F97316"
        onLoad={(e) => log(`onLoad: duration=${e.durationMs}ms`)}
        onLoadError={(e) => log(`onLoadError: ${e.message}`)}
        onPlayerStateChange={(e: AudioWaveformPlayerStateEvent) =>
          log(`state=${e.state} playing=${e.isPlaying} speed=${e.speed}`)
        }
        onTimeUpdate={(e: AudioWaveformTimeUpdateEvent) =>
          log(`time: ${e.currentTimeMs}/${e.durationMs}`)
        }
        onSeek={(e: AudioWaveformSeekEvent) => log(`onSeek: ${e.positionMs}ms`)}
        onEnd={() => log('onEnd')}
      />
      <View style={styles.logBox}>
        {lines.length === 0 ? (
          <Text style={styles.logEmpty}>(events will show here)</Text>
        ) : (
          lines.map((l, i) => (
            <Text key={i} style={styles.logLine}>
              {l}
            </Text>
          ))
        )}
      </View>
    </Demo>
  );
}

function Btn({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.btn, pressed && { opacity: 0.6 }]}
    >
      <Text style={styles.btnText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: '#F8FAFC',
    // RN's built-in `SafeAreaView` only insets on iOS; on Android we manually
    // pad by the status bar height so the title isn't drawn under it.
    paddingTop: Platform.OS === 'android' ? (StatusBar.currentHeight ?? 0) : 0,
  },
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 40,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#0F172A',
    marginBottom: 4,
  },
  subtitle: {
    color: '#475569',
    marginBottom: 16,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 14,
    marginBottom: 14,
    shadowColor: '#000000',
    shadowOpacity: 0.06,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
    elevation: 1,
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#0F172A',
    marginBottom: 10,
  },
  subtle: {
    color: '#64748B',
    fontSize: 12,
    marginBottom: 8,
  },
  waveform: {
    height: 56,
    width: '100%',
  },
  row: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 10,
  },
  btn: {
    backgroundColor: '#0F172A',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 999,
  },
  btnText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '600',
  },
  logBox: {
    backgroundColor: '#0F172A',
    borderRadius: 10,
    padding: 10,
    marginTop: 10,
  },
  logEmpty: {
    color: '#64748B',
    fontFamily: 'Menlo',
    fontSize: 11,
  },
  logLine: {
    color: '#22D3EE',
    fontFamily: 'Menlo',
    fontSize: 11,
    lineHeight: 16,
  },
});
