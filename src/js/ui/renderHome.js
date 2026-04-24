(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function renderPlayerSupplyButtons(items, sleeping) {
    return items
      .map(function (item) {
        var count = game.systems.playerSystem.getInventoryCount(item.id);
        return (
          '<button class="chip-button" data-use-player-item="' +
          item.id +
          '" ' +
          (count <= 0 || sleeping ? "disabled" : "") +
          ">" +
          item.icon +
          " " +
          format.escapeHtml(getText(item, "name")) +
          " ×" +
          count +
          "</button>"
        );
      })
      .join("");
  }

  function renderHome(state) {
    var selectedCat =
      state.cats.find(function (cat) {
        return cat.id === game.state.selectedCatId && cat.unlocked;
      }) ||
      state.cats.find(function (cat) {
        return cat.unlocked;
      });
    var activeWork = state.player.activeWork;
    var displayStats = game.systems.playerSystem.getDisplayStats();
    var currentHunger = game.systems.playerSystem.getCurrentHunger();
    var moodStatus = game.systems.playerSystem.getMoodStatus(displayStats.mood);
    var activeSleep = game.systems.playerSystem.getActiveSleep();
    var sleepRecovery = game.systems.playerSystem.getSleepRecovery();
    var hungerCountdown = game.systems.playerSystem.getHungerCountdown();
    var hungerBlockEta = game.systems.playerSystem.getHungerBlockEta();
    var playerFoods = game.systems.playerSystem.getPlayerConsumablesByCategory("playerFood");
    var playerDrinks = game.systems.playerSystem.getPlayerConsumablesByCategory("playerDrink");

    var dailyCards = state.tasks.daily
      .map(function (task) {
        return game.ui.helpers.renderTaskBadge(getText(task, "title"), task.progress, task.target);
      })
      .join("");

    var furnitureList = game.systems.homeSystem
      .getPlacedFurniture()
      .map(function (item) {
        return '<span class="status-pill">' + format.escapeHtml(getText(item, "name")) + "</span>";
      })
      .join(" ");
    var selectedCatDead = selectedCat.isAlive === false;
    var catVisual = game.systems.catSystem.getCatVisualState(selectedCat);
    var catDisease = game.systems.catSystem.getCatDisease(selectedCat);
    var sickCount = game.systems.hospitalSystem.getSickCats().length;
    var activeJob = activeWork ? game.data.jobMap[activeWork.jobId] || activeWork : null;
    var roomStep = game.systems.homeSystem.getCurrentRoomStep();

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("page_home") + "</p>" +
      '<h2 class="page-title">' + t("home_panel_title") + "</h2>" +
      '<p class="page-copy">' + t("home_panel_copy") + "</p>" +
      '<div class="inline-row" style="margin-top:18px; flex-wrap: wrap;">' +
      '<button class="primary-button" data-page-target="community">' + t("nav_community") + "</button>" +
      '<button class="primary-button" data-page-target="work">' + t("nav_work") + "</button>" +
      '<button class="primary-button" data-page-target="bank">' + t("nav_bank") + "</button>" +
      '<button class="secondary-button" data-page-target="cats">' + t("nav_cats") + "</button>" +
      '<button class="secondary-button" data-page-target="collection">' + t("nav_collection") + "</button>" +
      '<button class="secondary-button" data-page-target="arcade">' + t("nav_arcade") + "</button>" +
      '<button class="secondary-button" data-page-target="hospital">' + t("nav_hospital") + "</button>" +
      '<button class="ghost-button" data-page-target="shop">' + t("nav_shop") + "</button>" +
      '<button class="ghost-button" data-page-target="version">' + t("nav_version") + "</button>" +
      '<button class="ghost-button" data-page-target="save">' + t("nav_save") + "</button>" +
      "</div>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("todays_focus") + "</p>" +
      '<h3 class="panel-title">' + (activeWork ? format.escapeHtml(getText(activeJob, "name")) : t("idle_now")) + "</h3>" +
      '<p class="page-copy">' +
      (activeWork
        ? t("expected_finish") + "：" + format.escapeHtml(format.formatRealDateTime(activeWork.endsAt))
        : t("home_today_copy")) +
      "</p>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>' + t("room_upgrade_title") + '</strong></p><p>' +
      t("room_level_text", { level: roomStep.level }) +
      " · " +
      t("room_capacity_text", { count: roomStep.capacity }) +
      "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("hospital_alert") + '</strong></p><p>' +
      (sickCount > 0 ? t("hospital_alert_copy", { count: sickCount }) : t("hospital_empty_copy")) +
      "</p></div>" +
      "</div>" +
      "</div>" +
      "</section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">' + t("player_life_title") + '</p><h3 class="panel-title">' +
      t("player_status") +
      '</h3></div><span class="status-pill ' + moodStatus.tone + '">' + t(moodStatus.key) + "</span></div>" +
      '<div style="margin-top: 14px;">' +
      game.ui.helpers.renderBar(t("stamina"), displayStats.stamina) +
      game.ui.helpers.renderBar(t("mood"), displayStats.mood) +
      game.ui.helpers.renderBar(t("player_hunger"), currentHunger, { inverseTone: true }) +
      "</div>" +
      '<p class="helper-text" style="margin-top: 10px;">' + t("player_status_copy") + "</p>" +
      '<p class="helper-text" style="margin-top: 8px;">' +
      t("player_hunger_next_rise") + '：<span data-player-hunger-countdown>' +
      (hungerCountdown === null ? t("stopped") : format.formatDuration(hungerCountdown)) +
      '</span>' +
      (hungerBlockEta !== null
        ? " · " + t("work_hunger_eta") + '：<span data-player-hunger-eta>' + format.formatDuration(hungerBlockEta) + "</span>"
        : "") +
      "</p>" +
      (activeSleep
        ? '<div class="notice-list" style="margin-top: 14px;">' +
          '<div class="notice-item"><p><strong>' + t("sleeping_now") + "</strong></p><p>" + t("sleep_started_at") + "：" +
          format.escapeHtml(format.formatRealDateTime(activeSleep.startedAt)) +
          '</p></div><div class="notice-item"><p><strong>' + t("sleep_elapsed") + '</strong></p><p><span data-player-sleep-duration>' +
          format.formatDuration(sleepRecovery.elapsedMs) +
          '</span></p></div><div class="notice-item"><p><strong>' + t("sleep_recovery_live") + '</strong></p><p>' +
          t("sleep_live_prefix_stamina") + ' <span data-player-sleep-stamina>' + sleepRecovery.staminaGain + '</span> / ' +
          t("sleep_live_prefix_mood") + ' <span data-player-sleep-mood>' + sleepRecovery.moodGain + "</span>" +
          '</p></div></div>'
        : "") +
      (displayStats.mood < game.config.playerCondition.workMoodThresholds.tired
        ? '<p class="warning-copy" style="margin-top: 10px;">' + t("work_low_mood_warning") + "</p>"
        : "") +
      (currentHunger >= game.config.playerCondition.hungerBlockThreshold
        ? '<p class="warning-copy" style="margin-top: 10px;">' + t("work_hunger_warning") + "</p>"
        : "") +
      '<div class="inline-row" style="margin-top: 16px;">' +
      '<button class="primary-button" data-player-sleep>' + t(activeSleep ? "wake_action" : "sleep_action") + "</button>" +
      '<button class="secondary-button" data-page-target="shop">' + t("buy_recovery_supplies") + "</button>" +
      "</div>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("todays_focus") + "</p>" +
      '<p class="page-copy">' + t("today_task_reward") + "</p>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      dailyCards +
      "</div>" +
      "</div>" +
      "</section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("player_supplies_title") + "</p>" +
      '<h3 class="panel-title">' + t("player_foods_title") + "</h3>" +
      '<div class="button-cloud" style="margin-top: 14px;">' +
      renderPlayerSupplyButtons(playerFoods, Boolean(activeSleep)) +
      "</div>" +
      '<h3 class="panel-title" style="margin-top: 18px;">' + t("player_drinks_title") + "</h3>" +
      '<div class="button-cloud" style="margin-top: 14px;">' +
      renderPlayerSupplyButtons(playerDrinks, Boolean(activeSleep)) +
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
      '<img class="cat-illustration-large" src="' + game.utils.catArt.buildCatSvg(selectedCat, 132) + '" alt="' + format.escapeHtml(getText(selectedCat, "name")) + '" /><div><p class="mini-label">' + t("cat_portrait") + '</p><p class="page-copy">' + t(catVisual.labelKey) + "</p></div></div>" +
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
      (furnitureList || t("none_text")) +
      "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("room_upgrade_title") + "</strong></p><p>" +
      t("room_level_text", { level: roomStep.level }) +
      " · " +
      t("room_capacity_text", { count: roomStep.capacity }) +
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
