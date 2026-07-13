package hlmedia.types;

/**
	Metadata read from the opened media file.
**/
typedef VideoInfo = {
	/**
		Absolute or resolved source path.
	**/
	final path:String;

	/**
		Duration in seconds.
	**/
	final duration:Float;

	/**
		Video width in pixels.
	**/
	final width:Int;

	/**
		Video height in pixels.
	**/
	final height:Int;

	/**
		Reported frame rate.
	**/
	final fps:Float;

	/**
		FFmpeg video decoder name.
	**/
	final videoCodec:String;

	/**
		FFmpeg audio decoder name, or null for silent files.
	**/
	final audioCodec:Null<String>;

	/**
		True when an audio stream is present.
	**/
	final hasAudio:Bool;

	/**
		Output audio sample rate.
	**/
	final sampleRate:Int;

	/**
		Output audio channel count.
	**/
	final channels:Int;
}
