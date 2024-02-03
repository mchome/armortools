/// <reference path='./ContextFormat.ts'/>

class Context {

	static raw: TContext = new TContext(); //{};

	static useDeferred = (): bool => {
		///if is_paint
		return Context.raw.renderMode != RenderMode.RenderForward && (Context.raw.viewportMode == ViewportMode.ViewLit || Context.raw.viewportMode == ViewportMode.ViewPathTrace) && Context.raw.tool != WorkspaceTool.ToolColorId;
		///end

		///if (is_sculpt || is_lab)
		return Context.raw.renderMode != RenderMode.RenderForward && (Context.raw.viewportMode == ViewportMode.ViewLit || Context.raw.viewportMode == ViewportMode.ViewPathTrace);
		///end
	}

	///if (is_paint || is_sculpt)
	static selectMaterial = (i: i32) => {
		if (Project.materials.length <= i) return;
		Context.setMaterial(Project.materials[i]);
	}

	static setMaterial = (m: SlotMaterialRaw) => {
		if (Project.materials.indexOf(m) == -1) return;
		Context.raw.material = m;
		MakeMaterial.parsePaintMaterial();
		UIBase.hwnds[TabArea.TabSidebar1].redraws = 2;
		UIHeader.headerHandle.redraws = 2;
		UINodes.hwnd.redraws = 2;
		UINodes.groupStack = [];

		let decal = Context.raw.tool == WorkspaceTool.ToolDecal || Context.raw.tool == WorkspaceTool.ToolText;
		if (decal) {
			let _next = () => {
				UtilRender.makeDecalPreview();
			}
			Base.notifyOnNextFrame(_next);
		}
	}

	static selectBrush = (i: i32) => {
		if (Project.brushes.length <= i) return;
		Context.setBrush(Project.brushes[i]);
	}

	static setBrush = (b: SlotBrushRaw) => {
		if (Project.brushes.indexOf(b) == -1) return;
		Context.raw.brush = b;
		MakeMaterial.parseBrush();
		UIBase.hwnds[TabArea.TabSidebar1].redraws = 2;
		UINodes.hwnd.redraws = 2;
	}

	static selectFont = (i: i32) => {
		if (Project.fonts.length <= i) return;
		Context.setFont(Project.fonts[i]);
	}

	static setFont = (f: SlotFontRaw) => {
		if (Project.fonts.indexOf(f) == -1) return;
		Context.raw.font = f;
		UtilRender.makeTextPreview();
		UtilRender.makeDecalPreview();
		UIBase.hwnds[TabArea.TabStatus].redraws = 2;
		UIView2D.hwnd.redraws = 2;
	}

	static selectLayer = (i: i32) => {
		if (Project.layers.length <= i) return;
		Context.setLayer(Project.layers[i]);
	}

	static setLayer = (l: SlotLayerRaw) => {
		if (l == Context.raw.layer) return;
		Context.raw.layer = l;
		UIHeader.headerHandle.redraws = 2;

		let current = Graphics2.current;
		if (current != null) current.end();

		Base.setObjectMask();
		MakeMaterial.parseMeshMaterial();
		MakeMaterial.parsePaintMaterial();

		if (current != null) current.begin(false);

		UIBase.hwnds[TabArea.TabSidebar0].redraws = 2;
		UIView2D.hwnd.redraws = 2;
	}
	///end

	static selectTool = (i: i32) => {
		Context.raw.tool = i;
		MakeMaterial.parsePaintMaterial();
		MakeMaterial.parseMeshMaterial();
		Context.raw.ddirty = 3;
		let _viewportMode = Context.raw.viewportMode;
		Context.raw.viewportMode = -1 as ViewportMode;
		Context.setViewportMode(_viewportMode);

		///if (is_paint || is_sculpt)
		Context.initTool();
		UIHeader.headerHandle.redraws = 2;
		UIToolbar.toolbarHandle.redraws = 2;
		///end
	}

	///if (is_paint || is_sculpt)
	static initTool = () => {
		let decal = Context.raw.tool == WorkspaceTool.ToolDecal || Context.raw.tool == WorkspaceTool.ToolText;
		if (decal) {
			if (Context.raw.tool == WorkspaceTool.ToolText) {
				UtilRender.makeTextPreview();
			}
			UtilRender.makeDecalPreview();
		}

		else if (Context.raw.tool == WorkspaceTool.ToolParticle) {
			UtilParticle.initParticle();
			MakeMaterial.parseParticleMaterial();
		}

		else if (Context.raw.tool == WorkspaceTool.ToolBake) {
			///if (krom_direct3d12 || krom_vulkan || krom_metal)
			// Bake in lit mode for now
			if (Context.raw.viewportMode == ViewportMode.ViewPathTrace) {
				Context.raw.viewportMode = ViewportMode.ViewLit;
			}
			///end
		}

		else if (Context.raw.tool == WorkspaceTool.ToolMaterial) {
			Base.updateFillLayers();
			Context.mainObject().skip_context = null;
		}

		///if krom_ios
		// No hover on iPad, decals are painted by pen release
		Config.raw.brush_live = decal;
		///end
	}
	///end

	static selectPaintObject = (o: TMeshObject) => {
		///if (is_paint || is_sculpt)
		UIHeader.headerHandle.redraws = 2;
		for (let p of Project.paintObjects) p.skip_context = "paint";
		Context.raw.paintObject = o;

		let mask = SlotLayer.getObjectMask(Context.raw.layer);
		if (Context.layerFilterUsed()) mask = Context.raw.layerFilter;

		if (Context.raw.mergedObject == null || mask > 0) {
			Context.raw.paintObject.skip_context = "";
		}
		UtilUV.uvmapCached = false;
		UtilUV.trianglemapCached = false;
		UtilUV.dilatemapCached = false;
		///end

		///if is_lab
		Context.raw.paintObject = o;
		///end
	}

	static mainObject = (): TMeshObject => {
		///if (is_paint || is_sculpt)
		for (let po of Project.paintObjects) if (po.base.children.length > 0) return po;
		return Project.paintObjects[0];
		///end

		///if is_lab
		return Project.paintObjects[0];
		///end
	}

	static layerFilterUsed = (): bool => {
		///if (is_paint || is_sculpt)
		return Context.raw.layerFilter > 0 && Context.raw.layerFilter <= Project.paintObjects.length;
		///end

		///if is_lab
		return true;
		///end
	}

	static objectMaskUsed = (): bool => {
		///if (is_paint || is_sculpt)
		return SlotLayer.getObjectMask(Context.raw.layer) > 0 && SlotLayer.getObjectMask(Context.raw.layer) <= Project.paintObjects.length;
		///end

		///if is_lab
		return false;
		///end
	}

	static inViewport = (): bool => {
		return Context.raw.paintVec.x < 1 && Context.raw.paintVec.x > 0 &&
			   Context.raw.paintVec.y < 1 && Context.raw.paintVec.y > 0;
	}

	static inPaintArea = (): bool => {
		///if (is_paint || is_sculpt)
		let right = App.w();
		if (UIView2D.show) right += UIView2D.ww;
		return Mouse.viewX > 0 && Mouse.viewX < right &&
			   Mouse.viewY > 0 && Mouse.viewY < App.h();
		///end

		///if is_lab
		return Context.inViewport();
		///end
	}

	static inLayers = (): bool => {
		return UIBase.ui.getHoveredTabName() == tr("Layers");
	}

	static inMaterials = (): bool => {
		return UIBase.ui.getHoveredTabName() == tr("Materials");
	}

	///if (is_paint || is_sculpt)
	static in2dView = (type = View2DType.View2DLayer): bool => {
		return UIView2D.show && UIView2D.type == type &&
			   Mouse.x > UIView2D.wx && Mouse.x < UIView2D.wx + UIView2D.ww &&
			   Mouse.y > UIView2D.wy && Mouse.y < UIView2D.wy + UIView2D.wh;
	}
	///end

	static inNodes = (): bool => {
		return UINodes.show &&
			   Mouse.x > UINodes.wx && Mouse.x < UINodes.wx + UINodes.ww &&
			   Mouse.y > UINodes.wy && Mouse.y < UINodes.wy + UINodes.wh;
	}

	static inSwatches = (): bool => {
		return UIBase.ui.getHoveredTabName() == tr("Swatches");
	}

	static inBrowser = (): bool => {
		return UIBase.ui.getHoveredTabName() == tr("Browser");
	}

	static getAreaType = (): AreaType => {
		if (Context.inViewport()) return AreaType.AreaViewport;
		if (Context.inNodes()) return AreaType.AreaNodes;
		if (Context.inBrowser()) return AreaType.AreaBrowser;
		///if (is_paint || is_sculpt)
		if (Context.in2dView()) return AreaType.Area2DView;
		if (Context.inLayers()) return AreaType.AreaLayers;
		if (Context.inMaterials()) return AreaType.AreaMaterials;
		///end
		return -1 as AreaType;
	}

	static setViewportMode = (mode: ViewportMode) => {
		if (mode == Context.raw.viewportMode) return;

		Context.raw.viewportMode = mode;
		if (Context.useDeferred()) {
			RenderPath.commands = RenderPathDeferred.commands;
		}
		else {
			RenderPath.commands = RenderPathForward.commands;
		}
		let _workspace = UIHeader.worktab.position;
		UIHeader.worktab.position = 0;
		MakeMaterial.parseMeshMaterial();
		UIHeader.worktab.position = _workspace;
	}

	static loadEnvmap = () => {
		if (!Context.raw.envmapLoaded) {
			// TODO: Unable to share texture for both radiance and envmap - reload image
			Context.raw.envmapLoaded = true;
			Data.cachedImages.delete("World_radiance.k");
		}
		WorldData.loadEnvmap(Scene.world, (_) => {});
		if (Context.raw.savedEnvmap == null) Context.raw.savedEnvmap = Scene.world._envmap;
	}

	static updateEnvmap = () => {
		if (Context.raw.showEnvmap) {
			Scene.world._envmap = Context.raw.showEnvmapBlur ? Scene.world._radianceMipmaps[0] : Context.raw.savedEnvmap;
		}
		else {
			Scene.world._envmap = Context.raw.emptyEnvmap;
		}
	}

	static setViewportShader = (viewportShader: (ns: NodeShaderRaw)=>string) => {
		Context.raw.viewportShader = viewportShader;
		Context.setRenderPath();
	}

	static setRenderPath = () => {
		if (Context.raw.renderMode == RenderMode.RenderForward || Context.raw.viewportShader != null) {
			RenderPath.commands = RenderPathForward.commands;
		}
		else {
			RenderPath.commands = RenderPathDeferred.commands;
		}
		App.notifyOnInit(() => {
			MakeMaterial.parseMeshMaterial();
		});
	}

	static enableImportPlugin = (file: string): bool => {
		// Return plugin name suitable for importing the specified file
		if (BoxPreferences.filesPlugin == null) {
			BoxPreferences.fetchPlugins();
		}
		let ext = file.substr(file.lastIndexOf(".") + 1);
		for (let f of BoxPreferences.filesPlugin) {
			if (f.startsWith("import_") && f.indexOf(ext) >= 0) {
				Config.enablePlugin(f);
				Console.info(f + " " + tr("plugin enabled"));
				return true;
			}
		}
		return false;
	}

	static setSwatch = (s: TSwatchColor) => {
		Context.raw.swatch = s;
	}

	///if is_lab
	static runBrush = (from: i32) => {
		let left = 0.0;
		let right = 1.0;

		// First time init
		if (Context.raw.lastPaintX < 0 || Context.raw.lastPaintY < 0) {
			Context.raw.lastPaintVecX = Context.raw.paintVec.x;
			Context.raw.lastPaintVecY = Context.raw.paintVec.y;
		}

		let nodes = UINodes.getNodes();
		let canvas = UINodes.getCanvas(true);
		let inpaint = nodes.nodesSelectedId.length > 0 && nodes.getNode(canvas.nodes, nodes.nodesSelectedId[0]).type == "InpaintNode";

		// Paint bounds
		if (inpaint &&
			Context.raw.paintVec.x > left &&
			Context.raw.paintVec.x < right &&
			Context.raw.paintVec.y > 0 &&
			Context.raw.paintVec.y < 1 &&
			!Base.isDragging &&
			!Base.isResizing &&
			!Base.isScrolling() &&
			!Base.isComboSelected()) {

			let down = Mouse.down() || Pen.down();

			// Prevent painting the same spot
			let sameSpot = Context.raw.paintVec.x == Context.raw.lastPaintX && Context.raw.paintVec.y == Context.raw.lastPaintY;
			if (down && sameSpot) {
				Context.raw.painted++;
			}
			else {
				Context.raw.painted = 0;
			}
			Context.raw.lastPaintX = Context.raw.paintVec.x;
			Context.raw.lastPaintY = Context.raw.paintVec.y;

			if (Context.raw.painted == 0) {
				Context.parseBrushInputs();
			}

			if (Context.raw.painted <= 1) {
				Context.raw.pdirty = 1;
				Context.raw.rdirty = 2;
			}
		}
	}

	static parseBrushInputs = () => {
		if (!Context.raw.registered) {
			Context.raw.registered = true;
			App.notifyOnUpdate(Context.update);
		}

		Context.raw.paintVec = Context.raw.coords;
	}

	static update = () => {
		let paintX = Mouse.viewX / App.w();
		let paintY = Mouse.viewY / App.h();
		if (Mouse.started()) {
			Context.raw.startX = Mouse.viewX / App.w();
			Context.raw.startY = Mouse.viewY / App.h();
		}

		if (Pen.down()) {
			paintX = Pen.viewX / App.w();
			paintY = Pen.viewY / App.h();
		}
		if (Pen.started()) {
			Context.raw.startX = Pen.viewX / App.w();
			Context.raw.startY = Pen.viewY / App.h();
		}

		if (Operator.shortcut(Config.keymap.brush_ruler + "+" + Config.keymap.action_paint, ShortcutType.ShortcutDown)) {
			if (Context.raw.lockX) paintX = Context.raw.startX;
			if (Context.raw.lockY) paintY = Context.raw.startY;
		}

		Context.raw.coords.x = paintX;
		Context.raw.coords.y = paintY;

		if (Context.raw.lockBegin) {
			let dx = Math.abs(Context.raw.lockStartX - Mouse.viewX);
			let dy = Math.abs(Context.raw.lockStartY - Mouse.viewY);
			if (dx > 1 || dy > 1) {
				Context.raw.lockBegin = false;
				dx > dy ? Context.raw.lockY = true : Context.raw.lockX = true;
			}
		}

		if (Keyboard.started(Config.keymap.brush_ruler)) {
			Context.raw.lockStartX = Mouse.viewX;
			Context.raw.lockStartY = Mouse.viewY;
			Context.raw.lockBegin = true;
		}
		else if (Keyboard.released(Config.keymap.brush_ruler)) {
			Context.raw.lockX = Context.raw.lockY = Context.raw.lockBegin = false;
		}

		Context.parseBrushInputs();
	}
	///end
}
