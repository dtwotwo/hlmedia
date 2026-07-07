package hlmedia;

import hlmedia.types.VideoColorRange;
import hlmedia.types.VideoColorSpace;

/**
	Converts uploaded YUV video textures to RGB output.
**/
class VideoShader extends hxsl.Shader {
	static var SRC = {
		@param var rgbaTexture:Sampler2D;
		@param var yTexture:Sampler2D;
		@param var uTexture:Sampler2D;
		@param var vTexture:Sampler2D;
		@param var uvTexture:Sampler2D;
		@param var useRGBA:Bool;
		@param var useNV12:Bool;
		@param var fullRange:Bool;
		@param var colorSpaceIndex:Int;
		var calculatedUV:Vec2;
		var pixelColor:Vec4;
		function fragment() {
			if (useRGBA) {
				pixelColor = rgbaTexture.get(calculatedUV);
			} else {
				var y = yTexture.get(calculatedUV).r;
				var u = 0.0;
				var v = 0.0;
				if (useNV12) {
					var uv = uvTexture.get(calculatedUV);
					u = uv.r;
					v = uv.g;
				} else {
					u = uTexture.get(calculatedUV).r;
					v = vTexture.get(calculatedUV).r;
				}

				var yy = y;
				if (!fullRange)
					yy = (y - 0.0625) * 1.16438356;
				u -= 0.5;
				v -= 0.5;

				var r = yy + 1.5748 * v;
				var g = yy - 0.1873 * u - 0.4681 * v;
				var b = yy + 1.8556 * u;
				if (colorSpaceIndex == 0) {
					r = yy + 1.4020 * v;
					g = yy - 0.3441 * u - 0.7141 * v;
					b = yy + 1.7720 * u;
				}
				pixelColor = vec4(r, g, b, 1.0);
			}
		}
	}

	/**
		Color conversion matrix used for YUV to RGB output.
	**/
	public var colorSpace(default, set):VideoColorSpace = BT709;

	/**
		Input value range used by decoded video planes.
	**/
	public var colorRange(default, set):VideoColorRange = Limited;

	/**
		Creates a shader configured for BT.709 limited-range video.
	**/
	public function new() {
		super();
		this.colorSpace = BT709;
		this.colorRange = Limited;
	}

	@:noCompletion
	private function set_colorSpace(value:VideoColorSpace):VideoColorSpace {
		colorSpace = value;
		colorSpaceIndex = switch value {
			case BT601: 0;
			case BT709: 1;
			case BT2020: 2;
		}
		return value;
	}

	@:noCompletion
	private function set_colorRange(value:VideoColorRange):VideoColorRange {
		colorRange = value;
		fullRange = value == Full;
		return value;
	}
}
