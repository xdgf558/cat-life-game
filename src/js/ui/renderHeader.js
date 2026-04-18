(function (game) {
  var format = game.utils.format;

  function renderBar(label, value) {
    var safeValue = Math.round(value || 0);
    var tone = format.getBarTone(safeValue);
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

    return (
      '<div class="header-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">玩家状态</p>' +
      '<div class="inline-row"><div>' +
      '<h2 class="panel-title">' +
      format.escapeHtml(player.name) +
      ' · Lv.' +
      player.level +
      "</h2>" +
      '<p class="page-copy">现实时间：<span data-live-clock>' +
      format.formatGameTime() +
      "</span></p>" +
      (activeWork
        ? '<p class="helper-text" style="margin-top: 6px;">当前打工中：' +
          format.escapeHtml(activeWork.jobName) +
          '，剩余 <span data-active-work-remaining>' +
          format.formatDuration(game.systems.workSystem.getRemainingMs(activeWork)) +
          "</span></p>"
        : "") +
      "</div>" +
      '<span class="pill">' +
      (activeWork ? "打工进行中" : "今日已完成日常 " + dailyDone + "/" + state.tasks.daily.length) +
      "</span></div>" +
      renderBar("经验", format.toPercent(player.exp, expTarget)) +
      '<p class="helper-text">经验值：' +
      player.exp +
      " / " +
      expTarget +
      "，每次升级都会恢复一些体力。</p>" +
      "</div>" +
      '<div class="resource-grid">' +
      '<div class="resource-card"><p class="resource-label">金币</p><p class="resource-value">' +
      format.formatNumber(player.gold) +
      "</p></div>" +
      '<div class="resource-card"><p class="resource-label">体力</p><p class="resource-value">' +
      player.stamina +
      "</p></div>" +
      '<div class="resource-card"><p class="resource-label">心情</p><p class="resource-value">' +
      player.mood +
      "</p></div>" +
      '<div class="resource-card"><p class="resource-label">版本</p><p class="resource-value">v' +
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
