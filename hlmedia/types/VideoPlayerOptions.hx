package hlmedia.types;

import hlmedia.audio.AudioSink;
import hlmedia.types.VideoDecodeMode;

/**
	Constructor options for `VideoPlayer`.
**/
typedef VideoPlayerOptions = {
	/**
		Custom audio output. Defaults to `NullAudioSink`.
	**/
	?audioSink:AudioSink,

	/**
		Restart from the beginning at end of stream.
	**/
	?loop:Bool,

	/**
		Initial volume, clamped to `0...1`.
	**/
	?volume:Float,

	/**
		Open the file without starting playback.
	**/
	?startPaused:Bool,

	/**
		Native video decoder backend. Defaults to software.
	**/
	?videoDecodeMode:VideoDecodeMode,

	/**
		Fall back to software decode when hardware setup fails. Defaults to true.
	**/
	?allowHardwareFallback:Bool,

	/**
		Upload native YUV/NV12 planes instead of forcing RGBA conversion. Defaults to true.
	**/
	?preferNativePixelFormat:Bool,

	/**
		Decode on a worker thread instead of during `update()`. Defaults to false.
	**/
	?threadedDecode:Bool,

	/**
		Maximum decoded video frames retained by the worker. Defaults to 6.
	**/
	?maxQueuedVideoFrames:Int,

	/**
		Target number of decoded audio frames. Defaults to 12000.
	**/
	?targetAudioBufferFrames:Int,

	/**
		Seconds of media buffered before playback starts. Defaults to zero.
	**/
	?prebufferSeconds:Float
}
