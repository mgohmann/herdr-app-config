// ai.js: "Write message", a commit message drafted from the staged changes by
// whichever coding-agent CLI the person uses. dev-config addition: upstream
// Better Changes has no such feature. The CLI runs once, non-interactively, in
// a neutral folder (so it never reads the repository or edits files), and its
// reply only fills the message box; the person still presses Commit.
import { exec, panes, spaces, appHome, readTextFile, writeTextFile } from "herdr";
import { duration } from "./settings.js";

// Per harness: the program, the Herdr program keys that mean "this is the one
// in use", and how to ask it for one plain-text answer with no tools.
//   text: the whole prompt, as one argument (Windows allows ~32K per command line).
//   file: a path to a file holding the prompt, for programs launched through a
//         .cmd shim, where multi-line arguments are unreliable.
export const HARNESSES = {
  claude: {
    label: "Claude Code",
    command: "claude",
    keys: ["claude", "claude-code"],
    args: ({ model, effort, text }) => [
      "-p",
      "--tools",
      "",
      "--no-session-persistence",
      "--setting-sources",
      "",
      "--output-format",
      "text",
      "--model",
      model,
      "--effort",
      effort,
      text,
    ],
  },
  antigravity: {
    label: "Antigravity",
    command: "agy",
    keys: ["antigravity", "agy"],
    // agy's model ids carry the effort: gemini-4-hydrogen-low.
    args: ({ model, effort, text }) => [
      "-p",
      text,
      "--model",
      /-(low|medium|high|xhigh)$/.test(model) ? model : `${model}-${effort}`,
      "--mode",
      "plan",
      "--output-format",
      "text",
    ],
  },
  copilot: {
    label: "Copilot",
    command: "copilot",
    keys: ["copilot"],
    // --available-tools is variadic, so it goes last.
    args: ({ model, effort, text }) => [
      "-p",
      text,
      "-s",
      "--model",
      model,
      "--reasoning-effort",
      effort,
      "--no-ask-user",
      "--no-custom-instructions",
      "--disable-builtin-mcps",
      "--available-tools",
      "",
    ],
  },
  opencode: {
    label: "OpenCode",
    command: "opencode",
    keys: ["opencode"],
    needsFile: true,
    // "plan" is OpenCode's read-only agent; `#effort` picks the model variant.
    args: ({ model, effort, file }) => [
      "run",
      "-m",
      `${model}#${effort}`,
      "--agent",
      "plan",
      "-f",
      file,
      "Follow the instructions in the attached file and reply with the commit message only.",
    ],
  },
};
const ORDER = ["claude", "antigravity", "copilot", "opencode"];
const EXAMPLES = 8;
const EXAMPLE_LIMIT = 600;

// Which harnesses to try, best first: the one running in this tab (the focused
// pane's first), then the configured one, then the rest in a fixed order.
export function harnessOrder(configured, tabPanes) {
  const seen = [];
  const add = (id) => id && HARNESSES[id] && !seen.includes(id) && seen.push(id);
  if (configured && configured !== "auto") {
    add(configured);
    return seen; // An explicit choice is not second-guessed.
  }
  const inTab = [...tabPanes].sort((a, b) => Number(b.focused) - Number(a.focused));
  for (const pane of inTab) {
    const key = pane.program?.key ?? pane.app;
    add(ORDER.find((id) => HARNESSES[id].keys.includes(key) || HARNESSES[id].keys.includes(pane.app)));
  }
  for (const id of ORDER) add(id);
  return seen;
}

export function aiPrompt({ branch, stat, diff, truncated, examples }) {
  return [
    "Write a git commit message for the staged changes below.",
    "Reply with the commit message only: no quotes, no code fence, no explanation.",
    "Subject line: at most 72 characters, imperative mood, no trailing period.",
    examples.length
      ? "Copy the prefix style, language and body habits of the recent commits shown."
      : "Use Conventional Commits, in English.",
    "Add a short body only when the why is not obvious; explain what and why, not file lists. Wrap the body at 72 columns.",
    "Do not add Co-Authored-By, Signed-off-by or 'Generated with' lines.",
    "",
    `Branch: ${branch || "(detached)"}`,
    examples.length ? `Recent commit messages:\n${examples.map((e) => `---\n${e}`).join("\n")}\n---` : "",
    "",
    `Changed files:\n${stat.trim() || "(none)"}`,
    "",
    truncated ? `Staged diff (first ${truncated} characters):` : "Staged diff:",
    diff,
  ]
    .filter((line, i, all) => line !== "" || all[i - 1] !== "")
    .join("\n");
}

// Tidy an agent's reply into a commit message.
export function cleanMessage(raw) {
  let text = String(raw ?? "")
    .replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "") // colour codes
    .replace(/\r/g, "");
  const lines = text.split("\n");
  // OpenCode prints a "> agent · model" banner first.
  while (lines.length && (/^\s*$/.test(lines[0]) || /^>\s+\S+\s+·\s+/.test(lines[0]))) lines.shift();
  text = lines
    .filter((l) => !/^\s*```/.test(l))
    .filter((l) => !/^\s*(Co-Authored-By|Signed-off-by):/i.test(l))
    .filter((l) => !/generated (with|by)/i.test(l))
    .join("\n")
    .replace(/^\s*(commit message|subject)\s*:\s*/i, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  const quoted = /^(["'`])([\s\S]*)\1$/.exec(text);
  return (quoted ? quoted[2] : text).trim();
}

async function writePromptFile(text) {
  const path = `${appHome()}/data/better-changes/commit-prompt.txt`;
  const existing = await readTextFile(path).catch(() => null);
  await writeTextFile(path, text, existing);
  return path;
}

export const aiMethods = {
  canWriteMessage() {
    return Boolean(
      this.input &&
        this.root &&
        this.commitMode === "commit" &&
        this.stagedCount &&
        !this.conflicts &&
        !this.busy &&
        !this.loading &&
        !this.aiBusy &&
        this.contextKey() === this.context,
    );
  },

  writeMessage(cx) {
    if (!this.canWriteMessage()) return;
    const { root, on, context } = this;
    const revision = this.messageRevision;
    // Only an empty box, or one still holding the last AI draft, may be replaced.
    const replaceable = !this.message.trim() || this.message === this.aiDraft;
    const ai = this.settings.ai;
    this.aiBusy = true;
    this.note = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const [stat, diff, log, branch] = await Promise.all([
          this.git(["diff", "--cached", "--no-color", "--stat=80"], root, on),
          this.git(["diff", "--cached", "--no-color", "--no-ext-diff", "--no-textconv"], root, on),
          this.git(["log", "--no-merges", "-n", String(EXAMPLES), "--format=%B%x1e"], root, on),
          this.git(["symbolic-ref", "-q", "--short", "HEAD"], root, on),
        ]);
        if (diff.code !== 0) throw Error((diff.stderr || diff.stdout).trim() || "git diff failed");
        const limit = Math.max(1000, ai.diff_limit);
        const examples = log.code === 0
          ? log.stdout.split("\x1e").map((m) => m.trim().slice(0, EXAMPLE_LIMIT)).filter(Boolean)
          : [];
        const text = aiPrompt({
          branch: branch.stdout.trim(),
          stat: stat.stdout,
          diff: diff.stdout.slice(0, limit),
          truncated: diff.stdout.length > limit ? limit : 0,
          examples,
        });

        const space = spaces().find((s) => s.active);
        const tab = space?.tabs?.find((t) => t.active)?.id;
        const order = harnessOrder(
          ai.harness,
          panes().filter((p) => p.tab === tab && p.terminal),
        );
        const cwd = `${appHome()}/data/better-changes`;
        let file = null;
        let message = "";
        let lastError = "";
        const timeout = Math.min(600000, duration(ai.timeout, 90000));
        for (const id of order) {
          const harness = HARNESSES[id];
          const model = ai[`${id}_model`];
          let result;
          try {
            if (harness.needsFile && !file) file = await writePromptFile(text);
            result = await exec(harness.command, harness.args({ model, effort: ai.effort, text, file }), {
              cwd,
              timeout,
            });
          } catch (error) {
            lastError = `${harness.label} could not start (${error.message}).`;
            continue; // Not installed: try the next harness.
          }
          message = cleanMessage(result.stdout);
          if (result.code === 0 && message) {
            lastError = "";
            break;
          }
          lastError = `${harness.label} failed: ${(result.stderr || result.stdout).trim().split("\n")[0] || `exit ${result.code}`}`;
          message = "";
          if (ai.harness !== "auto") break;
        }
        if (!message) throw Error(lastError || "No coding agent answered.");

        if (!this.isCurrent(context)) return;
        if (replaceable && this.messageRevision === revision) {
          this.message = message;
          this.aiDraft = message;
          this.input.set_value(message);
        } else this.note = "Kept the message you typed; clear the box to use a new draft.";
      } catch (error) {
        if (this.isCurrent(context)) this.note = `Write commit message failed: ${error.message}`;
      } finally {
        this.aiBusy = false;
        cx.notify();
      }
    });
  },
};
