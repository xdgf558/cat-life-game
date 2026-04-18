(function (game) {
  var format = game.utils.format;

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

    var releaseNotes = game.config.releaseNotes
      .map(function (note) {
        return "<p>• " + format.escapeHtml(note) + "</p>";
      })
      .join("");

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">首页</p>' +
      '<h2 class="page-title">今天也为了猫咪认真生活</h2>' +
      '<p class="page-copy">先看看资源和猫咪状态，再决定是去打工、补货，还是回家陪它一会儿。</p>' +
      '<div class="inline-row" style="margin-top:18px; flex-wrap: wrap;">' +
      '<button class="primary-button" data-page-target="work">去打工</button>' +
      '<button class="secondary-button" data-page-target="cats">去陪猫</button>' +
      '<button class="ghost-button" data-page-target="shop">去采购</button>' +
      "</div>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' +
      (isNewVersion ? "版本更新" : "当前版本") +
      "</p>" +
      '<h3 class="panel-title">v' +
      format.escapeHtml(game.config.version) +
      (isNewVersion ? " 已更新" : " 版本内容") +
      "</h3>" +
      '<div class="helper-text" style="margin-top: 10px;">' +
      releaseNotes +
      "</div>" +
      (isNewVersion
        ? '<div class="inline-row" style="margin-top: 16px;"><span class="status-pill is-warning">有新调整</span><button class="secondary-button" data-dismiss-release-note>我知道了</button></div>'
        : "") +
      "</div>" +
      "</section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">今日重点</p>' +
      '<p class="page-copy">完成日常可以快速补贴金币和经验，适合开局滚动成长。</p>' +
      '<div class="notice-list" style="margin-top: 16px;">' +
      dailyCards +
      "</div>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">当前打工</p>' +
      (activeWork
        ? '<h3 class="panel-title">' +
          format.escapeHtml(activeWork.jobName) +
          '</h3><p class="page-copy">预计完成：' +
          format.escapeHtml(format.formatRealDateTime(activeWork.endsAt)) +
          '</p><p class="helper-text" style="margin-top: 10px;">剩余时间：<span data-active-work-remaining>' +
          format.formatDuration(game.systems.workSystem.getRemainingMs(activeWork)) +
          "</span></p>"
        : '<h3 class="panel-title">暂时空闲</h3><p class="page-copy">现在可以开始一份现实时间自动结算的打工。</p>') +
      "</div>" +
      "</section>" +
      '<section class="home-grid">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">猫咪概览</p>' +
      '<h3 class="panel-title">' +
      format.escapeHtml(selectedCat.name) +
      " · " +
      format.escapeHtml(selectedCat.breed) +
      "</h3>" +
      '<p class="page-copy">' +
      (selectedCatDead
        ? "当前状态：已死亡"
        : "亲密度 " + selectedCat.intimacy + " / 100，健康值 " + selectedCat.health + " / 100") +
      "</p>" +
      '<div style="margin-top: 14px;">' +
      game.ui.helpers.renderBar("饱腹", selectedCat.hunger) +
      game.ui.helpers.renderBar("清洁", selectedCat.clean) +
      game.ui.helpers.renderBar("心情", selectedCat.mood) +
      game.ui.helpers.renderBar("活力", selectedCat.energy) +
      "</div>" +
      '<p class="helper-text" style="margin-top: 10px;">' +
      (selectedCatDead
        ? "这只猫咪已经无法再互动。"
        : "饱腹下次下降：<span data-cat-stat-countdown data-cat-id=\"" +
          selectedCat.id +
          '" data-cat-stat="hunger">' +
          format.formatDuration(game.systems.catSystem.getStatCountdown(selectedCat, "hunger")) +
          '</span>，归零预计：<span data-cat-hunger-zero data-cat-id="' +
          selectedCat.id +
          '">' +
          format.formatDuration(game.systems.catSystem.getHungerDeathEta(selectedCat)) +
          "</span>") +
      "</p>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">小家状态</p>' +
      '<h3 class="panel-title">小客厅</h3>' +
      '<p class="page-copy">当前舒适度 ' +
      state.home.comfortScore +
      '，购买家具后会自动摆放到房间里。</p>' +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>已摆放家具</strong></p><p>' +
      (furnitureList || "暂无") +
      "</p></div>" +
      '<div class="notice-item"><p><strong>库存概览</strong></p><p>普通猫粮 ' +
      state.inventory.food +
      " / 高级猫粮 " +
      state.inventory.premiumFood +
      " / 猫砂 " +
      state.inventory.litter +
      " / 逗猫棒 " +
      state.inventory.toys +
      "</p></div>" +
      "</div>" +
      "</div>" +
      "</section>"
    );
  }

  game.ui.renderHome = renderHome;
})(window.CatGame);
