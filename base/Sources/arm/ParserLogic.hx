package arm;

import zui.Zui.Nodes;
import zui.Zui.TNode;
import zui.Zui.TNodeLink;
import zui.Zui.TNodeSocket;
import zui.Zui.TNodeCanvas;

class ParserLogic {

	public static var customNodes = js.Syntax.code("new Map()");
	static var nodes: Array<TNode>;
	static var links: Array<TNodeLink>;

	static var parsed_nodes: Array<String> = null;
	static var parsed_labels: Map<String, String> = null;
	static var nodeMap: Map<String, LogicNode>;
	static var rawMap: Map<LogicNode, TNode>;

	public static var packageName = "arm.nodes";

	public static function getLogicNode(node: TNode): LogicNode {
		return nodeMap.get(node_name(node));
	}

	public static function getRawNode(node: LogicNode): TNode {
		return rawMap.get(node);
	}

	public static function getNode(id: Int): TNode {
		for (n in nodes) if (n.id == id) return n;
		return null;
	}

	public static function getLink(id: Int): TNodeLink {
		for (l in links) if (l.id == id) return l;
		return null;
	}

	public static function getInputLink(inp: TNodeSocket): TNodeLink {
		for (l in links) {
			if (l.to_id == inp.node_id) {
				var node = getNode(inp.node_id);
				if (node.inputs.length <= l.to_socket) return null;
				if (node.inputs[l.to_socket] == inp) return l;
			}
		}
		return null;
	}

	public static function getOutputLinks(out: TNodeSocket): Array<TNodeLink> {
		var res: Array<TNodeLink> = [];
		for (l in links) {
			if (l.from_id == out.node_id) {
				var node = getNode(out.node_id);
				if (node.outputs.length <= l.from_socket) continue;
				if (node.outputs[l.from_socket] == out) res.push(l);
			}
		}
		return res;
	}

	static function safe_src(s:String): String {
		return StringTools.replace(s, " ", "");
	}

	static function node_name(node: TNode): String {
		var s = safe_src(node.name) + node.id;
		return s;
	}

	public static function parse(canvas: TNodeCanvas) {
		nodes = canvas.nodes;
		links = canvas.links;

		parsed_nodes = [];
		parsed_labels = new Map();
		nodeMap = new Map();
		rawMap = new Map();
		var root_nodes = get_root_nodes(canvas);

		for (node in root_nodes) build_node(node);
	}

	static function build_node(node: TNode): String {
		// Get node name
		var name = node_name(node);

		// Check if node already exists
		if (parsed_nodes.indexOf(name) != -1) {
			return name;
		}

		parsed_nodes.push(name);

		// Create node
		var v = createClassInstance(node.type, []);
		nodeMap.set(name, v);
		rawMap.set(v, node);

		// Expose button values in node class
		for (b in node.buttons) {
			if (b.type == "ENUM") {
				// var arrayData = Std.isOfType(b.data, Array);
				var arrayData = b.data.length > 1;
				var texts = arrayData ? b.data : Nodes.enumTextsHaxe(node.type);
				Reflect.setProperty(v, b.name, texts[b.default_value]);
			}
			else {
				Reflect.setProperty(v, b.name, b.default_value);
			}
		}

		// Create inputs
		var inp_node: LogicNode = null;
		var inp_from = 0;
		for (i in 0...node.inputs.length) {
			var inp = node.inputs[i];
			// Is linked - find node
			var l = getInputLink(inp);
			if (l != null) {
				inp_node = nodeMap.get(build_node(getNode(l.from_id)));
				inp_from = l.from_socket;
			}
			// Not linked - create node with default values
			else {
				inp_node = build_default_node(inp);
				inp_from = 0;
			}
			// Add input
			v.addInput(inp_node, inp_from);
		}

		// Create outputs
		for (out in node.outputs) {
			var outNodes:Array<LogicNode> = [];
			var ls = getOutputLinks(out);
			if (ls != null && ls.length > 0) {
				for (l in ls) {
					var n = getNode(l.to_id);
					var out_name = build_node(n);
					outNodes.push(nodeMap.get(out_name));
				}
			}
			// Not linked - create node with default values
			else {
				outNodes.push(build_default_node(out));
			}
			// Add outputs
			v.addOutputs(outNodes);
		}

		return name;
	}

	static function get_root_nodes(node_group: TNodeCanvas): Array<TNode> {
		var roots: Array<TNode> = [];
		for (node in node_group.nodes) {
			var linked = false;
			for (out in node.outputs) {
				var ls = getOutputLinks(out);
				if (ls != null && ls.length > 0) {
					linked = true;
					break;
				}
			}
			if (!linked) { // Assume node with no connected outputs as roots
				roots.push(node);
			}
		}
		return roots;
	}

	static function build_default_node(inp: TNodeSocket): LogicNode {

		var v: LogicNode = null;

		if (inp.type == "VECTOR") {
			if (inp.default_value == null) inp.default_value = [0, 0, 0]; // TODO
			v = createClassInstance("VectorNode", [inp.default_value[0], inp.default_value[1], inp.default_value[2]]);
		}
		else if (inp.type == "RGBA") {
			if (inp.default_value == null) inp.default_value = [0, 0, 0, 0]; // TODO
			v = createClassInstance("ColorNode", [inp.default_value[0], inp.default_value[1], inp.default_value[2], inp.default_value[3]]);
		}
		else if (inp.type == "RGB") {
			if (inp.default_value == null) inp.default_value = [0, 0, 0, 0]; // TODO
			v = createClassInstance("ColorNode", [inp.default_value[0], inp.default_value[1], inp.default_value[2], inp.default_value[3]]);
		}
		else if (inp.type == "VALUE") {
			v = createClassInstance("FloatNode", [inp.default_value]);
		}
		else if (inp.type == "INT") {
			v = createClassInstance("IntegerNode", [inp.default_value]);
		}
		else if (inp.type == "BOOLEAN") {
			v = createClassInstance("BooleanNode", [inp.default_value]);
		}
		else if (inp.type == "STRING") {
			v = createClassInstance("StringNode", [inp.default_value]);
		}
		else {
			v = createClassInstance("NullNode", []);
		}
		return v;
	}

	static function createClassInstance(className: String, args: Array<Dynamic>): Dynamic {
		if (customNodes.get(className) != null) {
			var node = new LogicNode();
			untyped node.get = function(from: Int) { return customNodes.get(className)(node, from); }
			return node;
		}
		var cname = Type.resolveClass(packageName + "." + className);
		if (cname == null) return null;
		return Type.createInstance(cname, args);
	}

	public static function f32(ar: Array<Float>): js.lib.Float32Array {
		var res = new js.lib.Float32Array(ar.length);
		for (i in 0...ar.length) res[i] = ar[i];
		return res;
	}
}