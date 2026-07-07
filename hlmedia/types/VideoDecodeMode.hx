package hlmedia.types;

/**
	Video decoder backend requested from the native decoder.

	Hardware modes are opt-in. `VideoPlayer` defaults to `Software`, and hardware
	requests fall back to software unless `allowHardwareFallback` is set to `false`.
**/
enum abstract VideoDecodeMode(Int) from Int to Int {
	/**
		Use FFmpeg software decoding.
	**/
	final Software = 0;

	/**
		Select the preferred hardware decoder for the current platform.
	**/
	final HardwareAuto = 1;

	/**
		Request D3D11VA hardware decoding on Windows.
	**/
	final HardwareD3D11VA = 2;

	/**
		Request DXVA2 hardware decoding on Windows.
	**/
	final HardwareDXVA2 = 3;

	/**
		Request VAAPI hardware decoding on Linux.
	**/
	final HardwareVAAPI = 4;

	/**
		Request VideoToolbox hardware decoding on macOS.
	**/
	final HardwareVideoToolbox = 5;

	/**
		Request CUDA hardware decoding when supported by FFmpeg and the GPU driver.
	**/
	final HardwareCUDA = 6;

	/**
		Request D3D12VA hardware decoding on Windows.
	**/
	final HardwareD3D12VA = 7;
}
