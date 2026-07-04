package hlmedia;

/**
	Errors thrown by the public Haxe API.
**/
enum MediaError {
	/**
		Native open, decode, or state setup failed.
	**/
	DecodeFailed(message:String);

	/**
		A decoded frame could not be uploaded to GPU textures.
	**/
	TextureUploadFailed(message:String);

	/**
		Native seek failed.
	**/
	SeekFailed(message:String);
}
