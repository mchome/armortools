package arm;

import zui.Zui;
import iron.System;
import iron.Data;

class TabConsole {

	public static function draw(htab: Handle) {
		var ui = UIBase.inst.ui;

		var title = Console.messageTimer > 0 ? Console.message + "        " : tr("Console");
		var color = Console.messageTimer > 0 ? Console.messageColor : -1;

		var statush = Config.raw.layout[LayoutStatusH];
		if (ui.tab(htab, title, false, color) && statush > UIStatus.defaultStatusH * ui.SCALE()) {

			ui.beginSticky();
			#if (krom_windows || krom_linux || krom_darwin) // Copy
			if (Config.raw.touch_ui) {
				ui.row([1 / 4, 1 / 4, 1 / 4]);
			}
			else {
				ui.row([1 / 14, 1 / 14, 1 / 14]);
			}
			#else
			if (Config.raw.touch_ui) {
				ui.row([1 / 4, 1 / 4]);
			}
			else {
				ui.row([1 / 14, 1 / 14]);
			}
			#end

			if (ui.button(tr("Clear"))) {
				Console.lastTraces = [];
			}
			if (ui.button(tr("Export"))) {
				var str = Console.lastTraces.join("\n");
				UIFiles.show("txt", true, false, function(path: String) {
					var f = UIFiles.filename;
					if (f == "") f = tr("untitled");
					path = path + Path.sep + f;
					if (!path.endsWith(".txt")) path += ".txt";
					Krom.fileSaveBytes(path, System.stringToBuffer(str));
				});
			}
			#if (krom_windows || krom_linux || krom_darwin)
			if (ui.button(tr("Copy"))) {
				var str = Console.lastTraces.join("\n");
				Krom.copyToClipboard(str);
			}
			#end

			ui.endSticky();

			var _font = ui.font;
			var _fontSize = ui.fontSize;
			Data.getFont("font_mono.ttf", function(f: Font) { ui.setFont(f); }); // Sync
			ui.fontSize = Std.int(15 * ui.SCALE());
			for (t in Console.lastTraces) {
				ui.text(t);
			}
			ui.setFont(_font);
			ui.fontSize = _fontSize;
		}
	}
}