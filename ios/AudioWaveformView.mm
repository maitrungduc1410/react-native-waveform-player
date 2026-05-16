#import "AudioWaveformView.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/AudioWaveformViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/AudioWaveformViewSpec/EventEmitters.h>
#import <react/renderer/components/AudioWaveformViewSpec/Props.h>
#import <react/renderer/components/AudioWaveformViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#if __has_include(<AudioWaveform/AudioWaveform-Swift.h>)
#import <AudioWaveform/AudioWaveform-Swift.h>
#else
#import "AudioWaveform-Swift.h"
#endif

using namespace facebook::react;

@implementation AudioWaveformView {
  AudioWaveformViewImpl *_impl;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<AudioWaveformViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const AudioWaveformViewProps>();
    _props = defaultProps;

    _impl = [[AudioWaveformViewImpl alloc] init];
    self.contentView = _impl;

    [self wireImplCallbacks];
  }
  return self;
}

- (void)wireImplCallbacks
{
  __weak __typeof__(self) weakSelf = self;

  _impl.onLoad = ^(NSInteger durationMs) {
    [weakSelf emitOnLoad:durationMs];
  };
  _impl.onLoadError = ^(NSString *_Nonnull message) {
    [weakSelf emitOnLoadError:message];
  };
  _impl.onPlayerStateChange =
      ^(NSString *_Nonnull state, BOOL isPlaying, float speed, NSString *_Nonnull error) {
        [weakSelf emitOnPlayerStateChange:state
                                isPlaying:isPlaying
                                    speed:speed
                                    error:error];
      };
  _impl.onTimeUpdate = ^(NSInteger currentTimeMs, NSInteger durationMs) {
    [weakSelf emitOnTimeUpdate:currentTimeMs durationMs:durationMs];
  };
  _impl.onSeek = ^(NSInteger positionMs) {
    [weakSelf emitOnSeek:positionMs];
  };
  _impl.onEnd = ^{
    [weakSelf emitOnEnd];
  };
}

#pragma mark - Event emitter forwarding

- (std::shared_ptr<const AudioWaveformViewEventEmitter>)typedEventEmitter
{
  return std::static_pointer_cast<const AudioWaveformViewEventEmitter>(_eventEmitter);
}

- (void)emitOnLoad:(NSInteger)durationMs
{
  if (auto e = [self typedEventEmitter]) {
    e->onLoad({.durationMs = static_cast<int>(durationMs)});
  }
}

- (void)emitOnLoadError:(NSString *)message
{
  if (auto e = [self typedEventEmitter]) {
    e->onLoadError({.message = std::string([message UTF8String] ?: "")});
  }
}

- (void)emitOnPlayerStateChange:(NSString *)state
                      isPlaying:(BOOL)isPlaying
                          speed:(float)speed
                          error:(NSString *)error
{
  if (auto e = [self typedEventEmitter]) {
    AudioWaveformViewEventEmitter::OnPlayerStateChange event = {
        .state = std::string([state UTF8String] ?: "idle"),
        .isPlaying = static_cast<bool>(isPlaying),
        .speed = static_cast<Float>(speed),
        .error = std::string([error UTF8String] ?: ""),
    };
    e->onPlayerStateChange(event);
  }
}

- (void)emitOnTimeUpdate:(NSInteger)currentTimeMs durationMs:(NSInteger)durationMs
{
  if (auto e = [self typedEventEmitter]) {
    e->onTimeUpdate({
        .currentTimeMs = static_cast<int>(currentTimeMs),
        .durationMs = static_cast<int>(durationMs),
    });
  }
}

- (void)emitOnSeek:(NSInteger)positionMs
{
  if (auto e = [self typedEventEmitter]) {
    e->onSeek({.positionMs = static_cast<int>(positionMs)});
  }
}

- (void)emitOnEnd
{
  if (auto e = [self typedEventEmitter]) {
    e->onEnd({});
  }
}

#pragma mark - Props

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps =
      *std::static_pointer_cast<AudioWaveformViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<AudioWaveformViewProps const>(props);

  // Source URI
  if (oldViewProps.source.uri != newViewProps.source.uri) {
    NSString *uri = [NSString stringWithUTF8String:newViewProps.source.uri.c_str()];
    _impl.sourceURI = uri ?: @"";
  }

  // Pre-computed samples
  if (oldViewProps.samples != newViewProps.samples) {
    if (newViewProps.samples.empty()) {
      _impl.providedSamples = nil;
    } else {
      NSMutableArray<NSNumber *> *arr =
          [NSMutableArray arrayWithCapacity:newViewProps.samples.size()];
      for (auto v : newViewProps.samples) {
        [arr addObject:@(v)];
      }
      _impl.providedSamples = arr;
    }
  }

  // Bar colors
  if (oldViewProps.playedBarColor != newViewProps.playedBarColor) {
    _impl.playedBarColor =
        RCTUIColorFromSharedColor(newViewProps.playedBarColor) ?: [UIColor whiteColor];
  }
  if (oldViewProps.unplayedBarColor != newViewProps.unplayedBarColor) {
    _impl.unplayedBarColor = RCTUIColorFromSharedColor(newViewProps.unplayedBarColor)
        ?: [[UIColor whiteColor] colorWithAlphaComponent:0.5];
  }

  // Bar geometry
  if (oldViewProps.barWidth != newViewProps.barWidth) {
    _impl.barWidth = (CGFloat)newViewProps.barWidth;
  }
  if (oldViewProps.barGap != newViewProps.barGap) {
    _impl.barGap = (CGFloat)newViewProps.barGap;
  }
  if (oldViewProps.barRadius != newViewProps.barRadius) {
    _impl.barRadius = (CGFloat)newViewProps.barRadius;
  }
  if (oldViewProps.barCount != newViewProps.barCount) {
    _impl.barCountOverride = (NSInteger)newViewProps.barCount;
  }

  // Container background
  if (oldViewProps.containerBackgroundColor != newViewProps.containerBackgroundColor) {
    _impl.containerBackgroundColor =
        RCTUIColorFromSharedColor(newViewProps.containerBackgroundColor)
        ?: [UIColor colorWithRed:0.204 green:0.471 blue:0.965 alpha:1.0];
  }
  if (oldViewProps.containerBorderRadius != newViewProps.containerBorderRadius) {
    _impl.containerBorderRadius = (CGFloat)newViewProps.containerBorderRadius;
  }
  if (oldViewProps.showBackground != newViewProps.showBackground) {
    _impl.showBackground = newViewProps.showBackground;
  }

  // Play button
  if (oldViewProps.showPlayButton != newViewProps.showPlayButton) {
    _impl.showPlayButton = newViewProps.showPlayButton;
  }
  if (oldViewProps.playButtonColor != newViewProps.playButtonColor) {
    _impl.playButtonColor =
        RCTUIColorFromSharedColor(newViewProps.playButtonColor) ?: [UIColor whiteColor];
  }

  // Time
  if (oldViewProps.showTime != newViewProps.showTime) {
    _impl.showTime = newViewProps.showTime;
  }
  if (oldViewProps.timeColor != newViewProps.timeColor) {
    _impl.timeColor = RCTUIColorFromSharedColor(newViewProps.timeColor) ?: [UIColor whiteColor];
  }
  if (oldViewProps.timeMode != newViewProps.timeMode) {
    NSString *mode = (newViewProps.timeMode == AudioWaveformViewTimeMode::CountDown)
        ? @"count-down"
        : @"count-up";
    _impl.timeMode = mode;
  }

  // Speed
  if (oldViewProps.showSpeedControl != newViewProps.showSpeedControl) {
    _impl.showSpeedControl = newViewProps.showSpeedControl;
  }
  if (oldViewProps.speedColor != newViewProps.speedColor) {
    _impl.speedColor =
        RCTUIColorFromSharedColor(newViewProps.speedColor) ?: [UIColor whiteColor];
  }
  if (oldViewProps.speedBackgroundColor != newViewProps.speedBackgroundColor) {
    _impl.speedBackgroundColor =
        RCTUIColorFromSharedColor(newViewProps.speedBackgroundColor)
        ?: [[UIColor whiteColor] colorWithAlphaComponent:0.25];
  }
  if (oldViewProps.speeds != newViewProps.speeds) {
    NSArray<NSNumber *> *speeds = [self speedsArrayFrom:newViewProps.speeds];
    _impl.speeds = speeds;
  }
  if (oldViewProps.defaultSpeed != newViewProps.defaultSpeed) {
    _impl.defaultSpeed = newViewProps.defaultSpeed;
  }

  // Playback config
  if (oldViewProps.autoPlay != newViewProps.autoPlay) {
    _impl.autoPlay = newViewProps.autoPlay;
  }
  if (oldViewProps.initialPositionMs != newViewProps.initialPositionMs) {
    _impl.initialPositionMs = newViewProps.initialPositionMs;
  }
  if (oldViewProps.loop != newViewProps.loop) {
    _impl.loop = newViewProps.loop;
  }
  if (oldViewProps.playInBackground != newViewProps.playInBackground) {
    _impl.playInBackground = newViewProps.playInBackground;
  }
  if (oldViewProps.pauseUiUpdatesInBackground != newViewProps.pauseUiUpdatesInBackground) {
    _impl.pauseUiUpdatesInBackground = newViewProps.pauseUiUpdatesInBackground;
  }

  // Controlled props
  if (oldViewProps.controlledPlaying != newViewProps.controlledPlaying) {
    _impl.controlledPlaying = newViewProps.controlledPlaying;
  }
  if (oldViewProps.controlledSpeed != newViewProps.controlledSpeed) {
    _impl.controlledSpeed = newViewProps.controlledSpeed;
  }

  [super updateProps:props oldProps:oldProps];
}

- (NSArray<NSNumber *> *)speedsArrayFrom:(const std::vector<Float> &)values
{
  if (values.empty()) {
    return @[ @0.5, @1.0, @1.5, @2.0 ];
  }
  NSMutableArray<NSNumber *> *arr = [NSMutableArray arrayWithCapacity:values.size()];
  for (auto v : values) {
    [arr addObject:@(v)];
  }
  return arr;
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  if ([commandName isEqualToString:@"play"]) {
    [_impl play];
  } else if ([commandName isEqualToString:@"pause"]) {
    [_impl pause];
  } else if ([commandName isEqualToString:@"toggle"]) {
    [_impl toggle];
  } else if ([commandName isEqualToString:@"seekTo"] && args.count >= 1) {
    NSInteger ms = [args[0] integerValue];
    [_impl seekToMs:ms];
  } else if ([commandName isEqualToString:@"setSpeed"] && args.count >= 1) {
    float s = [args[0] floatValue];
    [_impl setSpeedValue:s];
  }
}

- (void)prepareForRecycle
{
  // Stop the player BEFORE anything else — Fabric pools this component view,
  // so without an explicit teardown the underlying AVPlayer happily keeps
  // playing inside the pool after the React component has unmounted. See
  // `AudioWaveformViewImpl.tearDown()` for the full reset sequence.
  [_impl tearDown];
  [super prepareForRecycle];
  static const auto defaultProps = std::make_shared<const AudioWaveformViewProps>();
  _props = defaultProps;
}

@end
