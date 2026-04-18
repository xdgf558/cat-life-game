(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function renderHome(state) {
    var isNewVersion = state.meta.lastSeenVersion !== game.config.version;
    var selectedCat =
      state.cats.find(function (cat) {
        return cat.id === game.state.selectedCatId && cat.unlocked;
      }) ||
      state.cats.find(function (cat) {
        return cat.unlocked;
      });
    var activeWork = state.player.activeWork;

    var dailyCards = state.tasks.daily
      .map(function (task) {
        return game.ui.helpers.renderTaskBadge(task.title, task.progress, task.target);
      })
      .join("");

    var furnitureList = game.systems.homeSystem
      .getPlacedFurniture()
      .map(function (item) {
        return '<span class="status-pill">' + format.escapeHtml(item.name) + "</span>";
      })
      .join(" ");
    var selectedCatDead = selectedCat.isAlive === false;
    var catVisual = game.systems.catSystem.getCatVisualState(selectedCat);
    var catDisease = game.systems.catSystem.getCatDisease(selectedCat);
    var sickCount = game.systems.hospitalSystem.getSickCats().length;
    var activeJob = activeWork ? game.data.jobMap[activeWork.jobId] || activeWork : null;

    var releaseNotes = (game.config.releaseNotes[game.utils.i18n.getLanguage()] || game.config.releaseNotes["zh-CN"])
      .map(function (note) {
        return "<p>• " + format.escapeHtml(note) + "</p>";
      })
      .join("");

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("page_home") + "</p>" +
      '<h2 class="page-title">' + t("home_panel_title") + "</h2>" +
      '<p class="page-copy">' + t("home_panel_copy") + "</p>" +
      '<div class="inline-row" style="margin-top:18px; flex-wrap: wrap;">' +
      '<button class="primary-button" data-page-target="work">' + t("nav_work") + "</button>" +
      '<button class="secondary-button" data-page-target="cats">' + t("nav_cats") + "</button>" +
      '<button class="secondary-button" data-page-target="hospital">' + t("nav_hospital") + "</button>" +
      '<button class="ghost-button" data-page-target="shop">' + t("nav_shop") + "</button>" +
      "</div>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' +
      (isNewVersion ? t("release_update") : t("release_current")) +
      "</p>" +
      '<h3 class="panel-title">v' +
      format.escapeHtml(game.config.version) +
      (isNewVersion ? " " + t("release_updated") : " " + t("release_content")) +
      "</h3>" +
      '<div class="helper-text" style="margin-top: 10px;">' +
      releaseNotes +
      "</div>" +
      (isNewVersion
        ? '<div class="inline-row" style="margin-top: 16px;"><span class="status-pill is-warning">' + t("release_update") + '</span><button class="secondary-button" data-dismiss-release-note>' + t("release_ack") + "</button></div>"
        : "") +
      "</div>" +
      "</section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("todays_focus") + "</p>" +
      '<p class="page-copy">' + t("today_task_reward") + "</p>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      dailyCards +
      "</div>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("current_work") + "</p>" +
      (activeWork
        ? '<h3 class="panel-title">' +
          format.escapeHtml(getText(activeJob, "name")) +
          '</h3><p class="page-copy">' + t("expected_finish") + '：' +
          format.escapeHtml(format.formatRealDateTime(activeWork.endsAt)) +
          '</p><p class="helper-text" style="margin-top: 10px;">' + t("remaining") + '：<span data-active-work-remaining>' +
          format.formatDuration(game.systems.workSystem.getRemainingMs(activeWork)) +
          "</span></p>"
        : '<h3 class="panel-title">' + t("idle_now") + '</h3><p class="page-copy">' + t("start_realtime_work") + "</p>") +
      "</div>" +
      "</section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("cat_overview") + "</p>" +
      '<div class="cat-portrait">' +
      '<div class="cat-portrait-icon">' + catVisual.icon + '</div><div><p class="mini-label">' + t("cat_portrait") + '</p><p class="page-copy">' + t(catVisual.labelKey) + "</p></div></div>" +
      '<h3 class="panel-title">' +
      format.escapeHtml(getText(selectedCat, "name")) +
      " · " +
      format.escapeHtml(getText(selectedCat, "breed")) +
      "</h3>" +
      '<p class="page-copy">' +
      (selectedCatDead
        ? t("status_dead")
        : t("friendship_health", { intimacy: selectedCat.intimacy, health: selectedCat.health })) +
      "</p>" +
      '<p class="helper-text" style="margin-top: 8px;">' +
      t("age_label") + "：" +
      format.escapeHtml(format.formatAgeYears(game.systems.catSystem.getCatAgeYears(selectedCat))) +
      (catDisease
        ? " · " + t("disease_label") + "：" + format.escapeHtml(getText(catDisease, "name"))
        : " · " + t("disease_none")) +
      "</p>" +
      '<div style="margin-top: 14px;">' +
      game.ui.helpers.renderBar(t("hunger_label"), selectedCat.hunger) +
      game.ui.helpers.renderBar(t("clean_label"), selectedCat.clean) +
      game.ui.helpers.renderBar(t("mood_label"), selectedCat.mood) +
      game.ui.helpers.renderBar(t("energy_label"), selectedCat.energy) +
      "</div>" +
      '<p class="helper-text" style="margin-top: 10px;">' +
      (selectedCatDead
        ? t("cat_unavailable")
        : t("hunger_next_drop") + '：<span data-cat-stat-countdown data-cat-id="' +
          selectedCat.id +
          '" data-cat-stat="hunger">' +
          format.formatDuration(game.systems.catSystem.getStatCountdown(selectedCat, "hunger")) +
          '</span>，' + t("hunger_zero_eta") + '：<span data-cat-hunger-zero data-cat-id="' +
          selectedCat.id +
          '">' +
          format.formatDuration(game.systems.catSystem.getHungerDeathEta(selectedCat)) +
          "</span>") +
      "</p>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("home_status") + "</p>" +
      '<h3 class="panel-title">' + t("living_room") + "</h3>" +
      '<p class="page-copy">' + t("comfort_now", { value: state.home.comfortScore }) + "</p>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>' + t("placed_furniture") + "</strong></p><p>" +
      (furnitureList || "暂无") +
      "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("inventory_overview") + "</strong></p><p>🥣 " +
      state.inventory.food +
      " / 🍗 " +
      state.inventory.premiumFood +
      " / 🧺 " +
      state.inventory.litter +
      " / 🪶 " +
      state.inventory.toys +
      " " +
      t("uses_remaining") +
      '</p></div><div class="notice-item"><p><strong>' +
      t("hospital_alert") +
      "</strong></p><p>" +
      (sickCount > 0
        ? t("hospital_alert_copy", { count: sickCount })
        : t("hospital_empty_copy")) +
      "</p></div>" +
      "</div>" +
      "</div>" +
      "</section>"
    );
  }

  game.ui.renderHome = renderHome;
})(window.CatGame);
