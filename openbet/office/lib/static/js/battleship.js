jQuery(document).ready(function() {
  var game = new Game();
  populate_ships_control(game, jQuery('#game-setup .ships'));
  draw_board(game, jQuery('#game-setup .board'));
  jQuery('#start-game-btn').click(function() {
    game.start_game();
  });
});
var draw_board = function(game, jq_container) {
  game.create_setup_board(jq_container);
};
var populate_ships_control = function(game, jq_ships_list) {
  var ships_info = game.player.remaining_ships,
      ul = jQuery('<ul></ul>'),
      set_selected = true;
  for(var ship in ships_info){
    var li = jQuery('<li></li>'),
        radio = jQuery('<input type="radio" name="ship-select" value="' + ship + '">'),
        ship_img = jQuery('<span class="ship-img ship-img-' + ship + '"></span>');
        remaining = jQuery('<span class="remaining">' + ships_info[ship] + '</span>');
    if(set_selected === true){
      radio.attr({'checked': 'checked'});
      set_selected = false;
    }
    li.append(radio).append(remaining).append(ship_img);
    ul.append(li);
  }
  jq_ships_list.append(ul);
};