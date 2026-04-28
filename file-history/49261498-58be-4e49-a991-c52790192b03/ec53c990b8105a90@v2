'use strict';
// Token Domain: CommandRewriter service.
// Contract: read PreToolUse JSON from stdin, output modified_input if rewrite needed.
// Empty stdout = passthrough. Fail-safe: any error → process.exit(0) → passthrough.

const EXEMPT = new Set([
  'echo','printf','pwd','whoami','cd','pushd','popd','source','.','export',
  'unset','set','env','true','false','exit','return','break','continue',
  '[','test','if','while','for','do','done','fi','then','else','elif',
  'case','esac','function','read','wait','sleep','kill','exec','eval',
  'mkdir','rmdir','rm','mv','cp','touch','chmod','chown','type','which','where',
]);

function processSegment(seg) {
  const trimmed = seg.trim();
  if (!trimmed) return seg;
  if (trimmed.startsWith('RTK_DISABLED=1')) return seg;           // bypass env
  let prefix = '', rest = trimmed;
  const m = rest.match(/^([A-Z_][A-Z0-9_]*=[^\s]*\s+)*/i);
  if (m && m[0]) { prefix = m[0]; rest = rest.slice(prefix.length).trim(); }
  if (!rest) return seg;
  if (rest.startsWith('rtk ') || rest === 'rtk') return seg;      // already prefixed
  const cmdWord = rest.split(/\s+/)[0].replace(/^[!-]+/, '');
  if (EXEMPT.has(cmdWord) || '({)}'.includes(cmdWord)) return seg; // shell builtin
  const leading  = seg.match(/^\s*/)[0];
  const trailing = seg.match(/\s*$/)[0];
  return leading + prefix + 'rtk ' + rest + trailing;
}

function splitByLogicalOps(cmd) {
  const tokens = []; let cur = '', i = 0;
  while (i < cmd.length) {
    const ch = cmd[i];
    if (ch === "'") {
      let j = i + 1;
      while (j < cmd.length && cmd[j] !== "'") j++;
      cur += cmd.slice(i, j + 1); i = j + 1; continue;
    }
    if (ch === '"') {
      let j = i + 1;
      while (j < cmd.length && cmd[j] !== '"') { if (cmd[j] === '\\') j++; j++; }
      cur += cmd.slice(i, j + 1); i = j + 1; continue;
    }
    if (ch === '`') {
      let j = i + 1;
      while (j < cmd.length && cmd[j] !== '`') j++;
      cur += cmd.slice(i, j + 1); i = j + 1; continue;
    }
    if (ch === '$' && cmd[i + 1] === '(') {
      let d = 0, j = i;
      while (j < cmd.length) {
        if (cmd[j] === '(') d++;
        else if (cmd[j] === ')') { d--; if (!d) { j++; break; } }
        j++;
      }
      cur += cmd.slice(i, j); i = j; continue;
    }
    if (ch === '&' && cmd[i + 1] === '&') { tokens.push({ text: cur, sep: '&&' }); cur = ''; i += 2; continue; }
    if (ch === '|' && cmd[i + 1] === '|') { tokens.push({ text: cur, sep: '||' }); cur = ''; i += 2; continue; }
    if (ch === '|') { cur += ch; i++; continue; }   // pipe: NOT split (continuation)
    if (ch === ';') { tokens.push({ text: cur, sep: ';'  }); cur = ''; i++;    continue; }
    cur += ch; i++;
  }
  tokens.push({ text: cur, sep: '' });
  return tokens;
}

function rewriteCommand(cmd) {
  const tokens = splitByLogicalOps(cmd);
  let changed = false;
  const out = tokens.map(({ text, sep }) => {
    const n = processSegment(text);
    if (n !== text) changed = true;
    return { text: n, sep };
  });
  return changed ? out.map(({ text, sep }) => text + sep).join('') : null;
}

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', c => { input += c; });
process.stdin.on('end', () => {
  try {
    const p = JSON.parse(input);
    if (p.tool_name !== 'Bash') process.exit(0);
    const cmd = (p.tool_input && p.tool_input.command) || '';
    if (!cmd) process.exit(0);
    const rw = rewriteCommand(cmd);
    if (rw !== null) process.stdout.write(JSON.stringify({ modified_input: { command: rw } }));
    process.exit(0);
  } catch (_) { process.exit(0); }
});
