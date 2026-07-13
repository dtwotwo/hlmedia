package;

#if hlopenal
import haxe.io.Bytes;
import hlmedia.audio.AudioSink;
import openal.AL;
import openal.ALC;

/**
	Audio sink backed by OpenAL.
**/
class OpenALSink implements AudioSink {
	static inline var BUFFER_COUNT = 4;
	static inline var MAX_QUEUED_FRAMES = 24000;

	var device:openal.Device;
	var context:openal.Context;
	var ownsContext = false;
	var source:openal.Source;
	var freeBuffers:Array<openal.Buffer> = [];
	var queuedFrames:Array<Int> = [];
	var queuedFrameCount = 0;
	var playedBase = 0.0;
	var sampleRate = 48000;
	var channels = 2;
	var started = false;
	var paused = false;
	var volume = 1.0;

	/**
		Creates an OpenAL-backed audio sink.
	**/
	public function new() {}

	/**
		Opens an OpenAL source for the supplied audio format.
	**/
	public function start(sampleRate:Int, channels:Int):Void {
		stop();
		this.sampleRate = sampleRate;
		this.channels = channels;

		context = ALC.getCurrentContext();
		if (context == null) {
			device = ALC.openDevice(null);
			if (device == null)
				throw "Could not open OpenAL device";
			context = ALC.createContext(device, null);
			if (context == null || !ALC.makeContextCurrent(context))
				throw "Could not create OpenAL context";
			ownsContext = true;
		}

		final sourceBytes = Bytes.alloc(4);
		AL.genSources(1, @:privateAccess sourceBytes.b);
		source = cast sourceBytes.getInt32(0);

		final bufferBytes = Bytes.alloc(BUFFER_COUNT * 4);
		AL.genBuffers(BUFFER_COUNT, @:privateAccess bufferBytes.b);
		for (i in 0...BUFFER_COUNT)
			freeBuffers.push(cast bufferBytes.getInt32(i * 4));

		AL.sourcef(source, AL.GAIN, volume);
		started = true;
		paused = false;
	}

	/**
		Stops playback and releases OpenAL resources owned by this sink.
	**/
	public function stop():Void {
		if (!started)
			return;

		if (ownsContext)
			ALC.makeContextCurrent(context);

		AL.sourceStop(source);
		unqueueProcessed(true);

		final sourceBytes = Bytes.alloc(4);
		sourceBytes.setInt32(0, cast(source, Int));
		AL.deleteSources(1, @:privateAccess sourceBytes.b);

		if (freeBuffers.length > 0) {
			final bufferBytes = Bytes.alloc(freeBuffers.length * 4);
			for (i in 0...freeBuffers.length)
				bufferBytes.setInt32(i * 4, cast(freeBuffers[i], Int));
			AL.deleteBuffers(freeBuffers.length, @:privateAccess bufferBytes.b);
		}

		if (ownsContext) {
			ALC.makeContextCurrent(null);
			ALC.destroyContext(context);
			ALC.closeDevice(device);
		}

		freeBuffers = [];
		queuedFrames = [];
		queuedFrameCount = 0;
		playedBase = 0;
		device = null;
		context = null;
		ownsContext = false;
		started = false;
	}

	/**
		Pauses or resumes the OpenAL source.
	**/
	public function pause(paused:Bool):Void {
		if (!started || this.paused == paused)
			return;
		this.paused = paused;
		if (paused)
			AL.sourcePause(source);
		else
			AL.sourcePlay(source);
	}

	/**
		Stops the source and clears queued OpenAL buffers.
	**/
	public function flush():Void {
		if (!started)
			return;
		AL.sourceStop(source);
		unqueueProcessed(true);
		queuedFrameCount = 0;
		playedBase = 0;
	}

	/**
		Converts interleaved 32-bit float PCM to 16-bit PCM and queues it in OpenAL.
	**/
	public function writeFloat32Interleaved(samples:Bytes, frames:Int):Int {
		if (!started || frames <= 0)
			return 0;

		unqueueProcessed(false);
		if (freeBuffers.length == 0 || queuedFrameCount >= MAX_QUEUED_FRAMES)
			return 0;

		final writeFrames = Std.int(Math.min(frames, MAX_QUEUED_FRAMES - queuedFrameCount));
		final pcm = floatToInt16(samples, writeFrames, channels);
		final buffer = freeBuffers.pop();
		AL.bufferData(buffer, channels == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16, @:privateAccess pcm.b, pcm.length, sampleRate);

		final bufferBytes = Bytes.alloc(4);
		bufferBytes.setInt32(0, cast(buffer, Int));
		AL.sourceQueueBuffers(source, 1, @:privateAccess bufferBytes.b);
		queuedFrames.push(writeFrames);
		queuedFrameCount += writeFrames;

		if (!paused && AL.getSourcei(source, AL.SOURCE_STATE) != AL.PLAYING)
			AL.sourcePlay(source);

		return writeFrames;
	}

	/**
		Returns the number of queued frames waiting in OpenAL buffers.
	**/
	public function getBufferedFrames():Int {
		unqueueProcessed(false);
		return queuedFrameCount;
	}

	/**
		Returns the played-frame position reported by OpenAL plus released buffers.
	**/
	public function getPlayedFrames():Float {
		if (!started)
			return playedBase;
		return playedBase + AL.getSourcei(source, AL.SAMPLE_OFFSET);
	}

	/**
		Sets OpenAL source gain in the 0...1 range.
	**/
	public function setVolume(volume:Float):Void {
		this.volume = Math.max(0, Math.min(1, volume));
		if (started)
			AL.sourcef(source, AL.GAIN, this.volume);
	}

	private function unqueueProcessed(all:Bool):Void {
		if (!started)
			return;
		if (!all && paused)
			return;

		var count = all ? AL.getSourcei(source, AL.BUFFERS_QUEUED) : AL.getSourcei(source, AL.BUFFERS_PROCESSED);
		while (count-- > 0) {
			final bufferBytes = Bytes.alloc(4);
			AL.sourceUnqueueBuffers(source, 1, @:privateAccess bufferBytes.b);
			freeBuffers.push(cast bufferBytes.getInt32(0));

			final frames = queuedFrames.length == 0 ? 0 : queuedFrames.shift();
			queuedFrameCount -= frames;
			playedBase += frames;
		}
	}

	private function floatToInt16(samples:Bytes, frames:Int, channels:Int):Bytes {
		final out = Bytes.alloc(frames * channels * 2);
		var read = 0;
		var write = 0;
		for (_ in 0...(frames * channels)) {
			var sample = samples.getFloat(read);
			read += 4;
			if (sample < -1)
				sample = -1;
			else if (sample > 1)
				sample = 1;
			out.setUInt16(write, Std.int(sample * 32767) & 0xFFFF);
			write += 2;
		}
		return out;
	}
}
#else

/**
	Fallback OpenAL sink used when the build does not include OpenAL support.
**/
class OpenALSink extends hlmedia.audio.NullAudioSink {}
#end
