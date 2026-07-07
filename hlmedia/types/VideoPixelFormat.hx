package hlmedia.types;

/**
	Pixel layouts returned by the native decoder.
**/
enum abstract VideoPixelFormat(Int) from Int to Int {
	/**
		Packed RGBA pixels used when planar upload is bypassed.
	**/
	final RGBA = 0;

	/**
		Separate luma, U, and V planes.
	**/
	final YUV420P = 1;

	/**
		Luma plane plus interleaved chroma plane.
	**/
	final NV12 = 2;

	/**
		10-bit luma plane plus interleaved chroma plane.
	**/
	final P010 = 3;
}
