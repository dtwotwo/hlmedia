import haxe.io.Bytes;
import hxd.fmt.pak.Data;
import hxd.fmt.pak.Writer;
import hlmedia.MediaClock;
import hlmedia.native.NativeMedia;
import hlmedia.types.VideoDecodeMode;
import hlmedia.types.VideoPixelFormat;

private function main() {
	var failed = false;
	final issues:Array<String> = [];

	run("invalid open", () -> {
		final handle = NativeMedia.open("__missing__/missing.mp4");
		assert(handle == null, "missing file should not open");
		assert(NativeMedia.lastError().length > 0, "missing file should populate last error");
	}, issues);

	run("video type values", () -> {
		assert((RGBA : Int) == 0, "RGBA pixel format should be 0");
		assert((YUV420P : Int) == 1, "YUV420P pixel format should be 1");
		assert((NV12 : Int) == 2, "NV12 pixel format should be 2");
		assert((P010 : Int) == 3, "P010 pixel format should be 3");
		assert((Software : Int) == 0, "software decode mode should be 0");
		assert((HardwareAuto : Int) == 1, "hardware auto decode mode should be 1");
		assert((HardwareD3D11VA : Int) == 2, "D3D11VA decode mode should be 2");
		assert((HardwareCUDA : Int) == 6, "CUDA decode mode should be 6");
		assert((HardwareD3D12VA : Int) == 7, "D3D12VA decode mode should be 7");
		final format:VideoPixelFormat = NV12;
		final mode:VideoDecodeMode = HardwareAuto;
		assert((format : Int) == 2, "VideoPixelFormat should convert to Int");
		assert((mode : Int) == 1, "VideoDecodeMode should convert to Int");
	}, issues);

	run("invalid open with options", () -> {
		final handle = NativeMedia.open("__missing__/missing.mp4", HardwareAuto, true, true);
		assert(handle == null, "missing file should not open with decode options");
		assert(NativeMedia.lastError().length > 0, "option open should populate last error");
	}, issues);

	run("pak resource bytes", () -> {
		final pakPath = "pak-video-test.pak";
		deleteFile(pakPath);
		writePak(pakPath, "video.mp4", Bytes.ofString("not an mp4"));

		final pak = new hxd.fmt.pak.FileSystem();
		pak.loadPak(pakPath);
		final entry = pak.get("video.mp4");
		assert(entry.getBytes().toString() == "not an mp4", "pak entry bytes should be readable");

		final pathHandle = NativeMedia.open(entry.path);
		assert(pathHandle == null, "pak entry path should not open as a local file");
		final pathError = NativeMedia.lastError();
		assert(pathError.indexOf("No such file") >= 0, "path open should fail on missing local file");

		final bytesHandle = NativeMedia.openBytes(entry.path, entry.getBytes());
		assert(bytesHandle == null, "invalid pak media bytes should not decode");
		final bytesError = NativeMedia.lastError();
		assert(bytesError.length > 0, "bytes open should populate last error");
		assert(bytesError.indexOf("No such file") < 0, "bytes open should read pak bytes instead of local path");

		pak.dispose();
		deleteFile(pakPath);
	}, issues);

	run("media clock", () -> {
		final clock = new MediaClock();
		assertNear(0, clock.getTime(), 0.001, "new clock should start at zero");

		clock.start(1.0);
		Sys.sleep(0.02);
		assert(clock.getTime() >= 1.0, "running clock should advance from base time");

		clock.pause();
		final paused = clock.getTime();
		Sys.sleep(0.02);
		assertNear(paused, clock.getTime(), 0.01, "paused clock should not advance");

		clock.seek(2.5);
		assertNear(2.5, clock.getTime(), 0.01, "seek should update clock time");

		clock.reset();
		assertNear(0, clock.getTime(), 0.001, "reset should return to zero");
	}, issues);

	run("decode seek replay", () -> {
		final handle = NativeMedia.open("res/decode-seek-replay.mp4");
		assert(handle != null, "test video should open");
		NativeMedia.play(handle);
		final firstPass = decodeAllFrames(handle);
		assert(firstPass.video > 0, "first pass should decode video frames");
		assert(firstPass.audio > 0, "first pass should decode audio frames");
		assert(NativeMedia.seek(handle, 0), "seek to start should succeed after EOF");
		NativeMedia.play(handle);
		final secondPass = decodeAllFrames(handle);
		assert(secondPass.video == firstPass.video, "second pass should decode the same number of video frames");
		assert(secondPass.audio == firstPass.audio, "second pass should decode the same number of audio frames");
		NativeMedia.close(handle);
	}, issues);

	if (issues.length > 0) {
		Sys.println("");
		Sys.println("Failed checks: " + issues.length);
		for (issue in issues)
			Sys.println("- " + issue);
		failed = true;
	}

	if (failed)
		Sys.exit(1);

	Sys.println("HL tests passed.");
}

private function run(label:String, test:Void->Void, issues:Array<String>):Void {
	try {
		test();
		Sys.println("OK " + label);
	}
	catch (e) {
		final message = label + ": " + Std.string(e);
		issues.push(message);
		Sys.println("FAIL " + message);
	}
}

private function assert(condition:Bool, message:String):Void {
	if (!condition)
		throw message;
}

private function assertNear(expected:Float, actual:Float, tolerance:Float, message:String):Void {
	if (Math.isNaN(actual) || Math.abs(expected - actual) > tolerance)
		throw message + " expected " + expected + " got " + actual;
}

private function writePak(path:String, entryPath:String, bytes:Bytes):Void {
	final file = new File();
	file.name = entryPath;
	file.isDirectory = false;
	file.dataPosition = 0;
	file.dataSize = bytes.length;
	file.checksum = 0;

	final root = new File();
	root.name = "<root>";
	root.isDirectory = true;
	root.content = [file];

	final pak = new Data();
	pak.version = 0;
	pak.root = root;

	final output = sys.io.File.write(path, true);
	try {
		new Writer(output).write(pak, bytes);
	}
	catch (e) {
		output.close();
		throw e;
	}
	output.close();
}

private function deleteFile(path:String):Void {
	if (sys.FileSystem.exists(path))
		sys.FileSystem.deleteFile(path);
}

private function decodeAllFrames(handle:NativeHandle):{video:Int, audio:Int} {
	var videoFrames = 0;
	var audioFrames = 0;
	var iterations = 0;
	while (iterations++ < 100000) {
		final result = NativeMedia.decode(handle);
		while (true) {
			final frame = NativeMedia.getVideoFrame(handle);
			if (frame == null)
				break;
			videoFrames++;
			NativeMedia.releaseVideoFrame(handle, frame);
		}
		while (true) {
			final chunk = NativeMedia.getAudioSamples(handle, 4096);
			if (chunk == null)
				break;
			audioFrames += NativeMedia.audioChunkFrames(chunk);
			NativeMedia.releaseAudioSamples(handle, chunk);
		}
		if (result == 0)
			return {video: videoFrames, audio: audioFrames};
		assert(result > 0, "decode should not fail");
	}
	throw "decode did not reach EOF";
}
