(function (game) {
  var wallOptions = [
    { value: "sunny", labelKey: "room_wall_sunny" },
    { value: "mint", labelKey: "room_wall_mint" },
    { value: "starlight", labelKey: "room_wall_starlight" },
  ];
  var floorOptions = [
    { value: "oak", labelKey: "room_floor_oak" },
    { value: "cream", labelKey: "room_floor_cream" },
    { value: "berry", labelKey: "room_floor_berry" },
  ];
  var decorOptions = [
    { value: "plants", labelKey: "room_decor_plants" },
    { value: "posters", labelKey: "room_decor_posters" },
    { value: "lanterns", labelKey: "room_decor_lanterns" },
  ];
  var layoutOptions = [
    { value: "cozy", labelKey: "room_layout_cozy" },
    { value: "window", labelKey: "room_layout_window" },
    { value: "playful", labelKey: "room_layout_playful" },
  ];

  function recalculateComfort() {
    var baseComfort = 10;
    var furnitureScore = game.state.game.home.placedFurniture.reduce(function (sum, furnitureId) {
      var item = game.data.itemMap[furnitureId];
      return sum + (item && item.comfort ? item.comfort : 0);
    }, 0);

    game.state.game.home.comfortScore = baseComfort + furnitureScore;
    return game.state.game.home.comfortScore;
  }

  function getPlacedFurniture() {
    return game.state.game.home.placedFurniture
      .map(function (furnitureId) {
        return game.data.itemMap[furnitureId];
      })
      .filter(Boolean);
  }

  function ensureFurnitureLayout() {
    var scene = game.state.game.home.roomScene;
    var layout = game.state.game.home.furnitureLayout || {};

    game.state.game.home.placedFurniture.forEach(function (furnitureId, index) {
      if (!layout[furnitureId]) {
        layout[furnitureId] = getFurniturePlacement(scene.layout, index);
      }
    });

    game.state.game.home.furnitureLayout = layout;
    return layout;
  }

  function getFurniturePlacement(layout, index) {
    var layoutMap = {
      cozy: [
        { left: "10%", top: "58%" },
        { left: "56%", top: "54%" },
        { left: "34%", top: "40%" },
        { left: "70%", top: "34%" },
      ],
      window: [
        { left: "8%", top: "60%" },
        { left: "28%", top: "34%" },
        { left: "58%", top: "36%" },
        { left: "70%", top: "60%" },
      ],
      playful: [
        { left: "14%", top: "46%" },
        { left: "44%", top: "58%" },
        { left: "62%", top: "30%" },
        { left: "24%", top: "28%" },
      ],
    };
    var points = layoutMap[layout] || layoutMap.cozy;
    return points[index % points.length];
  }

  function getFurniturePosition(furnitureId, index, layoutName) {
    var layout = ensureFurnitureLayout();
    return layout[furnitureId] || getFurniturePlacement(layoutName, index);
  }

  function setFurniturePosition(furnitureId, left, top) {
    var layout = ensureFurnitureLayout();

    layout[furnitureId] = {
      left: left,
      top: top,
    };
  }

  function resetFurnitureLayout() {
    var scene = game.state.game.home.roomScene;
    var layout = {};

    game.state.game.home.placedFurniture.forEach(function (furnitureId, index) {
      layout[furnitureId] = getFurniturePlacement(scene.layout, index);
    });

    game.state.game.home.furnitureLayout = layout;
  }

  function renderRoomScene(scene, cats, furniture) {
    ensureFurnitureLayout();

    var catMarkup = cats
      .map(function (cat, index) {
        return (
          '<img class="room-cat-sprite room-cat-path-' +
          ((index % 3) + 1) +
          '" src="' +
          game.utils.catArt.buildCatSvg(cat, 120) +
          '" alt="' +
          cat.name +
          '" style="animation-delay:' +
          index * 0.6 +
          's;" />'
        );
      })
      .join("");

    var furnitureMarkup = furniture
      .map(function (item, index) {
        var spot = getFurniturePosition(item.id, index, scene.layout);
        return (
          '<div class="room-furniture" data-furniture-id="' +
          item.id +
          '" style="left:' +
          spot.left +
          ";top:" +
          spot.top +
          ';">' +
          '<span class="room-furniture-icon">' +
          item.icon +
          "</span>" +
          "</div>"
        );
      })
      .join("");

    return (
      '<div class="room-scene wall-' +
      scene.wall +
      " floor-" +
      scene.floor +
      " decor-" +
      scene.decor +
      '">' +
      '<div class="room-wall-art"></div>' +
      '<div class="room-floor"></div>' +
      furnitureMarkup +
      catMarkup +
      "</div>"
    );
  }

  game.systems.homeSystem = {
    recalculateComfort: recalculateComfort,
    getPlacedFurniture: getPlacedFurniture,
    ensureFurnitureLayout: ensureFurnitureLayout,
    getFurniturePosition: getFurniturePosition,
    setFurniturePosition: setFurniturePosition,
    resetFurnitureLayout: resetFurnitureLayout,
    renderRoomScene: renderRoomScene,
    roomWallOptions: wallOptions,
    roomFloorOptions: floorOptions,
    roomDecorOptions: decorOptions,
    roomLayoutOptions: layoutOptions,
  };
})(window.CatGame);
