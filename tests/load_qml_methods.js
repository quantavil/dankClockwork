// Execute the JavaScript bodies shipped in QML, not a second implementation.
// Qt property bindings, rendering and native processes require runtime verification.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

module.exports = function loadMethods(file, context, sourceOverride) {
  const source = sourceOverride ?? fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  const methods = {};
  const pattern = /\bfunction\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*\w+)?\s*\{/g;
  let match;
  while ((match = pattern.exec(source))) {
    let depth = 1;
    let cursor = pattern.lastIndex;
    let quote = null;
    let comment = null;
    for (; depth && cursor < source.length; cursor++) {
      const ch = source[cursor], next = source[cursor + 1];
      if (comment === 'line') { if (ch === '\n') comment = null; continue; }
      if (comment === 'block') { if (ch === '*' && next === '/') { comment = null; cursor++; } continue; }
      if (quote) { if (ch === '\\') cursor++; else if (ch === quote) quote = null; continue; }
      if (ch === '/' && next === '/') { comment = 'line'; cursor++; continue; }
      if (ch === '/' && next === '*') { comment = 'block'; cursor++; continue; }
      if (ch === '"' || ch === "'" || ch === '`') { quote = ch; continue; }
      if (ch === '{') depth++;
      if (ch === '}') depth--;
    }
    if (depth) throw new Error('Unterminated QML method: ' + match[1]);
    const args = match[2].replace(/:\s*\w+/g, '');
    const body = source.slice(pattern.lastIndex, cursor - 1);
    methods[match[1]] = vm.runInNewContext('(function(' + args + '){' + body + '})', context,
      { filename: file + ':' + match[1] });
    pattern.lastIndex = cursor;
  }
  return methods;
};
