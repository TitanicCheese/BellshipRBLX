// Pushes the code in src/ into the open Studio place through Studio MCP, without the Rojo plugin.
// It rebuilds the Shared, Server, and Client script trees from the Rojo sourcemap.
// Run while Studio is in Edit mode: bun tools/push.ts
// With several Studios open, set STUDIO to a part of the place name (STUDIO=Bellship).
import { $ } from "bun";

type Node = { name: string; className: string; filePaths?: string[]; children?: Node[] };

const ROOTS: [string[], string][] = [
	[["ReplicatedStorage", "Shared"], 'game:GetService("ReplicatedStorage")'],
	[["ServerScriptService", "Server"], 'game:GetService("ServerScriptService")'],
	[["StarterPlayer", "StarterPlayerScripts", "Client"], 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")'],
];

await $`rojo sourcemap default.project.json -o sourcemap.json`.quiet();
const map: Node = await Bun.file("sourcemap.json").json();

function find(path: string[]): Node {
	let node = map;
	for (const name of path) {
		const child = node.children?.find((c) => c.name === name);
		if (!child) throw new Error(`missing ${path.join(".")}`);
		node = child;
	}
	return node;
}

// A Luau long string that cannot be closed by the content.
function longString(text: string): string {
	let level = 1;
	while (text.includes(`]${"=".repeat(level)}]`)) level++;
	const eq = "=".repeat(level);
	return `[${eq}[\n${text}]${eq}]`;
}

async function emit(node: Node, parentVar: string, out: string[]) {
	// A table slot, not a local, because Luau allows only 200 locals in one function.
	const v = `N[${out.length}]`;
	out.push(`${v} = Instance.new(${JSON.stringify(node.className)})`);
	out.push(`${v}.Name = ${JSON.stringify(node.name)}`);
	const file = node.filePaths?.find((f) => /\.luau?$/.test(f));
	if (file && node.className !== "Folder") {
		out.push(`${v}.Source = ${longString(await Bun.file(file).text())}`);
	}
	for (const child of node.children ?? []) await emit(child, v, out);
	out.push(`${v}.Parent = ${parentVar}`);
}

const out: string[] = ["local N = {}"];
for (const [path, parentExpr] of ROOTS) {
	const node = find(path);
	const parent = `N[${out.length}]`;
	out.push(`${parent} = ${parentExpr}`);
	out.push(`do local old = ${parent}:FindFirstChild(${JSON.stringify(node.name)}) if old then old:Destroy() end end`);
	await emit(node, parent, out);
}
out.push(`return "pushed"`);

// Send the code on stdin: it is too long for a command-line argument.
const result = await $`bun tools/mcp.ts luau Edit < ${new Response(out.join("\n"))}`.text();
console.log(result.trim());
