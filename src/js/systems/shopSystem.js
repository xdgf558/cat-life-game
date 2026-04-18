(function (game) {
  function purchase(itemId) {
    var state = game.state.game;
    var item = game.data.itemMap[itemId];
    var messages = [];

    if (!item) {
      return { ok: false, message: "商店里没有这个物品。" };
    }
    if (state.player.gold < item.price) {
      return { ok: false, message: "金币不足，还差 " + (item.price - state.player.gold) + " 金币。" };
    }
    if (item.type === "furniture" && state.inventory.furnitureOwned.indexOf(item.id) !== -1) {
      return { ok: false, message: "这件家具已经买过了。" };
    }

    state.player.gold -= item.price;
    state.player.totalSpend += item.price;

    if (item.type === "furniture") {
      state.inventory.furnitureOwned.push(item.id);
      state.home.placedFurniture.push(item.id);
      state.player.furniturePurchaseCount += 1;
      if (game.systems.homeSystem) {
        game.systems.homeSystem.recalculateComfort();
      }
      messages.push("买下了「" + item.name + "」，已自动摆进小客厅。");
    } else {
      state.inventory[item.inventoryField] += 1;
      messages.push("购买成功：「" + item.name + "」已放入背包。");
    }

    if (game.systems.taskSystem) {
      game.systems.taskSystem.refreshAllTasks();
    }

    return {
      ok: true,
      messages: messages,
    };
  }

  game.systems.shopSystem = {
    purchase: purchase,
  };
})(window.CatGame);
