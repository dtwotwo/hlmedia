package;

import hxd.App;
import hxd.Key;
import hlmedia.VideoBitmap;
import hlmedia.VideoPlayer;

class Main extends App {
	var video:VideoPlayer;
	var bitmap:VideoBitmap;

	override function init():Void {
		video = new VideoPlayer({loop: true, audioSink: new OpenALSink()});
		video.open("../res/video/video.mp4");
		video.play();

		bitmap = video.createBitmap(s2d);
	}

	override function update(dt:Float):Void {
		if (Key.isPressed(Key.SPACE)) {
			if (video.isPlaying)
				video.pause();
			else
				video.play();
		}

		if (Key.isPressed(Key.LEFT))
			video.seek(video.time - 5);
		if (Key.isPressed(Key.RIGHT))
			video.seek(video.time + 5);
		if (Key.isPressed(Key.L))
			video.setLoop(true);

		video.update(dt);
	}

	override function dispose():Void {
		video.close();
		bitmap = null;
		super.dispose();
	}

	static function main():Void {
		new Main();
	}
}
