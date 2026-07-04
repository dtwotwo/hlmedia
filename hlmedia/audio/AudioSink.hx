package hlmedia.audio;

/**
	Audio output used by `VideoPlayer`.
**/
interface AudioSink {
	/**
		Opens the output stream.
	**/
	function start(sampleRate:Int, channels:Int):Void;

	/**
		Closes the output stream.
	**/
	function stop():Void;

	/**
		Pauses or resumes output.
	**/
	function pause(paused:Bool):Void;

	/**
		Drops queued audio and resets sink timing.
	**/
	function flush():Void;

	/**
		Queues interleaved Float32 PCM and returns accepted frames.
	**/
	function writeFloat32Interleaved(samples:haxe.io.Bytes, frames:Int):Int;

	/**
		Returns queued frames that have not played yet.
	**/
	function getBufferedFrames():Int;

	/**
		Returns frames played since start or the last flush.
	**/
	function getPlayedFrames():Float;

	/**
		Sets output volume in the `0...1` range.
	**/
	function setVolume(volume:Float):Void;
}
