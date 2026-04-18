(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

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
      format.escapeHtml(getText(cat, "name")) +
      "</strong><span class=\"pill\">" +
      format.escapeHtml(getText(cat, "breed")) +
      "</span></div>" +
      '<p class="page-copy" style="margin-top: 6px;">' +
      (cat.unlocked
        ? cat.isAlive === false
          ? t("dead_label")
          : t("alive_at_home")
        : t("later_unlock")) +
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
    var catVisual = game.systems.catSystem.getCatVisualState(selectedCat);

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("page_cats") + "</p>" +
      '<h2 class="page-title">' + t("cats_panel_title") + "</h2>" +
      '<p class="page-copy">' + t("cats_panel_copy") + "</p>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("interaction_info") + "</p>" +
      '<p class="page-copy">' + t("cat_interaction_copy") + "</p>" +
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
      '<div class="inline-row"><div><p class="section-eyebrow">' + t("current_cat") + '</p><h3 class="panel-title">' +
      format.escapeHtml(getText(selectedCat, "name")) +
      " · " +
      format.escapeHtml(getText(selectedCat, "breed")) +
      '</h3></div><span class="status-pill ' +
      (isDead ? "is-danger" : "is-success") +
      '">' +
      (isDead ? t("dead_label") : t("friendship_health", { intimacy: selectedCat.intimacy, health: selectedCat.health })) +
      "</span></div>" +
      '<div class="cat-portrait" style="margin-top: 14px;"><div class="cat-portrait-icon">' +
      catVisual.icon +
      '</div><div><p class="mini-label">' + t("cat_portrait") + '</p><p class="page-copy">' + t(catVisual.labelKey) + "</p></div></div>" +
      (isDead
        ? '<div class="notice-item" style="margin-top: 14px;"><p><strong>' + t("death_state") + '</strong></p><p>' +
          t("death_desc", { name: getText(selectedCat, "name") }) +
          '</p><p style="margin-top:8px;"><button class="secondary-button" data-readopt-cat="' +
          selectedCat.id +
          '">' +
          t("readopt_action") +
          "</button></p><p class=\"helper-text\" style=\"margin-top:8px;\">" +
          t("readopt_cost", { cost: game.config.readoptCost }) +
          "</p></div>"
        : "") +
      '<div style="margin-top: 14px;">' +
      game.ui.helpers.renderBar(t("hunger_label"), selectedCat.hunger) +
      game.ui.helpers.renderBar(t("clean_label"), selectedCat.clean) +
      game.ui.helpers.renderBar(t("mood_label"), selectedCat.mood) +
      game.ui.helpers.renderBar(t("health_label"), selectedCat.health) +
      game.ui.helpers.renderBar(t("energy_label"), selectedCat.energy) +
      "</div>" +
      '<div class="inline-row" style="margin-top: 16px; flex-wrap: wrap;">' +
      '<button class="action-button" data-cat-action="feedBasic" ' +
      (isDead ? "disabled" : "") +
      '>' + t("feed_basic") + "</button>" +
      '<button class="secondary-button" data-cat-action="feedPremium" ' +
      (isDead ? "disabled" : "") +
      '>' + t("feed_premium") + "</button>" +
      '<button class="ghost-button" data-cat-action="clean" ' +
      (isDead ? "disabled" : "") +
      '>' + t("clean_action") + "</button>" +
      '<button class="primary-button" data-cat-action="play" ' +
      (isDead ? "disabled" : "") +
      '>' + t("play_action") + "</button>" +
      '<button class="chip-button" data-cat-action="rest" ' +
      (isDead ? "disabled" : "") +
      '>' + t("rest_action") + "</button>" +
      "</div>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>' + t("bag_inventory") + "</strong></p><p>🥣 " +
      state.inventory.food +
      " / 🍗 " +
      state.inventory.premiumFood +
      " / 🧺 " +
      state.inventory.litter +
      " / 🪶 " +
      state.inventory.toys +
      "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("care_tips") + "</strong></p><p>" + t("care_tips_copy") + "</p></div>" +
      renderCountdownItem(selectedCat, "hunger", t("hunger_next_drop"), true) +
      renderCountdownItem(selectedCat, "clean", t("clean_label"), false) +
      renderCountdownItem(selectedCat, "mood", t("mood_label"), false) +
      renderCountdownItem(selectedCat, "health", t("health_label"), false) +
      renderCountdownItem(selectedCat, "energy", t("energy_label"), false) +
      "</div>" +
      "</div>" +
      "</section>"
    );
  }

  game.ui.renderCatPanel = renderCatPanel;
})(window.CatGame);
