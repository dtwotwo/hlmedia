package hlmedia.types;

/**
	Runtime playback and performance statistics.
**/
typedef VideoStats = {
	/**
		Decoder mode requested through `VideoPlayerOptions`.
	**/
	final decodeModeRequested:VideoDecodeMode;

	/**
		Decoder backend accepted by FFmpeg, or `Software`.
	**/
	final actualDecodeBackend:String;

	/**
		True when a hardware decoder is active.
	**/
	final hardwareDecodeActive:Bool;

	/**
		Pixel format of the textures receiving decoded frames.
	**/
	final pixelFormat:VideoPixelFormat;

	/**
		Smoothed time spent in each native decode call, in milliseconds.
	**/
	final decodeMs:Float;

	/**
		Smoothed time spent uploading a presented frame, in milliseconds.
	**/
	final uploadMs:Float;

	/**
		Decoded frames skipped because their presentation time had passed.
	**/
	final droppedFrames:Int;

	/**
		Frames uploaded for presentation since the current video was opened.
	**/
	final presentedFrames:Int;

	/**
		Frames currently waiting in the native video queue.
	**/
	final videoQueueSize:Int;

	/**
		Audio frames queued in the active audio sink.
	**/
	final audioBufferedFrames:Int;

	/**
		Bytes per second copied on the CPU to remove decoder row padding.
	**/
	final copiedBytesPerSecond:Float;

	/**
		Audio playback position minus the media clock, in milliseconds.
	**/
	final audioDriftMs:Float;
}
