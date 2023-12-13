package arm;

import haxe.Json;
import zui.Zui;
import iron.System;
import iron.Scene;
import iron.Mat4;
import iron.Data;
import iron.Input;

class UIMenu {

	public static var show = false;
	public static var menuCategory = 0;
	public static var menuCategoryW = 0;
	public static var menuCategoryH = 0;
	public static var menuX = 0;
	public static var menuY = 0;
	public static var menuElements = 0;
	public static var keepOpen = false;
	public static var menuCommands: Zui->Void = null;
	static var showMenuFirst = true;
	static var hideMenu = false;

	public static function render(g: Graphics2) {
		var ui = Base.uiMenu;
		var menuW = menuCommands != null ? Std.int(Base.defaultElementW * Base.uiMenu.SCALE() * 2.3) : Std.int(ui.ELEMENT_W() * 2.3);
		var _BUTTON_COL = ui.t.BUTTON_COL;
		ui.t.BUTTON_COL = ui.t.SEPARATOR_COL;
		var _ELEMENT_OFFSET = ui.t.ELEMENT_OFFSET;
		ui.t.ELEMENT_OFFSET = 0;
		var _ELEMENT_H = ui.t.ELEMENT_H;
		ui.t.ELEMENT_H = Config.raw.touch_ui ? (28 + 2) : 28;

		ui.beginRegion(g, menuX, menuY, menuW);

		if (menuCommands != null) {
			ui.g.color = ui.t.ACCENT_SELECT_COL;
			ui.drawRect(ui.g, true, ui._x + -1, ui._y + -1, ui._w + 2, ui.ELEMENT_H() * menuElements + 2);
			ui.g.color = ui.t.SEPARATOR_COL;
			ui.drawRect(ui.g, true, ui._x + 0, ui._y + 0, ui._w, ui.ELEMENT_H() * menuElements);
			ui.g.color = 0xffffffff;

			menuCommands(ui);
		}
		else {
			menuStart(ui);
			if (menuCategory == MenuFile) {
				if (menuButton(ui, tr("New Project..."), Config.keymap.file_new)) Project.projectNewBox();
				if (menuButton(ui, tr("Open..."), Config.keymap.file_open)) Project.projectOpen();
				if (menuButton(ui, tr("Open Recent..."), Config.keymap.file_open_recent)) BoxProjects.show();
				if (menuButton(ui, tr("Save"), Config.keymap.file_save)) Project.projectSave();
				if (menuButton(ui, tr("Save As..."), Config.keymap.file_save_as)) Project.projectSaveAs();
				menuSeparator(ui);
				if (menuButton(ui, tr("Import Texture..."), Config.keymap.file_import_assets)) Project.importAsset(Path.textureFormats.join(","), false);
				if (menuButton(ui, tr("Import Envmap..."))) {
					UIFiles.show("hdr", false, false, function(path: String) {
						if (!path.endsWith(".hdr")) {
							Console.error(tr("Error: .hdr file expected"));
							return;
						}
						ImportAsset.run(path);
					});
				}

				#if (is_paint || is_sculpt)
				if (menuButton(ui, tr("Import Font..."))) Project.importAsset("ttf,ttc,otf");
				if (menuButton(ui, tr("Import Material..."))) Project.importMaterial();
				if (menuButton(ui, tr("Import Brush..."))) Project.importBrush();
				#end

				#if (is_paint || is_lab)
				if (menuButton(ui, tr("Import Swatches..."))) Project.importSwatches();
				#end
				if (menuButton(ui, tr("Import Mesh..."))) Project.importMesh();
				if (menuButton(ui, tr("Reimport Mesh"), Config.keymap.file_reimport_mesh)) Project.reimportMesh();
				if (menuButton(ui, tr("Reimport Textures"), Config.keymap.file_reimport_textures)) Project.reimportTextures();
				menuSeparator(ui);
				#if (is_paint || is_lab)
				if (menuButton(ui, tr("Export Textures..."), Config.keymap.file_export_textures_as)) {
					#if is_paint
					Context.raw.layersExport = ExportVisible;
					#end
					BoxExport.showTextures();
				}
				if (menuButton(ui, tr("Export Swatches..."))) Project.exportSwatches();
				#end
				if (menuButton(ui, tr("Export Mesh..."))) {
					Context.raw.exportMeshIndex = 0; // All
					BoxExport.showMesh();
				}

				#if is_paint
				if (menuButton(ui, tr("Bake Material..."))) BoxExport.showBakeMaterial();
				#end

				menuSeparator(ui);
				if (menuButton(ui, tr("Exit"))) System.stop();
			}
			else if (menuCategory == MenuEdit) {
				var stepUndo = "";
				var stepRedo = "";
				if (History.undos > 0) {
					stepUndo = History.steps[History.steps.length - 1 - History.redos].name;
				}
				if (History.redos > 0) {
					stepRedo = History.steps[History.steps.length - History.redos].name;
				}
				ui.enabled = History.undos > 0;
				if (menuButton(ui, tr("Undo {step}", ["step" => stepUndo]), Config.keymap.edit_undo)) History.undo();
				ui.enabled = History.redos > 0;
				if (menuButton(ui, tr("Redo {step}", ["step" => stepRedo]), Config.keymap.edit_redo)) History.redo();
				ui.enabled = true;
				menuSeparator(ui);
				if (menuButton(ui, tr("Preferences..."), Config.keymap.edit_prefs)) BoxPreferences.show();
			}
			else if (menuCategory == MenuViewport) {
				if (menuButton(ui, tr("Distract Free"), Config.keymap.view_distract_free)) {
					UIBase.inst.toggleDistractFree();
					UIBase.inst.ui.isHovered = false;
				}

				#if !(krom_android || krom_ios)
				if (menuButton(ui, tr("Toggle Fullscreen"), "alt+enter")) {
					Base.toggleFullscreen();
				}
				#end

				ui.changed = false;

				menuFill(ui);
				var p = Scene.active.world.probe;
				var envHandle = Zui.handle("uimenu_0");
				envHandle.value = p.raw.strength;
				menuAlign(ui);
				p.raw.strength = ui.slider(envHandle, tr("Environment"), 0.0, 8.0, true);
				if (envHandle.changed) Context.raw.ddirty = 2;

				menuFill(ui);
				var envaHandle = Zui.handle("uimenu_1");
				envaHandle.value = Context.raw.envmapAngle / Math.PI * 180.0;
				if (envaHandle.value < 0) {
					envaHandle.value += (Std.int(-envaHandle.value / 360) + 1) * 360;
				}
				else if (envaHandle.value > 360) {
					envaHandle.value -= Std.int(envaHandle.value / 360) * 360;
				}
				menuAlign(ui);
				Context.raw.envmapAngle = ui.slider(envaHandle, tr("Environment Angle"), 0.0, 360.0, true, 1) / 180.0 * Math.PI;
				if (ui.isHovered) ui.tooltip(tr("{shortcut} and move mouse", ["shortcut" => Config.keymap.rotate_envmap]));
				if (envaHandle.changed) Context.raw.ddirty = 2;

				if (Scene.active.lights.length > 0) {
					var light = Scene.active.lights[0];

					menuFill(ui);
					var lhandle = Zui.handle("uimenu_2");
					var scale = 1333;
					lhandle.value = light.data.raw.strength / scale;
					lhandle.value = Std.int(lhandle.value * 100) / 100;
					menuAlign(ui);
					light.data.raw.strength = ui.slider(lhandle, tr("Light"), 0.0, 4.0, true) * scale;
					if (lhandle.changed) Context.raw.ddirty = 2;

					menuFill(ui);
					var light = Scene.active.lights[0];
					var lahandle = Zui.handle("uimenu_3");
					lahandle.value = Context.raw.lightAngle / Math.PI * 180;
					menuAlign(ui);
					var newAngle = ui.slider(lahandle, tr("Light Angle"), 0.0, 360.0, true, 1) / 180 * Math.PI;
					if (ui.isHovered) ui.tooltip(tr("{shortcut} and move mouse", ["shortcut" => Config.keymap.rotate_light]));
					var ldiff = newAngle - Context.raw.lightAngle;
					if (Math.abs(ldiff) > 0.005) {
						if (newAngle < 0) newAngle += (Std.int(-newAngle / (2 * Math.PI)) + 1) * 2 * Math.PI;
						else if (newAngle > 2 * Math.PI) newAngle -= Std.int(newAngle / (2 * Math.PI)) * 2 * Math.PI;
						Context.raw.lightAngle = newAngle;
						var m = Mat4.rotationZ(ldiff);
						light.transform.local.multmat(m);
						light.transform.decompose();
						Context.raw.ddirty = 2;
					}

					menuFill(ui);
					var sxhandle = Zui.handle("uimenu_4");
					sxhandle.value = light.data.raw.size;
					menuAlign(ui);
					light.data.raw.size = ui.slider(sxhandle, tr("Light Size"), 0.0, 4.0, true);
					if (sxhandle.changed) Context.raw.ddirty = 2;
				}

				#if (is_paint || is_sculpt)
				menuFill(ui);
				var splitViewHandle = Zui.handle("uimenu_5", { selected: Context.raw.splitView });
				Context.raw.splitView = ui.check(splitViewHandle, " " + tr("Split View"));
				if (splitViewHandle.changed) {
					Base.resize();
				}
				#end

				#if is_lab
				menuFill(ui);
				var brushScaleHandle = Zui.handle("uimenu_6", { value: Context.raw.brushScale });
				menuAlign(ui);
				Context.raw.brushScale = ui.slider(brushScaleHandle, tr("UV Scale"), 0.01, 5.0, true);
				if (brushScaleHandle.changed) {
					MakeMaterial.parseMeshMaterial();
					#if (krom_direct3d12 || krom_vulkan || krom_metal)
					RenderPathRaytrace.uvScale = Context.raw.brushScale;
					RenderPathRaytrace.ready = false;
					#end
				}
				#end

				menuFill(ui);
				var cullHandle = Zui.handle("uimenu_7", { selected: Context.raw.cullBackfaces });
				Context.raw.cullBackfaces = ui.check(cullHandle, " " + tr("Cull Backfaces"));
				if (cullHandle.changed) {
					MakeMaterial.parseMeshMaterial();
				}

				menuFill(ui);
				var filterHandle = Zui.handle("uimenu_8", { selected: Context.raw.textureFilter });
				Context.raw.textureFilter = ui.check(filterHandle, " " + tr("Filter Textures"));
				if (filterHandle.changed) {
					MakeMaterial.parsePaintMaterial();
					MakeMaterial.parseMeshMaterial();
				}

				#if (is_paint || is_sculpt)
				menuFill(ui);
				Context.raw.drawWireframe = ui.check(Context.raw.wireframeHandle, " " + tr("Wireframe"));
				if (Context.raw.wireframeHandle.changed) {
					ui.g.end();
					UtilUV.cacheUVMap();
					ui.g.begin(false);
					MakeMaterial.parseMeshMaterial();
				}
				#end

				#if is_paint
				menuFill(ui);
				Context.raw.drawTexels = ui.check(Context.raw.texelsHandle, " " + tr("Texels"));
				if (Context.raw.texelsHandle.changed) {
					MakeMaterial.parseMeshMaterial();
				}
				#end

				menuFill(ui);
				var compassHandle = Zui.handle("uimenu_9", { selected: Context.raw.showCompass });
				Context.raw.showCompass = ui.check(compassHandle, " " + tr("Compass"));
				if (compassHandle.changed) Context.raw.ddirty = 2;

				menuFill(ui);
				Context.raw.showEnvmap = ui.check(Context.raw.showEnvmapHandle, " " + tr("Envmap"));
				if (Context.raw.showEnvmapHandle.changed) {
					Context.loadEnvmap();
					Context.raw.ddirty = 2;
				}

				menuFill(ui);
				Context.raw.showEnvmapBlur = ui.check(Context.raw.showEnvmapBlurHandle, " " + tr("Blur Envmap"));
				if (Context.raw.showEnvmapBlurHandle.changed) Context.raw.ddirty = 2;

				Context.updateEnvmap();

				if (ui.changed) keepOpen = true;
			}
			else if (menuCategory == MenuMode) {
				var modeHandle = Zui.handle("uimenu_10");
				modeHandle.position = Context.raw.viewportMode;
				var modes = [
					tr("Lit"),
					tr("Base Color"),
					#if (is_paint || is_lab)
					tr("Normal"),
					tr("Occlusion"),
					tr("Roughness"),
					tr("Metallic"),
					tr("Opacity"),
					tr("Height"),
					#end
					#if (is_paint)
					tr("Emission"),
					tr("Subsurface"),
					#end
					#if (is_paint || is_sculpt)
					tr("TexCoord"),
					tr("Object Normal"),
					tr("Material ID"),
					tr("Object ID"),
					tr("Mask")
					#end
				];
				var shortcuts = ["l", "b", "n", "o", "r", "m", "a", "h", "e", "s", "t", "1", "2", "3", "4"];

				#if (krom_direct3d12 || krom_vulkan || krom_metal)
				if (Krom.raytraceSupported()) {
					modes.push(tr("Path Traced"));
					shortcuts.push("p");
				}
				#end

				for (i in 0...modes.length) {
					menuFill(ui);
					var shortcut = Config.raw.touch_ui ? "" : Config.keymap.viewport_mode + ", " + shortcuts[i];
					ui.radio(modeHandle, i, modes[i], shortcut);
				}

				if (modeHandle.changed) {
					Context.setViewportMode(modeHandle.position);
					// TODO: rotate mode is not supported for path tracing yet
					if (modeHandle.position == ViewPathTrace && Context.raw.cameraControls == ControlsRotate) {
						Context.raw.cameraControls = ControlsOrbit;
						Viewport.reset();
					}
				}
			}
			else if (menuCategory == MenuCamera) {
				if (menuButton(ui, tr("Reset"), Config.keymap.view_reset)) {
					Viewport.reset();
					Viewport.scaleToBounds();
				}
				menuSeparator(ui);
				if (menuButton(ui, tr("Front"), Config.keymap.view_front)) {
					Viewport.setView(0, -1, 0, Math.PI / 2, 0, 0);
				}
				if (menuButton(ui, tr("Back"), Config.keymap.view_back)) {
					Viewport.setView(0, 1, 0, Math.PI / 2, 0, Math.PI);
				}
				if (menuButton(ui, tr("Right"), Config.keymap.view_right)) {
					Viewport.setView(1, 0, 0, Math.PI / 2, 0, Math.PI / 2);
				}
				if (menuButton(ui, tr("Left"), Config.keymap.view_left)) {
					Viewport.setView(-1, 0, 0, Math.PI / 2, 0, -Math.PI / 2);
				}
				if (menuButton(ui, tr("Top"), Config.keymap.view_top)) {
					Viewport.setView(0, 0, 1, 0, 0, 0);
				}
				if (menuButton(ui, tr("Bottom"), Config.keymap.view_bottom)) {
					Viewport.setView(0, 0, -1, Math.PI, 0, Math.PI);
				}
				menuSeparator(ui);

				ui.changed = false;

				if (menuButton(ui, tr("Orbit Left"), Config.keymap.view_orbit_left)) {
					Viewport.orbit(-Math.PI / 12, 0);
				}
				if (menuButton(ui, tr("Orbit Right"), Config.keymap.view_orbit_right)) {
					Viewport.orbit(Math.PI / 12, 0);
				}
				if (menuButton(ui, tr("Orbit Up"), Config.keymap.view_orbit_up)) {
					Viewport.orbit(0, -Math.PI / 12);
				}
				if (menuButton(ui, tr("Orbit Down"), Config.keymap.view_orbit_down)) {
					Viewport.orbit(0, Math.PI / 12);
				}
				if (menuButton(ui, tr("Orbit Opposite"), Config.keymap.view_orbit_opposite)) {
					Viewport.orbitOpposite();
				}
				if (menuButton(ui, tr("Zoom In"), Config.keymap.view_zoom_in)) {
					Viewport.zoom(0.2);
				}
				if (menuButton(ui, tr("Zoom Out"), Config.keymap.view_zoom_out)) {
					Viewport.zoom(-0.2);
				}
				// menuSeparator(ui);

				menuFill(ui);
				var cam = Scene.active.camera;
				Context.raw.fovHandle = Zui.handle("uimenu_11", { value: Std.int(cam.data.raw.fov * 100) / 100 });
				menuAlign(ui);
				cam.data.raw.fov = ui.slider(Context.raw.fovHandle, tr("FoV"), 0.3, 1.4, true);
				if (Context.raw.fovHandle.changed) {
					Viewport.updateCameraType(Context.raw.cameraType);
				}

				menuFill(ui);
				menuAlign(ui);
				var cameraControlsHandle = Zui.handle("uimenu_12");
				cameraControlsHandle.position = Context.raw.cameraControls;
				Context.raw.cameraControls = ui.inlineRadio(cameraControlsHandle, [tr("Orbit"), tr("Rotate"), tr("Fly")], Left);

				var orbitAndRotateTooltip = tr("Orbit and Rotate mode:\n{rotate_shortcut} or move right mouse button to rotate.\n{zoom_shortcut} or scroll to zoom.\n{pan_shortcut} or move middle mouse to pan.",
					[
						"rotate_shortcut" => Config.keymap.action_rotate,
						"zoom_shortcut" => Config.keymap.action_zoom,
						"pan_shortcut" => Config.keymap.action_pan
					]
				);
				var flyTooltip = tr("Fly mode:\nHold the right mouse button and one of the following commands:\nmove mouse to rotate.\nw, up or scroll up to move forward.\ns, down or scroll down to move backward.\na or left to move left.\nd or right to move right.\ne to move up.\nq to move down.\nHold shift to move faster or alt to move slower.");
				if (ui.isHovered) ui.tooltip(orbitAndRotateTooltip + "\n\n" + flyTooltip);

				menuFill(ui);
				menuAlign(ui);
				Context.raw.cameraType = ui.inlineRadio(Context.raw.camHandle, [tr("Perspective"), tr("Orthographic")], Left);
				if (ui.isHovered) ui.tooltip(tr("Camera Type") + ' (${Config.keymap.view_camera_type})');
				if (Context.raw.camHandle.changed) {
					Viewport.updateCameraType(Context.raw.cameraType);
				}

				if (ui.changed) keepOpen = true;
			}
			else if (menuCategory == MenuHelp) {
				if (menuButton(ui, tr("Manual"))) {
					File.loadUrl(Manifest.url + "/manual");
				}
				if (menuButton(ui, tr("How To"))) {
					File.loadUrl(Manifest.url + "/howto");
				}
				if (menuButton(ui, tr("What's New"))) {
					File.loadUrl(Manifest.url + "/notes");
				}
				if (menuButton(ui, tr("Issue Tracker"))) {
					File.loadUrl("https://github.com/armory3d/armortools/issues");
				}
				if (menuButton(ui, tr("Report Bug"))) {
					#if (krom_darwin || krom_ios) // Limited url length
					File.loadUrl("https://github.com/armory3d/armortools/issues/new?labels=bug&template=bug_report.md&body=*" + Manifest.title + "%20" + Manifest.version + "-" + Config.getSha() + ",%20" + System.systemId);
					#else
					File.loadUrl("https://github.com/armory3d/armortools/issues/new?labels=bug&template=bug_report.md&body=*" + Manifest.title + "%20" + Manifest.version + "-" + Config.getSha() + ",%20" + System.systemId + "*%0A%0A**Issue description:**%0A%0A**Steps to reproduce:**%0A%0A");
					#end
				}
				if (menuButton(ui, tr("Request Feature"))) {
					#if (krom_darwin || krom_ios) // Limited url length
					File.loadUrl("https://github.com/armory3d/armortools/issues/new?labels=feature%20request&template=feature_request.md&body=*" + Manifest.title + "%20" + Manifest.version + "-" + Config.getSha() + ",%20" + System.systemId);
					#else
					File.loadUrl("https://github.com/armory3d/armortools/issues/new?labels=feature%20request&template=feature_request.md&body=*" + Manifest.title + "%20" + Manifest.version + "-" + Config.getSha() + ",%20" + System.systemId + "*%0A%0A**Feature description:**%0A%0A");
					#end
				}
				menuSeparator(ui);

				if (menuButton(ui, tr("Check for Updates..."))) {
					#if krom_android
					File.loadUrl(Manifest.url_android);
					#elseif krom_ios
					File.loadUrl(Manifest.url_ios);
					#else
					// Retrieve latest version number
					File.downloadBytes("https://server.armorpaint.org/" + Manifest.title.toLowerCase() + ".html", function(buffer: js.lib.ArrayBuffer) {
						if (buffer != null)  {
							// Compare versions
							var update = Json.parse(System.bufferToString(buffer));
							var updateVersion = Std.int(update.version);
							if (updateVersion > 0) {
								var date = Config.getDate().substr(2); // 2019 -> 19
								var dateInt = Std.parseInt(date.replace("-", ""));
								if (updateVersion > dateInt) {
									UIBox.showMessage(tr("Update"), tr("Update is available!\nPlease visit {url}.", ["url" => Manifest.url]));
								}
								else {
									UIBox.showMessage(tr("Update"), tr("You are up to date!"));
								}
							}
						}
						else {
							UIBox.showMessage(tr("Update"), tr("Unable to check for updates.\nPlease visit {url}.", ["url" => Manifest.url]));
						}
					});
					#end
				}

				if (menuButton(ui, tr("About..."))) {

					var msg = Manifest.title + ".org - v" + Manifest.version + " (" + Config.getDate() + ") - " + Config.getSha() + "\n";
					msg += System.systemId + " - " + Strings.graphics_api;

					#if krom_windows
					var save = (Path.isProtected() ? Krom.savePath() : Path.data()) + Path.sep + "tmp.txt";
					Krom.sysCommand('wmic path win32_VideoController get name > "' + save + '"');
					var blob = Krom.loadBlob(save);
					var u8 = new js.lib.Uint8Array(blob);
					var gpuRaw = "";
					for (i in 0...Std.int(u8.length / 2)) {
						var c = String.fromCharCode(u8[i * 2]);
						gpuRaw += c;
					}

					var gpus = gpuRaw.split("\n");
					gpus = gpus.splice(1, gpus.length - 2);
					var gpu = "";
					for (g in gpus) {
						gpu += g.rtrim() + ", ";
					}
					gpu = gpu.substr(0, gpu.length - 2);
					msg += '\n$gpu';
					#else
					// { lshw -C display }
					#end

					UIBox.showCustom(function(ui: Zui) {
						var tabVertical = Config.raw.touch_ui;
						if (ui.tab(Zui.handle("uimenu_13"), tr("About"), tabVertical)) {

							Data.getImage("badge.k", function(img) {
								ui.image(img);
								ui.endElement();
							});

							ui.textArea(Zui.handle("uimenu_14", { text: msg }), false);

							ui.row([1 / 3, 1 / 3, 1 / 3]);

							#if (krom_windows || krom_linux || krom_darwin)
							if (ui.button(tr("Copy"))) {
								Krom.copyToClipboard(msg);
							}
							#else
							ui.endElement();
							#end

							if (ui.button(tr("Contributors"))) {
								File.loadUrl("https://github.com/armory3d/armortools/graphs/contributors");
							}
							if (ui.button(tr("OK"))) {
								UIBox.hide();
							}
						}
					}, 400, 320);
				}
			}
		}

		hideMenu = ui.comboSelectedHandle_ptr == null && !keepOpen && !showMenuFirst && (ui.changed || ui.inputReleased || ui.inputReleasedR || ui.isEscapeDown);
		showMenuFirst = false;
		keepOpen = false;

		ui.t.BUTTON_COL = _BUTTON_COL;
		ui.t.ELEMENT_OFFSET = _ELEMENT_OFFSET;
		ui.t.ELEMENT_H = _ELEMENT_H;
		ui.endRegion();

		if (hideMenu) {
			hide();
			showMenuFirst = true;
			menuCommands = null;
		}
	}

	static function hide() {
		show = false;
		Base.redrawUI();
	}

	public static function draw(commands: Zui->Void = null, elements: Int, x = -1, y = -1) {
		Base.uiMenu.endInput();
		show = true;
		menuCommands = commands;
		menuElements = elements;
		menuX = x > -1 ? x : Std.int(Input.getMouse().x + 1);
		menuY = y > -1 ? y : Std.int(Input.getMouse().y + 1);
		fitToScreen();
	}

	public static function fitToScreen() {
		// Prevent the menu going out of screen
		var menuW = Base.defaultElementW * Base.uiMenu.SCALE() * 2.3;
		if (menuX + menuW > System.width) {
			if (menuX - menuW > 0) {
				menuX = Std.int(menuX - menuW);
			}
			else {
				menuX = Std.int(System.width - menuW);
			}
		}
		var menuH = Std.int(menuElements * 30 * Base.uiMenu.SCALE()); // ui.t.ELEMENT_H
		if (menuY + menuH > System.height) {
			if (menuY - menuH > 0) {
				menuY = Std.int(menuY - menuH);
			}
			else {
				menuY = System.height - menuH;
			}
			menuX += 1; // Move out of mouse focus
		}
	}

	public static function menuFill(ui: Zui) {
		ui.g.color = ui.t.ACCENT_SELECT_COL;
		ui.g.fillRect(ui._x - 1, ui._y, ui._w + 2, ui.ELEMENT_H() + 1 + 1);
		ui.g.color = ui.t.SEPARATOR_COL;
		ui.g.fillRect(ui._x, ui._y, ui._w, ui.ELEMENT_H() + 1);
		ui.g.color = 0xffffffff;
	}

	public static function menuSeparator(ui: Zui) {
		ui._y++;
		if (Config.raw.touch_ui) {
			ui.fill(0, 0, ui._w / ui.SCALE(), 1, ui.t.ACCENT_SELECT_COL);
		}
		else {
			ui.fill(26, 0, ui._w / ui.SCALE() - 26, 1, ui.t.ACCENT_SELECT_COL);
		}
	}

	public static function menuButton(ui: Zui, text: String, label = ""/*, icon = -1*/): Bool {
		menuFill(ui);
		if (Config.raw.touch_ui) {
			label = "";
		}

		// var icons = icon > -1 ? Res.get("icons.k") : null;
		// var r = Res.tile25(icons, icon, 8);
		// return ui.button(Config.buttonSpacing + text, Config.buttonAlign, label, icons, r.x, r.y, r.w, r.h);

		return ui.button(Config.buttonSpacing + text, Config.buttonAlign, label);
	}

	public static function menuAlign(ui: Zui) {
		if (!Config.raw.touch_ui) {
			ui.row([12 / 100, 88 / 100]);
			ui.endElement();
		}
	}

	public static function menuStart(ui: Zui) {
		// Draw top border
		ui.g.color = ui.t.ACCENT_SELECT_COL;
		if (Config.raw.touch_ui) {
			ui.g.fillRect(ui._x + ui._w / 2 + menuCategoryW / 2, ui._y - 1, ui._w / 2 - menuCategoryW / 2 + 1, 1);
			ui.g.fillRect(ui._x - 1, ui._y - 1, ui._w / 2 - menuCategoryW / 2 + 1, 1);
			ui.g.fillRect(ui._x + ui._w / 2 - menuCategoryW / 2, ui._y - menuCategoryH, menuCategoryW, 1);
			ui.g.fillRect(ui._x + ui._w / 2 - menuCategoryW / 2, ui._y - menuCategoryH, 1, menuCategoryH);
			ui.g.fillRect(ui._x + ui._w / 2 + menuCategoryW / 2, ui._y - menuCategoryH, 1, menuCategoryH);
		}
		else {
			ui.g.fillRect(ui._x - 1 + menuCategoryW, ui._y - 1, ui._w + 2 - menuCategoryW, 1);
			ui.g.fillRect(ui._x - 1, ui._y - menuCategoryH, menuCategoryW, 1);
			ui.g.fillRect(ui._x - 1, ui._y - menuCategoryH, 1, menuCategoryH);
			ui.g.fillRect(ui._x - 1 + menuCategoryW, ui._y - menuCategoryH, 1, menuCategoryH);
		}
		ui.g.color = 0xffffffff;
	}
}