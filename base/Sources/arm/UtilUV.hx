package arm;

import iron.System;

class UtilUV {

	public static var uvmap: Image = null;
	public static var uvmapCached = false;
	public static var trianglemap: Image = null;
	public static var trianglemapCached = false;
	public static var dilatemap: Image = null;
	public static var dilatemapCached = false;
	public static var uvislandmap: Image = null;
	public static var uvislandmapCached = false;
	static var dilateBytes: js.lib.ArrayBuffer = null;
	static var pipeDilate: PipelineState = null;

	public static function cacheUVMap() {
		if (uvmap != null && (uvmap.width != Config.getTextureResX() || uvmap.height != Config.getTextureResY())) {
			uvmap.unload();
			uvmap = null;
			uvmapCached = false;
		}

		if (uvmapCached) return;

		var resX = Config.getTextureResX();
		var resY = Config.getTextureResY();
		if (uvmap == null) {
			uvmap = Image.createRenderTarget(resX, resY);
		}

		uvmapCached = true;
		var merged = Context.raw.mergedObject;
		var mesh = (Context.raw.layerFilter == 0 && merged != null) ?
					merged.data.raw : Context.raw.paintObject.data.raw;

		var texa = mesh.vertex_arrays[2].values;
		var inda = mesh.index_arrays[0].values;
		uvmap.g2.begin(true, 0x00000000);
		uvmap.g2.color = 0xffcccccc;
		var strength = resX > 2048 ? 2.0 : 1.0;
		var f = (1 / 32767) * uvmap.width;
		for (i in 0...Std.int(inda.length / 3)) {
			var x1 = (texa[inda[i * 3    ] * 2    ]) * f;
			var x2 = (texa[inda[i * 3 + 1] * 2    ]) * f;
			var x3 = (texa[inda[i * 3 + 2] * 2    ]) * f;
			var y1 = (texa[inda[i * 3    ] * 2 + 1]) * f;
			var y2 = (texa[inda[i * 3 + 1] * 2 + 1]) * f;
			var y3 = (texa[inda[i * 3 + 2] * 2 + 1]) * f;
			uvmap.g2.drawLine(x1, y1, x2, y2, strength);
			uvmap.g2.drawLine(x2, y2, x3, y3, strength);
			uvmap.g2.drawLine(x3, y3, x1, y1, strength);
		}
		uvmap.g2.end();
	}

	public static function cacheTriangleMap() {
		if (trianglemap != null && (trianglemap.width != Config.getTextureResX() || trianglemap.height != Config.getTextureResY())) {
			trianglemap.unload();
			trianglemap = null;
			trianglemapCached = false;
		}

		if (trianglemapCached) return;

		if (trianglemap == null) {
			trianglemap = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY());
		}

		trianglemapCached = true;
		var merged = Context.raw.mergedObject != null ? Context.raw.mergedObject.data.raw : Context.raw.paintObject.data.raw;
		var mesh = merged;
		var texa = mesh.vertex_arrays[2].values;
		var inda = mesh.index_arrays[0].values;
		trianglemap.g2.begin(true, 0xff000000);
		var f = (1 / 32767) * trianglemap.width;
		var color = 0xff000001;
		for (i in 0...Std.int(inda.length / 3)) {
			if (color == 0xffffffff) color = 0xff000001;
			color++;
			trianglemap.g2.color = color;
			var x1 = (texa[inda[i * 3    ] * 2    ]) * f;
			var x2 = (texa[inda[i * 3 + 1] * 2    ]) * f;
			var x3 = (texa[inda[i * 3 + 2] * 2    ]) * f;
			var y1 = (texa[inda[i * 3    ] * 2 + 1]) * f;
			var y2 = (texa[inda[i * 3 + 1] * 2 + 1]) * f;
			var y3 = (texa[inda[i * 3 + 2] * 2 + 1]) * f;
			trianglemap.g2.fillTriangle(x1, y1, x2, y2, x3, y3);
		}
		trianglemap.g2.end();
	}

	public static function cacheDilateMap() {
		if (dilatemap != null && (dilatemap.width != Config.getTextureResX() || dilatemap.height != Config.getTextureResY())) {
			dilatemap.unload();
			dilatemap = null;
			dilatemapCached = false;
		}

		if (dilatemapCached) return;

		if (dilatemap == null) {
			dilatemap = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY(), TextureFormat.R8);
		}

		if (pipeDilate == null) {
			pipeDilate = new PipelineState();
			pipeDilate.vertexShader = System.getShader("dilate_map.vert");
			pipeDilate.fragmentShader = System.getShader("dilate_map.frag");
			var vs = new VertexStructure();
			#if (krom_metal || krom_vulkan)
			vs.add("tex", VertexData.I16_2X_Normalized);
			#else
			vs.add("pos", VertexData.I16_4X_Normalized);
			vs.add("nor", VertexData.I16_2X_Normalized);
			vs.add("tex", VertexData.I16_2X_Normalized);
			#end
			pipeDilate.inputLayout = [vs];
			pipeDilate.depthWrite = false;
			pipeDilate.depthMode = CompareMode.Always;
			pipeDilate.colorAttachments[0] = TextureFormat.R8;
			pipeDilate.compile();
			// dilateTexUnpack = pipeDilate.getConstantLocation("texUnpack");
		}

		var mask = Context.objectMaskUsed() ? Context.raw.layer.getObjectMask() : 0;
		if (Context.layerFilterUsed()) mask = Context.raw.layerFilter;
		var geom = mask == 0 && Context.raw.mergedObject != null ? Context.raw.mergedObject.data : Context.raw.paintObject.data;
		var g4 = dilatemap.g4;
		g4.begin();
		g4.clear(0x00000000);
		g4.setPipeline(pipeDilate);
		#if (krom_metal || krom_vulkan)
		g4.setVertexBuffer(geom.get([{name: "tex", data: "short2norm"}]));
		#else
		g4.setVertexBuffer(geom.vertexBuffer);
		#end
		g4.setIndexBuffer(geom.indexBuffers[0]);
		g4.drawIndexedVertices();
		g4.end();
		dilatemapCached = true;
		dilateBytes = null;
	}

	public static function cacheUVIslandMap() {
		cacheDilateMap();
		if (dilateBytes == null) {
			dilateBytes = dilatemap.getPixels();
		}
		UtilRender.pickPosNorTex();
		var w = 2048; // Config.getTextureResX()
		var h = 2048; // Config.getTextureResY()
		var x = Std.int(Context.raw.uvxPicked * w);
		var y = Std.int(Context.raw.uvyPicked * h);
		var bytes = new js.lib.ArrayBuffer(w * h);
		var view = new js.lib.DataView(bytes);
		var coords: Array<TCoord> = [{ x: x, y: y }];
		var r = Std.int(dilatemap.width / w);

		function check(c: TCoord) {
			if (c.x < 0 || c.x >= w || c.y < 0 || c.y >= h) return;
			if (view.getUint8(c.y * w + c.x) == 255) return;
			var dilateView = new js.lib.DataView(dilateBytes);
			if (dilateView.getUint8(c.y * r * dilatemap.width + c.x * r) == 0) return;
			view.setUint8(c.y * w + c.x, 255);
			coords.push({ x: c.x + 1, y: c.y });
			coords.push({ x: c.x - 1, y: c.y });
			coords.push({ x: c.x, y: c.y + 1 });
			coords.push({ x: c.x, y: c.y - 1 });
		}

		while (coords.length > 0) {
			check(coords.pop());
		}

		if (uvislandmap != null) {
			uvislandmap.unload();
		}
		uvislandmap = Image.fromBytes(bytes, w, h, TextureFormat.R8);
		uvislandmapCached = true;
	}
}

typedef TCoord = {
	public var x: Int;
	public var y: Int;
}