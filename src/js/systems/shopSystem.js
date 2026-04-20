(function (game) {
  var getText = game.utils.i18n.getDataText;

  function useEnglishFallback() {
    return game.utils.i18n.getLanguage() !== "zh-CN";
  }

  function purchase(itemId) {
    var state = game.state.game;
    var item = game.data.itemMap[itemId];
    var messages = [];
    var placedFurnitureIds;

    if (!item) {
      return { ok: false, message: useEnglishFallback() ? "That item does not exist in the shop." : "商店里没有这个物品。" };
    }
    if (state.player.gold < item.price) {
      return {
        ok: false,
        message:
          useEnglishFallback()
            ? "Not enough gold. You need " + (item.price - state.player.gold) + " more."
            : "金币不足，还差 " + (item.price - state.player.gold) + " 金币。",
      };
    }
    if (item.type === "furniture" && state.inventory.furnitureOwned.indexOf(item.id) !== -1) {
      return { ok: false, message: useEnglishFallback() ? "You already own this furniture." : "这件家具已经买过了。" };
    }

    state.player.gold -= item.price;
    state.player.totalSpend += item.price;

    if (item.type === "furniture") {
      state.inventory.furnitureOwned.push(item.id);
      state.player.furniturePurchaseCount += 1;
      if (game.systems.homeSystem) {
        game.systems.homeSystem.recalculateComfort();
        placedFurnitureIds = game.state.game.home.placedFurniture;
      }
      messages.push(
        placedFurnitureIds && placedFurnitureIds.indexOf(item.id) !== -1
          ? game.utils.i18n.t("room_auto_place_added", { name: getText(item, "name") })
          : game.utils.i18n.t("room_auto_place_full", { name: getText(item, "name") })
      );
    } else {
      if (typeof state.inventory[item.inventoryField] !== "number") {
        state.inventory[item.inventoryField] = 0;
      }
      if (item.inventoryField === "toys" && item.usesPerPurchase) {
        state.inventory[item.inventoryField] += item.usesPerPurchase;
      } else {
        state.inventory[item.inventoryField] += 1;
      }
      messages.push(
        useEnglishFallback()
          ? "Purchased " + getText(item, "name") + ". It was added to your inventory."
          : "购买成功：「" + getText(item, "name") + "」已放入背包。"
      );
      if (item.inventoryField === "toys" && item.usesPerPurchase) {
        messages.push(game.utils.i18n.t("toy_purchase_uses", { count: item.usesPerPurchase }));
      }
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
