package;

import h2d.Text;
import hxd.App;
import hxd.Key;
import hlmedia.VideoBitmap;
import hlmedia.types.VideoDecodeMode;
import hlmedia.types.VideoPixelFormat;
import hlmedia.VideoPlayer;

class Main extends App {
	var video:VideoPlayer;
	var bitmap:VideoBitmap;
	var stats:Text;
	var path:String;
	var error:String;
	var mode:VideoDecodeMode = Software;
	var preferNativePixelFormat = true;

	override function init():Void {
		path = Sys.args()[0] ?? "../res/video/video.mp4";
		stats = new Text(hxd.res.DefaultFont.get(), s2d);
		stats.x = 12;
		stats.y = 12;
		openVideo();
	}

	override function update(dt:Float):Void {
		if (Key.isPressed(Key.NUMBER_1))
			switchMode(Software, true);
		if (Key.isPressed(Key.NUMBER_2))
			switchMode(HardwareAuto, true);
		if (Key.isPressed(Key.NUMBER_3))
			switchMode(HardwareD3D11VA, true);
		if (Key.isPressed(Key.NUMBER_4))
			switchMode(Software, false);
		if (Key.isPressed(Key.NUMBER_5))
			switchMode(HardwareVAAPI, true);
		if (Key.isPressed(Key.NUMBER_6))
			switchMode(HardwareVideoToolbox, true);
		if (Key.isPressed(Key.NUMBER_7))
			switchMode(HardwareCUDA, true);
		if (Key.isPressed(Key.NUMBER_8))
			switchMode(HardwareD3D12VA, true);
		if (Key.isPressed(Key.R))
			openVideo();
		if (Key.isPressed(Key.SPACE)) {
			if (video == null)
				return;

			if (video.isPlaying)
				video.pause();
			else
				video.play();
		}

		if (video == null) {
			stats.text = error;
			return;
		}

		video.update(dt);

		stats.text = [
			"decode mode: " + modeName(mode),
			"actual backend: " + video.actualDecodeBackend,
			"pixel format: " + pixelFormatName(video.videoTexture.pixelFormat),
			"resolution: " + video.getInfo().width + "x" + video.getInfo().height,
			"average decode ms: " + formatFloat(video.averageDecodeTimeMs),
			"average upload ms: " + formatFloat(video.averageUploadTimeMs),
			"dropped frames: " + video.droppedFrames,
			"queue size: " + video.currentVideoQueueSize,
			"CPU RGBA conversion path: " + (!preferNativePixelFormat || video.videoTexture.pixelFormat == RGBA)
		].join("\n");
	}

	private function switchMode(nextMode:VideoDecodeMode, nextPreferNativePixelFormat:Bool):Void {
		mode = nextMode;
		preferNativePixelFormat = nextPreferNativePixelFormat;
		openVideo();
	}

	private function openVideo():Void {
		video?.close();
		bitmap?.remove();

		video = new VideoPlayer({
			audioSink: new OpenALSink(),
			loop: true,
			videoDecodeMode: mode,
			allowHardwareFallback: true,
			preferNativePixelFormat: preferNativePixelFormat
		});

		try {
			video.open(path);
		} catch (e) {
			error = "Failed to open video: " + path + "\n" + Std.string(e);
			video = null;
			stats.text = error;
			return;
		}

		video.play();
		bitmap = video.createBitmap(s2d);
		stats.remove();
		s2d.addChild(stats);
	}

	private function modeName(value:VideoDecodeMode):String {
		return switch value {
			case Software: "Software";
			case HardwareAuto: "HardwareAuto";
			case HardwareD3D11VA: "HardwareD3D11VA";
			case HardwareDXVA2: "HardwareDXVA2";
			case HardwareVAAPI: "HardwareVAAPI";
			case HardwareVideoToolbox: "HardwareVideoToolbox";
			case HardwareCUDA: "HardwareCUDA";
			case HardwareD3D12VA: "HardwareD3D12VA";
			default: "Unknown";
		}
	}

	private function pixelFormatName(value:VideoPixelFormat):String {
		return switch value {
			case RGBA: "RGBA";
			case YUV420P: "YUV420P";
			case NV12: "NV12";
			case P010: "P010";
			default: "Unknown";
		}
	}

	private function formatFloat(value:Float):String {
		return Std.string(Math.round(value * 100) * .01);
	}

	override function dispose():Void {
		video?.close();
		super.dispose();
	}

	static function main():Void {
		new Main();
	}
}
