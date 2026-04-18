(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.2.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: [
        "猫咪属性会随现实时间自动下降，离线期间也会同步结算。",
        "猫咪页面新增各项状态的下降倒计时显示。",
        "饱腹感下降速度调整为最慢，但归零后猫咪会死亡。",
        "死亡后的猫咪无法继续互动，状态会在界面中明确提示。",
      ],
      catDecayRules: {
        hunger: { intervalMs: 12 * 60 * 1000, label: "饱腹" },
        clean: { intervalMs: 8 * 60 * 1000, label: "清洁" },
        mood: { intervalMs: 6 * 60 * 1000, label: "心情" },
        health: { intervalMs: 10 * 60 * 1000, label: "健康" },
        energy: { intervalMs: 5 * 60 * 1000, label: "活力" },
      },
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
