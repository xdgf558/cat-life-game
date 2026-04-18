(function (game) {
  var format = game.utils.format;

  function renderShopCard(item, gold, owned) {
    var buttonLabel = owned ? "已拥有" : "购买";
    var disabled = gold < item.price || owned;

    return (
      '<article class="shop-card ' +
      (owned ? "is-owned" : "") +
      '">' +
      '<div class="shop-row"><div><p class="section-eyebrow">' +
      (item.type === "furniture" ? "家具" : "道具") +
      "</p><h3 class=\"panel-title\">" +
      format.escapeHtml(item.name) +
      "</h3></div>" +
      '<span class="pill">' +
      item.price +
      " 金币</span></div>" +
      '<p class="page-copy">' +
      format.escapeHtml(item.description) +
      "</p>" +
      '<p class="shop-meta" style="margin-top: 10px;">效果：' +
      format.escapeHtml(item.effectText) +
      "</p>" +
      '<div class="inline-row" style="margin-top: 16px;">' +
      '<span class="status-pill ' +
      (gold >= item.price ? "is-success" : "is-warning") +
      '">' +
      (gold >= item.price ? "可购买" : "金币不足") +
      "</span>" +
      '<button class="store-button" data-store-item="' +
      item.id +
      '" ' +
      (disabled ? "disabled" : "") +
      ">" +
      buttonLabel +
      "</button></div>" +
      "</article>"
    );
  }

  function renderShopPanel(state) {
    var items = game.data.items.filter(function (item) {
      return item.type !== "furniture";
    });
    var furniture = game.data.items.filter(function (item) {
      return item.type === "furniture";
    });

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">商店页面</p>' +
      '<h2 class="page-title">把猫咪需要的东西慢慢添齐</h2>' +
      '<p class="page-copy">道具用于日常照顾，家具会自动摆进家里并提高舒适度。</p>' +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">购物说明</p>' +
      '<p class="page-copy">本版不做折扣、抽卡和付费货币，所有商品固定价格，买到就是赚到。</p>' +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>当前金币</strong></p><p>' +
      state.player.gold +
      " 金币</p></div>" +
      "</div>" +
      "</div>" +
      "</section>" +
      '<section class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">消耗品</p><h3 class="panel-title">日常照顾用品</h3></div></div>' +
      '<div class="shop-grid" style="margin-top: 16px;">' +
      items
        .map(function (item) {
          return renderShopCard(item, state.player.gold, false);
        })
        .join("") +
      "</div></section>" +
      '<section class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">家具</p><h3 class="panel-title">让小客厅更温馨</h3></div></div>' +
      '<div class="shop-grid" style="margin-top: 16px;">' +
      furniture
        .map(function (item) {
          return renderShopCard(
            item,
            state.player.gold,
            state.inventory.furnitureOwned.indexOf(item.id) !== -1
          );
        })
        .join("") +
      "</div></section>"
    );
  }

  game.ui.renderShopPanel = renderShopPanel;
})(window.CatGame);
