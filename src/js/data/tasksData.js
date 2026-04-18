(function (game) {
  game.data.tasks = {
    tutorial: [
      {
        id: "tutorial_first_job",
        title: "第一次打工",
        description: "完成 1 次打工，挣到养猫的第一笔钱。",
        metric: "workTimes",
        target: 1,
        reward: { gold: 40, exp: 10 },
      },
      {
        id: "tutorial_feed_cat",
        title: "给猫喂饭",
        description: "完成 1 次喂食。",
        metric: "feedTimes",
        target: 1,
        reward: { gold: 30, exp: 8 },
      },
      {
        id: "tutorial_buy_furniture",
        title: "给家里添件家具",
        description: "购买 1 件家具，让小家更舒适。",
        metric: "furniturePurchaseCount",
        target: 1,
        reward: { gold: 60, exp: 12 },
      },
    ],
    daily: [
      {
        id: "daily_work_three_times",
        title: "今日勤工",
        description: "今天打工 3 次。",
        metric: "workTimesToday",
        target: 3,
        reward: { gold: 90, exp: 16 },
      },
      {
        id: "daily_play_twice",
        title: "猫咪陪伴日",
        description: "今天陪猫玩耍 2 次。",
        metric: "playTimesToday",
        target: 2,
        reward: { gold: 50, exp: 10 },
      },
      {
        id: "daily_spend_hundred",
        title: "温馨采购",
        description: "今天累计消费 100 金币。",
        metric: "spendGoldToday",
        target: 100,
        reward: { gold: 70, exp: 14 },
      },
    ],
    achievements: [
      {
        id: "achievement_total_income",
        title: "勤劳打工人",
        description: "累计收入达到 1000 金币。",
        metric: "totalIncome",
        target: 1000,
        reward: { gold: 120, exp: 25 },
      },
      {
        id: "achievement_furniture_three",
        title: "温馨小窝",
        description: "拥有 3 件家具。",
        metric: "furnitureCount",
        target: 3,
        reward: { gold: 100, exp: 18 },
      },
      {
        id: "achievement_intimacy_fifty",
        title: "最好的伙伴",
        description: "任意一只猫咪亲密度达到 50。",
        metric: "maxIntimacy",
        target: 50,
        reward: { gold: 140, exp: 24 },
      },
    ],
  };
})(window.CatGame);
