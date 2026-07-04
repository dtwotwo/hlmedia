package hlmedia.native;

import haxe.io.Bytes;
import hlmedia.VideoFrame.VideoPixelFormat;

private typedef NativeHandleData = hl.Abstract<"hlmedia_decoder">;
private typedef NativeFrameData = hl.Abstract<"hlmedia_frame">;
private typedef NativeAudioChunkData = hl.Abstract<"hlmedia_audio_chunk">;

@:noDoc
abstract NativeHandle(NativeHandleData) from NativeHandleData to NativeHandleData {}

@:noDoc
abstract NativeFrame(NativeFrameData) from NativeFrameData to NativeFrameData {}

@:noDoc
abstract NativeAudioChunk(NativeAudioChunkData) from NativeAudioChunkData to NativeAudioChunkData {}

@:hlNative("hlmedia")
@:noDoc
class NativeMedia {
	public static inline function open(path:String):NativeHandle {
		final bytes = haxe.io.Bytes.alloc(path.length + 1);
		bytes.blit(0, haxe.io.Bytes.ofString(path), 0, path.length);
		bytes.set(path.length, 0);
		return _open(@:privateAccess bytes.b);
	}

	@:hlNative("hlmedia", "open")
	static function _open(path:hl.Bytes):NativeHandle {
		return null;
	}

	@:hlNative("hlmedia", "close")
	public static function close(handle:NativeHandle):Void {}

	@:hlNative("hlmedia", "decode")
	public static function decode(handle:NativeHandle):Int {
		return 0;
	}

	@:hlNative("hlmedia", "play")
	public static function play(handle:NativeHandle):Void {}

	@:hlNative("hlmedia", "pause")
	public static function pause(handle:NativeHandle, paused:Bool):Void {}

	@:hlNative("hlmedia", "stop")
	public static function stop(handle:NativeHandle):Void {}

	@:hlNative("hlmedia", "seek")
	public static function seek(handle:NativeHandle, seconds:Float):Bool {
		return false;
	}

	@:hlNative("hlmedia", "duration")
	public static function duration(handle:NativeHandle):Float {
		return 0;
	}

	@:hlNative("hlmedia", "width")
	public static function width(handle:NativeHandle):Int {
		return 0;
	}

	@:hlNative("hlmedia", "height")
	public static function height(handle:NativeHandle):Int {
		return 0;
	}

	@:hlNative("hlmedia", "fps")
	public static function fps(handle:NativeHandle):Float {
		return 0;
	}

	@:hlNative("hlmedia", "has_audio")
	public static function hasAudio(handle:NativeHandle):Bool {
		return false;
	}

	@:hlNative("hlmedia", "sample_rate")
	public static function sampleRate(handle:NativeHandle):Int {
		return 0;
	}

	@:hlNative("hlmedia", "channels")
	public static function channels(handle:NativeHandle):Int {
		return 0;
	}

	public static inline function videoCodec(handle:NativeHandle):String {
		return @:privateAccess String.fromUTF8(_videoCodec(handle));
	}

	public static inline function audioCodec(handle:NativeHandle):String {
		return @:privateAccess String.fromUTF8(_audioCodec(handle));
	}

	public static inline function lastError():String {
		return @:privateAccess String.fromUTF8(_lastError());
	}

	@:hlNative("hlmedia", "video_codec")
	static function _videoCodec(handle:NativeHandle):hl.Bytes {
		return null;
	}

	@:hlNative("hlmedia", "audio_codec")
	static function _audioCodec(handle:NativeHandle):hl.Bytes {
		return null;
	}

	@:hlNative("hlmedia", "last_error")
	static function _lastError():hl.Bytes {
		return null;
	}

	@:hlNative("hlmedia", "get_video_frame")
	public static function getVideoFrame(handle:NativeHandle):NativeFrame {
		return null;
	}

	@:hlNative("hlmedia", "release_video_frame")
	public static function releaseVideoFrame(handle:NativeHandle, frame:NativeFrame):Void {}

	@:hlNative("hlmedia", "frame_pts")
	public static function framePts(frame:NativeFrame):Float {
		return 0;
	}

	@:hlNative("hlmedia", "frame_format")
	static function frameFormatIndex(frame:NativeFrame):Int {
		return 0;
	}

	public static function frameFormat(frame:NativeFrame):VideoPixelFormat {
		return switch frameFormatIndex(frame) {
			case 1: YUV420P;
			case 2: RGBAFallback;
			default: NV12;
		}
	}

	@:hlNative("hlmedia", "frame_width")
	public static function frameWidth(frame:NativeFrame):Int {
		return 0;
	}

	@:hlNative("hlmedia", "frame_height")
	public static function frameHeight(frame:NativeFrame):Int {
		return 0;
	}

	@:hlNative("hlmedia", "frame_stride")
	public static function frameStride(frame:NativeFrame, plane:Int):Int {
		return 0;
	}

	@:hlNative("hlmedia", "frame_plane_size")
	public static function framePlaneSize(frame:NativeFrame, plane:Int):Int {
		return 0;
	}

	@:hlNative("hlmedia", "frame_plane")
	static function _framePlane(frame:NativeFrame, plane:Int):hl.Bytes {
		return null;
	}

	public static function framePlane(frame:NativeFrame, plane:Int):Bytes {
		final size = framePlaneSize(frame, plane);
		final bytes = _framePlane(frame, plane);
		return bytes == null ? null : @:privateAccess new Bytes(bytes, size);
	}

	@:hlNative("hlmedia", "get_audio_samples")
	public static function getAudioSamples(handle:NativeHandle, maxFrames:Int):NativeAudioChunk {
		return null;
	}

	@:hlNative("hlmedia", "release_audio_samples")
	public static function releaseAudioSamples(handle:NativeHandle, chunk:NativeAudioChunk):Void {}

	@:hlNative("hlmedia", "audio_chunk_frames")
	public static function audioChunkFrames(chunk:NativeAudioChunk):Int {
		return 0;
	}

	@:hlNative("hlmedia", "audio_chunk_size")
	public static function audioChunkSize(chunk:NativeAudioChunk):Int {
		return 0;
	}

	@:hlNative("hlmedia", "audio_chunk_bytes")
	static function _audioChunkBytes(chunk:NativeAudioChunk):hl.Bytes {
		return null;
	}

	public static function audioChunkBytes(chunk:NativeAudioChunk):Bytes {
		final size = audioChunkSize(chunk);
		final bytes = _audioChunkBytes(chunk);
		return bytes == null ? null : @:privateAccess new Bytes(bytes, size);
	}
}
