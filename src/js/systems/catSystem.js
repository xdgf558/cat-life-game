(function (game) {
  var clamp = game.utils.format.clamp;

  function getCat(catId) {
    return game.state.game.cats.find(function (cat) {
      return cat.id === catId;
    });
  }

  function performAction(catId, actionKey) {
    var state = game.state.game;
    var cat = getCat(catId);
    var messages = [];
    var comfortBonus = Math.floor(state.home.comfortScore / 20);

    if (!cat || !cat.unlocked) {
      return { ok: false, message: "这只猫咪还没有解锁。" };
    }

    if (actionKey === "feedBasic") {
      if (state.inventory.food <= 0) {
        return { ok: false, message: "普通猫粮不够了，去商店补货吧。" };
      }
      state.inventory.food -= 1;
      cat.hunger = clamp(cat.hunger + 25, 0, 100);
      cat.mood = clamp(cat.mood + 4, 0, 100);
      state.player.feedTimes += 1;
      state.player.feedTimesToday += 1;
      messages.push(cat.name + "吃得很认真，饱腹值明显回升。");
    } else if (actionKey === "feedPremium") {
      if (state.inventory.premiumFood <= 0) {
        return { ok: false, message: "高级猫粮用完了。" };
      }
      state.inventory.premiumFood -= 1;
      cat.hunger = clamp(cat.hunger + 45, 0, 100);
      cat.intimacy = clamp(cat.intimacy + 2, 0, 100);
      cat.mood = clamp(cat.mood + 6, 0, 100);
      state.player.feedTimes += 1;
      state.player.feedTimesToday += 1;
      messages.push(cat.name + "吃到了高级猫粮，开心得蹭了蹭你。");
    } else if (actionKey === "clean") {
      if (state.inventory.litter <= 0) {
        return { ok: false, message: "猫砂不够了，先去商店买一些。" };
      }
      state.inventory.litter -= 1;
      cat.clean = clamp(cat.clean + 30, 0, 100);
      cat.health = clamp(cat.health + 4, 0, 100);
      state.player.cleanTimes += 1;
      messages.push("你帮" + cat.name + "整理了环境，清洁值提升了。");
    } else if (actionKey === "play") {
      cat.mood = clamp(cat.mood + 18 + comfortBonus, 0, 100);
      cat.intimacy = clamp(cat.intimacy + 8 + Math.min(4, state.inventory.toys * 2), 0, 100);
      cat.energy = clamp(cat.energy - 10, 0, 100);
      state.player.playTimes += 1;
      state.player.playTimesToday += 1;
      state.player.mood = clamp(state.player.mood + 4, 0, 100);
      messages.push("你陪" + cat.name + "玩了好一会儿，气氛变得轻松很多。");
      if (state.inventory.toys > 0) {
        messages.push("家里的逗猫棒让这次陪玩更有效率。");
      }
    } else if (actionKey === "rest") {
      cat.energy = clamp(cat.energy + 20 + comfortBonus, 0, 100);
      cat.health = clamp(cat.health + 5, 0, 100);
      cat.mood = clamp(cat.mood + 3, 0, 100);
      messages.push(cat.name + "在猫窝里舒舒服服地休息了一会儿。");
    } else {
      return { ok: false, message: "未知的猫咪互动。" };
    }

    if (game.systems.taskSystem) {
      game.systems.taskSystem.refreshAllTasks();
    }

    return {
      ok: true,
      messages: messages,
    };
  }

  game.systems.catSystem = {
    getCat: getCat,
    performAction: performAction,
  };
})(window.CatGame);
