const fs = require("node:fs");
const path = require("node:path");

const rootDir = path.resolve(__dirname, "..");
const sourceLibDir = path.join(rootDir, "lib");
const targets = [
  path.join(rootDir, "app-api", "lib"),
  path.join(rootDir, "on-sleep-session-write", "lib"),
  path.join(rootDir, "on-dream-entry-write", "lib"),
];

if (!fs.existsSync(sourceLibDir)) {
  throw new Error(`Compiled lib directory not found: ${sourceLibDir}`);
}

for (const target of targets) {
  fs.rmSync(target, { recursive: true, force: true });
  fs.cpSync(sourceLibDir, target, { recursive: true });
  process.stdout.write(`Synced ${sourceLibDir} -> ${target}\n`);
}
