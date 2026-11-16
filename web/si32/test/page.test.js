// SPDX-License-Identifier: MIT
// index.html is self-contained (it inlines the core and the demo programs so
// it also works from file://). This test keeps the inlined copies identical
// to si32-core.js / programs.js, which the Node tests load, and parses the
// page's app script so a syntax error cannot ship.
"use strict";
const fs = require("fs"), path = require("path"), vm = require("vm");
const dir = path.join(__dirname, "..");
const html = fs.readFileSync(path.join(dir, "index.html"), "utf8");
const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1].replace(/^\n+/, ""));
if (blocks.length !== 3) throw new Error(`expected 3 inline scripts, found ${blocks.length}`);
const want = [["si32-core.js", 0], ["programs.js", 1]];
for (const [f, i] of want) {
  if (fs.readFileSync(path.join(dir, f), "utf8") !== blocks[i]) throw new Error(`index.html inline script ${i} differs from ${f}`);
}
new vm.Script(blocks[2], { filename: "index.html#app" });
console.log("PASS page: inline core and programs match the tested files; app script parses");
