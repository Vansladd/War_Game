# ==============================================================
# File path
# ~/git_src/induction/training/admin/tcl/war_games/war_game.tcl
# ==============================================================

namespace eval WAR_GAME {

	asSetAct WAR_GAME_Login                 [namespace code go_login_page]
    asSetAct WAR_GAME_Lobby                 [namespace code go_lobby_page]

    proc go_login_page args {
        asPlayFile -nocache war_games/login.html
    }
    
    proc go_lobby_page args {
        asPlayFile -nocache war_games/lobby.html
    }
}