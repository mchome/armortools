
let flags = globalThis.flags;
flags.android = process.argv.indexOf("android") >= 0;
flags.ios = process.argv.indexOf("ios") >= 0;
flags.d3d12 = process.argv.indexOf("direct3d12") >= 0;
flags.vulkan = process.argv.indexOf("vulkan") >= 0;
flags.metal = process.argv.indexOf("metal") >= 0;
flags.raytrace = flags.d3d12 || flags.vulkan || flags.metal;
flags.snapshot = process.argv.indexOf("--snapshot") >= 0;
flags.plugin_embed = flags.ios;
flags.physics = !flags.ios;
flags.voxels = !flags.raytrace && !flags.android && !flags.ios;

flags.with_d3dcompiler = true;
flags.with_nfd = true;
flags.with_tinydir = true;
flags.with_zlib = true;
flags.with_stb_image_write = true;
flags.with_g2 = true;
flags.with_iron = true;
flags.with_zui = true;

flags.on_c_project_created = async function(c_project, platform, graphics) {
	c_project.addDefine("IDLE_SLEEP");
	let dir = flags.name.toLowerCase();

	if (graphics === "vulkan") {
		c_project.addDefine("KORE_VKRT");
		await c_project.addProject("../" + dir + "/glsl_to_spirv");
	}
	if (platform === "ios") {
		flags.with_plugin_embed = true;
	}

	if (flags.with_onnx) {
		c_project.addDefine("WITH_ONNX");
		c_project.addIncludeDir("../" + dir + "/onnx/include");
		if (platform === Platform.Windows) {
			c_project.addLib("../" + dir + "/onnx/win32/onnxruntime");
		}
		else if (platform === Platform.Linux) {
			// patchelf --set-rpath . ArmorLab
			c_project.addLib("onnxruntime -L" + __dirname + "/../" + dir + "/onnx/linux");
		}
		else if (platform === Platform.OSX) {
			c_project.addLib("../" + dir + "/onnx/macos/libonnxruntime.1.14.1.dylib");
		}
	}

	if (flags.with_plugin_embed) {
		await c_project.addProject("../" + dir + "/plugins");
	}
};

let project = new Project("Base");
project.addSources("Sources");
project.addShaders("../armorcore/Shaders/*.glsl", { embed: flags.snapshot });
project.addShaders("Shaders/*.glsl", { embed: flags.snapshot });
project.addAssets("Assets/*", { destination: "data/{name}", embed: flags.snapshot });
project.addAssets("Assets/locale/*", { destination: "data/locale/{name}" });
project.addAssets("Assets/licenses/**", { destination: "data/licenses/{name}" });
project.addAssets("Assets/plugins/*", { destination: "data/plugins/{name}" });
project.addAssets("Assets/themes/*.json", { destination: "data/themes/{name}" });

if (flags.snapshot) {
	project.addDefine("arm_snapshot");
	project.addDefine("arm_image_embed");
	project.addDefine("arm_shader_embed");
	project.addParameter("--no-traces");
}
else {
	project.addDefine("arm_noembed");
	project.addAssets("Assets/extra/*", { destination: "data/{name}" });
}

project.addParameter("--macro include('arm.logic')");
project.addParameter("-dce full");
project.addDefine("analyzer-optimize");
project.addDefine("js-es=6");
project.addDefine("arm_particles");
// project.addDefine("arm_skin");
// project.addDefine("arm_audio");

if (flags.android) {
	project.addDefine("krom_android_rmb");
}

if (flags.raytrace) {
	project.addAssets("Assets/raytrace/*", { destination: "data/{name}", embed: flags.snapshot });

	if (flags.d3d12) {
		project.addAssets("Shaders/raytrace/*.cso", { destination: "data/{name}", embed: flags.snapshot });
	}
	else if (flags.vulkan) {
		project.addAssets("Shaders/raytrace/*.spirv", { destination: "data/{name}", embed: flags.snapshot });
	}
	else if (flags.metal) {
		project.addAssets("Shaders/raytrace/*.metal", { destination: "data/{name}", embed: flags.snapshot });
	}
}

if (flags.voxels) {
	project.addDefine("arm_voxels");

	if (process.platform === "win32") {
		project.addShaders("Shaders/voxel_hlsl/*.glsl", { embed: flags.snapshot, noprocessing: true });
	}
	else {
		project.addShaders("Shaders/voxel_glsl/*.glsl", { embed: flags.snapshot });
	}
}

resolve(project);