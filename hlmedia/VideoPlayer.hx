package hlmedia;

import haxe.extern.EitherType;
import hxd.fs.LocalFileSystem;
import hxd.fs.FileSystem;
import hxd.fs.MultiFileSystem;
import hxd.res.Any;
import hxd.res.Resource;
import hlmedia.audio.AudioSink;
import hlmedia.audio.NullAudioSink;
import hlmedia.native.NativeMedia;
import hlmedia.MediaError;
import hlmedia.VideoFrame.VideoPixelFormat;
import hlmedia.VideoInfo.VideoPlayerOptions;

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
	var currentFrame:VideoFrame;
	var pendingFrame:VideoFrame;
	var timeCallbacks:Array<VideoTimeCallback> = [];
	var finished = false;

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
		final path:String = source is String ? cast source : resolveResourcePath(cast source);
		close();
		handle = NativeMedia.open(path);
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
		if (isPlaying)
			play();
	}

	/**
		Starts or resumes playback.
	**/
	public function play():Void {
		requireOpen();
		final wasPlaying = isPlaying;
		NativeMedia.play(handle);
		audioSink.pause(false);
		clock.start(time);
		isPlaying = true;
		isPaused = false;
		if (!wasPlaying && onStart != null)
			onStart();
	}

	/**
		Pauses playback without closing the file.
	**/
	public function pause():Void {
		requireOpen();
		NativeMedia.pause(handle, true);
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
		NativeMedia.stop(handle);
		audioSink.stop();
		clock.reset();
		playbackBaseTime = 0;
		time = 0;
		isPlaying = false;
		isPaused = false;
		finished = false;
		resetTimeCallbacks(0);
	}

	/**
		Closes the file and releases decoder state.
	**/
	public function close():Void {
		if (handle != null) {
			NativeMedia.close(handle);
			handle = null;
		}
		audioSink.stop();
		clock.reset();
		playbackBaseTime = 0;
		info = null;
		currentFrame = null;
		pendingFrame = null;
		isPlaying = false;
		isPaused = false;
		time = 0;
		duration = 0;
		droppedFrames = 0;
		presentedFrames = 0;
		finished = false;
		resetTimeCallbacks(0);
	}

	/**
		Seeks to `seconds`, clamped to the media duration.
	**/
	public function seek(seconds:Float):Void {
		requireOpen();
		final wasPlaying = isPlaying;
		final target = Math.max(0, Math.min(duration, seconds));
		if (!NativeMedia.seek(handle, target))
			throw SeekFailed(NativeMedia.lastError());
		audioSink.flush();
		currentFrame = null;
		pendingFrame = null;
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

		while (audioSink.getBufferedFrames() < AUDIO_TARGET_FRAMES) {
			final chunk = NativeMedia.getAudioSamples(handle, AUDIO_MAX_PULL_FRAMES);
			if (chunk == null)
				break;
			final frames = NativeMedia.audioChunkFrames(chunk);
			final bytes = NativeMedia.audioChunkBytes(chunk);
			if (frames > 0 && bytes != null)
				audioSink.writeFloat32Interleaved(bytes, frames);
			NativeMedia.releaseAudioSamples(handle, chunk);
			if (frames == 0)
				break;
		}

		for (_ in 0...8)
			if (NativeMedia.decode(handle) <= 0)
				break;

		time = info.hasAudio ? playbackBaseTime + audioSink.getPlayedFrames() / info.sampleRate : clock.getTime();
		dispatchTimeCallbacks(time);
		presentFrame(time);

		if (duration > 0 && time >= duration) {
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
		audioSink.pause(!isPlaying);
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
		Creates a Heaps bitmap bound to this player.
	**/
	public function createBitmap(?parent:h2d.Object, fitScene = true):VideoBitmap {
		return new VideoBitmap(this, parent, fitScene);
	}

	private function presentFrame(clockTime:Float):Void {
		var selected:VideoFrame = null;
		if (pendingFrame != null) {
			if (pendingFrame.pts > clockTime + 0.025)
				return;
			selected = pendingFrame;
			pendingFrame = null;
		}
		while (true) {
			final nativeFrame = NativeMedia.getVideoFrame(handle);
			if (nativeFrame == null)
				break;
			final frame = readFrame(nativeFrame);
			NativeMedia.releaseVideoFrame(handle, nativeFrame);
			if (frame.pts <= clockTime + 0.025) {
				if (selected != null)
					droppedFrames++;
				selected = frame;
			} else {
				pendingFrame = frame;
				break;
			}
		}
		if (selected != null) {
			currentFrame = selected;
			videoTexture.upload(selected);
			presentedFrames++;
		}
	}

	private function finish():Void {
		if (finished)
			return;
		finished = true;
		isPlaying = false;
		isPaused = false;
		time = duration;
		NativeMedia.pause(handle, true);
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

	private function readFrame(frame:NativeFrame):VideoFrame {
		final format = NativeMedia.frameFormat(frame);
		return {
			pts: NativeMedia.framePts(frame),
			width: NativeMedia.frameWidth(frame),
			height: NativeMedia.frameHeight(frame),
			format: format,
			y: NativeMedia.framePlane(frame, 0),
			u: format == YUV420P ? NativeMedia.framePlane(frame, 1) : null,
			v: format == YUV420P ? NativeMedia.framePlane(frame, 2) : null,
			uv: format == NV12 ? NativeMedia.framePlane(frame, 1) : null,
			yStride: NativeMedia.frameStride(frame, 0),
			uStride: NativeMedia.frameStride(frame, 1),
			vStride: NativeMedia.frameStride(frame, 2),
			uvStride: NativeMedia.frameStride(frame, 1)
		};
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

	static function resolveFileSystemPath(fileSystem:FileSystem, path:String):String {
		final localFileSystem = Std.downcast(fileSystem, LocalFileSystem);
		if (localFileSystem != null && localFileSystem.exists(path))
			return localFileSystem.getAbsolutePath(localFileSystem.get(path));

		final multiFileSystem = Std.downcast(fileSystem, MultiFileSystem);
		if (multiFileSystem != null) {
			for (child in multiFileSystem.fs)
				if (child.exists(path))
					return resolveFileSystemPath(child, path);
		}

		return path;
	}
}

private typedef VideoTimeCallback = {
	final time:Float;
	final callback:Void->Void;
	var fired:Bool;
}
