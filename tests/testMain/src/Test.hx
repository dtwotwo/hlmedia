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
