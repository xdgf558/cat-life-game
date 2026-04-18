(function (game) {
  var format = game.utils.format;

  function renderCatChip(cat, selectedId) {
    var className = "cat-chip";
    if (cat.id === selectedId) {
      className += " is-selected";
    }
    if (!cat.unlocked) {
      className += " is-locked";
    }
    if (cat.isAlive === false) {
      className += " is-dead";
    }

    return (
      '<button class="' +
      className +
      '" data-select-cat="' +
      cat.id +
      '">' +
      '<div class="inline-row"><strong>' +
      format.escapeHtml(cat.name) +
      "</strong><span class=\"pill\">" +
      format.escapeHtml(cat.breed) +
      "</span></div>" +
      '<p class="page-copy" style="margin-top: 6px;">' +
      (cat.unlocked
        ? cat.isAlive === false
          ? "已死亡"
          : "已入住小家"
        : "后续版本预留解锁") +
      "</p>" +
      "</button>"
    );
  }

  function renderCountdownItem(cat, statKey, label, showDeathEta) {
    var nextDrop = game.systems.catSystem.getStatCountdown(cat, statKey);
    var deathEta = showDeathEta ? game.systems.catSystem.getHungerDeathEta(cat) : null;

    return (
      '<div class="notice-item"><p><strong>' +
      label +
      "</strong></p><p>下次下降：<span data-cat-stat-countdown data-cat-id=\"" +
      cat.id +
      '" data-cat-stat="' +
      statKey +
      '">' +
      (nextDrop === null ? "已停止" : format.formatDuration(nextDrop)) +
      "</span>" +
      (showDeathEta
        ? '<br />归零预计：<span data-cat-hunger-zero data-cat-id="' +
          cat.id +
          '">' +
          (deathEta === null ? "已死亡" : format.formatDuration(deathEta)) +
          "</span>"
        : "") +
      "</p></div>"
    );
  }

  function renderCatPanel(state) {
    var selectedCat =
      state.cats.find(function (cat) {
        return cat.id === game.state.selectedCatId && cat.unlocked;
      }) ||
      state.cats.find(function (cat) {
        return cat.unlocked;
      });
    var isDead = selectedCat.isAlive === false;

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">猫咪页面</p>' +
      '<h2 class="page-title">和猫咪一起把日常过得暖一点</h2>' +
      '<p class="page-copy">猫咪状态会按现实时间自动下降，其中饱腹下降最慢，但归零后猫咪会死亡。</p>' +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">互动说明</p>' +
      '<p class="page-copy">普通猫粮和猫砂会被消耗；逗猫棒属于长期道具，只要持有就会让陪玩更有效。</p>' +
      "</div>" +
      "</section>" +
      '<section class="cat-layout">' +
      '<div class="cat-list">' +
      state.cats
        .map(function (cat) {
          return renderCatChip(cat, selectedCat.id);
        })
        .join("") +
      "</div>" +
      '<div class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">当前照顾对象</p><h3 class="panel-title">' +
      format.escapeHtml(selectedCat.name) +
      " · " +
      format.escapeHtml(selectedCat.breed) +
      '</h3></div><span class="status-pill ' +
      (isDead ? "is-danger" : "is-success") +
      '">' +
      (isDead ? "已死亡" : "亲密度 " + selectedCat.intimacy + "/100") +
      "</span></div>" +
      (isDead
        ? '<div class="notice-item" style="margin-top: 14px;"><p><strong>死亡状态</strong></p><p>' +
          format.escapeHtml(selectedCat.name) +
          "因饱腹感归零而死亡，当前无法继续互动。</p></div>"
        : "") +
      '<div style="margin-top: 14px;">' +
      game.ui.helpers.renderBar("饱腹", selectedCat.hunger) +
      game.ui.helpers.renderBar("清洁", selectedCat.clean) +
      game.ui.helpers.renderBar("心情", selectedCat.mood) +
      game.ui.helpers.renderBar("健康", selectedCat.health) +
      game.ui.helpers.renderBar("活力", selectedCat.energy) +
      "</div>" +
      '<div class="inline-row" style="margin-top: 16px; flex-wrap: wrap;">' +
      '<button class="action-button" data-cat-action="feedBasic" ' +
      (isDead ? "disabled" : "") +
      '>喂普通猫粮</button>' +
      '<button class="secondary-button" data-cat-action="feedPremium" ' +
      (isDead ? "disabled" : "") +
      '>喂高级猫粮</button>' +
      '<button class="ghost-button" data-cat-action="clean" ' +
      (isDead ? "disabled" : "") +
      '>做清洁</button>' +
      '<button class="primary-button" data-cat-action="play" ' +
      (isDead ? "disabled" : "") +
      '>陪玩</button>' +
      '<button class="chip-button" data-cat-action="rest" ' +
      (isDead ? "disabled" : "") +
      '>休息</button>' +
      "</div>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>背包库存</strong></p><p>普通猫粮 ' +
      state.inventory.food +
      " / 高级猫粮 " +
      state.inventory.premiumFood +
      " / 猫砂 " +
      state.inventory.litter +
      " / 逗猫棒 " +
      state.inventory.toys +
      "</p></div>" +
      '<div class="notice-item"><p><strong>照顾建议</strong></p><p>饱腹下降最慢，但一旦归零就会死亡；记得优先补充食物。</p></div>' +
      renderCountdownItem(selectedCat, "hunger", "饱腹计时", true) +
      renderCountdownItem(selectedCat, "clean", "清洁计时", false) +
      renderCountdownItem(selectedCat, "mood", "心情计时", false) +
      renderCountdownItem(selectedCat, "health", "健康计时", false) +
      renderCountdownItem(selectedCat, "energy", "活力计时", false) +
      "</div>" +
      "</div>" +
      "</section>"
    );
  }

  game.ui.renderCatPanel = renderCatPanel;
})(window.CatGame);
