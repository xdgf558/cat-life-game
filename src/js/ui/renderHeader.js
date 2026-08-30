(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function renderBar(label, value, options) {
    var safeValue = Math.max(0, Math.min(100, Math.round(value || 0)));
    var isDanger = options && options.inverseTone ? safeValue >= 70 : safeValue <= 25;
    return (
      '<div class="stat-row"><div class="stat-row-heading"><span class="stat-label">' + label +
      '</span><strong>' + safeValue + '</strong></div><div class="bar-track"><div class="bar-fill ' +
      (isDanger ? "is-danger" : "is-normal") + '" style="width:' + safeValue + '%"></div></div></div>'
    );
  }

  function renderTaskBadge(title, current, total) {
    var percent = format.toPercent(current, total);
    return (
      '<div class="task-brief"><div class="task-brief-line"><strong>' + format.escapeHtml(title) +
      '</strong><span>' + current + ' / ' + total + '</span></div><div class="bar-track"><div class="bar-fill is-normal" style="width:' +
      percent + '%"></div></div></div>'
    );
  }

  function getConditionCopy(displayStats, hunger) {
    if (displayStats.mood < 35) {
      return t("work_low_mood_warning");
    }
    if (hunger >= 75) {
      return t("work_hunger_warning");
    }
    return t("player_status_copy");
  }

  function renderHeader(state) {
    var player = state.player;
    var displayStats = game.systems.playerSystem.getDisplayStats();
    var hunger = game.systems.playerSystem.getCurrentHunger();
    var activeWork = player.activeWork;
    var activeJob = activeWork ? game.data.jobMap[activeWork.jobId] || activeWork : null;

    return (
      '<div class="masthead-rule is-heavy"></div>' +
      '<div class="masthead"><div class="masthead-title"><h1>' + t("brandTitle") +
      '</h1><span>CAT LIFE DAILY</span></div><div class="masthead-meta"><span>' +
      t("day_label", { day: player.currentDay || 1 }) + '</span><span data-live-clock>' + format.formatGameTime() +
      '</span><span>v' + format.escapeHtml(game.config.version) + '</span></div></div>' +
      '<div class="masthead-rule is-fine"></div>' +
      '<div class="statusbar"><div class="cash-block"><span>' + t("cash_outside_bank") +
      '</span><strong>¥' + format.formatNumber(player.gold) + '</strong></div><div class="statusbar-stats">' +
      renderBar(t("stamina"), displayStats.stamina) +
      renderBar(t("mood"), displayStats.mood) +
      renderBar(t("player_hunger"), hunger, { inverseTone: true }) +
      '</div><div class="statusbar-note"><span>' + getConditionCopy(displayStats, hunger) + '</span>' +
      (activeWork ? '<strong>' + format.escapeHtml(getText(activeJob, "name")) + ' · <span data-active-work-remaining>' +
        format.formatDuration(game.systems.workSystem.getRemainingMs(activeWork)) + '</span></strong>' : '') +
      '</div></div><div class="masthead-rule is-medium"></div>'
    );
  }

  game.ui.helpers = {
    renderBar: renderBar,
    renderTaskBadge: renderTaskBadge,
  };
  game.ui.renderHeader = renderHeader;
})(window.CatGame);
