#!/usr/bin/env bash
# Builds the throwaway repo the README demo is recorded in.
# Usage: .github/demo/setup.sh <dir>   (called by demo.tape; see README.md here)
set -euo pipefail

DEMO_DIR="${1:?usage: setup.sh <dir>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Only ever wipe a directory this script created.
if [ -e "$DEMO_DIR" ] && [ ! -f "$DEMO_DIR/.gitb-demo" ]; then
    echo "setup.sh: $DEMO_DIR exists and is not a gitb demo dir; refusing to delete it" >&2
    exit 1
fi
rm -rf "$DEMO_DIR"
mkdir -p "$DEMO_DIR/home" "$DEMO_DIR/bin"
touch "$DEMO_DIR/.gitb-demo"

# Isolated HOME: the demo must not read or write the recorder's git config.
export HOME="$DEMO_DIR/home"
git config --global user.name "Alex Doe"
git config --global user.email "alex@example.com"
git config --global init.defaultBranch main
git config --global gitbasher.completion.prompted true
git config --global advice.detachedHead false

version=$(node -p "require('$ROOT/package.json').version" 2>/dev/null || echo dev)
(cd "$ROOT" && ./dist/build.sh ./scripts/gitb.sh "$DEMO_DIR/bin/gitb" "$version") >/dev/null
chmod +x "$DEMO_DIR/bin/gitb"

# A real-looking remote URL on screen; git transparently rewrites it to a
# local bare repo, so push/pull/fetch work offline.
REMOTE_URL="https://github.com/alex/todo-app.git"
git init -q --bare "$DEMO_DIR/origin.git"
git config --global "url.$DEMO_DIR/origin.git.insteadOf" "$REMOTE_URL"
git clone -q "$REMOTE_URL" "$DEMO_DIR/todo-app" 2>/dev/null
cd "$DEMO_DIR/todo-app"
git config gitbasher.isfirst false
git config gitbasher.branch main
git config gitbasher.scopes "api ui"

mkdir -p api ui
cat > api/server.js <<'JS'
const express = require("express");
const app = express();
const todos = [];

app.get("/todos", (req, res) => res.json(todos));

app.listen(3000);
JS
cat > ui/app.js <<'JS'
export function renderTodos(todos) {
  return todos.map((t) => `<li>${t.title}</li>`).join("");
}
JS
printf '# todo-app\n\nA tiny todo list.\n' > README.md
git add -A && git commit -q -m "feat: initial todo app"
git push -q -u origin main 2>/dev/null

# Uncommitted work in two scopes, so gitb offers to split it into two commits.
cat > api/server.js <<'JS'
const express = require("express");
const app = express();
app.use(express.json());
const todos = [];

app.get("/todos", (req, res) => res.json(todos));

app.post("/todos", (req, res) => {
  const todo = { id: todos.length + 1, title: req.body.title, done: false };
  todos.push(todo);
  res.status(201).json(todo);
});

app.listen(3000);
JS
cat > ui/app.js <<'JS'
export function renderTodos(todos) {
  return todos
    .map((t) => `<li class="${t.done ? "done" : ""}">${t.title}</li>`)
    .join("");
}
JS

# Shell for the recording: isolated HOME, the fresh gitb first on PATH, a
# short prompt that shows the branch.
cat > "$DEMO_DIR/rc" <<RC
export HOME="$DEMO_DIR/home"
export PATH="$DEMO_DIR/bin:\$PATH"
cd "$DEMO_DIR/todo-app"
PS1='\[\e[1;36m\]todo-app\[\e[0m\] \[\e[35m\]\$(git branch --show-current)\[\e[0m\] \[\e[32m\]❯\[\e[0m\] '
RC
