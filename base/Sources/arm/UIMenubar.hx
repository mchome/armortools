package arm;

import zui.Zui;
import iron.App;
import iron.System;
import iron.Mat4;
import iron.Scene;
import iron.MeshData;
import iron.MeshObject;

class UIMenubar {

	public static var inst: UIMenubar;
	public static inline var defaultMenubarW = 330;
	public var workspaceHandle = new Handle({ layout: Horizontal });
	public var menuHandle = new Handle({ layout: Horizontal });
	public var menubarw = defaultMenubarW;

	#if is_lab
	static var _savedCamera: Mat4 = null;
	static var _plane: MeshObject = null;
	#end

	public function new() {
		inst = this;
	}

	public function renderUI(g: Graphics2) {
		var ui = UIBase.inst.ui;

		#if (is_paint || is_sculpt)
		var panelx = App.x() - UIToolbar.inst.toolbarw;
		#end
		#if is_lab
		var panelx = App.x();
		#end

		if (ui.window(menuHandle, panelx, 0, menubarw, UIHeader.headerh)) {
			ui._x += 1; // Prevent "File" button highlight on startup

			ui.beginMenu();

			if (Config.raw.touch_ui) {

				#if (is_paint || is_sculpt)
				ui._w = UIToolbar.inst.toolbarw;
				#end
				#if is_lab
				ui._w = 36;
				#end

				if (iconButton(ui, 0, 2)) BoxPreferences.show();
				if (iconButton(ui, 0, 3)) {
					#if (krom_android || krom_ios)
					Console.toast(tr("Saving project"));
					Project.projectSave();
					#end
					Base.notifyOnNextFrame(function() {
						BoxProjects.show();
					});
				}
				if (iconButton(ui, 4, 2)) Project.importAsset();
				#if (is_paint || is_lab)
				if (iconButton(ui, 5, 2)) BoxExport.showTextures();
				#end
				var size = Std.int(ui._w / ui.SCALE());
				if (UIMenu.show && UIMenu.menuCategory == MenuViewport) ui.fill(0, -6, size, size - 4, ui.t.HIGHLIGHT_COL);
				if (iconButton(ui, 8, 2)) showMenu(ui, MenuViewport);
				if (UIMenu.show && UIMenu.menuCategory == MenuMode) ui.fill(0, -6, size, size - 4, ui.t.HIGHLIGHT_COL);
				if (iconButton(ui, 9, 2)) showMenu(ui, MenuMode);
				if (UIMenu.show && UIMenu.menuCategory == MenuCamera) ui.fill(0, -6, size, size - 4, ui.t.HIGHLIGHT_COL);
				if (iconButton(ui, 10, 2)) showMenu(ui, MenuCamera);
				if (UIMenu.show && UIMenu.menuCategory == MenuHelp) ui.fill(0, -6, size, size - 4, ui.t.HIGHLIGHT_COL);
				if (iconButton(ui, 11, 2)) showMenu(ui, MenuHelp);
				ui.enabled = History.undos > 0;
				if (iconButton(ui, 6, 2)) History.undo();
				ui.enabled = History.redos > 0;
				if (iconButton(ui, 7, 2)) History.redo();
				ui.enabled = true;
			}
			else {
				var categories = [tr("File"), tr("Edit"), tr("Viewport"), tr("Mode"), tr("Camera"), tr("Help")];
				for (i in 0...categories.length) {
					if (ui.menuButton(categories[i]) || (UIMenu.show && UIMenu.menuCommands == null && ui.isHovered)) {
						showMenu(ui, i);
					}
				}
			}

			if (menubarw < ui._x + 10) {
				menubarw = Std.int(ui._x + 10);

				#if (is_paint || is_sculpt)
				UIToolbar.inst.toolbarHandle.redraws = 2;
				#end
			}

			ui.endMenu();
		}

		var nodesw = (UINodes.inst.show || UIView2D.inst.show) ? Config.raw.layout[LayoutNodesW] : 0;
		#if (is_paint || is_sculpt)
		var ww = System.width - Config.raw.layout[LayoutSidebarW] - menubarw - nodesw;
		var panelx = (App.x() - UIToolbar.inst.toolbarw) + menubarw;
		#else
		var ww = System.width - menubarw - nodesw;
		var panelx = (App.x()) + menubarw;
		#end

		if (ui.window(workspaceHandle, panelx, 0, ww, UIHeader.headerh)) {

			if (!Config.raw.touch_ui) {
				ui.tab(UIHeader.inst.worktab, tr("3D View"));
			}
			else {
				ui.fill(0, 0, ui._windowW, ui._windowH + 4, ui.t.SEPARATOR_COL);
			}

			#if is_lab
			ui.tab(UIHeader.inst.worktab, tr("2D View"));
			if (UIHeader.inst.worktab.changed) {
				Context.raw.ddirty = 2;
				Context.raw.brushBlendDirty = true;
				UIHeader.inst.headerHandle.redraws = 2;
				Context.mainObject().skip_context = null;

				if (UIHeader.inst.worktab.position == Space3D) {
					if (_savedCamera != null) {
						Scene.active.camera.transform.setMatrix(_savedCamera);
						_savedCamera = null;
					}
					Scene.active.meshes = [Context.mainObject()];
				}
				else { // Space2D
					if (_plane == null) {
						var mesh: Dynamic = new GeomPlane(1, 1, 2, 2);
						var raw = {
							name: "2DView",
							vertex_arrays: [
								{ values: mesh.posa, attrib: "pos", data: "short4norm" },
								{ values: mesh.nora, attrib: "nor", data: "short2norm" },
								{ values: mesh.texa, attrib: "tex", data: "short2norm" }
							],
							index_arrays: [
								{ values: mesh.inda, material: 0 }
							],
							scale_pos: mesh.scalePos,
							scale_tex: mesh.scaleTex
						};
						var md = new MeshData(raw, function(md: MeshData) {});
						var dotPlane: MeshObject = cast Scene.active.getChild(".Plane");
						_plane = new MeshObject(md, dotPlane.materials);
						Scene.active.meshes.remove(_plane);
					}

					if (_savedCamera == null) {
						_savedCamera = Scene.active.camera.transform.local.clone();
					}
					Scene.active.meshes = [_plane];
					var m = Mat4.identity();
					m.translate(0, 0, 1.6);
					Scene.active.camera.transform.setMatrix(m);
				}
				#if (krom_direct3d12 || krom_vulkan || krom_metal)
				RenderPathRaytrace.ready = false;
				#end
			}
			#end
		}
	}

	function showMenu(ui: Zui, category: Int) {
		UIMenu.show = true;
		UIMenu.menuCommands = null;
		UIMenu.menuCategory = category;
		UIMenu.menuCategoryW = ui._w;
		UIMenu.menuCategoryH = Std.int(ui.MENUBAR_H());
		UIMenu.menuX = Std.int(ui._x - ui._w);
		UIMenu.menuY = Std.int(ui.MENUBAR_H());
		if (Config.raw.touch_ui) {
			var menuW = Std.int(Base.defaultElementW * Base.uiMenu.SCALE() * 2.0);
			UIMenu.menuX -= Std.int((menuW - ui._w) / 2) + Std.int(UIHeader.headerh / 2);
			UIMenu.menuX += Std.int(2 * Base.uiMenu.SCALE());
			UIMenu.menuY -= Std.int(2 * Base.uiMenu.SCALE());
			UIMenu.keepOpen = true;
		}
	}

	public static function iconButton(ui: Zui, i: Int, j: Int): Bool {
		var col = ui.t.WINDOW_BG_COL;
		if (col < 0) col += untyped 4294967296;
		var light = col > 0xff666666 + 4294967296;
		var iconAccent = light ? 0xff666666 : 0xffaaaaaa;
		var img = Res.get("icons.k");
		var rect = Res.tile50(img, i, j);
		return ui.image(img, iconAccent, null, rect.x, rect.y, rect.w, rect.h) == State.Released;
	}
}