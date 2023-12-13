package arm;

import haxe.Json;
import zui.Zui;
import iron.App;
import iron.System;
import iron.Data;
import iron.Scene;

class BoxPreferences {

	public static var htab = new Handle();
	public static var filesPlugin: Array<String> = null;
	public static var filesKeymap: Array<String> = null;
	public static var themeHandle: Handle;
	public static var presetHandle: Handle;
	static var locales: Array<String> = null;
	static var themes: Array<String> = null;
	static var worldColor = Color.fromValue(0xff080808);

	public static function show() {

		UIBox.showCustom(function(ui: Zui) {
			if (ui.tab(htab, tr("Interface"), true)) {

				if (locales == null) {
					locales = Translator.getSupportedLocales();
				}

				var localeHandle = Zui.handle("boxpreferences_0", { position: locales.indexOf(Config.raw.locale) });
				ui.combo(localeHandle, locales, tr("Language"), true);
				if (localeHandle.changed) {
					var localeCode = locales[localeHandle.position];
					Config.raw.locale = localeCode;
					Translator.loadTranslations(localeCode);
					UIBase.inst.tagUIRedraw();
				}

				var hscale = Zui.handle("boxpreferences_1", { value: Config.raw.window_scale });
				ui.slider(hscale, tr("UI Scale"), 1.0, 4.0, true, 10);
				if (Context.raw.hscaleWasChanged && !ui.inputDown) {
					Context.raw.hscaleWasChanged = false;
					if (hscale.value == null || Math.isNaN(hscale.value)) hscale.value = 1.0;
					Config.raw.window_scale = hscale.value;
					setScale();
				}
				if (hscale.changed) Context.raw.hscaleWasChanged = true;

				var hspeed = Zui.handle("boxpreferences_2", { value: Config.raw.camera_zoom_speed });
				Config.raw.camera_zoom_speed = ui.slider(hspeed, tr("Camera Zoom Speed"), 0.1, 4.0, true);

				hspeed = Zui.handle("boxpreferences_3", { value: Config.raw.camera_rotation_speed });
				Config.raw.camera_rotation_speed = ui.slider(hspeed, tr("Camera Rotation Speed"), 0.1, 4.0, true);

				hspeed = Zui.handle("boxpreferences_4", { value: Config.raw.camera_pan_speed });
				Config.raw.camera_pan_speed = ui.slider(hspeed, tr("Camera Pan Speed"), 0.1, 4.0, true);

				var zoomDirectionHandle = Zui.handle("boxpreferences_5", { position: Config.raw.zoom_direction });
				ui.combo(zoomDirectionHandle, [tr("Vertical"), tr("Vertical Inverted"), tr("Horizontal"), tr("Horizontal Inverted"), tr("Vertical and Horizontal"), tr("Vertical and Horizontal Inverted")], tr("Direction to Zoom"), true);
				if (zoomDirectionHandle.changed) {
					Config.raw.zoom_direction = zoomDirectionHandle.position;
				}

				Config.raw.wrap_mouse = ui.check(Zui.handle("boxpreferences_6", { selected: Config.raw.wrap_mouse }), tr("Wrap Mouse"));
				if (ui.isHovered) ui.tooltip(tr("Wrap mouse around view boundaries during camera control"));

				Config.raw.node_preview = ui.check(Zui.handle("boxpreferences_7", { selected: Config.raw.node_preview }), tr("Show Node Preview"));

				ui.changed = false;
				Config.raw.show_asset_names = ui.check(Zui.handle("boxpreferences_8", { selected: Config.raw.show_asset_names }), tr("Show Asset Names"));
				if (ui.changed) {
					UIBase.inst.tagUIRedraw();
				}

				#if !(krom_android || krom_ios)
				ui.changed = false;
				Config.raw.touch_ui = ui.check(Zui.handle("boxpreferences_9", { selected: Config.raw.touch_ui }), tr("Touch UI"));
				if (ui.changed) {
					Zui.touchScroll = Zui.touchHold = Zui.touchTooltip = Config.raw.touch_ui;
					Config.loadTheme(Config.raw.theme);
					setScale();
					UIBase.inst.tagUIRedraw();
				}
				#end

				Config.raw.splash_screen = ui.check(Zui.handle("boxpreferences_10", { selected: Config.raw.splash_screen }), tr("Splash Screen"));

				// ui.text("Node Editor");
				// var gridSnap = ui.check(Zui.handle("boxpreferences_11", { selected: false }), "Grid Snap");

				ui.endElement();
				ui.row([0.5, 0.5]);
				if (ui.button(tr("Restore")) && !UIMenu.show) {
					UIMenu.draw(function(ui: Zui) {
						if (UIMenu.menuButton(ui, tr("Confirm"))) {
							App.notifyOnInit(function() {
								ui.t.ELEMENT_H = Base.defaultElementH;
								Config.restore();
								setScale();
								if (filesPlugin != null) for (f in filesPlugin) Plugin.stop(f);
								filesPlugin = null;
								filesKeymap = null;
								MakeMaterial.parseMeshMaterial();
								MakeMaterial.parsePaintMaterial();
							});
						}
						if (UIMenu.menuButton(ui, tr("Import..."))) {
							UIFiles.show("json", false, false, function(path: String) {
								Data.getBlob(path, function(b: js.lib.ArrayBuffer) {
									var raw = Json.parse(System.bufferToString(b));
									App.notifyOnInit(function() {
										ui.t.ELEMENT_H = Base.defaultElementH;
										Config.importFrom(raw);
										setScale();
										MakeMaterial.parseMeshMaterial();
										MakeMaterial.parsePaintMaterial();
									});
								});
							});
						}
					}, 2);
				}
				if (ui.button(tr("Reset Layout")) && !UIMenu.show) {
					UIMenu.draw(function(ui: Zui) {
						if (UIMenu.menuButton(ui, tr("Confirm"))) {
							Base.initLayout();
							Config.save();
						}
					}, 1);
				}
			}

			if (ui.tab(htab, tr("Theme"), true)) {

				if (themes == null) {
					fetchThemes();
				}
				themeHandle = Zui.handle("boxpreferences_12", { position: getThemeIndex() });

				ui.beginSticky();
				ui.row([1 / 4, 1 / 4, 1 / 4, 1 / 4]);

				ui.combo(themeHandle, themes, tr("Theme"));
				if (themeHandle.changed) {
					Config.raw.theme = themes[themeHandle.position] + ".json";
					Config.loadTheme(Config.raw.theme);
				}

				if (ui.button(tr("New"))) {
					UIBox.showCustom(function(ui: Zui) {
						if (ui.tab(Zui.handle("boxpreferences_13"), tr("New Theme"))) {
							ui.row([0.5, 0.5]);
							var themeName = ui.textInput(Zui.handle("boxpreferences_14", { text: "new_theme" }), tr("Name"));
							if (ui.button(tr("OK")) || ui.isReturnDown) {
								var template = Json.stringify(Base.theme);
								if (!themeName.endsWith(".json")) themeName += ".json";
								var path = Path.data() + Path.sep + "themes" + Path.sep + themeName;
								Krom.fileSaveBytes(path, System.stringToBuffer(template));
								fetchThemes(); // Refresh file list
								Config.raw.theme = themeName;
								themeHandle.position = getThemeIndex();
								UIBox.hide();
								BoxPreferences.htab.position = 1; // Themes
								BoxPreferences.show();
							}
						}
					});
				}

				if (ui.button(tr("Import"))) {
					UIFiles.show("json", false, false, function(path: String) {
						ImportTheme.run(path);
					});
				}

				if (ui.button(tr("Export"))) {
					UIFiles.show("json", true, false, function(path) {
						path += Path.sep + UIFiles.filename;
						if (!path.endsWith(".json")) path += ".json";
						Krom.fileSaveBytes(path, System.stringToBuffer(Json.stringify(Base.theme)));
					});
				}

				ui.endSticky();

				var i = 0;
				var theme = Base.theme;
				var hlist = Zui.handle("boxpreferences_15");

				// Viewport color
				var h = hlist.nest(i++, { color: worldColor });
				ui.row([1 / 8, 7 / 8]);
				ui.text("", 0, h.color);
				if (ui.isHovered && ui.inputReleased) {
					UIMenu.draw(function(ui) {
						ui.changed = false;
						ui.colorWheel(h, false, null, 11 * ui.t.ELEMENT_H * ui.SCALE(), true);
						if (ui.changed) UIMenu.keepOpen = true;
					}, 11);
				}
				var val = untyped h.color;
				if (val < 0) val += untyped 4294967296;
				h.text = untyped val.toString(16);
				ui.textInput(h, "VIEWPORT_COL");
				h.color = untyped parseInt(h.text, 16);

				if (worldColor != h.color) {
					worldColor = h.color;
					var b = new js.lib.Uint8Array(4);
					b[0] = worldColor.Rb;
					b[1] = worldColor.Gb;
					b[2] = worldColor.Bb;
					b[3] = 255;
					Context.raw.emptyEnvmap = Image.fromBytes(b.buffer, 1, 1);
					Context.raw.ddirty = 2;
					if (!Context.raw.showEnvmap) {
						Scene.active.world.envmap = Context.raw.emptyEnvmap;
					}
				}

				// Theme fields
				for (key in Type.getInstanceFields(zui.Zui.Theme)) {
					if (key == "theme_") continue;
					if (key.startsWith("set_")) continue;
					if (key.startsWith("get_")) key = key.substr(4);

					var h = hlist.nest(i++);
					var val: Dynamic = Reflect.getProperty(theme, key);

					var isHex = key.endsWith("_COL");
					if (isHex && val < 0) val += untyped 4294967296;

					if (isHex) {
						ui.row([1 / 8, 7 / 8]);
						ui.text("", 0, val);
						if (ui.isHovered && ui.inputReleased) {
							h.color = Reflect.getProperty(theme, key);
							UIMenu.draw(function(ui) {
								ui.changed = false;
								var color = ui.colorWheel(h, false, null, 11 * ui.t.ELEMENT_H * ui.SCALE(), true);
								Reflect.setProperty(theme, key, color);
								if (ui.changed) UIMenu.keepOpen = true;
							}, 11);
						}
					}

					ui.changed = false;

					if (Std.isOfType(val, Bool)) {
						h.selected = val;
						var b = ui.check(h, key);
						Reflect.setProperty(theme, key, b);
					}
					else if (key == "LINK_STYLE") {
						var styles = [tr("Straight"), tr("Curved")];
						h.position = val;
						var i = ui.combo(h, styles, key, true);
						Reflect.setProperty(theme, key, i);
					}
					else {
						h.text = isHex ? untyped val.toString(16) : untyped val.toString();
						var res = ui.textInput(h, key);
						if (isHex) Reflect.setProperty(theme, key, untyped parseInt(h.text, 16));
						else Reflect.setProperty(theme, key, untyped parseInt(h.text));
					}

					if (ui.changed) {
						for (ui in Base.getUIs()) {
							ui.elementsBaked = false;
						}
					}
				}
			}

			if (ui.tab(htab, tr("Usage"), true)) {
				Context.raw.undoHandle = Zui.handle("boxpreferences_16", { value: Config.raw.undo_steps });
				Config.raw.undo_steps = Std.int(ui.slider(Context.raw.undoHandle, tr("Undo Steps"), 1, 64, false, 1));
				if (Config.raw.undo_steps < 1) {
					Config.raw.undo_steps = Std.int(Context.raw.undoHandle.value = 1);
				}
				if (Context.raw.undoHandle.changed) {
					ui.g.end();

					#if (is_paint || is_sculpt)
					while (History.undoLayers.length < Config.raw.undo_steps) {
						var l = new SlotLayer("_undo" + History.undoLayers.length);
						History.undoLayers.push(l);
					}
					while (History.undoLayers.length > Config.raw.undo_steps) {
						var l = History.undoLayers.pop();
						l.unload();
					}
					#end

					History.reset();
					ui.g.begin(false);
				}

				#if is_paint
				Config.raw.dilate_radius = Std.int(ui.slider(Zui.handle("boxpreferences_17", { value: Config.raw.dilate_radius }), tr("Dilate Radius"), 0.0, 16.0, true, 1));
				if (ui.isHovered) ui.tooltip(tr("Dilate painted textures to prevent seams"));

				var dilateHandle = Zui.handle("boxpreferences_18", { position: Config.raw.dilate });
				ui.combo(dilateHandle, [tr("Instant"), tr("Delayed")], tr("Dilate"), true);
				if (dilateHandle.changed) {
					Config.raw.dilate = dilateHandle.position;
				}
				#end

				#if is_lab
				var workspaceHandle = Zui.handle("boxpreferences_19", { position: Config.raw.workspace });
				ui.combo(workspaceHandle, [tr("3D View"), tr("2D View")], tr("Default Workspace"), true);
				if (workspaceHandle.changed) {
					Config.raw.workspace = workspaceHandle.position;
				}
				#end

				var cameraControlsHandle = Zui.handle("boxpreferences_20", { position: Config.raw.camera_controls });
				ui.combo(cameraControlsHandle, [tr("Orbit"), tr("Rotate"), tr("Fly")], tr("Default Camera Controls"), true);
				if (cameraControlsHandle.changed) {
					Config.raw.camera_controls = cameraControlsHandle.position;
				}

				var layerResHandle = Zui.handle("boxpreferences_21", { position: Config.raw.layer_res });

				#if is_paint
				#if (krom_android || krom_ios)
				ui.combo(layerResHandle, ["128", "256", "512", "1K", "2K", "4K"], tr("Default Layer Resolution"), true);
				#else
				ui.combo(layerResHandle, ["128", "256", "512", "1K", "2K", "4K", "8K"], tr("Default Layer Resolution"), true);
				#end
				#end

				#if is_lab
				#if (krom_android || krom_ios)
				ui.combo(layerResHandle, ["2K", "4K"], tr("Default Layer Resolution"), true);
				#else
				ui.combo(layerResHandle, ["2K", "4K", "8K", "16K"], tr("Default Layer Resolution"), true);
				#end
				#end

				if (layerResHandle.changed) {
					Config.raw.layer_res = layerResHandle.position;
				}

				var serverHandle = Zui.handle("boxpreferences_22", { text: Config.raw.server });
				Config.raw.server = ui.textInput(serverHandle, tr("Cloud Server"));

				#if (is_paint || is_sculpt)
				var materialLiveHandle = Zui.handle("boxpreferences_23", {selected: Config.raw.material_live });
				Config.raw.material_live = ui.check(materialLiveHandle, tr("Live Material Preview"));
				if (ui.isHovered) ui.tooltip(tr("Instantly update material preview on node change"));

				var brushLiveHandle = Zui.handle("boxpreferences_24", { selected: Config.raw.brush_live });
				Config.raw.brush_live = ui.check(brushLiveHandle, tr("Live Brush Preview"));
				if (ui.isHovered) ui.tooltip(tr("Draw live brush preview in viewport"));
				if (brushLiveHandle.changed) Context.raw.ddirty = 2;

				var brush3dHandle = Zui.handle("boxpreferences_25", { selected: Config.raw.brush_3d });
				Config.raw.brush_3d = ui.check(brush3dHandle, tr("3D Cursor"));
				if (brush3dHandle.changed) MakeMaterial.parsePaintMaterial();

				ui.enabled = Config.raw.brush_3d;
				var brushDepthRejectHandle = Zui.handle("boxpreferences_26", { selected: Config.raw.brush_depth_reject });
				Config.raw.brush_depth_reject = ui.check(brushDepthRejectHandle, tr("Depth Reject"));
				if (brushDepthRejectHandle.changed) MakeMaterial.parsePaintMaterial();

				ui.row([0.5, 0.5]);

				var brushAngleRejectHandle = Zui.handle("boxpreferences_27", { selected: Config.raw.brush_angle_reject });
				Config.raw.brush_angle_reject = ui.check(brushAngleRejectHandle, tr("Angle Reject"));
				if (brushAngleRejectHandle.changed) MakeMaterial.parsePaintMaterial();

				if (!Config.raw.brush_angle_reject) ui.enabled = false;
				var angleDotHandle = Zui.handle("boxpreferences_28", { value: Context.raw.brushAngleRejectDot });
				Context.raw.brushAngleRejectDot = ui.slider(angleDotHandle, tr("Angle"), 0.0, 1.0, true);
				if (angleDotHandle.changed) {
					MakeMaterial.parsePaintMaterial();
				}
				ui.enabled = true;
				#end

				#if is_lab
				Config.raw.gpu_inference = ui.check(Zui.handle("boxpreferences_29", { selected: Config.raw.gpu_inference }), tr("Use GPU"));
				if (ui.isHovered) ui.tooltip(tr("Use GPU to accelerate node graph processing"));
				#end
			}

			#if krom_ios
			if (ui.tab(htab, tr("Pencil"), true)) {
			#else
			if (ui.tab(htab, tr("Pen"), true)) {
			#end
				ui.text(tr("Pressure controls"));
				Config.raw.pressure_radius = ui.check(Zui.handle("boxpreferences_30", { selected: Config.raw.pressure_radius }), tr("Brush Radius"));
				Config.raw.pressure_sensitivity = ui.slider(Zui.handle("boxpreferences_31", { value: Config.raw.pressure_sensitivity }), tr("Sensitivity"), 0.0, 10.0, true);
				#if (is_paint || is_sculpt)
				Config.raw.pressure_hardness = ui.check(Zui.handle("boxpreferences_32", { selected: Config.raw.pressure_hardness }), tr("Brush Hardness"));
				Config.raw.pressure_opacity = ui.check(Zui.handle("boxpreferences_33", { selected: Config.raw.pressure_opacity }), tr("Brush Opacity"));
				Config.raw.pressure_angle = ui.check(Zui.handle("boxpreferences_34", { selected: Config.raw.pressure_angle }), tr("Brush Angle"));
				#end

				ui.endElement();
				ui.row([0.5]);
				if (ui.button(tr("Help"))) {
					#if (is_paint || is_sculpt)
					File.loadUrl("https://github.com/armory3d/armorpaint_docs#pen");
					#end
					#if is_lab
					File.loadUrl("https://github.com/armory3d/armorlab_docs#pen");
					#end
				}
			}

			Context.raw.hssao = Zui.handle("boxpreferences_35", { selected: Config.raw.rp_ssao });
			Context.raw.hssr = Zui.handle("boxpreferences_36", { selected: Config.raw.rp_ssr });
			Context.raw.hbloom = Zui.handle("boxpreferences_37", { selected: Config.raw.rp_bloom });
			Context.raw.hsupersample = Zui.handle("boxpreferences_38", { position: Config.getSuperSampleQuality(Config.raw.rp_supersample) });
			Context.raw.hvxao = Zui.handle("boxpreferences_39", { selected: Config.raw.rp_gi });
			if (ui.tab(htab, tr("Viewport"), true)) {
				#if (krom_direct3d12 || krom_vulkan || krom_metal)

				var hpathtracemode = Zui.handle("boxpreferences_40", { position: Context.raw.pathTraceMode });
				Context.raw.pathTraceMode = ui.combo(hpathtracemode, [tr("Core"), tr("Full")], tr("Path Tracer"), true);
				if (hpathtracemode.changed) {
					RenderPathRaytrace.ready = false;
				}

				#end

				var hrendermode = Zui.handle("boxpreferences_41", { position: Context.raw.renderMode });
				Context.raw.renderMode = ui.combo(hrendermode, [tr("Full"), tr("Mobile")], tr("Renderer"), true);
				if (hrendermode.changed) {
					Context.setRenderPath();
				}

				ui.combo(Context.raw.hsupersample, ["0.25x", "0.5x", "1.0x", "1.5x", "2.0x", "4.0x"], tr("Super Sample"), true);
				if (Context.raw.hsupersample.changed) Config.applyConfig();

				if (Context.raw.renderMode == RenderDeferred) {
					#if arm_voxels
					ui.check(Context.raw.hvxao, tr("Voxel AO"));
					if (ui.isHovered) ui.tooltip(tr("Cone-traced AO and shadows"));
					if (Context.raw.hvxao.changed) {
						Config.applyConfig();
					}

					ui.enabled = Context.raw.hvxao.selected;
					var h = Zui.handle("boxpreferences_42", { value: Context.raw.vxaoOffset });
					Context.raw.vxaoOffset = ui.slider(h, tr("Cone Offset"), 1.0, 4.0, true);
					if (h.changed) Context.raw.ddirty = 2;
					var h = Zui.handle("boxpreferences_43", { value: Context.raw.vxaoAperture });
					Context.raw.vxaoAperture = ui.slider(h, tr("Aperture"), 1.0, 4.0, true);
					if (h.changed) Context.raw.ddirty = 2;
					ui.enabled = true;
					#end

					ui.check(Context.raw.hssao, tr("SSAO"));
					if (Context.raw.hssao.changed) Config.applyConfig();
					ui.check(Context.raw.hssr, tr("SSR"));
					if (Context.raw.hssr.changed) Config.applyConfig();
					ui.check(Context.raw.hbloom, tr("Bloom"));
					if (Context.raw.hbloom.changed) Config.applyConfig();
				}

				var h = Zui.handle("boxpreferences_44", { value: Config.raw.rp_vignette });
				Config.raw.rp_vignette = ui.slider(h, tr("Vignette"), 0.0, 1.0, true);
				if (h.changed) Context.raw.ddirty = 2;

				var h = Zui.handle("boxpreferences_45", { value: Config.raw.rp_grain });
				Config.raw.rp_grain = ui.slider(h, tr("Noise Grain"), 0.0, 1.0, true);
				if (h.changed) Context.raw.ddirty = 2;

				// var h = Zui.handle("boxpreferences_46", { value: Context.raw.autoExposureStrength });
				// Context.raw.autoExposureStrength = ui.slider(h, "Auto Exposure", 0.0, 2.0, true);
				// if (h.changed) Context.raw.ddirty = 2;

				var cam = Scene.active.camera;
				var camRaw = cam.data.raw;
				var near_handle = Zui.handle("boxpreferences_47");
				var far_handle = Zui.handle("boxpreferences_48");
				near_handle.value = Std.int(camRaw.near_plane * 1000) / 1000;
				far_handle.value = Std.int(camRaw.far_plane * 100) / 100;
				camRaw.near_plane = ui.slider(near_handle, tr("Clip Start"), 0.001, 1.0, true);
				camRaw.far_plane = ui.slider(far_handle, tr("Clip End"), 50.0, 100.0, true);
				if (near_handle.changed || far_handle.changed) {
					cam.buildProjection();
				}

				var dispHandle = Zui.handle("boxpreferences_49", { value: Config.raw.displace_strength });
				Config.raw.displace_strength = ui.slider(dispHandle, tr("Displacement Strength"), 0.0, 10.0, true);
				if (dispHandle.changed) {
					Context.raw.ddirty = 2;
					MakeMaterial.parseMeshMaterial();
				}
			}
			if (ui.tab(htab, tr("Keymap"), true)) {

				if (filesKeymap == null) {
					fetchKeymaps();
				}

				ui.beginSticky();
				ui.row([1 / 4, 1 / 4, 1 / 4, 1 / 4]);

				presetHandle = Zui.handle("boxpreferences_50", { position: getPresetIndex() });
				ui.combo(presetHandle, filesKeymap, tr("Preset"));
				if (presetHandle.changed) {
					Config.raw.keymap = filesKeymap[presetHandle.position] + ".json";
					Config.applyConfig();
					Config.loadKeymap();
				}

				if (ui.button(tr("New"))) {
					UIBox.showCustom(function(ui: Zui) {
						if (ui.tab(Zui.handle("boxpreferences_51"), tr("New Keymap"))) {
							ui.row([0.5, 0.5]);
							var keymapName = ui.textInput(Zui.handle("boxpreferences_52", { text: "new_keymap" }), tr("Name"));
							if (ui.button(tr("OK")) || ui.isReturnDown) {
								var template = Json.stringify(Base.defaultKeymap);
								if (!keymapName.endsWith(".json")) keymapName += ".json";
								var path = Path.data() + Path.sep + "keymap_presets" + Path.sep + keymapName;
								Krom.fileSaveBytes(path, System.stringToBuffer(template));
								fetchKeymaps(); // Refresh file list
								Config.raw.keymap = keymapName;
								presetHandle.position = getPresetIndex();
								UIBox.hide();
								BoxPreferences.htab.position = 5; // Keymap
								BoxPreferences.show();
							}
						}
					});
				}

				if (ui.button(tr("Import"))) {
					UIFiles.show("json", false, false, function(path: String) {
						ImportKeymap.run(path);
					});
				}
				if (ui.button(tr("Export"))) {
					UIFiles.show("json", true, false, function(dest: String) {
						if (!UIFiles.filename.endsWith(".json")) UIFiles.filename += ".json";
						var path = Path.data() + Path.sep + "keymap_presets" + Path.sep + Config.raw.keymap;
						File.copy(path, dest + Path.sep + UIFiles.filename);
					});
				}

				ui.endSticky();

				ui.separator(8, false);

				var i = 0;
				ui.changed = false;
				for (key in Reflect.fields(Config.keymap)) {
					var h = Zui.handle("boxpreferences_53").nest(i++);
					h.text = Reflect.field(Config.keymap, key);
					var text = ui.textInput(h, key, Left);
					Reflect.setField(Config.keymap, key, text);
				}
				if (ui.changed) {
					Config.applyConfig();
					Config.saveKeymap();
				}
			}
			if (ui.tab(htab, tr("Plugins"), true)) {
				ui.beginSticky();
				ui.row([1 / 4, 1 / 4]);
				if (ui.button(tr("New"))) {
					UIBox.showCustom(function(ui: Zui) {
						if (ui.tab(Zui.handle("boxpreferences_54"), tr("New Plugin"))) {
							ui.row([0.5, 0.5]);
							var pluginName = ui.textInput(Zui.handle("boxpreferences_55", { text: "new_plugin" }), tr("Name"));
							if (ui.button(tr("OK")) || ui.isReturnDown) {
								var template =
"let plugin = new arm.Plugin();
let h1 = new zui.Handle();
plugin.drawUI = function(ui) {
	if (ui.panel(h1, 'New Plugin')) {
		if (ui.button('Button')) {
			console.error('Hello');
		}
	}
}
";
								if (!pluginName.endsWith(".js")) pluginName += ".js";
								var path = Path.data() + Path.sep + "plugins" + Path.sep + pluginName;
								Krom.fileSaveBytes(path, System.stringToBuffer(template));
								filesPlugin = null; // Refresh file list
								UIBox.hide();
								BoxPreferences.htab.position = 6; // Plugins
								BoxPreferences.show();
							}
						}
					});
				}
				if (ui.button(tr("Import"))) {
					UIFiles.show("js,wasm,zip", false, false, function(path: String) {
						ImportPlugin.run(path);
					});
				}
				ui.endSticky();

				if (filesPlugin == null) {
					fetchPlugins();
				}

				if (Config.raw.plugins == null) Config.raw.plugins = [];
				var h = Zui.handle("boxpreferences_56", { selected: false });
				for (f in filesPlugin) {
					var isJs = f.endsWith(".js");
					var isWasm = false; //f.endsWith(".wasm");
					if (!isJs && !isWasm) continue;
					var enabled = Config.raw.plugins.indexOf(f) >= 0;
					h.selected = enabled;
					var tag = isJs ? f.split(".")[0] : f;
					ui.check(h, tag);
					if (h.changed && h.selected != enabled) {
						h.selected ? Config.enablePlugin(f) : Config.disablePlugin(f);
						Base.redrawUI();
					}
					if (ui.isHovered && ui.inputReleasedR) {
						UIMenu.draw(function(ui: Zui) {
							var path = Path.data() + Path.sep + "plugins" + Path.sep + f;
							if (UIMenu.menuButton(ui, tr("Edit in Text Editor"))) {
								File.start(path);
							}
							if (UIMenu.menuButton(ui, tr("Edit in Script Tab"))) {
								Data.getBlob("plugins/" + f, function(blob: js.lib.ArrayBuffer) {
									TabScript.hscript.text = System.bufferToString(blob);
									Data.deleteBlob("plugins/" + f);
									Console.info(tr("Script opened"));
								});

							}
							if (UIMenu.menuButton(ui, tr("Export"))) {
								UIFiles.show("js", true, false, function(dest: String) {
									if (!UIFiles.filename.endsWith(".js")) UIFiles.filename += ".js";
									File.copy(path, dest + Path.sep + UIFiles.filename);
								});
							}
							if (UIMenu.menuButton(ui, tr("Delete"))) {
								if (Config.raw.plugins.indexOf(f) >= 0) {
									Config.raw.plugins.remove(f);
									Plugin.stop(f);
								}
								filesPlugin.remove(f);
								File.delete(path);
							}
						}, 4);
					}
				}
			}
		}, 620, Config.raw.touch_ui ? 480 : 420, function() { Config.save(); });
	}

	public static function fetchThemes() {
		themes = File.readDirectory(Path.data() + Path.sep + "themes");
		for (i in 0...themes.length) themes[i] = themes[i].substr(0, themes[i].length - 5); // Strip .json
		themes.unshift("default");
	}

	public static function fetchKeymaps() {
		filesKeymap = File.readDirectory(Path.data() + Path.sep + "keymap_presets");
		for (i in 0...filesKeymap.length) {
			filesKeymap[i] = filesKeymap[i].substr(0, filesKeymap[i].length - 5); // Strip .json
		}
		filesKeymap.unshift("default");
	}

	public static function fetchPlugins() {
		filesPlugin = File.readDirectory(Path.data() + Path.sep + "plugins");
	}

	public static function getThemeIndex(): Int {
		return themes.indexOf(Config.raw.theme.substr(0, Config.raw.theme.length - 5)); // Strip .json
	}

	public static function getPresetIndex(): Int {
		return filesKeymap.indexOf(Config.raw.keymap.substr(0, Config.raw.keymap.length - 5)); // Strip .json
	}

	static function setScale() {
		var scale = Config.raw.window_scale;
		UIBase.inst.ui.setScale(scale);
		UIHeader.headerh = Std.int(UIHeader.defaultHeaderH * scale);
		Config.raw.layout[LayoutStatusH] = Std.int(UIStatus.defaultStatusH * scale);
		UIMenubar.inst.menubarw = Std.int(UIMenubar.defaultMenubarW * scale);
		UIBase.inst.setIconScale();
		UINodes.inst.ui.setScale(scale);
		UIView2D.inst.ui.setScale(scale);
		Base.uiBox.setScale(scale);
		Base.uiMenu.setScale(scale);
		Base.resize();
		#if (is_paint || is_sculpt)
		Config.raw.layout[LayoutSidebarW] = Std.int(UIBase.defaultSidebarW * scale);
		UIToolbar.inst.toolbarw = Std.int(UIToolbar.defaultToolbarW * scale);
		#end
	}
}