package;

#if hlminiaudio
import haxe.io.Bytes;
import hlmedia.audio.AudioSink;
import miniaudio.Miniaudio.PcmSink;
import miniaudio.Miniaudio.SoundGroup;

/**
	Audio sink backed by the native miniaudio extension.
**/
class MiniAudioSink implements AudioSink {
	var sink:PcmSink;
	var started = false;
	var paused = true;
	var volume = 1.0;

	/**
		Creates a miniaudio-backed sink.
	**/
	public function new(?parent:SoundGroup) {}

	/**
		Opens the native miniaudio sink for the supplied audio format.
	**/
	public function start(sampleRate:Int, channels:Int):Void {
		stop();
		sink = new PcmSink(sampleRate, channels);
		if (sink == null)
			throw "Failed to open miniaudio PCM sink";
		started = true;
		paused = false;
		sink.setVolume(volume);
	}

	/**
		Destroys the native miniaudio sink.
	**/
	public function stop():Void {
		if (!started)
			return;
		sink.dispose();
		sink = null;
		started = false;
		paused = true;
	}

	/**
		Pauses or resumes the native sink.
	**/
	public function pause(paused:Bool):Void {
		this.paused = paused;
		if (started)
			sink.pause(paused);
	}

	/**
		Clears queued native audio.
	**/
	public function flush():Void {
		if (started)
			sink.flush();
	}

	/**
		Queues interleaved 32-bit float PCM frames.
	**/
	public function writeFloat32Interleaved(samples:Bytes, frames:Int):Int {
		if (!started || paused || frames <= 0)
			return 0;
		return sink.writeFloat32Interleaved(samples, frames);
	}

	/**
		Returns the native sink's queued frame count.
	**/
	public function getBufferedFrames():Int {
		return started ? sink.getBufferedFrames() : 0;
	}

	/**
		Returns the native sink's played-frame position.
	**/
	public function getPlayedFrames():Float {
		return started ? sink.getPlayedFrames() : 0;
	}

	/**
		Sets native output volume in the 0...1 range.
	**/
	public function setVolume(volume:Float):Void {
		this.volume = Math.max(0, Math.min(1, volume));
		if (started)
			sink.setVolume(this.volume);
	}
}
#else

/**
	Fallback miniaudio sink used when the build does not include miniaudio support.
**/
class MiniAudioSink extends hlmedia.audio.NullAudioSink {}
#end
