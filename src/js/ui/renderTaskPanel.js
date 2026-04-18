(function (game) {
  var format = game.utils.format;

  function renderTaskCard(categoryLabel, categoryKey, task) {
    var claimable = task.progress >= task.target && !task.claimed;
    var buttonLabel = task.claimed ? "已领取" : claimable ? "领取奖励" : "未完成";

    return (
      '<article class="task-card ' +
      (task.claimed ? "is-complete" : "") +
      '">' +
      '<p class="section-eyebrow">' +
      format.escapeHtml(categoryLabel) +
      "</p>" +
      '<h3 class="panel-title">' +
      format.escapeHtml(task.title) +
      "</h3>" +
      '<p class="page-copy">' +
      format.escapeHtml(task.description) +
      "</p>" +
      '<div class="bar-track" style="margin-top: 14px;"><div class="bar-fill ' +
      format.getBarTone(format.toPercent(task.progress, task.target)) +
      '" style="width:' +
      format.toPercent(task.progress, task.target) +
      '%;"></div></div>' +
      '<div class="inline-row" style="margin-top: 10px;"><span class="task-meta">' +
      task.progress +
      " / " +
      task.target +
      '</span><span class="task-meta">奖励：' +
      (task.reward.gold || 0) +
      " 金币 / " +
      (task.reward.exp || 0) +
      " 经验</span></div>" +
      '<div class="inline-row" style="margin-top: 16px;">' +
      '<span class="status-pill ' +
      (task.claimed ? "is-success" : claimable ? "is-warning" : "") +
      '">' +
      (task.claimed ? "已完成" : claimable ? "可领取" : "进行中") +
      "</span>" +
      '<button class="task-button ' +
      (claimable ? "is-claimable" : "") +
      '" data-task-claim="' +
      task.id +
      '" data-task-category="' +
      categoryKey +
      '" ' +
      (!claimable ? "disabled" : "") +
      ">" +
      buttonLabel +
      "</button></div>" +
      "</article>"
    );
  }

  function renderTaskSection(title, categoryKey, list) {
    var displayTitleMap = {
      tutorial: "新手任务",
      daily: "每日任务",
      achievements: "成就任务",
    };

    return (
      '<section class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">任务系统</p><h3 class="panel-title">' +
      title +
      "</h3></div><span class=\"pill\">" +
      list.filter(function (task) {
        return task.claimed;
      }).length +
      "/" +
      list.length +
      "</span></div>" +
      '<div class="task-grid" style="margin-top: 16px;">' +
      list
        .map(function (task) {
          return renderTaskCard(displayTitleMap[categoryKey], categoryKey, task);
        })
        .join("") +
      "</div></section>"
    );
  }

  function renderTaskPanel(state) {
    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">任务页面</p>' +
      '<h2 class="page-title">把每天的小目标做成稳定成长</h2>' +
      '<p class="page-copy">任务会随着打工、采购和照顾猫咪自动更新，达成后记得手动领取奖励。</p>' +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">重置规则</p>' +
      '<p class="page-copy">每日任务会在游戏内跨天后自动重置，教程与成就会一直保留。</p>' +
      "</div></section>" +
      renderTaskSection("新手任务", "tutorial", state.tasks.tutorial) +
      renderTaskSection("每日任务", "daily", state.tasks.daily) +
      renderTaskSection("成就任务", "achievements", state.tasks.achievements)
    );
  }

  game.ui.renderTaskPanel = renderTaskPanel;
})(window.CatGame);
