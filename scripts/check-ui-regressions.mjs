import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const main = read("src/js/main.js");
const index = read("index.html");
const navigation = read("src/js/ui/renderNavigation.js");
const more = read("src/js/ui/renderMorePanel.js");

assert.doesNotMatch(index, /app-quick/, "the removed quick panel must not remain in the shell");
assert.doesNotMatch(main, /renderQuickPanel|dom\.quick/, "quick panel dead code must stay removed");
assert.match(navigation, /pages: \["version", "save", "settings"\]/, "desktop navigation must expose version notes");
assert.match(more, /page: "version"/, "mobile More must expose version notes");
assert.match(main, /if \(activeToastId !== null\) \{\s*return;/, "an active toast must not be rewritten");
assert.match(main, /queuedNotice\.id !== notice\.id/, "dismissed toasts must be consumed");

const context = vm.createContext({
  console,
  Date,
  Math,
  Intl,
  setTimeout,
  clearTimeout,
  window: {
    addEventListener() {},
  },
});
context.window.window = context.window;

for (const file of [
  "src/js/core/namespace.js",
  "src/js/core/i18n.js",
  "src/js/utils/format.js",
]) {
  vm.runInContext(read(file), context, { filename: file });
}

const game = context.window.CatGame;
game.state.game = { settings: { language: "en" } };
game.data.jobMap = {};
game.ui.helpers = {
  renderTaskBadge() { return ""; },
};
game.utils.catArt = {
  buildCatSvg() { return "cat.svg"; },
};
game.systems.catSystem = {
  getCatDisease() { return null; },
};
let playerHunger = 79;
game.systems.playerSystem = {
  getCurrentHunger() { return playerHunger; },
};
game.systems.homeSystem = {
  getPlacedFurniture() { return []; },
};
game.systems.workSystem = {
  getRemainingMs() { return 0; },
};

vm.runInContext(read("src/js/ui/renderHome.js"), context, { filename: "src/js/ui/renderHome.js" });

const baseState = {
  player: { activeWork: null },
  cats: [{
    id: "cat_001",
    name: '<img src=x onerror="alert(1)">',
    nameEn: '<img src=x onerror="alert(1)">',
    unlocked: true,
    isAlive: true,
    hunger: 90,
    clean: 90,
    health: 100,
  }],
  inventory: { food: 0, litter: 0, toys: 0 },
  tasks: { daily: [] },
  home: { comfortScore: 0 },
};

let html = game.ui.renderHome(baseState);
assert.doesNotMatch(html, /<img src=x onerror=/, "player-provided cat names must not create markup");
assert.match(html, /&lt;img src=x onerror=/, "player-provided cat names must be escaped");

const hungryCatState = structuredClone(baseState);
hungryCatState.cats[0].name = "Mochi";
hungryCatState.cats[0].nameEn = "Mochi";
hungryCatState.cats[0].hunger = 20;
html = game.ui.renderHome(hungryCatState);
assert.match(html, /data-page-target="shop"[^>]*>Buy cat food</, "missing cat food must lead to the shop");
assert.doesNotMatch(html, /data-cat-action="feedBasic"[^>]*disabled/, "missing supplies must not leave a dead action");

const healthyState = structuredClone(baseState);
healthyState.cats[0].name = "Mochi";
healthyState.cats[0].nameEn = "Mochi";
healthyState.cats[0].hunger = 90;
playerHunger = game.config.playerCondition.hungerBlockThreshold - 1;
html = game.ui.renderHome(healthyState);
assert.match(html, />Find work</, "hunger warning must use the configured block threshold");
playerHunger = game.config.playerCondition.hungerBlockThreshold;
html = game.ui.renderHome(healthyState);
assert.match(html, />Buy food</, "the configured hunger threshold must trigger the shop action");

game.systems.playerSystem = {
  getCurrentHunger() { return 20; },
  getDisplayStats() { return { stamina: 45, mood: 70 }; },
  getActiveSleep() { return { startedAt: new Date().toISOString() }; },
  getSleepRecovery() { return { elapsedMs: 5000, staminaGain: 1, moodGain: 1 }; },
};
vm.runInContext(read("src/js/ui/renderHeader.js"), context, { filename: "src/js/ui/renderHeader.js" });
html = game.ui.renderHeader({
  player: { activeWork: null, currentDay: 2, gold: 120 },
});
assert.match(html, /data-player-sleep[^>]*>Wake Up</, "sleeping saves must always render a wake action");
assert.match(html, /data-player-stamina-live/, "header stamina must expose a live binding");
assert.match(html, /data-player-mood-live/, "header mood must expose a live binding");
assert.match(html, /data-player-hunger-live/, "header hunger must expose a live binding");
assert.doesNotMatch(html, /¥/, "the header must use the localized game currency unit");

console.log("UI regression checks passed.");
