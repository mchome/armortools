package arm;

import iron.System;
import iron.Mat4;
import iron.MeshObject;
import iron.SceneFormat;
import iron.RenderPath;
import iron.Scene;
import iron.App;

class RenderPathPaint {

	static var path: RenderPath;
	public static var liveLayerDrawn = 0; ////

	public static function init(_path: RenderPath) {
		path = _path;

		{
			var t = new RenderTargetRaw();
			t.name = "texpaint_blend0";
			t.width = Config.getTextureResX();
			t.height = Config.getTextureResY();
			t.format = "R8";
			path.createRenderTarget(t);
		}
		{
			var t = new RenderTargetRaw();
			t.name = "texpaint_blend1";
			t.width = Config.getTextureResX();
			t.height = Config.getTextureResY();
			t.format = "R8";
			path.createRenderTarget(t);
		}
		{
			var t = new RenderTargetRaw();
			t.name = "texpaint_picker";
			t.width = 1;
			t.height = 1;
			t.format = "RGBA32";
			path.createRenderTarget(t);
		}
		{
			var t = new RenderTargetRaw();
			t.name = "texpaint_nor_picker";
			t.width = 1;
			t.height = 1;
			t.format = "RGBA32";
			path.createRenderTarget(t);
		}
		{
			var t = new RenderTargetRaw();
			t.name = "texpaint_pack_picker";
			t.width = 1;
			t.height = 1;
			t.format = "RGBA32";
			path.createRenderTarget(t);
		}
		{
			var t = new RenderTargetRaw();
			t.name = "texpaint_uv_picker";
			t.width = 1;
			t.height = 1;
			t.format = "RGBA32";
			path.createRenderTarget(t);
		}

		path.loadShader("shader_datas/copy_mrt3_pass/copy_mrt3_pass");
	}

	public static function commandsPaint(dilation = true) {
		var tid = "";

		if (Context.raw.pdirty > 0) {

			if (Context.raw.tool == ToolPicker) {

					#if krom_metal
					//path.setTarget("texpaint_picker");
					//path.clearTarget(0xff000000);
					//path.setTarget("texpaint_nor_picker");
					//path.clearTarget(0xff000000);
					//path.setTarget("texpaint_pack_picker");
					//path.clearTarget(0xff000000);
					path.setTarget("texpaint_picker", ["texpaint_nor_picker", "texpaint_pack_picker", "texpaint_uv_picker"]);
					#else
					path.setTarget("texpaint_picker", ["texpaint_nor_picker", "texpaint_pack_picker", "texpaint_uv_picker"]);
					//path.clearTarget(0xff000000);
					#end
					path.bindTarget("gbuffer2", "gbuffer2");
					// tid = Context.raw.layer.id;
					path.bindTarget("texpaint" + tid, "texpaint");
					path.bindTarget("texpaint_nor" + tid, "texpaint_nor");
					path.bindTarget("texpaint_pack" + tid, "texpaint_pack");
					path.drawMeshes("paint");
					UIHeader.inst.headerHandle.redraws = 2;

					var texpaint_picker = path.renderTargets.get("texpaint_picker").image;
					var texpaint_nor_picker = path.renderTargets.get("texpaint_nor_picker").image;
					var texpaint_pack_picker = path.renderTargets.get("texpaint_pack_picker").image;
					var texpaint_uv_picker = path.renderTargets.get("texpaint_uv_picker").image;
					var a = texpaint_picker.getPixels();
					var b = texpaint_nor_picker.getPixels();
					var c = texpaint_pack_picker.getPixels();
					var d = texpaint_uv_picker.getPixels();

					if (Context.raw.colorPickerCallback != null) {
						Context.raw.colorPickerCallback(Context.raw.pickedColor);
					}

					// Picked surface values
					// #if (krom_metal || krom_vulkan)
					// Context.raw.pickedColor.base.Rb = a.get(2);
					// Context.raw.pickedColor.base.Gb = a.get(1);
					// Context.raw.pickedColor.base.Bb = a.get(0);
					// Context.raw.pickedColor.normal.Rb = b.get(2);
					// Context.raw.pickedColor.normal.Gb = b.get(1);
					// Context.raw.pickedColor.normal.Bb = b.get(0);
					// Context.raw.pickedColor.occlusion = c.get(2) / 255;
					// Context.raw.pickedColor.roughness = c.get(1) / 255;
					// Context.raw.pickedColor.metallic = c.get(0) / 255;
					// Context.raw.pickedColor.height = c.get(3) / 255;
					// Context.raw.pickedColor.opacity = a.get(3) / 255;
					// Context.raw.uvxPicked = d.get(2) / 255;
					// Context.raw.uvyPicked = d.get(1) / 255;
					// #else
					// Context.raw.pickedColor.base.Rb = a.get(0);
					// Context.raw.pickedColor.base.Gb = a.get(1);
					// Context.raw.pickedColor.base.Bb = a.get(2);
					// Context.raw.pickedColor.normal.Rb = b.get(0);
					// Context.raw.pickedColor.normal.Gb = b.get(1);
					// Context.raw.pickedColor.normal.Bb = b.get(2);
					// Context.raw.pickedColor.occlusion = c.get(0) / 255;
					// Context.raw.pickedColor.roughness = c.get(1) / 255;
					// Context.raw.pickedColor.metallic = c.get(2) / 255;
					// Context.raw.pickedColor.height = c.get(3) / 255;
					// Context.raw.pickedColor.opacity = a.get(3) / 255;
					// Context.raw.uvxPicked = d.get(0) / 255;
					// Context.raw.uvyPicked = d.get(1) / 255;
					// #end
			}
			else {
				var texpaint = "texpaint_node_target";

				path.setTarget("texpaint_blend1");
				path.bindTarget("texpaint_blend0", "tex");
				path.drawShader("shader_datas/copy_pass/copyR8_pass");

				path.setTarget(texpaint, ["texpaint_nor" + tid, "texpaint_pack" + tid, "texpaint_blend0"]);

				path.bindTarget("_main", "gbufferD");

				path.bindTarget("texpaint_blend1", "paintmask");

				// Read texcoords from gbuffer
				var readTC = Context.raw.tool == ToolClone ||
							 Context.raw.tool == ToolBlur ||
							 Context.raw.tool == ToolSmudge;
				if (readTC) {
					path.bindTarget("gbuffer2", "gbuffer2");
				}

				path.drawMeshes("paint");
			}
		}
	}

	public static function commandsCursor() {
		var tool = Context.raw.tool;
		if (tool != ToolEraser &&
			tool != ToolClone &&
			tool != ToolBlur &&
			tool != ToolSmudge) {
			return;
		}

		var nodes = UINodes.inst.getNodes();
		var canvas = UINodes.inst.getCanvas(true);
		var inpaint = nodes.nodesSelectedId.length > 0 && nodes.getNode(canvas.nodes, nodes.nodesSelectedId[0]).type == "InpaintNode";

		if (!Base.uiEnabled || Base.isDragging || !inpaint) {
			return;
		}

		var mx = Context.raw.paintVec.x;
		var my = 1.0 - Context.raw.paintVec.y;
		if (Context.raw.brushLocked) {
			mx = (Context.raw.lockStartedX - App.x()) / App.w();
			my = 1.0 - (Context.raw.lockStartedY - App.y()) / App.h();
		}
		var radius = Context.raw.brushRadius;
		drawCursor(mx, my, radius / 3.4);
	}

	static function drawCursor(mx: Float, my: Float, radius: Float, tintR = 1.0, tintG = 1.0, tintB = 1.0) {
		var plane = cast(Scene.active.getChild(".Plane"), MeshObject);
		var geom = plane.data;

		var g = path.frameG;
		if (Base.pipeCursor == null) Base.makeCursorPipe();

		path.setTarget("");
		g.setPipeline(Base.pipeCursor);
		var img = Res.get("cursor.k");
		g.setTexture(Base.cursorTex, img);
		var gbuffer0 = path.renderTargets.get("gbuffer0").image;
		g.setTextureDepth(Base.cursorGbufferD, gbuffer0);
		g.setFloat2(Base.cursorMouse, mx, my);
		g.setFloat2(Base.cursorTexStep, 1 / gbuffer0.width, 1 / gbuffer0.height);
		g.setFloat(Base.cursorRadius, radius);
		var right = Scene.active.camera.rightWorld().normalize();
		g.setFloat3(Base.cursorCameraRight, right.x, right.y, right.z);
		g.setFloat3(Base.cursorTint, tintR, tintG, tintB);
		g.setMatrix(Base.cursorVP, Scene.active.camera.VP);
		var helpMat = Mat4.identity();
		helpMat.getInverse(Scene.active.camera.VP);
		g.setMatrix(Base.cursorInvVP, helpMat);
		#if (krom_metal || krom_vulkan)
		g.setVertexBuffer(geom.get([{name: "tex", data: "short2norm"}]));
		#else
		g.setVertexBuffer(geom.vertexBuffer);
		#end
		g.setIndexBuffer(geom.indexBuffers[0]);
		g.drawIndexedVertices();

		g.disableScissor();
		path.end();
	}

	static function paintEnabled(): Bool {
		return !Context.raw.foregroundEvent;
	}

	public static function begin() {
		if (!paintEnabled()) return;
	}

	public static function end() {
		commandsCursor();
		Context.raw.ddirty--;
		Context.raw.rdirty--;

		if (!paintEnabled()) return;
		Context.raw.pdirty--;
	}

	public static function draw() {
		if (!paintEnabled()) return;

		commandsPaint();

		if (Context.raw.brushBlendDirty) {
			Context.raw.brushBlendDirty = false;
			#if krom_metal
			path.setTarget("texpaint_blend0");
			path.clearTarget(0x00000000);
			path.setTarget("texpaint_blend1");
			path.clearTarget(0x00000000);
			#else
			path.setTarget("texpaint_blend0", ["texpaint_blend1"]);
			path.clearTarget(0x00000000);
			#end
		}
	}

	public static function bindLayers() {
		var image: Image = null;
		var nodes = UINodes.inst.getNodes();
		var canvas = UINodes.inst.getCanvas(true);
		if (nodes.nodesSelectedId.length > 0) {
			var node = nodes.getNode(canvas.nodes, nodes.nodesSelectedId[0]);
			var brushNode = ParserLogic.getLogicNode(node);
			if (brushNode != null) {
				image = brushNode.getCachedImage();
			}
		}
		if (image != null) {
			if (path.renderTargets.get("texpaint_node") == null) {
				var t = new RenderTargetRaw();
				t.name = "texpaint_node";
				t.width = Config.getTextureResX();
				t.height = Config.getTextureResY();
				t.format = "RGBA32";
				var rt = new RenderTarget(t);
				path.renderTargets.set(t.name, rt);
			}
			if (path.renderTargets.get("texpaint_node_target") == null) {
				var t = new RenderTargetRaw();
				t.name = "texpaint_node_target";
				t.width = Config.getTextureResX();
				t.height = Config.getTextureResY();
				t.format = "RGBA32";
				var rt = new RenderTarget(t);
				path.renderTargets.set(t.name, rt);
			}
			path.renderTargets.get("texpaint_node").image = image;
			path.bindTarget("texpaint_node", "texpaint");
			path.bindTarget("texpaint_nor_empty", "texpaint_nor");
			path.bindTarget("texpaint_pack_empty", "texpaint_pack");

			var nodes = UINodes.inst.getNodes();
			var canvas = UINodes.inst.getCanvas(true);
			var node = nodes.getNode(canvas.nodes, nodes.nodesSelectedId[0]);
			var inpaint = node.type == "InpaintNode";
			if (inpaint) {
				var brushNode = ParserLogic.getLogicNode(node);
				path.renderTargets.get("texpaint_node_target").image = cast(brushNode, arm.nodes.InpaintNode).getTarget();
			}
		}
		else {
			path.bindTarget("texpaint", "texpaint");
			path.bindTarget("texpaint_nor", "texpaint_nor");
			path.bindTarget("texpaint_pack", "texpaint_pack");
		}
	}

	public static function unbindLayers() {

	}

	static function u32(ar: Array<Int>): js.lib.Uint32Array {
		var res = new js.lib.Uint32Array(ar.length);
		for (i in 0...ar.length) res[i] = ar[i];
		return res;
	}

	static function i16(ar: Array<Int>): js.lib.Int16Array {
		var res = new js.lib.Int16Array(ar.length);
		for (i in 0...ar.length) res[i] = ar[i];
		return res;
	}
}