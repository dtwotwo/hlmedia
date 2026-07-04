package hlmedia;

import h3d.mat.Texture;
import h3d.mat.Data.TextureFlags;
import haxe.io.Bytes;
import hxd.Pixels;
import hxd.PixelFormat;
import hlmedia.MediaError;
import hlmedia.VideoFrame.VideoFrame;
import hlmedia.VideoFrame.VideoPixelFormat;

/**
	GPU texture set used to upload decoded video frames.
**/
class VideoTexture {
	/**
		Shader used to convert planar video textures to RGB output.
	**/
	public var shader(default, null):VideoShader;

	/**
		RGB texture for display.
	**/
	public var output(default, null):Texture;

	/**
		Luma texture for NV12 and YUV420P frames.
	**/
	public var yTexture(default, null):Texture;

	/**
		U chroma texture for YUV420P frames.
	**/
	public var uTexture(default, null):Texture;

	/**
		V chroma texture for YUV420P frames.
	**/
	public var vTexture(default, null):Texture;

	/**
		Interleaved UV chroma texture for NV12 frames.
	**/
	public var uvTexture(default, null):Texture;

	var width = 0;
	var height = 0;
	var format:VideoPixelFormat;

	/**
		Creates a texture set with initial 1x1 textures.
	**/
	public function new() {
		shader = new VideoShader();
		output = filledTexture(1, 1, RGBA, 255);
		yTexture = filledTexture(1, 1, R8, 0);
		uTexture = filledTexture(1, 1, R8, 128);
		vTexture = filledTexture(1, 1, R8, 128);
		uvTexture = filledTexture(1, 1, RG8, 128);
		shader.useNV12 = true;
		shader.yTexture = yTexture;
		shader.uTexture = uTexture;
		shader.vTexture = vTexture;
		shader.uvTexture = uvTexture;
	}

	/**
		Uploads decoded frame planes to GPU textures.
	**/
	public function upload(frame:VideoFrame):Void {
		ensure(frame.width, frame.height, frame.format);

		switch frame.format {
			case NV12:
				uploadPlane(yTexture, frame.y, frame.width, frame.height, frame.yStride, R8);
				uploadPlane(uvTexture, frame.uv, frame.width >> 1, frame.height >> 1, frame.uvStride, RG8);
				shader.useNV12 = true;
				shader.yTexture = yTexture;
				shader.uvTexture = uvTexture;
			case YUV420P:
				uploadPlane(yTexture, frame.y, frame.width, frame.height, frame.yStride, R8);
				uploadPlane(uTexture, frame.u, frame.width >> 1, frame.height >> 1, frame.uStride, R8);
				uploadPlane(vTexture, frame.v, frame.width >> 1, frame.height >> 1, frame.vStride, R8);
				shader.useNV12 = false;
				shader.yTexture = yTexture;
				shader.uTexture = uTexture;
				shader.vTexture = vTexture;
			case RGBAFallback:
				uploadPlane(output, frame.y, frame.width, frame.height, frame.yStride, RGBA);
		}
	}

	/**
		Releases all GPU textures owned by this instance.
	**/
	public function dispose():Void {
		for (texture in [output, yTexture, uTexture, vTexture, uvTexture])
			if (texture != null)
				texture.dispose();
	}

	private function ensure(width:Int, height:Int, format:VideoPixelFormat):Void {
		if (this.width == width && this.height == height && this.format == format)
			return;

		dispose();
		this.width = width;
		this.height = height;
		this.format = format;

		final flags = [TextureFlags.Dynamic];
		output = filledTexture(width, height, RGBA, 255);
		switch format {
			case NV12:
				yTexture = new Texture(width, height, flags, R8);
				uTexture = filledTexture(1, 1, R8, 128);
				vTexture = filledTexture(1, 1, R8, 128);
				uvTexture = new Texture(width >> 1, height >> 1, flags, RG8);
			case YUV420P:
				yTexture = new Texture(width, height, flags, R8);
				uTexture = new Texture(width >> 1, height >> 1, flags, R8);
				vTexture = new Texture(width >> 1, height >> 1, flags, R8);
				uvTexture = filledTexture(1, 1, RG8, 128);
			case RGBAFallback:
				yTexture = filledTexture(1, 1, R8, 0);
				uTexture = filledTexture(1, 1, R8, 128);
				vTexture = filledTexture(1, 1, R8, 128);
				uvTexture = filledTexture(1, 1, RG8, 128);
		}
		shader.yTexture = yTexture;
		shader.uTexture = uTexture;
		shader.vTexture = vTexture;
		shader.uvTexture = uvTexture;
	}

	private function uploadPlane(texture:Texture, source:Bytes, width:Int, height:Int, stride:Int, pixelFormat:PixelFormat):Void {
		if (source == null)
			throw TextureUploadFailed("Missing video plane");

		final rowSize = Pixels.calcStride(width, pixelFormat);
		final packed = if (stride == rowSize) source else {
			final bytes = Bytes.alloc(rowSize * height);
			for (row in 0...height)
				bytes.blit(row * rowSize, source, row * stride, rowSize);
			bytes;
		}

		texture.uploadPixels(new Pixels(width, height, packed, pixelFormat));
	}

	private function filledTexture(width:Int, height:Int, pixelFormat:PixelFormat, value:Int):Texture {
		final texture = new Texture(width, height, [TextureFlags.Dynamic], pixelFormat);
		final bytes = Bytes.alloc(Pixels.calcStride(width, pixelFormat) * height);
		for (i in 0...bytes.length)
			bytes.set(i, value);
		texture.uploadPixels(new Pixels(width, height, bytes, pixelFormat));
		return texture;
	}
}
