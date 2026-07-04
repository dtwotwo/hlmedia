package hlmedia;

/**
	Pixel layouts returned by the native decoder.
**/
enum VideoPixelFormat {
	/**
		Luma plane plus interleaved chroma plane.
	**/
	NV12;

	/**
		Separate luma, U, and V planes.
	**/
	YUV420P;

	/**
		Packed RGBA pixels used when planar upload is bypassed.
	**/
	RGBAFallback;
}

/**
	YUV color conversion matrices supported by `VideoShader`.
**/
enum VideoColorSpace {
	/**
		SD video color conversion matrix.
	**/
	BT601;

	/**
		HD video color conversion matrix.
	**/
	BT709;

	/**
		UHD and HDR video color conversion matrix.
	**/
	BT2020;
}

/**
	Video plane value range used during YUV to RGB conversion.
**/
enum VideoColorRange {
	/**
		Studio range luma/chroma values.
	**/
	Limited;

	/**
		Full range luma/chroma values.
	**/
	Full;
}

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
		Luma plane for NV12/YUV420P, or packed RGBA bytes for RGBAFallback.
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
}
