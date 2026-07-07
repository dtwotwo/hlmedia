import haxe.io.Bytes;
import hxd.fmt.pak.Data;
import hxd.fmt.pak.Writer;
import hlmedia.MediaClock;
import hlmedia.native.NativeMedia;

private function main() {
	var failed = false;
	final issues:Array<String> = [];

	run("invalid open", () -> {
		final handle = NativeMedia.open("__missing__/missing.mp4");
		assert(handle == null, "missing file should not open");
		assert(NativeMedia.lastError().length > 0, "missing file should populate last error");
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
