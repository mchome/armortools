
let plugin = new Plugin();

let h1 = new Handle();
let h2 = new Handle({value: 5});
let timer = 0.0;

plugin.drawUI = function(ui) {
	if (ui.panel(h1, "Auto Save")) {
		ui.slider(h2, "min", 1, 15, false, 1);
	}
}

plugin.update = function() {
	if (Project.filepath == "") return;
	timer += 1 / 60;
	if (timer >= h2.value * 60) {
		timer = 0.0;
		Project.projectSave();
	}
}
