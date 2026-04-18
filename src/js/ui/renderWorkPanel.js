(function (game) {
  var format = game.utils.format;

  function renderJobCard(job, player) {
    var hasActiveWork = Boolean(player.activeWork);
    var disabled = !job.unlocked || player.stamina < job.staminaCost || hasActiveWork;
    var buttonText = !job.unlocked
      ? "Lv." + job.unlockLevel + " 解锁"
      : player.stamina < job.staminaCost
        ? "体力不足"
        : hasActiveWork
          ? "进行中"
        : "开始打工";

    return (
      '<article class="work-card">' +
      '<div class="work-row">' +
      '<div><p class="section-eyebrow">工作机会</p><h3 class="panel-title">' +
      format.escapeHtml(job.name) +
      "</h3></div>" +
      '<span class="status-pill ' +
      (job.unlocked ? "is-success" : "is-warning") +
      '">' +
      (job.unlocked ? "已解锁" : "未解锁") +
      "</span></div>" +
      '<p class="page-copy">' +
      format.escapeHtml(job.description) +
      "</p>" +
      '<div class="notice-list" style="margin-top: 14px;">' +
      '<div class="notice-item"><p><strong>现实用时</strong></p><p>' +
      job.durationMinutes +
      " 分钟</p></div>" +
      '<div class="notice-item"><p><strong>体力消耗</strong></p><p>' +
      job.staminaCost +
      "</p></div>" +
      '<div class="notice-item"><p><strong>基础收益</strong></p><p>' +
      job.goldReward +
      " 金币 / " +
      job.expReward +
      " 经验</p></div>" +
      "</div>" +
      '<div class="inline-row" style="margin-top: 16px;">' +
      '<span class="pill">累计完成 ' +
      job.workCount +
      " 次</span>" +
      '<button class="primary-button" data-job-id="' +
      job.id +
      '" ' +
      (disabled ? "disabled" : "") +
      ">" +
      buttonText +
      "</button></div>" +
      "</article>"
    );
  }

  function renderWorkPanel(state) {
    var activeWork = state.player.activeWork;

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">打工页面</p>' +
      '<h2 class="page-title">先把今天的猫粮钱赚出来</h2>' +
      '<p class="page-copy">现在的打工会按现实时间自动进行，开始后可以退出页面，回来会自动同步结果。</p>' +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' +
      (activeWork ? "当前进行中" : "打工提醒") +
      "</p>" +
      (activeWork
        ? '<h3 class="panel-title">' +
          format.escapeHtml(activeWork.jobName) +
          '</h3><p class="page-copy">开始时间：' +
          format.escapeHtml(format.formatRealDateTime(activeWork.startedAt)) +
          '</p><p class="page-copy">预计完成：' +
          format.escapeHtml(format.formatRealDateTime(activeWork.endsAt)) +
          '</p><p class="helper-text" style="margin-top: 10px;">剩余时间：<span data-active-work-remaining>' +
          format.formatDuration(game.systems.workSystem.getRemainingMs(activeWork)) +
          "</span></p>"
        : '<p class="page-copy">玩家等级会解锁更高收益的工作；升级时也会恢复部分体力。</p>') +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>当前体力</strong></p><p>' +
      state.player.stamina +
      " / 100</p></div>" +
      '<div class="notice-item"><p><strong>当前等级</strong></p><p>Lv.' +
      state.player.level +
      "</p></div>" +
      "</div>" +
      "</div>" +
      "</section>" +
      '<section class="work-grid">' +
      state.jobs
        .map(function (job) {
          return renderJobCard(job, state.player);
        })
        .join("") +
      "</section>"
    );
  }

  game.ui.renderWorkPanel = renderWorkPanel;
})(window.CatGame);
