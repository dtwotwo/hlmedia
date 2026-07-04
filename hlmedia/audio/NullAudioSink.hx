package hlmedia.audio;

/**
	Timing-only sink used when no audio backend is enabled.
**/
class NullAudioSink implements AudioSink {
	var sampleRate = 48000;
	var channels = 2;
	var queuedFrames = 0;
	var playedBase = 0.0;
	var startedAt = 0.0;
	var paused = true;
	var volume = 1.0;

	/**
		Creates a silent sink.
	**/
	public function new() {}

	/**
		Starts virtual playback timing.
	**/
	public function start(sampleRate:Int, channels:Int):Void {
		this.sampleRate = sampleRate;
		this.channels = channels;
		playedBase = 0.0;
		queuedFrames = 0;
		startedAt = haxe.Timer.stamp();
		paused = false;
	}

	/**
		Stops and clears queued audio.
	**/
	public function stop():Void {
		flush();
		paused = true;
	}

	/**
		Pauses or resumes virtual playback timing.
	**/
	public function pause(paused:Bool):Void {
		if (this.paused == paused)
			return;
		playedBase = getPlayedFrames();
		startedAt = haxe.Timer.stamp();
		this.paused = paused;
	}

	/**
		Clears queued frames and resets timing.
	**/
	public function flush():Void {
		queuedFrames = 0;
		playedBase = 0.0;
		startedAt = haxe.Timer.stamp();
	}

	/**
		Queues frames for virtual playback.
	**/
	public function writeFloat32Interleaved(samples:haxe.io.Bytes, frames:Int):Int {
		queuedFrames += frames;
		return frames;
	}

	/**
		Returns queued virtual frames.
	**/
	public function getBufferedFrames():Int {
		return Std.int(Math.max(0, queuedFrames - getPlayedFrames()));
	}

	/**
		Returns the virtual playback position in frames.
	**/
	public function getPlayedFrames():Float {
		if (paused)
			return playedBase;
		return playedBase + (haxe.Timer.stamp() - startedAt) * sampleRate;
	}

	/**
		Stores clamped volume for API compatibility.
	**/
	public function setVolume(volume:Float):Void {
		this.volume = Math.max(0, Math.min(1, volume));
	}
}
