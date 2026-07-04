package hlmedia;

/**
	Simple monotonic playback clock measured in seconds.
**/
class MediaClock {
	var base = 0.0;
	var startedAt = 0.0;
	var running = false;

	/**
		Creates a stopped clock at time zero.
	**/
	public function new() {}

	/**
		Starts the clock from `time` seconds.
	**/
	public function start(?time = 0.0):Void {
		base = time;
		startedAt = haxe.Timer.stamp();
		running = true;
	}

	/**
		Stops the clock and keeps its current time.
	**/
	public function pause():Void {
		if (!running)
			return;
		base = getTime();
		running = false;
	}

	/**
		Sets the clock to `time` seconds. Running state is unchanged.
	**/
	public function seek(time:Float):Void {
		base = time;
		startedAt = haxe.Timer.stamp();
	}

	/**
		Stops the clock and returns it to time zero.
	**/
	public function reset():Void {
		base = 0.0;
		startedAt = haxe.Timer.stamp();
		running = false;
	}

	/**
		Returns the current clock time in seconds.
	**/
	public function getTime():Float {
		return running ? base + haxe.Timer.stamp() - startedAt : base;
	}
}
