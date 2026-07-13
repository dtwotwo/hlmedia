package hlmedia;

import haxe.extern.EitherType;
import haxe.io.Bytes;
import hxd.fs.LocalFileSystem;
import hxd.fs.FileSystem;
import hxd.fs.MultiFileSystem;
import hxd.res.Any;
import hxd.res.Resource;
import sys.thread.Lock;
import sys.thread.Mutex;
import sys.thread.Thread;
import hlmedia.audio.AudioSink;
import hlmedia.audio.NullAudioSink;
import hlmedia.native.NativeMedia;
import hlmedia.MediaError;
import hlmedia.types.VideoFrame;
import hlmedia.types.VideoPixelFormat;
import hlmedia.types.VideoDecodeMode;
import hlmedia.types.VideoStats;
import hlmedia.types.VideoInfo;
import hlmedia.types.VideoPlayerOptions;

/**
	Opens, decodes, and presents one video file.
**/
@:access(hxd.res.Any)
class VideoPlayer {
	static inline var AUDIO_TARGET_FRAMES = 12000;
	static inline var AUDIO_MAX_PULL_FRAMES = 4096;

	/**
		True while playback is running.
	**/
	public var isPlaying(default, null) = false;

	/**
		True after `pause()` is called on an open file.
	**/
	public var isPaused(default, null) = false;

	/**
		Duration in seconds, or zero before `open()`.
	**/
	public var duration(default, null) = 0.0;

	/**
		Current playback position in seconds.
	**/
	public var time(default, null) = 0.0;

	/**
		Texture set that receives decoded frames.
	**/
	public var videoTexture(default, null):VideoTexture;

	/**
		Decoded frames skipped because playback had already passed them.
	**/
	public var droppedFrames(default, null) = 0;

	/**
		Frames uploaded for presentation.
	**/
	public var presentedFrames(default, null) = 0;

	/**
		Average time spent in native decode calls, in milliseconds.
	**/
	public var averageDecodeTimeMs(default, null) = 0.0;

	/**
		Average time spent uploading the selected frame, in milliseconds.
	**/
	public var averageUploadTimeMs(default, null) = 0.0;

	/**
		Current native video frame queue size.
	**/
	public var currentVideoQueueSize(default, null) = 0;

	/**
		True when the native decoder initialized a hardware device.
	**/
	public var hardwareDecodeActive(default, null) = false;

	/**
		Actual hardware backend accepted by FFmpeg, or `Software`.
	**/
	public var actualDecodeBackend(default, null) = "Software";

	/**
		Called when playback starts or resumes.
	**/
	public var onStart:Void->Void;

	/**
		Called once when playback reaches the end without looping.
	**/
	public var onFinish:Void->Void;

	var options:VideoPlayerOptions;
	var handle:NativeHandle;
	var info:VideoInfo;
	var audioSink:AudioSink;
	var clock = new MediaClock();
	var loop = false;
	var volume = 1.0;
	var playbackBaseTime = 0.0;
	var pendingFrame:QueuedVideoFrame;
	var timeCallbacks:Array<VideoTimeCallback> = [];
	var finished = false;
	var copiedBytesWindow = 0.0;
	var copiedBytesWindowStart = haxe.Timer.stamp();
	var copiedBytesPerSecond = 0.0;
	var hasCopiedBytesRate = false;
	var audioDriftMs = 0.0;
	var nativeMutex = new Mutex();
	var decodeWake = new Lock();
	var decodeStopped:Lock;
	var decodeThread:Thread;
	var stopDecodeThread = false;
	var prebuffering = false;
	var notifyAfterPrebuffer = false;
	var audioBufferedForDecode = 0;
	var pendingAudioBytes:Bytes;
	var pendingAudioFrames = 0;

	/**
		Creates a player. Use `open()` before playback.
	**/
	public function new(?options:VideoPlayerOptions) {
		this.options = options == null ? {} : options;
		loop = this.options.loop;
		if (this.options.volume != null)
			volume = this.options.volume;
		audioSink = this.options.audioSink ?? new NullAudioSink();
		audioSink.setVolume(volume);
		videoTexture = new VideoTexture();
	}

	/**
		Opens a filesystem path or Heaps resource.
	**/
	public function open(source:EitherType<String, Resource>):Void {
		final resource:Resource = source is String ? null : cast source;
		final path:String = resource == null ? cast source : resolveResourcePath(resource);
		close();
		handle = resource == null
			|| isLocalResource(resource) ? NativeMedia.open(path, decodeMode(), allowHardwareFallback(),
				preferNativePixelFormat()) : NativeMedia.openBytes(path, resource.entry.getBytes(), decodeMode(), allowHardwareFallback(), preferNativePixelFormat());
		if (handle == null)
			throw DecodeFailed(NativeMedia.lastError());

		info = {
			path: path,
			duration: NativeMedia.duration(handle),
			width: NativeMedia.width(handle),
			height: NativeMedia.height(handle),
			fps: NativeMedia.fps(handle),
			videoCodec: NativeMedia.videoCodec(handle),
			audioCodec: NativeMedia.hasAudio(handle) ? NativeMedia.audioCodec(handle) : null,
			hasAudio: NativeMedia.hasAudio(handle),
			sampleRate: NativeMedia.sampleRate(handle),
			channels: NativeMedia.channels(handle)
		};
		duration = info.duration;
		audioSink.start(info.sampleRate > 0 ? info.sampleRate : 48000, info.channels > 0 ? info.channels : 2);
		audioSink.pause(true);
		clock.reset();
		playbackBaseTime = 0;
		resetTimeCallbacks(0);
		finished = false;
		isPaused = options.startPaused;
		isPlaying = !isPaused;
		if (isPlaying) {
			NativeMedia.play(handle);
			prebuffering = prebufferSeconds() > 0;
			notifyAfterPrebuffer = false;
			if (!prebuffering)
				startPlaybackClock();
		}
		startDecodeThread();
	}

	/**
		Starts or resumes playback.
	**/
	public function play():Void {
		requireOpen();
		if (finished)
			seek(0);
		final wasPlaying = isPlaying;
		lockNative();
		NativeMedia.play(handle);
		unlockNative();
		isPlaying = true;
		isPaused = false;
		prebuffering = prebufferSeconds() > 0 && time == 0;
		notifyAfterPrebuffer = !wasPlaying;
		if (prebuffering)
			audioSink.pause(true);
		else
			startPlaybackClock(!wasPlaying);
		decodeWake.release();
	}

	/**
		Pauses playback without closing the file.
	**/
	public function pause():Void {
		requireOpen();
		lockNative();
		NativeMedia.pause(handle, true);
		unlockNative();
		audioSink.pause(true);
		clock.pause();
		isPlaying = false;
		isPaused = true;
	}

	/**
		Stops playback and seeks to the start.
	**/
	public function stop():Void {
		if (handle == null)
			return;
		lockNative();
		NativeMedia.stop(handle);
		audioBufferedForDecode = 0;
		unlockNative();
		audioSink.flush();
		audioSink.pause(true);
		clearPendingAudio();
		clock.reset();
		playbackBaseTime = 0;
		time = 0;
		isPlaying = false;
		isPaused = false;
		finished = false;
		prebuffering = false;
		resetTimeCallbacks(0);
	}

	/**
		Closes the current file and releases decoder state. The player can be
		reused by calling `open()` again.
	**/
	public function close():Void {
		stopDecodeWorker();
		releasePendingFrame();
		if (handle != null) {
			NativeMedia.close(handle);
			handle = null;
		}
		audioSink.stop();
		clearPendingAudio();
		clock.reset();
		playbackBaseTime = 0;
		info = null;
		isPlaying = false;
		isPaused = false;
		time = 0;
		duration = 0;
		droppedFrames = 0;
		presentedFrames = 0;
		averageDecodeTimeMs = 0;
		averageUploadTimeMs = 0;
		currentVideoQueueSize = 0;
		hardwareDecodeActive = false;
		actualDecodeBackend = "Software";
		resetStatsWindow();
		prebuffering = false;
		audioBufferedForDecode = 0;
		finished = false;
		resetTimeCallbacks(0);
	}

	/**
		Closes the current file and releases the GPU textures owned by this
		player. The player must not be reused after disposal.
	**/
	public function dispose():Void {
		close();
		videoTexture.dispose();
	}

	/**
		Seeks to `seconds`, clamped to the media duration.
	**/
	public function seek(seconds:Float):Void {
		requireOpen();
		final wasPlaying = isPlaying;
		final target = Math.max(0, Math.min(duration, seconds));
		releasePendingFrame();
		lockNative();
		if (!NativeMedia.seek(handle, target)) {
			unlockNative();
			throw SeekFailed(NativeMedia.lastError());
		}
		audioBufferedForDecode = 0;
		unlockNative();
		audioSink.flush();
		clearPendingAudio();
		playbackBaseTime = target;
		clock.seek(target);
		time = target;
		finished = false;
		resetTimeCallbacks(target);
		if (wasPlaying)
			play();
		else
			audioSink.pause(true);
	}

	/**
		Decodes queued work and presents the frame for the current clock time.
	**/
	public function update(dt:Float):Void {
		if (handle == null || !isPlaying)
			return;

		while (audioSink.getBufferedFrames() < targetAudioBufferFrames()) {
			if (pendingAudioFrames > 0) {
				if (!writePendingAudio())
					break;
				continue;
			}
			lockNative();
			final chunk = NativeMedia.getAudioSamples(handle, AUDIO_MAX_PULL_FRAMES);
			if (chunk == null) {
				unlockNative();
				break;
			}
			final frames = NativeMedia.audioChunkFrames(chunk);
			final bytes = NativeMedia.audioChunkBytes(chunk);
			NativeMedia.releaseAudioSamples(handle, chunk);
			unlockNative();
			if (frames > 0 && bytes != null) {
				pendingAudioBytes = bytes;
				pendingAudioFrames = frames;
				if (!writePendingAudio())
					break;
			}
			if (frames == 0)
				break;
		}
		final bufferedAudioFrames = audioSink.getBufferedFrames();
		lockNative();
		audioBufferedForDecode = bufferedAudioFrames + pendingAudioFrames;
		unlockNative();
		if (!threadedDecode()) {
			for (_ in 0...8) {
				final videoFull = NativeMedia.videoQueueSize(handle) >= maxQueuedVideoFrames();
				final audioFull = !info.hasAudio
					|| NativeMedia.audioQueueFrames(handle) + audioBufferedForDecode >= targetAudioBufferFrames();
				if (videoFull && audioFull)
					break;
				final decodeStart = haxe.Timer.stamp();
				final result = NativeMedia.decode(handle);
				averageDecodeTimeMs = smoothAverage(averageDecodeTimeMs, (haxe.Timer.stamp() - decodeStart) * 1000);
				if (result <= 0)
					break;
			}
		}
		lockNative();
		currentVideoQueueSize = NativeMedia.videoQueueSize(handle);
		final currentAudioQueueFrames = NativeMedia.audioQueueFrames(handle);
		final decoderEof = NativeMedia.eof(handle);
		hardwareDecodeActive = NativeMedia.hardwareDecodeActive(handle);
		final hardwareBackend = NativeMedia.hardwareDecodeBackend(handle);
		unlockNative();
		actualDecodeBackend = hardwareBackend.length == 0 ? "Software" : hardwareBackend;

		if (prebuffering) {
			final targetVideoFrames = Math.min(maxQueuedVideoFrames(), Math.ceil(prebufferSeconds() * info.fps));
			final audioReady = !info.hasAudio || audioSink.getBufferedFrames() >= Math.ceil(prebufferSeconds() * info.sampleRate);
			if (currentVideoQueueSize < targetVideoFrames || !audioReady)
				return;
			prebuffering = false;
			startPlaybackClock(notifyAfterPrebuffer);
		}

		final clockTime = clock.getTime();
		if (info.hasAudio) {
			time = playbackBaseTime + audioSink.getPlayedFrames() / info.sampleRate;
			audioDriftMs = (time - clockTime) * 1000;
			if (duration > 0 && clockTime >= duration && audioSink.getBufferedFrames() == 0)
				time = duration;
		} else {
			time = clockTime;
			audioDriftMs = 0;
		}
		dispatchTimeCallbacks(time);
		presentFrame(time);

		final playbackDrained = decoderEof
			&& currentVideoQueueSize == 0
			&& pendingFrame == null
			&& currentAudioQueueFrames == 0
			&& pendingAudioFrames == 0
			&& (!info.hasAudio || audioSink.getBufferedFrames() == 0);
		if (duration > 0 && time >= duration || playbackDrained) {
			if (loop)
				seek(0);
			else
				finish();
		}
	}

	/**
		Runs `callback` once when playback reaches `seconds`.
	**/
	public function onTime(seconds:Float, callback:Void->Void):Void {
		timeCallbacks.push({
			time: Math.max(0, seconds),
			callback: callback,
			fired: false
		});
	}

	/**
		Enables or disables end-of-stream looping.
	**/
	public function setLoop(loop:Bool):Void {
		this.loop = loop;
	}

	/**
		Sets output volume in the `0...1` range.
	**/
	public function setVolume(volume:Float):Void {
		this.volume = Math.max(0, Math.min(1, volume));
		audioSink.setVolume(this.volume);
	}

	/**
		Replaces the current audio output.
	**/
	public function setAudioSink(sink:AudioSink):Void {
		audioSink.stop();
		audioSink = sink;
		audioSink.setVolume(volume);
		if (info != null)
			audioSink.start(info.sampleRate, info.channels);
		audioSink.pause(!isPlaying || prebuffering);
	}

	/**
		Returns the current output texture.
	**/
	public function getTexture():h3d.mat.Texture {
		return videoTexture.output;
	}

	/**
		Returns metadata for the open file, or null before `open()`.
	**/
	public function getInfo():VideoInfo {
		return info;
	}

	/**
		Returns a snapshot of current playback and performance statistics.
	**/
	public function getStats():VideoStats {
		return {
			decodeModeRequested: decodeMode(),
			actualDecodeBackend: actualDecodeBackend,
			hardwareDecodeActive: hardwareDecodeActive,
			pixelFormat: videoTexture.pixelFormat,
			decodeMs: averageDecodeTimeMs,
			uploadMs: averageUploadTimeMs,
			droppedFrames: droppedFrames,
			presentedFrames: presentedFrames,
			videoQueueSize: currentVideoQueueSize,
			audioBufferedFrames: info == null ? 0 : audioSink.getBufferedFrames(),
			copiedBytesPerSecond: currentCopiedBytesRate(),
			audioDriftMs: audioDriftMs
		};
	}

	/**
		Creates a Heaps bitmap bound to this player.
	**/
	public function createBitmap(?parent:h2d.Object, fitScene = true):VideoBitmap {
		return new VideoBitmap(this, parent, fitScene);
	}

	private function presentFrame(clockTime:Float):Void {
		var selected:QueuedVideoFrame = null;
		if (pendingFrame != null) {
			if (pendingFrame.frame.pts > clockTime + 0.025)
				return;
			selected = pendingFrame;
			pendingFrame = null;
		}

		while (true) {
			lockNative();
			final nativeFrame = NativeMedia.getVideoFrame(handle);
			if (nativeFrame == null) {
				unlockNative();
				break;
			}

			final queuedFrame = readFrame(nativeFrame);
			unlockNative();
			if (queuedFrame.frame.pts <= clockTime + 0.025) {
				if (selected != null) {
					lockNative();
					NativeMedia.releaseVideoFrame(handle, selected.nativeFrame);
					unlockNative();
					droppedFrames++;
				}
				selected = queuedFrame;
			} else {
				pendingFrame = queuedFrame;
				break;
			}
		}

		if (selected != null) {
			final uploadStart = haxe.Timer.stamp();
			try {
				videoTexture.upload(selected.frame);
			} catch (error) {
				lockNative();
				NativeMedia.releaseVideoFrame(handle, selected.nativeFrame);
				unlockNative();
				throw error;
			}

			lockNative();
			NativeMedia.releaseVideoFrame(handle, selected.nativeFrame);
			unlockNative();

			copiedBytesWindow += videoTexture.lastCopiedBytes;
			averageUploadTimeMs = smoothAverage(averageUploadTimeMs, (haxe.Timer.stamp() - uploadStart) * 1000);
			presentedFrames++;
		}
	}

	private function smoothAverage(current:Float, sample:Float):Float {
		return current == 0 ? sample : current * 0.9 + sample * 0.1;
	}

	private function finish():Void {
		if (finished)
			return;
		finished = true;
		isPlaying = false;
		isPaused = false;
		time = duration;
		lockNative();
		NativeMedia.pause(handle, true);
		unlockNative();
		audioSink.pause(true);
		clock.pause();
		if (onFinish != null)
			onFinish();
	}

	private function dispatchTimeCallbacks(time:Float):Void {
		for (item in timeCallbacks) {
			if (!item.fired && time >= item.time) {
				item.fired = true;
				item.callback();
			}
		}
	}

	private function resetTimeCallbacks(time:Float):Void {
		for (item in timeCallbacks)
			item.fired = item.time < time;
	}

	private function readFrame(frame:NativeFrame):QueuedVideoFrame {
		final format = NativeMedia.frameFormat(frame);
		return {
			nativeFrame: frame,
			frame: {
				pts: NativeMedia.framePts(frame),
				width: NativeMedia.frameWidth(frame),
				height: NativeMedia.frameHeight(frame),
				format: format,
				planeCount: NativeMedia.framePlaneCount(frame),
				y: NativeMedia.framePlane(frame, 0),
				u: format == YUV420P ? NativeMedia.framePlane(frame, 1) : null,
				v: format == YUV420P ? NativeMedia.framePlane(frame, 2) : null,
				uv: format == NV12 ? NativeMedia.framePlane(frame, 1) : null,
				yStride: NativeMedia.frameStride(frame, 0),
				uStride: NativeMedia.frameStride(frame, 1),
				vStride: NativeMedia.frameStride(frame, 2),
				uvStride: NativeMedia.frameStride(frame, 1),
				planeWidths: [
					for (i in 0...NativeMedia.framePlaneCount(frame))
						NativeMedia.framePlaneWidth(frame, i)
				],
				planeHeights: [
					for (i in 0...NativeMedia.framePlaneCount(frame))
						NativeMedia.framePlaneHeight(frame, i)
				]
			}
		};
	}

	private function releasePendingFrame():Void {
		if (pendingFrame == null)
			return;
		lockNative();
		NativeMedia.releaseVideoFrame(handle, pendingFrame.nativeFrame);
		unlockNative();
		pendingFrame = null;
	}

	private function writePendingAudio():Bool {
		final acceptedFrames = audioSink.writeFloat32Interleaved(pendingAudioBytes, pendingAudioFrames);
		if (acceptedFrames <= 0)
			return false;
		if (acceptedFrames >= pendingAudioFrames) {
			clearPendingAudio();
			return true;
		}

		final byteOffset = acceptedFrames * info.channels * 4;
		pendingAudioBytes = pendingAudioBytes.sub(byteOffset, pendingAudioBytes.length - byteOffset);
		pendingAudioFrames -= acceptedFrames;
		return true;
	}

	private function clearPendingAudio():Void {
		pendingAudioBytes = null;
		pendingAudioFrames = 0;
	}

	private function startDecodeThread():Void {
		if (!threadedDecode())
			return;
		stopDecodeThread = false;
		decodeStopped = new Lock();

		final hasAudio = info.hasAudio;
		final videoTarget = maxQueuedVideoFrames();
		final audioTarget = targetAudioBufferFrames();
		decodeThread = Thread.create(() -> {
			while (true) {
				nativeMutex.acquire();
				if (stopDecodeThread) {
					nativeMutex.release();
					break;
				}
				final videoFull = NativeMedia.videoQueueSize(handle) >= videoTarget;
				final audioFull = !hasAudio || NativeMedia.audioQueueFrames(handle) + audioBufferedForDecode >= audioTarget;
				if (videoFull && audioFull) {
					nativeMutex.release();
					decodeWake.wait(.005);
					continue;
				}
				final decodeStart = haxe.Timer.stamp();
				final result = NativeMedia.decode(handle);
				averageDecodeTimeMs = smoothAverage(averageDecodeTimeMs, (haxe.Timer.stamp() - decodeStart) * 1000);
				nativeMutex.release();
				if (result <= 0)
					decodeWake.wait(.01);
			}
			decodeStopped.release();
		});
	}

	private function stopDecodeWorker():Void {
		if (decodeThread == null)
			return;
		nativeMutex.acquire();
		stopDecodeThread = true;
		nativeMutex.release();
		decodeWake.release();
		decodeStopped.wait();
		decodeThread = null;
		decodeStopped = null;
	}

	private function startPlaybackClock(notify = false):Void {
		audioSink.pause(false);
		clock.start(time);
		if (notify && onStart != null)
			onStart();
	}

	private inline function lockNative():Void {
		if (decodeThread != null)
			nativeMutex.acquire();
	}

	private inline function unlockNative():Void {
		if (decodeThread != null)
			nativeMutex.release();
	}

	private function currentCopiedBytesRate():Float {
		final now = haxe.Timer.stamp();
		final elapsed = now - copiedBytesWindowStart;
		if (elapsed >= 1) {
			copiedBytesPerSecond = copiedBytesWindow / elapsed;
			copiedBytesWindow = 0;
			copiedBytesWindowStart = now;
			hasCopiedBytesRate = true;
		}
		return hasCopiedBytesRate || elapsed <= 0 ? copiedBytesPerSecond : copiedBytesWindow / elapsed;
	}

	private function resetStatsWindow():Void {
		copiedBytesWindow = 0;
		copiedBytesWindowStart = haxe.Timer.stamp();
		copiedBytesPerSecond = 0;
		hasCopiedBytesRate = false;
		audioDriftMs = 0;
	}

	private function decodeMode():VideoDecodeMode {
		return options.videoDecodeMode ?? Software;
	}

	private function allowHardwareFallback():Bool {
		return options.allowHardwareFallback ?? true;
	}

	private function preferNativePixelFormat():Bool {
		return options.preferNativePixelFormat ?? true;
	}

	private function threadedDecode():Bool {
		return options.threadedDecode ?? false;
	}

	private function maxQueuedVideoFrames():Int {
		return Std.int(Math.max(1, options.maxQueuedVideoFrames ?? 6));
	}

	private function targetAudioBufferFrames():Int {
		return Std.int(Math.max(1, options.targetAudioBufferFrames ?? AUDIO_TARGET_FRAMES));
	}

	private function prebufferSeconds():Float {
		return Math.max(0, options.prebufferSeconds ?? 0);
	}

	private function requireOpen():Void {
		if (handle == null)
			throw DecodeFailed("No media file is open");
	}

	static function resolveResourcePath(resource:Resource):String {
		final any = Std.downcast(resource, Any);
		final loader = any == null ? null : any.loader;
		final path = resource.entry.path;
		return loader == null ? path : resolveFileSystemPath(loader.fs, path);
	}

	static function isLocalResource(resource:Resource):Bool {
		final any = Std.downcast(resource, Any);
		final loader = any == null ? null : any.loader;
		return loader != null && resolveLocalFileSystem(loader.fs, resource.entry.path) != null;
	}

	static function resolveFileSystemPath(fileSystem:FileSystem, path:String):String {
		final localPath = resolveLocalFileSystem(fileSystem, path);
		if (localPath != null)
			return localPath;
		return path;
	}

	static function resolveLocalFileSystem(fileSystem:FileSystem, path:String):String {
		final localFileSystem = Std.downcast(fileSystem, LocalFileSystem);
		if (localFileSystem != null && localFileSystem.exists(path))
			return localFileSystem.getAbsolutePath(localFileSystem.get(path));

		final multiFileSystem = Std.downcast(fileSystem, MultiFileSystem);
		if (multiFileSystem != null) {
			for (child in multiFileSystem.fs)
				if (child.exists(path))
					return resolveLocalFileSystem(child, path);
		}

		return null;
	}
}

private typedef VideoTimeCallback = {
	final time:Float;
	final callback:Void->Void;
	var fired:Bool;
}

private typedef QueuedVideoFrame = {
	final nativeFrame:NativeFrame;
	final frame:VideoFrame;
}
