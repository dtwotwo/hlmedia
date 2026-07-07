package hlmedia.types;

/**
	Decoded video frame data passed from the native decoder to `VideoTexture`.
**/
typedef VideoFrame = {
	/**
		Presentation timestamp in seconds.
	**/
	final pts:Float;

	/**
		Frame width in pixels.
	**/
	final width:Int;

	/**
		Frame height in pixels.
	**/
	final height:Int;

	/**
		Pixel layout used by the frame planes.
	**/
	final format:VideoPixelFormat;

	/**
		Number of populated frame planes.
	**/
	final planeCount:Int;

	/**
		Luma plane for NV12/YUV420P, or packed RGBA bytes for RGBA frames.
	**/
	final y:haxe.io.Bytes;

	/**
		U chroma plane for YUV420P frames.
	**/
	final u:Null<haxe.io.Bytes>;

	/**
		V chroma plane for YUV420P frames.
	**/
	final v:Null<haxe.io.Bytes>;

	/**
		Interleaved UV chroma plane for NV12 frames.
	**/
	final uv:Null<haxe.io.Bytes>;

	/**
		Row stride, in bytes, for the luma or packed RGBA plane.
	**/
	final yStride:Int;

	/**
		Row stride, in bytes, for the U plane.
	**/
	final uStride:Int;

	/**
		Row stride, in bytes, for the V plane.
	**/
	final vStride:Int;

	/**
		Row stride, in bytes, for the interleaved UV plane.
	**/
	final uvStride:Int;

	/**
		Per-plane widths in pixels.
	**/
	final planeWidths:Array<Int>;

	/**
		Per-plane heights in pixels.
	**/
	final planeHeights:Array<Int>;
}
