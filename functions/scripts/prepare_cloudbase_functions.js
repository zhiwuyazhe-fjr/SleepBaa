const fs = require("node:fs");
const path = require("node:path");

const rootDir = path.resolve(__dirname, "..");
const sourceLibDir = path.join(rootDir, "lib");
const targets = [
  path.join(rootDir, "app-api", "lib"),
  path.join(rootDir, "on-sleep-session-write", "lib"),
  path.join(rootDir, "on-dream-entry-write", "lib"),
];
const httpFunctionDirs = [path.join(rootDir, "app-api")];
const httpBootstrapContent =
  "#!/bin/sh\n" +
  'cd "$(dirname "$0")"\n' +
  "exec /var/lang/node18/bin/node index.js\n";

if (!fs.existsSync(sourceLibDir)) {
  throw new Error(`Compiled lib directory not found: ${sourceLibDir}`);
}

for (const target of targets) {
  fs.rmSync(target, { recursive: true, force: true });
  fs.cpSync(sourceLibDir, target, { recursive: true });
  process.stdout.write(`Synced ${sourceLibDir} -> ${target}\n`);
}

for (const dir of httpFunctionDirs) {
  const bootstrapPath = path.join(dir, "scf_bootstrap");
  fs.writeFileSync(bootstrapPath, httpBootstrapContent, "utf8");
  try {
    fs.chmodSync(bootstrapPath, 0o755);
  } catch (error) {
    process.stdout.write(
      `Skipped chmod for ${bootstrapPath}: ${String(error)}\n`,
    );
  }
  process.stdout.write(`Normalized ${bootstrapPath}\n`);
}
