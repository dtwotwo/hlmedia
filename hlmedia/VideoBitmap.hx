package hlmedia;

import h2d.Bitmap;
import h2d.Object;
import h2d.RenderContext;
import h2d.Tile;
import h3d.mat.Texture;

/**
	Heaps bitmap that follows a `VideoPlayer` output texture.

	The bitmap does not own the player or its textures. Remove the bitmap from
	its scene before disposing the player.
**/
class VideoBitmap extends Bitmap {
	final player:VideoPlayer;
	final fitScene:Bool;
	var texture:Texture;

	/**
		Creates a bitmap that displays frames from `player`.
	**/
	public function new(player:VideoPlayer, ?parent:Object, fitScene = true) {
		this.player = player;
		this.fitScene = fitScene;
		texture = player.getTexture();
		super(Tile.fromTexture(texture), parent);
		addShader(player.videoTexture.shader);
	}

	override function draw(ctx:RenderContext):Void {
		final current = player.getTexture();
		if (texture != current) {
			texture = current;
			tile = Tile.fromTexture(texture);
		}

		if (fitScene && texture.width > 1 && texture.height > 1)
			fitToScene();
		super.draw(ctx);
	}

	private function fitToScene():Void {
		final scene = getScene();
		if (scene == null || scene.width <= 0 || scene.height <= 0)
			return;

		final scale = Math.min(scene.width / texture.width, scene.height / texture.height);
		width = texture.width * scale;
		height = texture.height * scale;
		x = (scene.width - width) * 0.5;
		y = (scene.height - height) * 0.5;
	}
}
