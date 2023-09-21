# ==============================================================
# $Id: topspot.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc H_GoTopSpotChoosePics {} {
    tpBindString XGAME_ID [reqGetArg xgame_id]
    X_play_file "topspot/choosePics_frames.html"
}

proc H_GoTopSpotChoosePicLeft {} {
    global xgaQry

    # Get all the pictures already in the database
    # - these can't be chosen again.
    if [catch {set rs [xg_exec_qry $xgaQry(get_all_topspot_pics)]} msg] {
	return [handle_err "get_all_topspot_pics" "error: $msg"]
    }
    for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
	set already([db_get_col $rs $r small_pic_filename]) 1
	OT_LogWrite 5 "Already have [db_get_col $rs $r small_pic_filename]"
    }
    db_close $rs

    # Find all the pictures 
    set dir [OT_CfgGet TOPSPOTIMAGEDIR]
    set out ""
    if [file isdirectory $dir/pics] {
	set i 1
	OT_LogWrite 3 "Looking in $dir for images"
	foreach f [glob -nocomplain [file join $dir/pics {*_small.jpg}]] {

	    
	    if {![info exists already([file tail $f])]} {
		append out "<tr>"
		append out "<td width=81 height=70 align=center valign=middle>"
		append out "<a href=\"javascript:selectIt($i)\"><img src=\"[OT_CfgGet GIF_URL]/topspot/pics/[file tail $f]\" border=0 name=\"ap$i\">[file tail $f]</a>"
		append out "</td>"
		append out "<td width=81 height=70 align=center valign=middle>&nbsp;</td>"
		append out "</tr>"
		incr i
	    }
	}
    }

    tpBindString IMAGES $out

    X_play_file "topspot/choosePic_left.html"
}
proc H_GoTopSpotChoosePicRight {} {
    tpBindString XGAME_ID [reqGetArg xgame_id]
    X_play_file "topspot/choosePic_right.html"
}

proc H_DoTopSpotChoosePics {} {
    global xgaQry DB

    inf_begin_tran $DB

    set xgame_id [reqGetArg xgame_id]

    # First take out the old pictures associate with this game
    if [catch {set rs [xg_exec_qry $xgaQry(remove_pictures) $xgame_id]} msg] {
	inf_rollback_tran $DB
	return [handle_err "remove_pictures" "error: $msg"]
    }


    # Then the new ones in
    for {set i 1} {$i <= 4} {incr i} {
	set base_fname [reqGetArg choice$i]
	if [catch {set rs [xg_exec_qry $xgaQry(add_picture) $xgame_id \
			       ${base_fname}.jpg \
			       ${base_fname}_small.jpg \
			       $i]} msg] {
	    inf_rollback_tran $DB
	    return [handle_err "add_picture" "error: $msg"]
	}
    }

    inf_commit_tran $DB
    
    handle_success "Setup pictures complete" "Your pictures have been selected"
}


proc H_GoTopSpotAssignArea {} {

    global xgaQry

    set xgame_id [reqGetArg xgame_id]

    bind_comp_date_param_tags $xgame_id

    if [catch {set rs [xg_exec_qry $xgaQry(get_topspot_pics) $xgame_id]} msg] {
	return [handle_err "get_topspot_pics" "error: $msg"]
    }
    
    set nrows [db_get_nrows $rs]

    if {$nrows!=4} {
	db_close $rs
	return [handle_err "get_topspot_pics" "error: There are only $nrows pictures set up for this game"]
    }

    set output ""

    for {set r 0} {$r < $nrows} {incr r} {
	set number [db_get_col $rs $r number]
	set smallpic [db_get_col $rs $r small_pic_filename]
	set pic [db_get_col $rs $r pic_filename]
	set id [db_get_col $rs $r topspot_pic_id]
	append output [writeJavaParamTag smallpic$number $smallpic]
	append output [writeJavaParamTag pic$number $pic]
	append output [writeJavaParamTag pid$number $id]
    }

    db_close $rs

    tpBindString PARAMS $output
    tpBindString IMAGE_LOC "[OT_CfgGet GIF_URL]/topspot/"
    
    X_play_file "assignArea.html"
}

proc writeJavaParamTag {name value} {
    return "<param name=\"$name\" value=\"$value\">\n"
}

# Set up the rectangle bounding the ball positions
proc H_DoTopSpotAssignArea {} {
    global xgaQry DB
    
    inf_begin_tran $DB
    for {set i 1} {$i <= 4} {incr i} {
	set id [reqGetArg id$i]
	foreach x {left right top bottom} {
	    set v_$x [reqGetArg ${i}_$x]
	}
	if [catch {set rs [xg_exec_qry $xgaQry(update_pic_rectangle)\
			       $v_left\
			       $v_right\
			       $v_top\
			       $v_bottom\
			       $id]} msg] {
	    inf_rollback_tran $DB
	    return [handle_err "update_pic_rectangle" "error: $msg"]
	}
    }
    inf_commit_tran $DB
    handle_success "Assign Area Successful" "The rectangle's coordinates have been recorded"
}

proc H_GoPlaceBalls {} {
    global xgaQry

    set xgame_id [reqGetArg xgame_id]
    TopSpotPlaceBallsParams $xgame_id
    bind_comp_date_param_tags $xgame_id
    X_play_file "topspot/tsPlaceBalls.html"
}

proc TopSpotPlaceBallsParams {xgame_id} {
    global xgaQry

    if [catch {set rs [xg_exec_qry $xgaQry(get_topspot_pics)\
			   $xgame_id]} msg] {
	return [handle_err "get_topspot_pics" "error: $msg"]
    }

    set nrows [db_get_nrows $rs]
    if {$nrows!=4} {
	db_close $rs
	return [handle_err "get_topspot_pics" "error: There are only $nrows pictures chosen for this game"]
    }

    set out ""
    set i 0
    for {set r 0} {$r < $nrows} {incr r} {
	incr i
	foreach x {left right top bottom topspot_pic_id pic_filename small_pic_filename} {
	    set v_$x [db_get_col $rs $r $x]
	    if {[set v_$x]==""} {
		db_close $rs
		return [handle_err "get_topspot_pics" "error: the value '$x' for one of the pictures is not set up"]
	    }
	}
	append out [writeJavaParamTag smallpic$i $v_small_pic_filename]
	append out [writeJavaParamTag pic$i $v_pic_filename]
	append out [writeJavaParamTag pid$i $v_topspot_pic_id]
	append out [writeJavaParamTag p${i}r_x1 $v_left]
	append out [writeJavaParamTag p${i}r_x2 $v_right]
	append out [writeJavaParamTag p${i}r_y1 $v_top]
	append out [writeJavaParamTag p${i}r_y2 $v_bottom]
    }

    tpBindString PARAMS $out
}

proc H_DoPlaceBalls {} {
    global xgaQryDB

    inf_begin_tran $DB

    #Take out all the old balls for these pictures
    for {set i 1} {$i<=4} {incr i} {
	set id [reqGetArg id$i]
	if [catch {xg_exec_qry $xgaQry(remove_topspot_balls) $id} msg] {
	    inf_rollback_tran $DB
	    return [handle_err "remove_topspot_balls" "err: $msg"]
	}
    }
    
    #New ones in
    for {set p 1} {$p<=4} {incr p} {
	set pid [reqGetArg id$p]
	for {set b 1} {$b<=12} {incr b} {
	    set x [reqGetArg x${p}_${b}]
	    set y [reqGetArg y${p}_${b}]
	    if [catch {xg_exec_qry $xgaQry(add_topspot_ball)\
			   $pid\
			   $b\
			   $x\
			   $y} msg] {
		inf_rollback_tran $DB
		return [handle_err "add_topspot_ball" "err: $msg"]
	    }
	}
    }    
    inf_commit_tran $DB

    handle_success "Success" "The positions of the balls have been recorded"
}

proc H_GoTopSpotMark {} {
    global xgaQry USER_ID
    set paramtags ""
    
    set xgame_id [reqGetArg xgame_id]
    set compno  [reqGetArg comp_no]
    set compdate  [reqGetArg draw_at]

    tpBindString XGAME_ID $xgame_id
    
    # Rectangle stuff
    TopSpotPlaceBallsParams $xgame_id

    # First the easy stuff which we've already been given
    foreach p {xgame_id} {
	append paramtags "<param name=\"$p\" value=\"[set $p]\">\n"
    }

    # Then the picture names
    if [catch {set rs [xg_exec_qry $xgaQry(get_topspot_pictures)\
			   $xgame_id]} msg] {
	return [handle_err "get_topspot_pictures" $xgame_id \
		    "error retrieving xgame: $msg"]
    }
    set nrows [db_get_nrows $rs]
    for {set r 0} {$r < $nrows} {incr r} {
	set filename [db_get_col $rs $r pic_filename]
	set small_filename [db_get_col $rs $r small_pic_filename]
	set number [db_get_col $rs $r number]
	set id [db_get_col $rs $r topspot_pic_id]
	append paramtags "<param name=\"pic$number\" value=\"$filename\">\n"
	append paramtags "<param name=\"smallpic$number\" value=\"$small_filename\">\n"
	append paramtags "<param name=\"pid$number\" value=\"$id\">\n"
    }

    # Then the ball locations
    if [catch {set rs [xg_exec_qry $xgaQry(get_topspot_balls)\
			   $xgame_id]} msg] {
	return [handle_err "get_topspot_balls" $xgame_id \
		    "error retrieving xgame: $msg"]
    }
    set nrows [db_get_nrows $rs]
    for {set r 0} {$r < $nrows} {incr r} {
	foreach v {ball_number pic_number x y} {
	    set v_$v [db_get_col $rs $r $v]
	}
	foreach xy {x y} {
	    append paramtags "<param name=\"pic${v_pic_number}spot${v_ball_number}${xy}\" value=\"[set v_$xy]\">\n"
	}
	append paramtags "<param name=\"pic${v_pic_number}spot${v_ball_number}id\" value=\"${v_pic_number}_${v_ball_number}\">\n"

    }
    db_close $rs

    tpBindString PARAMTAGS $paramtags
    bind_comp_date_param_tags $xgame_id
    X_play_file "topspot/tsMarkGame.html"
}

proc H_DoTopSpotMark {} {

    global xgaQry

    set xgame_id [reqGetArg xgame_id]
    for {set i 1} {$i<=4} {incr i} {
	set id$i [reqGetArg id$i]
	if {[set id$i]>12.0 || [set id$i]<1.0} {
	    return [handle_err "Applet Error" "The applet has returned an illegal ball number (there is no such ball [set id$i]). Please try again."]
	}
    }
    
    set final_answer "1_${id1}|2_${id2}|3_${id3}|4_${id4}"
    
    if [catch [xg_exec_qry $xgaQry(update_results) $final_answer $xgame_id] msg] {
	return [handle_err "update_results"\
		    "error: $msg"]
    }
    
    handle_success "Results updated" "The correct results were entered as balls $id1, $id2, $id3, $id4 (respectively)"

}

proc bind_comp_date_param_tags {xgame_id} {
    global xgaQry

    if [catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg] {
	[handle_err "Can't get details" "for xgame_id $xgame_id: $msg"]
    }

    tpBindString COMP_NO [db_get_col $rs 0 comp_no]
    tpBindString DRAW_AT [short_date [db_get_col $rs 0 draw_at]]

    db_close $rs
}

proc short_date {informix_date} {
    regexp {^....-(..)-(..)} $informix_date junk month day
    return "$day/$month"
}
