(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function renderBar(label, value, options) {
    var safeValue = Math.round(value || 0);
    var toneValue = options && options.inverseTone ? 100 - safeValue : safeValue;
    var tone = format.getBarTone(toneValue);
    return (
      '<div class="stat-row">' +
      '<div style="flex:1;">' +
      '<div class="inline-row"><span class="stat-label">' +
      label +
      "</span><strong>" +
      safeValue +
      "/100</strong></div>" +
      '<div class="bar-track"><div class="bar-fill ' +
      tone +
      '" style="width:' +
      safeValue +
      '%;"></div></div>' +
      "</div></div>"
    );
  }

  function renderTaskBadge(title, current, total) {
    return (
      '<div class="notice-item"><p><strong>' +
      format.escapeHtml(title) +
      "</strong></p><p>" +
      current +
      " / " +
      total +
      "</p></div>"
    );
  }

  function renderHeader(state) {
    var player = state.player;
    var expTarget = player.level * 100;
    var dailyDone = state.tasks.daily.filter(function (task) {
      return task.claimed;
    }).length;
    var activeWork = player.activeWork;
    var activeJob = activeWork ? game.data.jobMap[activeWork.jobId] || activeWork : null;
    var musicLabel = game.systems.musicSystem ? game.systems.musicSystem.getCurrentTrackLabel() : t("music_waiting");
    var displayStats = game.systems.playerSystem.getDisplayStats();
    var currentHunger = game.systems.playerSystem.getCurrentHunger();
    var moodStatus = game.systems.playerSystem.getMoodStatus(displayStats.mood);
    var activeSleep = game.systems.playerSystem.getActiveSleep();

    return (
      '<div class="header-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("player_status") + "</p>" +
      '<div class="inline-row"><div>' +
      '<h2 class="panel-title">' +
      format.escapeHtml(player.name) +
      ' · Lv.' +
      player.level +
      "</h2>" +
      '<p class="page-copy">' + t("realtime") + '：<span data-live-clock>' +
      format.formatGameTime() +
      "</span></p>" +
      (activeSleep
        ? '<p class="helper-text" style="margin-top: 6px;">' + t("sleeping_now") + ' · <span data-player-sleep-duration>' +
          format.formatDuration(game.systems.playerSystem.getSleepElapsedMs()) +
          "</span></p>"
        : "") +
      (activeWork
        ? '<p class="helper-text" style="margin-top: 6px;">' +
          t("working_now") +
          "：" +
          format.escapeHtml(getText(activeJob, "name")) +
          '，' +
          t("remaining") +
          ' <span data-active-work-remaining>' +
          format.formatDuration(game.systems.workSystem.getRemainingMs(activeWork)) +
          "</span></p>"
        : "") +
      '<p class="helper-text" style="margin-top: 6px;">' + t("mood") + '：<span data-player-mood-status>' + t(moodStatus.key) + "</span></p>" +
      '<p class="helper-text" style="margin-top: 6px;">' + t("music_now") + "：" + format.escapeHtml(musicLabel) + "</p>" +
      "</div>" +
      '<span class="pill">' +
      (activeWork ? t("work_in_progress") : t("daily_done", { done: dailyDone, total: state.tasks.daily.length })) +
      "</span></div>" +
      renderBar(t("experience"), format.toPercent(player.exp, expTarget)) +
      '<p class="helper-text">' +
      t("experience_info", { current: player.exp, target: expTarget }) +
      "</p>" +
      "</div>" +
      '<div class="resource-grid">' +
      '<div class="resource-card"><p class="resource-label">' + t("gold") + '</p><p class="resource-value">' +
      format.formatNumber(player.gold) +
      "</p></div>" +
      '<div class="resource-card"><p class="resource-label">' + t("stamina") + '</p><p class="resource-value"><span data-player-stamina-live>' +
      Math.round(displayStats.stamina) +
      "</span>" +
      "</p></div>" +
      '<div class="resource-card"><p class="resource-label">' + t("player_hunger") + '</p><p class="resource-value"><span data-player-hunger-live>' +
      Math.round(currentHunger) +
      "</span>" +
      "</p></div>" +
      '<div class="resource-card"><p class="resource-label">' + t("mood") + '</p><p class="resource-value"><span data-player-mood-live>' +
      Math.round(displayStats.mood) +
      "</span>" +
      "</p></div>" +
      '<div class="resource-card"><p class="resource-label">' + t("version") + '</p><p class="resource-value">v' +
      format.escapeHtml(game.config.version) +
      "</p></div>" +
      "</div>" +
      "</div>"
    );
  }

  game.ui.helpers = {
    renderBar: renderBar,
    renderTaskBadge: renderTaskBadge,
  };

  game.ui.renderHeader = renderHeader;
})(window.CatGame);
