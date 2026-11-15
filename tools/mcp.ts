// Minimal stdio client for Roblox StudioMCP.
// Set STUDIO_MCP to the path of the Studio MCP server binary if it is not in the default place.
// Usage: bun tools/mcp.ts list
//        bun tools/mcp.ts call <tool> '<json args>'   (studio_id defaults to the first open Studio)
// With several Studios open, set STUDIO to a part of the place name to pick one (STUDIO=UI).
//        bun tools/mcp.ts luau <Edit|Client|Server> < code.luau   (runs code from stdin)
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";

let [cmd, tool, rawArgs] = Bun.argv.slice(2);
if (cmd === "luau") {
	rawArgs = JSON.stringify({ code: await Bun.stdin.text(), datamodel_type: tool });
	[cmd, tool] = ["call", "execute_luau"];
}
const server = process.env.STUDIO_MCP ?? join(homedir(), ".codex", "bin", "roblox-studio-mcp");
const proc = Bun.spawn([server], { stdin: "pipe", stdout: "pipe", stderr: "inherit" });
const send = (msg: object) => { proc.stdin.write(JSON.stringify(msg) + "\n"); proc.stdin.flush(); };
const reader = proc.stdout.getReader();
let buf = "";
async function next(id: number): Promise<any> {
	for (;;) {
		const nl = buf.indexOf("\n");
		if (nl >= 0) {
			const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
			if (!line.trim()) continue;
			const msg = JSON.parse(line);
			if (msg.id === id) return msg;
			continue;
		}
		const { value, done } = await reader.read();
		if (done) throw new Error("server closed");
		buf += new TextDecoder().decode(value);
	}
}
send({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "cli", version: "1" } } });
await next(1);
send({ jsonrpc: "2.0", method: "notifications/initialized" });
if (cmd === "list") {
	send({ jsonrpc: "2.0", id: 2, method: "tools/list" });
	const r = await next(2);
	for (const t of r.result.tools) console.log(`## ${t.name}\n${t.description}\n${JSON.stringify(t.inputSchema.properties)}\n`);
} else {
	const args = JSON.parse(rawArgs ?? "{}");
	// Fill in the Studio named by STUDIO, or else the first open one, when the caller does not name one.
	if (tool !== "list_roblox_studios" && !args.studio_id) {
		// A fresh server lists no Studios until it has connected, so ask again for a few seconds.
		let list: { studios: { id: string; name: string | null }[] } = { studios: [] };
		for (let attempt = 0; attempt < 10 && list.studios.length === 0; attempt++) {
			if (attempt > 0) await Bun.sleep(1000);
			send({ jsonrpc: "2.0", id: 3 + attempt * 100, method: "tools/call", params: { name: "list_roblox_studios", arguments: {} } });
			list = JSON.parse((await next(3 + attempt * 100)).result.content[0].text);
		}
		const want = process.env.STUDIO;
		const studio = want ? list.studios.find((s) => s.name?.includes(want)) : list.studios[0];
		if (want && !studio) throw new Error(`no open Studio has "${want}" in its name`);
		args.studio_id = studio?.id;
	}
	// A fresh server needs a moment to connect to Studio, so retry while it reports no connection.
	let r: any;
	for (let attempt = 0; attempt < 10; attempt++) {
		const id = 10 + attempt;
		send({ jsonrpc: "2.0", id, method: "tools/call", params: { name: tool, arguments: args } });
		r = await next(id);
		const text = r.result?.content?.[0]?.text ?? "";
		if (!String(text).includes("No Roblox Studio instances are connected")) break;
		await Bun.sleep(1500);
	}
	for (const c of r.result?.content ?? []) {
		if (c.type === "text") console.log(c.text);
		else if (c.type === "image") { const f = join(tmpdir(), `studio-${Date.now()}.png`); await Bun.write(f, Buffer.from(c.data, "base64")); console.log(`[image] ${f}`); }
	}
	if (r.error) console.log("ERROR", JSON.stringify(r.error));
}
proc.kill();
process.exit(0);
