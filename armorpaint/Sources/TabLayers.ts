
class TabLayers {

	static layerNameEdit = -1;
	static layerNameHandle = new Handle();
	static showContextMenu = false;

	static draw = (htab: Handle) => {
		let mini = Config.raw.layout[LayoutSize.LayoutSidebarW] <= UIBase.sidebarMiniW;
		mini ? TabLayers.drawMini(htab) : TabLayers.drawFull(htab);
	}

	static drawMini = (htab: Handle) => {
		let ui = UIBase.ui;
		ui.setHoveredTabName(tr("Layers"));

		let _ELEMENT_H = ui.t.ELEMENT_H;
		ui.t.ELEMENT_H = Math.floor(UIBase.sidebarMiniW / 2 / ui.SCALE());

		ui.beginSticky();
		ui.separator(5);

		TabLayers.comboFilter();
		TabLayers.button2dView();
		TabLayers.buttonNew("+");

		ui.endSticky();
		ui._y += 2;

		TabLayers.highlightOddLines();
		TabLayers.drawSlots(true);

		ui.t.ELEMENT_H = _ELEMENT_H;
	}

	static drawFull = (htab: Handle) => {
		let ui = UIBase.ui;
		if (ui.tab(htab, tr("Layers"))) {
			ui.beginSticky();
			ui.row([1 / 4, 1 / 4, 1 / 2]);

			TabLayers.buttonNew(tr("New"));
			TabLayers.button2dView();
			TabLayers.comboFilter();

			ui.endSticky();
			ui._y += 2;

			TabLayers.highlightOddLines();
			TabLayers.drawSlots(false);
		}
	}

	static button2dView = () => {
		let ui = UIBase.ui;
		if (ui.button(tr("2D View"))) {
			UIBase.show2DView(View2DType.View2DLayer);
		}
		else if (ui.isHovered) ui.tooltip(tr("Show 2D View") + ` (${Config.keymap.toggle_2d_view})`);
	}

	static drawSlots = (mini: bool) => {
		for (let i = 0; i < Project.layers.length; ++i) {
			if (i >= Project.layers.length) break; // Layer was deleted
			let j = Project.layers.length - 1 - i;
			let l = Project.layers[j];
			TabLayers.drawLayerSlot(l, j, mini);
		}
	}

	static highlightOddLines = () => {
		let ui = UIBase.ui;
		let step = ui.t.ELEMENT_H * 2;
		let fullH = ui._windowH - UIBase.hwnds[0].scrollOffset;
		for (let i = 0; i < Math.floor(fullH / step); ++i) {
			if (i % 2 == 0) {
				ui.fill(0, i * step, (ui._w / ui.SCALE() - 2), step, ui.t.WINDOW_BG_COL - 0x00040404);
			}
		}
	}

	static buttonNew = (text: string) => {
		let ui = UIBase.ui;
		if (ui.button(text)) {
			UIMenu.draw((ui: Zui) => {
				let l = Context.raw.layer;
				if (UIMenu.menuButton(ui, tr("Paint Layer"))) {
					Base.newLayer();
					History.newLayer();
				}
				if (UIMenu.menuButton(ui, tr("Fill Layer"))) {
					Base.createFillLayer(UVType.UVMap);
				}
				if (UIMenu.menuButton(ui, tr("Decal Layer"))) {
					Base.createFillLayer(UVType.UVProject);
				}
				if (UIMenu.menuButton(ui, tr("Black Mask"))) {
					if (SlotLayer.isMask(l)) Context.setLayer(l.parent);
					// let l = Context.raw.layer;

					let m = Base.newMask(false, l);
					let _next = () => {
						SlotLayer.clear(m, 0x00000000);
					}
					Base.notifyOnNextFrame(_next);
					Context.raw.layerPreviewDirty = true;
					History.newBlackMask();
					Base.updateFillLayers();
				}
				if (UIMenu.menuButton(ui, tr("White Mask"))) {
					if (SlotLayer.isMask(l)) Context.setLayer(l.parent);
					// let l = Context.raw.layer;

					let m = Base.newMask(false, l);
					let _next = () => {
						SlotLayer.clear(m, 0xffffffff);
					}
					Base.notifyOnNextFrame(_next);
					Context.raw.layerPreviewDirty = true;
					History.newWhiteMask();
					Base.updateFillLayers();
				}
				if (UIMenu.menuButton(ui, tr("Fill Mask"))) {
					if (SlotLayer.isMask(l)) Context.setLayer(l.parent);
					// let l = Context.raw.layer;

					let m = Base.newMask(false, l);
					let _init = () => {
						SlotLayer.toFillLayer(m);
					}
					App.notifyOnInit(_init);
					Context.raw.layerPreviewDirty = true;
					History.newFillMask();
					Base.updateFillLayers();
				}
				ui.enabled = !SlotLayer.isGroup(Context.raw.layer) && !SlotLayer.isInGroup(Context.raw.layer);
				if (UIMenu.menuButton(ui, tr("Group"))) {
					if (SlotLayer.isGroup(l) || SlotLayer.isInGroup(l)) return;

					if (SlotLayer.isLayerMask(l)) l = l.parent;

					let pointers = TabLayers.initLayerMap();
					let group = Base.newGroup();
					Context.setLayer(l);
					array_remove(Project.layers, group);
					Project.layers.splice(Project.layers.indexOf(l) + 1, 0, group);
					l.parent = group;
					for (let m of Project.materials) TabLayers.remapLayerPointers(m.canvas.nodes, TabLayers.fillLayerMap(pointers));
					Context.setLayer(group);
					History.newGroup();
				}
				ui.enabled = true;
			}, 7);
		}
	}

	static comboFilter = () => {
		let ui = UIBase.ui;
		let ar = [tr("All")];
		for (let p of Project.paintObjects) ar.push(p.name);
		let atlases = Project.getUsedAtlases();
		if (atlases != null) for (let a of atlases) ar.push(a);
		let filterHandle = Zui.handle("tablayers_0");
		filterHandle.position = Context.raw.layerFilter;
		Context.raw.layerFilter = ui.combo(filterHandle, ar, tr("Filter"), false, Align.Left);
		if (filterHandle.changed) {
			for (let p of Project.paintObjects) {
				p.visible = Context.raw.layerFilter == 0 || p.name == ar[Context.raw.layerFilter] || Project.isAtlasObject(p);
			}
			if (Context.raw.layerFilter == 0 && Context.raw.mergedObjectIsAtlas) { // All
				UtilMesh.mergeMesh();
			}
			else if (Context.raw.layerFilter > Project.paintObjects.length) { // Atlas
				let visibles: MeshObject[] = [];
				for (let p of Project.paintObjects) if (p.visible) visibles.push(p);
				UtilMesh.mergeMesh(visibles);
			}
			Base.setObjectMask();
			UtilUV.uvmapCached = false;
			Context.raw.ddirty = 2;
			///if (krom_direct3d12 || krom_vulkan || krom_metal)
			RenderPathRaytrace.ready = false;
			///end
		}
	}

	static remapLayerPointers = (nodes: TNode[], pointerMap: Map<i32, i32>) => {
		for (let n of nodes) {
			if (n.type == "LAYER" || n.type == "LAYER_MASK") {
				let i = n.buttons[0].default_value;
				if (pointerMap.has(i)) {
					n.buttons[0].default_value = pointerMap.get(i);
				}
			}
		}
	}

	static initLayerMap = (): Map<SlotLayerRaw, i32> => {
		let res: Map<SlotLayerRaw, i32> = new Map();
		for (let i = 0; i < Project.layers.length; ++i) res.set(Project.layers[i], i);
		return res;
	}

	static fillLayerMap = (map: Map<SlotLayerRaw, i32>): Map<i32, i32> => {
		let res: Map<i32, i32> = new Map();
		for (let l of map.keys()) res.set(map.get(l), Project.layers.indexOf(l) > -1 ? Project.layers.indexOf(l) : 9999);
		return res;
	}

	static setDragLayer = (layer: SlotLayerRaw, offX: f32, offY: f32) => {
		Base.dragOffX = offX;
		Base.dragOffY = offY;
		Base.dragLayer = layer;
		Context.raw.dragDestination = Project.layers.indexOf(layer);
	}

	static drawLayerSlot = (l: SlotLayerRaw, i: i32, mini: bool) => {
		let ui = UIBase.ui;

		if (Context.raw.layerFilter > 0 &&
			SlotLayer.getObjectMask(l) > 0 &&
			SlotLayer.getObjectMask(l) != Context.raw.layerFilter) {
			return;
		}

		if (l.parent != null && !l.parent.show_panel) { // Group closed
			return;
		}
		if (l.parent != null && l.parent.parent != null && !l.parent.parent.show_panel) {
			return;
		}

		let step = ui.t.ELEMENT_H;
		let checkw = (ui._windowW / 100 * 8) / ui.SCALE();

		// Highlight drag destination
		let absy = ui._windowY + ui._y;
		if (Base.isDragging && Base.dragLayer != null && Context.inLayers()) {
			if (Mouse.y > absy + step && Mouse.y < absy + step * 3) {
				let down = Project.layers.indexOf(Base.dragLayer) >= i;
				Context.raw.dragDestination = down ? i : i - 1;

				let ls = Project.layers;
				let dest = Context.raw.dragDestination;
				let toGroup = down ? dest > 0 && ls[dest - 1].parent != null && ls[dest - 1].parent.show_panel : dest < ls.length && ls[dest].parent != null && ls[dest].parent.show_panel;
				let nestedGroup = SlotLayer.isGroup(Base.dragLayer) && toGroup;
				if (!nestedGroup) {
					if (SlotLayer.canMove(Context.raw.layer, Context.raw.dragDestination)) {
						ui.fill(checkw, step * 2, (ui._windowW / ui.SCALE() - 2) - checkw, 2 * ui.SCALE(), ui.t.HIGHLIGHT_COL);
					}
				}
			}
			else if (i == Project.layers.length - 1 && Mouse.y < absy + step) {
				Context.raw.dragDestination = Project.layers.length - 1;
				if (SlotLayer.canMove(Context.raw.layer, Context.raw.dragDestination)) {
					ui.fill(checkw, 0, (ui._windowW / ui.SCALE() - 2) - checkw, 2 * ui.SCALE(), ui.t.HIGHLIGHT_COL);
				}
			}
		}
		if (Base.isDragging && (Base.dragMaterial != null || Base.dragSwatch != null) && Context.inLayers()) {
			if (Mouse.y > absy + step && Mouse.y < absy + step * 3) {
				Context.raw.dragDestination = i;
				if (TabLayers.canDropNewLayer(i))
					ui.fill(checkw, 2 * step, (ui._windowW / ui.SCALE() - 2) - checkw, 2 * ui.SCALE(), ui.t.HIGHLIGHT_COL);
			}
			else if (i == Project.layers.length - 1 && Mouse.y < absy + step) {
				Context.raw.dragDestination = Project.layers.length;
				if (TabLayers.canDropNewLayer(Project.layers.length))
					ui.fill(checkw, 0, (ui._windowW / ui.SCALE() - 2) - checkw, 2 * ui.SCALE(), ui.t.HIGHLIGHT_COL);
			}
		}

		mini ? TabLayers.drawLayerSlotMini(l, i) : TabLayers.drawLayerSlotFull(l, i);

		TabLayers.drawLayerHighlight(l, mini);

		if (TabLayers.showContextMenu) {
			TabLayers.drawLayerContextMenu(l, mini);
		}
	}

	static drawLayerSlotMini = (l: SlotLayerRaw, i: i32) => {
		let ui = UIBase.ui;

		ui.row([1, 1]);
		let uix = ui._x;
		let uiy = ui._y;
		let state = TabLayers.drawLayerIcon(l, i, uix, uiy, true);
		TabLayers.handleLayerIconState(l, i, state, uix, uiy);
		ui.endElement();

		ui._y += ui.ELEMENT_H();
		ui._y -= ui.ELEMENT_OFFSET();
	}

	static drawLayerSlotFull = (l: SlotLayerRaw, i: i32) => {
		let ui = UIBase.ui;

		let step = ui.t.ELEMENT_H;

		let hasPanel = SlotLayer.isGroup(l) || (SlotLayer.isLayer(l) && SlotLayer.getMasks(l, false) != null);
		if (hasPanel) {
			ui.row([8 / 100, 16 / 100, 36 / 100, 30 / 100, 10 / 100]);
		}
		else {
			ui.row([8 / 100, 16 / 100, 36 / 100, 30 / 100]);
		}

		// Draw eye icon
		let icons = Res.get("icons.k");
		let r = Res.tile18(icons, l.visible ? 0 : 1, 0);
		let center = (step / 2) * ui.SCALE();
		ui._x += 2;
		ui._y += 3;
		ui._y += center;
		let col = ui.t.ACCENT_SELECT_COL;
		let parentHidden = l.parent != null && (!l.parent.visible || (l.parent.parent != null && !l.parent.parent.visible));
		if (parentHidden) col -= 0x99000000;

		if (ui.image(icons, col, null, r.x, r.y, r.w, r.h) == State.Released) {
			TabLayers.layerToggleVisible(l);
		}
		ui._x -= 2;
		ui._y -= 3;
		ui._y -= center;

		///if krom_opengl
		ui.imageInvertY = l.fill_layer != null;
		///end

		let uix = ui._x;
		let uiy = ui._y;
		ui._x += 2;
		ui._y += 3;
		if (l.parent != null) {
			ui._x += 10 * ui.SCALE();
			if (l.parent.parent != null) ui._x += 10 * ui.SCALE();
		}

		let state = TabLayers.drawLayerIcon(l, i, uix, uiy, false);

		ui._x -= 2;
		ui._y -= 3;

		if (Config.raw.touch_ui) {
			ui._x += 12 * ui.SCALE();
		}

		///if krom_opengl
		ui.imageInvertY = false;
		///end

		TabLayers.handleLayerIconState(l, i, state, uix, uiy);

		// Draw layer name
		ui._y += center;
		if (TabLayers.layerNameEdit == l.id) {
			TabLayers.layerNameHandle.text = l.name;
			l.name = ui.textInput(TabLayers.layerNameHandle);
			if (ui.textSelectedHandle_ptr != TabLayers.layerNameHandle.ptr) TabLayers.layerNameEdit = -1;
		}
		else {
			if (ui.enabled && ui.inputEnabled && ui.comboSelectedHandle_ptr == null &&
				ui.inputX > ui._windowX + ui._x && ui.inputX < ui._windowX + ui._windowW &&
				ui.inputY > ui._windowY + ui._y - center && ui.inputY < ui._windowY + ui._y - center + (step * ui.SCALE()) * 2) {
				if (ui.inputStarted) {
					Context.setLayer(l);
					TabLayers.setDragLayer(Context.raw.layer, -(Mouse.x - uix - ui._windowX - 3), -(Mouse.y - uiy - ui._windowY + 1));
				}
				else if (ui.inputReleasedR) {
					Context.setLayer(l);
					TabLayers.showContextMenu = true;
				}
			}

			let state = ui.text(l.name);
			if (state == State.Released) {
				if (Time.time() - Context.raw.selectTime < 0.25) {
					TabLayers.layerNameEdit = l.id;
					TabLayers.layerNameHandle.text = l.name;
					ui.startTextEdit(TabLayers.layerNameHandle);
				}
				Context.raw.selectTime = Time.time();
			}

			let inFocus = ui.inputX > ui._windowX && ui.inputX < ui._windowX + ui._windowW &&
						  ui.inputY > ui._windowY && ui.inputY < ui._windowY + ui._windowH;
			if (inFocus && ui.isDeleteDown && TabLayers.canDelete(Context.raw.layer)) {
				ui.isDeleteDown = false;
				let _init = () => {
					TabLayers.deleteLayer(Context.raw.layer);
				}
				App.notifyOnInit(_init);
			}
		}
		ui._y -= center;

		if (l.parent != null) {
			ui._x -= 10 * ui.SCALE();
			if (l.parent.parent != null) ui._x -= 10 * ui.SCALE();
		}

		if (SlotLayer.isGroup(l)) {
			ui.endElement();
		}
		else {
			if (SlotLayer.isMask(l)) {
				ui._y += center;
			}

			TabLayers.comboBlending(ui, l);

			if (SlotLayer.isMask(l)) {
				ui._y -= center;
			}
		}

		if (hasPanel) {
			ui._y += center;
			let layerPanel = Zui.handle("tablayers_1").nest(l.id);
			layerPanel.selected = l.show_panel;
			l.show_panel = ui.panel(layerPanel, "", true, false, false);
			ui._y -= center;
		}

		if (SlotLayer.isGroup(l) || SlotLayer.isMask(l)) {
			ui._y -= ui.ELEMENT_OFFSET();
			ui.endElement();
		}
		else {
			ui._y -= ui.ELEMENT_OFFSET();

			ui.row([8 / 100, 16 / 100, 36 / 100, 30 / 100, 10 / 100]);
			ui.endElement();
			ui.endElement();
			ui.endElement();

			if (Config.raw.touch_ui) {
				ui._x += 12 * ui.SCALE();
			}

			TabLayers.comboObject(ui, l);
			ui.endElement();
		}

		ui._y -= ui.ELEMENT_OFFSET();
	}

	static comboObject = (ui: Zui, l: SlotLayerRaw, label = false): Handle => {
		let ar = [tr("Shared")];
		for (let p of Project.paintObjects) ar.push(p.name);
		let atlases = Project.getUsedAtlases();
		if (atlases != null) for (let a of atlases) ar.push(a);
		let objectHandle = Zui.handle("tablayers_2").nest(l.id);
		objectHandle.position = l.objectMask;
		l.objectMask = ui.combo(objectHandle, ar, tr("Object"), label, Align.Left);
		if (objectHandle.changed) {
			Context.setLayer(l);
			MakeMaterial.parseMeshMaterial();
			if (l.fill_layer != null) { // Fill layer
				let _init = () => {
					Context.raw.material = l.fill_layer;
					SlotLayer.clear(l);
					Base.updateFillLayers();
				}
				App.notifyOnInit(_init);
			}
			else {
				Base.setObjectMask();
			}
		}
		return objectHandle;
	}

	static comboBlending = (ui: Zui, l: SlotLayerRaw, label = false): Handle => {
		let blendingHandle = Zui.handle("tablayers_3").nest(l.id);
		blendingHandle.position = l.blending;
		ui.combo(blendingHandle, [
			tr("Mix"),
			tr("Darken"),
			tr("Multiply"),
			tr("Burn"),
			tr("Lighten"),
			tr("Screen"),
			tr("Dodge"),
			tr("Add"),
			tr("Overlay"),
			tr("Soft Light"),
			tr("Linear Light"),
			tr("Difference"),
			tr("Subtract"),
			tr("Divide"),
			tr("Hue"),
			tr("Saturation"),
			tr("Color"),
			tr("Value"),
		], tr("Blending"), label);
		if (blendingHandle.changed) {
			Context.setLayer(l);
			History.layerBlending();
			l.blending = blendingHandle.position;
			MakeMaterial.parseMeshMaterial();
		}
		return blendingHandle;
	}

	static layerToggleVisible = (l: SlotLayerRaw) => {
		l.visible = !l.visible;
		UIView2D.hwnd.redraws = 2;
		MakeMaterial.parseMeshMaterial();
	}

	static drawLayerHighlight = (l: SlotLayerRaw, mini: bool) => {
		let ui = UIBase.ui;
		let step = ui.t.ELEMENT_H;

		// Separator line
		ui.fill(0, 0, (ui._w / ui.SCALE() - 2), 1 * ui.SCALE(), ui.t.SEPARATOR_COL);

		// Highlight selected
		if (Context.raw.layer == l) {
			if (mini) {
				ui.rect(1, -step * 2, ui._w / ui.SCALE() - 1, step * 2 + (mini ? -1 : 1), ui.t.HIGHLIGHT_COL, 3);
			}
			else {
				ui.rect(1, -step * 2 - 1, ui._w / ui.SCALE() - 2, step * 2 + (mini ? -2 : 1), ui.t.HIGHLIGHT_COL, 2);
			}
		}
	}

	static handleLayerIconState = (l: SlotLayerRaw, i: i32, state: State, uix: f32, uiy: f32) => {
		let ui = UIBase.ui;

		///if is_paint
		let texpaint_preview = l.texpaint_preview;
		///end
		///if is_sculpt
		let texpaint_preview = l.texpaint;
		///end

		TabLayers.showContextMenu = false;

		// Layer preview tooltip
		if (ui.isHovered && texpaint_preview != null) {
			if (SlotLayer.isMask(l)) {
				TabLayers.makeMaskPreviewRgba32(l);
				ui.tooltipImage(Context.raw.maskPreviewRgba32);
			}
			else {
				ui.tooltipImage(texpaint_preview);
			}
			if (i < 9) ui.tooltip(l.name + " - (" + Config.keymap.select_layer + " " + (i + 1) + ")");
			else ui.tooltip(l.name);
		}

		// Show context menu
		if (ui.isHovered && ui.inputReleasedR) {
			Context.setLayer(l);
			TabLayers.showContextMenu = true;
		}

		if (state == State.Started) {
			Context.setLayer(l);
			TabLayers.setDragLayer(Context.raw.layer, -(Mouse.x - uix - ui._windowX - 3), -(Mouse.y - uiy - ui._windowY + 1));
		}
		else if (state == State.Released) {
			if (Time.time() - Context.raw.selectTime < 0.2) {
				UIBase.show2DView(View2DType.View2DLayer);
			}
			if (Time.time() - Context.raw.selectTime > 0.2) {
				Context.raw.selectTime = Time.time();
			}
			if (l.fill_layer != null) Context.setMaterial(l.fill_layer);
		}
	}

	static drawLayerIcon = (l: SlotLayerRaw, i: i32, uix: f32, uiy: f32, mini: bool) => {
		let ui = UIBase.ui;
		let icons = Res.get("icons.k");
		let iconH = (ui.ELEMENT_H() - (mini ? 2 : 3)) * 2;

		if (mini && ui.SCALE() > 1) {
			ui._x -= 1 * ui.SCALE();
		}

		if (l.parent != null) {
			ui._x += (iconH - iconH * 0.9) / 2;
			iconH *= 0.9;
			if (l.parent.parent != null) {
				ui._x += (iconH - iconH * 0.9) / 2;
				iconH *= 0.9;
			}
		}

		if (!SlotLayer.isGroup(l)) {
			///if is_paint
			let texpaint_preview = l.texpaint_preview;
			///end
			///if is_sculpt
			let texpaint_preview = l.texpaint;
			///end

			let icon = l.fill_layer == null ? texpaint_preview : l.fill_layer.imageIcon;
			if (l.fill_layer == null) {
				// Checker
				let r = Res.tile50(icons, 4, 1);
				let _x = ui._x;
				let _y = ui._y;
				let _w = ui._w;
				ui.image(icons, 0xffffffff, iconH, r.x, r.y, r.w, r.h);
				ui.curRatio--;
				ui._x = _x;
				ui._y = _y;
				ui._w = _w;
			}
			if (l.fill_layer == null && SlotLayer.isMask(l)) {
				ui.g.pipeline = UIView2D.pipe;
				///if krom_opengl
				Krom.setPipeline(UIView2D.pipe.pipeline_);
				///end
				Krom.setInt(UIView2D.channelLocation, 1);
			}

			let state = ui.image(icon, 0xffffffff, iconH);

			if (l.fill_layer == null && SlotLayer.isMask(l)) {
				ui.g.pipeline = null;
			}

			// Draw layer numbers when selecting a layer via keyboard shortcut
			let isTyping = ui.isTyping || UIView2D.ui.isTyping || UINodes.ui.isTyping;
			if (!isTyping) {
				if (i < 9 && Operator.shortcut(Config.keymap.select_layer, ShortcutType.ShortcutDown)) {
					let number = String(i + 1) ;
					let width = ui.font.width(ui.fontSize, number) + 10;
					let height = ui.font.height(ui.fontSize);
					ui.g.color = ui.t.TEXT_COL;
					ui.g.fillRect(uix, uiy, width, height);
					ui.g.color = ui.t.ACCENT_COL;
					ui.g.drawString(number, uix + 5, uiy);
				}
			}

			return state;
		}
		else { // Group
			let folderClosed = Res.tile50(icons, 2, 1);
			let folderOpen = Res.tile50(icons, 8, 1);
			let folder = l.show_panel ? folderOpen : folderClosed;
			return ui.image(icons, ui.t.LABEL_COL - 0x00202020, iconH, folder.x, folder.y, folder.w, folder.h);
		}
	}

	static canMergeDown = (l: SlotLayerRaw) : bool => {
		let index = Project.layers.indexOf(l);
		// Lowest layer
		if (index == 0) return false;
		// Lowest layer that has masks
		if (SlotLayer.isLayer(l) && SlotLayer.isMask(Project.layers[0]) && Project.layers[0].parent == l) return false;
		// The lowest toplevel layer is a group
		if (SlotLayer.isGroup(l) && SlotLayer.isInGroup(Project.layers[0]) && SlotLayer.getContainingGroup(Project.layers[0]) == l) return false;
		// Masks must be merged down to masks
		if (SlotLayer.isMask(l) && !SlotLayer.isMask(Project.layers[index - 1])) return false;
		return true;
	}

	static drawLayerContextMenu = (l: SlotLayerRaw, mini: bool) => {
		let add = 0;

		if (l.fill_layer == null) add += 1; // Clear
		if (l.fill_layer != null && !SlotLayer.isMask(l)) add += 3;
		if (l.fill_layer != null && SlotLayer.isMask(l)) add += 2;
		if (SlotLayer.isMask(l)) add += 2;
		if (mini) {
			add += 1;
			if (!SlotLayer.isGroup(l)) add += 1;
			if (SlotLayer.isLayer(l)) add += 1;
		}
		let menuElements = SlotLayer.isGroup(l) ? 7 : (19 + add);

		UIMenu.draw((ui: Zui) => {

			if (mini) {
				let visibleHandle = Zui.handle("tablayers_4");
				visibleHandle.selected = l.visible;
				UIMenu.menuFill(ui);
				ui.check(visibleHandle, tr("Visible"));
				if (visibleHandle.changed) {
					TabLayers.layerToggleVisible(l);
					UIMenu.keepOpen = true;
				}

				if (!SlotLayer.isGroup(l)) {
					UIMenu.menuFill(ui);
					if (TabLayers.comboBlending(ui, l, true).changed) {
						UIMenu.keepOpen = true;
					}
				}
				if (SlotLayer.isLayer(l)) {
					UIMenu.menuFill(ui);
					if (TabLayers.comboObject(ui, l, true).changed) {
						UIMenu.keepOpen = true;
					}
				}
			}

			if (UIMenu.menuButton(ui, tr("Export"))) {
				if (SlotLayer.isMask(l)) {
					UIFiles.show("png", true, false, (path: string) => {
						let f = UIFiles.filename;
						if (f == "") f = tr("untitled");
						if (!f.endsWith(".png")) f += ".png";
						Krom.writePng(path + Path.sep + f, l.texpaint.getPixels(), l.texpaint.width, l.texpaint.height, 3); // RRR1
					});
				}
				else {
					///if is_paint
					Context.raw.layersExport = ExportMode.ExportSelected;
					BoxExport.showTextures();
					///end
				}
			}

			if (!SlotLayer.isGroup(l)) {
				let toFillString = SlotLayer.isLayer(l) ? tr("To Fill Layer") : tr("To Fill Mask");
				let toPaintString = SlotLayer.isLayer(l) ? tr("To Paint Layer") : tr("To Paint Mask");

				if (l.fill_layer == null && UIMenu.menuButton(ui, toFillString)) {
					let _init = () => {
						SlotLayer.isLayer(l) ? History.toFillLayer() : History.toFillMask();
						SlotLayer.toFillLayer(l);
					}
					App.notifyOnInit(_init);
				}
				if (l.fill_layer != null && UIMenu.menuButton(ui, toPaintString)) {
					let _init = () => {
						SlotLayer.isLayer(l) ? History.toPaintLayer() : History.toPaintMask();
						SlotLayer.toPaintLayer(l);
					}
					App.notifyOnInit(_init);
				}
			}

			ui.enabled = TabLayers.canDelete(l);
			if (UIMenu.menuButton(ui, tr("Delete"), "delete")) {
				let _init = () => {
					TabLayers.deleteLayer(Context.raw.layer);
				}
				App.notifyOnInit(_init);
			}
			ui.enabled = true;

			if (l.fill_layer == null && UIMenu.menuButton(ui, tr("Clear"))) {
				Context.setLayer(l);
				let _init = () => {
					if (!SlotLayer.isGroup(l)) {
						History.clearLayer();
						SlotLayer.clear(l);
					}
					else {
						for (let c of SlotLayer.getChildren(l)) {
							Context.raw.layer = c;
							History.clearLayer();
							SlotLayer.clear(c);
						}
						Context.raw.layersPreviewDirty = true;
						Context.raw.layer = l;
					}
				}
				App.notifyOnInit(_init);
			}
			if (SlotLayer.isMask(l) && l.fill_layer == null && UIMenu.menuButton(ui, tr("Invert"))) {
				let _init = () => {
					Context.setLayer(l);
					History.invertMask();
					SlotLayer.invertMask(l);
				}
				App.notifyOnInit(_init);
			}
			if (SlotLayer.isMask(l) && UIMenu.menuButton(ui, tr("Apply"))) {
				let _init = () => {
					Context.raw.layer = l;
					History.applyMask();
					SlotLayer.applyMask(l);
					Context.setLayer(l.parent);
					MakeMaterial.parseMeshMaterial();
					Context.raw.layersPreviewDirty = true;
				}
				App.notifyOnInit(_init);
			}
			if (SlotLayer.isGroup(l) && UIMenu.menuButton(ui, tr("Merge Group"))) {
				let _init = () => {
					Base.mergeGroup(l);
				}
				App.notifyOnInit(_init);
			}
			ui.enabled = TabLayers.canMergeDown(l);
			if (UIMenu.menuButton(ui, tr("Merge Down"))) {
				let _init = () => {
					Context.setLayer(l);
					History.mergeLayers();
					Base.mergeDown();
					if (Context.raw.layer.fill_layer != null) SlotLayer.toPaintLayer(Context.raw.layer);
				}
				App.notifyOnInit(_init);
			}
			ui.enabled = true;
			if (UIMenu.menuButton(ui, tr("Duplicate"))) {
				let _init = () => {
					Context.setLayer(l);
					History.duplicateLayer();
					Base.duplicateLayer(l);
				}
				App.notifyOnInit(_init);
			}

			UIMenu.menuFill(ui);
			UIMenu.menuAlign(ui);
			let layerOpacHandle = Zui.handle("tablayers_5").nest(l.id);
			layerOpacHandle.value = l.maskOpacity;
			ui.slider(layerOpacHandle, tr("Opacity"), 0.0, 1.0, true);
			if (layerOpacHandle.changed) {
				if (ui.inputStarted) History.layerOpacity();
				l.maskOpacity = layerOpacHandle.value;
				MakeMaterial.parseMeshMaterial();
				UIMenu.keepOpen = true;
			}

			if (!SlotLayer.isGroup(l)) {
				UIMenu.menuFill(ui);
				UIMenu.menuAlign(ui);
				let resHandleChangedLast = Base.resHandle.changed;
				///if (krom_android || krom_ios)
				let ar = ["128", "256", "512", "1K", "2K", "4K"];
				///else
				let ar = ["128", "256", "512", "1K", "2K", "4K", "8K", "16K"];
				///end
				let _y = ui._y;
				Base.resHandle.value = Base.resHandle.position;
				Base.resHandle.position = Math.floor(ui.slider(Base.resHandle, ar[Base.resHandle.position], 0, ar.length - 1, false, 1, false, Align.Left, false));
				if (Base.resHandle.changed) {
					UIMenu.keepOpen = true;
				}
				if (resHandleChangedLast && !Base.resHandle.changed) {
					Base.onLayersResized();
				}
				ui._y = _y;
				ui.drawString(ui.g, tr("Res"), null, 0, Align.Right);
				ui.endElement();

				UIMenu.menuFill(ui);
				UIMenu.menuAlign(ui);
				///if (krom_android || krom_ios)
				ui.inlineRadio(Base.bitsHandle, ["8bit"]);
				///else
				ui.inlineRadio(Base.bitsHandle, ["8bit", "16bit", "32bit"]);
				///end
				if (Base.bitsHandle.changed) {
					App.notifyOnInit(Base.setLayerBits);
					UIMenu.keepOpen = true;
				}
			}

			if (l.fill_layer != null) {
				UIMenu.menuFill(ui);
				UIMenu.menuAlign(ui);
				let scaleHandle = Zui.handle("tablayers_6").nest(l.id);
				scaleHandle.value = l.scale;
				l.scale = ui.slider(scaleHandle, tr("UV Scale"), 0.0, 5.0, true);
				if (scaleHandle.changed) {
					Context.setMaterial(l.fill_layer);
					Context.setLayer(l);
					let _init = () => {
						Base.updateFillLayers();
					}
					App.notifyOnInit(_init);
					UIMenu.keepOpen = true;
				}

				UIMenu.menuFill(ui);
				UIMenu.menuAlign(ui);
				let angleHandle = Zui.handle("tablayers_7").nest(l.id);
				angleHandle.value = l.angle;
				l.angle = ui.slider(angleHandle, tr("Angle"), 0.0, 360, true, 1);
				if (angleHandle.changed) {
					Context.setMaterial(l.fill_layer);
					Context.setLayer(l);
					MakeMaterial.parsePaintMaterial();
					let _init = () => {
						Base.updateFillLayers();
					}
					App.notifyOnInit(_init);
					UIMenu.keepOpen = true;
				}

				UIMenu.menuFill(ui);
				UIMenu.menuAlign(ui);
				let uvTypeHandle = Zui.handle("tablayers_8").nest(l.id);
				uvTypeHandle.position = l.uvType;
				l.uvType = ui.inlineRadio(uvTypeHandle, [tr("UV Map"), tr("Triplanar"), tr("Project")], Align.Left);
				if (uvTypeHandle.changed) {
					Context.setMaterial(l.fill_layer);
					Context.setLayer(l);
					MakeMaterial.parsePaintMaterial();
					let _init = () => {
						Base.updateFillLayers();
					}
					App.notifyOnInit(_init);
					UIMenu.keepOpen = true;
				}
			}

			if (!SlotLayer.isGroup(l)) {
				let baseHandle = Zui.handle("tablayers_9").nest(l.id);
				let opacHandle = Zui.handle("tablayers_10").nest(l.id);
				let norHandle = Zui.handle("tablayers_11").nest(l.id);
				let norBlendHandle = Zui.handle("tablayers_12").nest(l.id);
				let occHandle = Zui.handle("tablayers_13").nest(l.id);
				let roughHandle = Zui.handle("tablayers_14").nest(l.id);
				let metHandle = Zui.handle("tablayers_15").nest(l.id);
				let heightHandle = Zui.handle("tablayers_16").nest(l.id);
				let heightBlendHandle = Zui.handle("tablayers_17").nest(l.id);
				let emisHandle = Zui.handle("tablayers_18").nest(l.id);
				let subsHandle = Zui.handle("tablayers_19").nest(l.id);
				baseHandle.selected = l.paintBase;
				opacHandle.selected = l.paintOpac;
				norHandle.selected = l.paintNor;
				norBlendHandle.selected = l.paintNorBlend;
				occHandle.selected = l.paintOcc;
				roughHandle.selected = l.paintRough;
				metHandle.selected = l.paintMet;
				heightHandle.selected = l.paintHeight;
				heightBlendHandle.selected = l.paintHeightBlend;
				emisHandle.selected = l.paintEmis;
				subsHandle.selected = l.paintSubs;
				UIMenu.menuFill(ui);
				l.paintBase = ui.check(baseHandle, tr("Base Color"));
				UIMenu.menuFill(ui);
				l.paintOpac = ui.check(opacHandle, tr("Opacity"));
				UIMenu.menuFill(ui);
				l.paintNor = ui.check(norHandle, tr("Normal"));
				UIMenu.menuFill(ui);
				l.paintNorBlend = ui.check(norBlendHandle, tr("Normal Blending"));
				UIMenu.menuFill(ui);
				l.paintOcc = ui.check(occHandle, tr("Occlusion"));
				UIMenu.menuFill(ui);
				l.paintRough = ui.check(roughHandle, tr("Roughness"));
				UIMenu.menuFill(ui);
				l.paintMet = ui.check(metHandle, tr("Metallic"));
				UIMenu.menuFill(ui);
				l.paintHeight = ui.check(heightHandle, tr("Height"));
				UIMenu.menuFill(ui);
				l.paintHeightBlend = ui.check(heightBlendHandle, tr("Height Blending"));
				UIMenu.menuFill(ui);
				l.paintEmis = ui.check(emisHandle, tr("Emission"));
				UIMenu.menuFill(ui);
				l.paintSubs = ui.check(subsHandle, tr("Subsurface"));
				if (baseHandle.changed ||
					opacHandle.changed ||
					norHandle.changed ||
					norBlendHandle.changed ||
					occHandle.changed ||
					roughHandle.changed ||
					metHandle.changed ||
					heightHandle.changed ||
					heightBlendHandle.changed ||
					emisHandle.changed ||
					subsHandle.changed) {
					MakeMaterial.parseMeshMaterial();
					UIMenu.keepOpen = true;
				}
			}
		}, menuElements);
	}

	static makeMaskPreviewRgba32 = (l: SlotLayerRaw) => {
		///if is_paint
		if (Context.raw.maskPreviewRgba32 == null) {
			Context.raw.maskPreviewRgba32 = Image.createRenderTarget(UtilRender.layerPreviewSize, UtilRender.layerPreviewSize);
		}
		// Convert from R8 to RGBA32 for tooltip display
		if (Context.raw.maskPreviewLast != l) {
			Context.raw.maskPreviewLast = l;
			App.notifyOnInit(() => {
				Context.raw.maskPreviewRgba32.g2.begin();
				Context.raw.maskPreviewRgba32.g2.pipeline = UIView2D.pipe;
				Context.raw.maskPreviewRgba32.g4.setInt(UIView2D.channelLocation, 1);
				Context.raw.maskPreviewRgba32.g2.drawImage(l.texpaint_preview, 0, 0);
				Context.raw.maskPreviewRgba32.g2.end();
				Context.raw.maskPreviewRgba32.g2.pipeline = null;
			});
		}
		///end
	}

	static deleteLayer = (l: SlotLayerRaw) => {
		let pointers = TabLayers.initLayerMap();

		if (SlotLayer.isLayer(l) && SlotLayer.hasMasks(l, false)) {
			for (let m of SlotLayer.getMasks(l, false)) {
				Context.raw.layer = m;
				History.deleteLayer();
				SlotLayer.delete(m);
			}
		}
		if (SlotLayer.isGroup(l)) {
			for (let c of SlotLayer.getChildren(l)) {
				if (SlotLayer.hasMasks(c, false)) {
					for (let m of SlotLayer.getMasks(c, false)) {
						Context.raw.layer = m;
						History.deleteLayer();
						SlotLayer.delete(m);
					}
				}
				Context.raw.layer = c;
				History.deleteLayer();
				SlotLayer.delete(c);
			}
			if (SlotLayer.hasMasks(l)) {
				for (let m of SlotLayer.getMasks(l)) {
					Context.raw.layer = m;
					History.deleteLayer();
					SlotLayer.delete(m);
				}
			}
		}

		Context.raw.layer = l;
		History.deleteLayer();
		SlotLayer.delete(l);

		if (SlotLayer.isMask(l)) {
			Context.raw.layer = l.parent;
			Base.updateFillLayers();
		}

		// Remove empty group
		if (SlotLayer.isInGroup(l) && SlotLayer.getChildren(SlotLayer.getContainingGroup(l)) == null) {
			let g = SlotLayer.getContainingGroup(l);
			// Maybe some group masks are left
			if (SlotLayer.hasMasks(g)) {
				for (let m of SlotLayer.getMasks(g)) {
					Context.raw.layer = m;
					History.deleteLayer();
					SlotLayer.delete(m);
				}
			}
			Context.raw.layer = l.parent;
			History.deleteLayer();
			SlotLayer.delete(l.parent);
		}
		Context.raw.ddirty = 2;
		for (let m of Project.materials) TabLayers.remapLayerPointers(m.canvas.nodes, TabLayers.fillLayerMap(pointers));
	}

	static canDelete = (l: SlotLayerRaw) => {
		let numLayers = 0;

		if (SlotLayer.isMask(l)) return true;

		for (let slot of Project.layers) {
			if (SlotLayer.isLayer(slot)) ++numLayers;
		}

		// All layers are in one group
		if (SlotLayer.isGroup(l) && SlotLayer.getChildren(l).length == numLayers) return false;

		// Do not delete last layer
		return numLayers > 1;
	}

	static canDropNewLayer = (position: i32) => {
		if (position > 0 && position < Project.layers.length && SlotLayer.isMask(Project.layers[position - 1])) {
			// 1. The layer to insert is inserted in the middle
			// 2. The layer below is a mask, i.e. the layer would have to be a (group) mask, too.
			return false;
		}
		return true;
	}
}
