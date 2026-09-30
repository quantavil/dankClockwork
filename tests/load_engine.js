// Loads ClockworkEngine.js in Node. The file starts with QML's ".pragma library" directive,
// which is not valid JavaScript, so we strip it before evaluating (QML itself consumes it).
const fs = require("fs");
const path = require("path");
const Module = require("module");

module.exports = function loadEngine(file) {
  const target = file || path.join(__dirname, "..", "ClockworkEngine.js");
  const source = fs.readFileSync(target, "utf8").replace(/^\.pragma library\s*$/m, "");
  const engineModule = new Module(target, module);
  engineModule.filename = target;
  engineModule.paths = Module._nodeModulePaths(path.dirname(target));
  engineModule._compile(source, target);
  return engineModule.exports;
};
