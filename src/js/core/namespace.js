(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.1.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: [
        "游戏时间改为读取电脑当前时间显示。",
        "打工改为按现实时间自动进行，关闭页面后会继续结算。",
        "重新进入游戏时会自动同步已完成的打工收益。",
        "首页新增版本更新公告区，展示本次调整内容。",
      ],
    },
    data: {},
    utils: {},
    state: {
      game: null,
      currentPage: "home",
      selectedCatId: "cat_001",
      notifications: [],
    },
    systems: {},
    ui: {},
  };
})();
