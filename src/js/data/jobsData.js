(function (game) {
  var jobs = [
    {
      id: "job_flyer",
      name: "发传单",
      unlockLevel: 1,
      duration: 2,
      durationMinutes: 2,
      staminaCost: 10,
      goldReward: 60,
      expReward: 22,
      description: "轻松上手的基础工作，适合开局攒第一桶金。",
      eventPool: [
        { text: "路过的上班族给了你额外小费。", goldDelta: 20 },
        { text: "今天发得很顺利，没有额外状况。", goldDelta: 0 },
        { text: "风有点大，传单飞了几张，但还是顺利收工。", goldDelta: -5 },
      ],
    },
    {
      id: "job_store",
      name: "便利店兼职",
      unlockLevel: 2,
      duration: 3,
      durationMinutes: 3,
      staminaCost: 15,
      goldReward: 100,
      expReward: 35,
      description: "节奏更忙，但收入稳定，适合中期冲级。",
      eventPool: [
        { text: "老板夸你手脚利落，奖励了额外奖金。", goldDelta: 30 },
        { text: "有位顾客不小心打翻饮料，忙了好一阵。", goldDelta: -10 },
        { text: "一切都很平稳，准时打卡下班。", goldDelta: 0 },
      ],
    },
    {
      id: "job_petshop",
      name: "宠物店助理",
      unlockLevel: 4,
      duration: 4,
      durationMinutes: 4,
      staminaCost: 20,
      goldReward: 160,
      expReward: 52,
      description: "能接触到猫咪用品，收益更高，也更累。",
      eventPool: [
        { text: "店长送了你一袋普通猫粮。", goldDelta: 0, itemReward: "food_basic", itemAmount: 1 },
        { text: "你帮客人挑选用品，得到了一笔奖励。", goldDelta: 25 },
        { text: "今天工作很扎实，拿到了基础薪水。", goldDelta: 0 },
      ],
    },
  ];

  game.data.jobs = jobs;
  game.data.jobMap = jobs.reduce(function (map, job) {
    map[job.id] = job;
    return map;
  }, {});
})(window.CatGame);
