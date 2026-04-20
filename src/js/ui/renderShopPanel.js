(function (game) {
  var format = game.utils.format;
  var t = game.utils.i18n.t;
  var getText = game.utils.i18n.getDataText;

  function renderShopCard(item, gold, owned) {
    var count = item.type === "furniture" ? null : game.systems.playerSystem.getInventoryCount(item.id);
    var sleeping = game.systems.playerSystem.hasActiveSleep();
    var buttonLabel = owned ? t("owned") : t("buy");
    var disabled = gold < item.price || owned;
    var useButton =
      item.type === "playerConsumable"
        ? '<button class="secondary-button" data-use-player-item="' +
          item.id +
          '" ' +
          (count <= 0 || sleeping ? "disabled" : "") +
          ">" +
          t("use_item") +
          "</button>"
        : "";

    return (
      '<article class="shop-card ' +
      (owned ? "is-owned" : "") +
      '">' +
      '<div class="shop-row"><div><p class="section-eyebrow">' +
      (item.type === "furniture"
        ? t("furniture")
        : item.type === "playerConsumable"
          ? t(item.category === "playerDrink" ? "player_drinks_title" : "player_foods_title")
          : t("item")) +
      '</p><div class="item-title"><span class="item-icon">' +
      item.icon +
      "</span><h3 class=\"panel-title\">" +
      format.escapeHtml(getText(item, "name")) +
      "</h3></div></div>" +
      '<span class="pill">' +
      item.price +
      " " + t("gold_unit") + "</span></div>" +
      '<p class="page-copy">' +
      format.escapeHtml(getText(item, "description")) +
      "</p>" +
      '<p class="shop-meta" style="margin-top: 10px;">' + t("effect") + '：' +
      format.escapeHtml(getText(item, "effectText")) +
      "</p>" +
      (item.type === "playerConsumable"
        ? '<p class="helper-text" style="margin-top: 8px;">' + t("owned_count", { count: count }) + "</p>"
        : "") +
      '<div class="inline-row" style="margin-top: 16px;">' +
      '<span class="status-pill ' +
      (gold >= item.price ? "is-success" : "is-warning") +
      '">' +
      (gold >= item.price ? t("can_buy") : t("not_enough_gold")) +
      "</span>" +
      '<button class="store-button" data-store-item="' +
      item.id +
      '" ' +
      (disabled ? "disabled" : "") +
      ">" +
      buttonLabel +
      "</button>" +
      useButton +
      "</div>" +
      "</article>"
    );
  }

  function renderShopPanel(state) {
    var currentHunger = game.systems.playerSystem.getCurrentHunger();
    var catItems = game.data.items.filter(function (item) {
      return item.type === "consumable";
    });
    var playerFoods = game.data.items.filter(function (item) {
      return item.type === "playerConsumable" && item.category === "playerFood";
    });
    var playerDrinks = game.data.items.filter(function (item) {
      return item.type === "playerConsumable" && item.category === "playerDrink";
    });
    var furniture = game.data.items.filter(function (item) {
      return item.type === "furniture";
    });

    return (
      '<section class="page-header">' +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("page_shop") + "</p>" +
      '<h2 class="page-title">' + t("shop_panel_title") + "</h2>" +
      '<p class="page-copy">' + t("shop_panel_copy") + "</p>" +
      "</div>" +
      '<div class="page-card">' +
      '<p class="section-eyebrow">' + t("shopping_info") + "</p>" +
      '<p class="page-copy">' + t("shopping_copy") + "</p>" +
      '<div class="notice-list" style="margin-top: 16px;">' +
      '<div class="notice-item"><p><strong>' + t("current_gold") + "</strong></p><p>" +
      state.player.gold +
      " " + t("gold_unit") + "</p></div>" +
      '<div class="notice-item"><p><strong>' + t("stamina") + "</strong></p><p>" +
      state.player.stamina +
      ' / 100</p></div>' +
      '<div class="notice-item"><p><strong>' + t("player_hunger") + "</strong></p><p>" +
      currentHunger +
      ' / 100</p></div>' +
      '<div class="notice-item"><p><strong>' + t("mood") + "</strong></p><p>" +
      state.player.mood +
      ' / 100</p></div>' +
      "</div>" +
      "</div>" +
      "</section>" +
      '<section class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">' + t("consumables") + '</p><h3 class="panel-title">' + t("daily_supplies") + "</h3></div></div>" +
      '<div class="shop-grid" style="margin-top: 16px;">' +
      catItems
        .map(function (item) {
          return renderShopCard(item, state.player.gold, false);
        })
        .join("") +
      "</div></section>" +
      '<section class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">' + t("player_supplies_title") + '</p><h3 class="panel-title">' + t("player_foods_title") + "</h3></div></div>" +
      '<div class="shop-grid" style="margin-top: 16px;">' +
      playerFoods
        .map(function (item) {
          return renderShopCard(item, state.player.gold, false);
        })
        .join("") +
      "</div></section>" +
      '<section class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">' + t("player_supplies_title") + '</p><h3 class="panel-title">' + t("player_drinks_title") + "</h3></div></div>" +
      '<div class="shop-grid" style="margin-top: 16px;">' +
      playerDrinks
        .map(function (item) {
          return renderShopCard(item, state.player.gold, false);
        })
        .join("") +
      "</div></section>" +
      '<section class="page-card">' +
      '<div class="inline-row"><div><p class="section-eyebrow">' + t("furniture") + '</p><h3 class="panel-title">' + t("warm_home") + "</h3></div></div>" +
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
