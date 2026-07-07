package hlmedia.types;

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
