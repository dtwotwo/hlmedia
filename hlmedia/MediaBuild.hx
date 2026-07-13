package hlmedia;

import hlmedia.native.NativeMedia;
import hlmedia.types.MediaBuildInfo;

class MediaBuild {
	public static function getInfo():MediaBuildInfo {
		return NativeMedia.buildInfo();
	}
}
