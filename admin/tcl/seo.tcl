

namespace eval ADMIN::SEO {

	asSetAct ADMIN::SEO::GoSEOMain       [namespace code go_seo_main]
	asSetAct ADMIN::SEO::GoSEOPKW        [namespace code go_seo_pkws]
	asSetAct ADMIN::SEO::GoSEOTags       [namespace code go_seo_tags]

	variable INIT 0
	variable HIERARCHY
	variable SEO

proc _init args {

	variable INIT
	variable HIERARCHY

	if {$INIT} {
		return
	}

	array set SEO [list]
	# Set default
	set SEO(channel_id) "I"

	array set HIERARCHY { "7,name"  "HOME"     "7,table"  "none"        "7,id"  "none"           "7,title"  "none"\
		              "6,name"  "GLOBAL"   "6,table"  "none"        "6,id"  "none"           "6,title"  "none"\
		              "5,name"  "CATEGORY" "5,table"  "tEvCategory" "5,id"  "ev_category_id" "5,title"  "category"\
		              "4,name"  "CLASS"    "4,table"  "tEvClass"    "4,id"  "ev_class_id"    "4,title"  "name"\
		              "3,name"  "REGION"   "3,table"  "tRegion"     "3,id"  "region_id"      "3,title"  "name"\
		              "2,name"  "COUPON"   "2,table"  "tCoupon"     "2,id"  "coupon_id"      "2,title"  "desc"\
		              "1,name"  "TYPE"     "1,table"  "tEvType"     "1,id"  "ev_type_id"     "1,title"  "name"\
		              "0,name"  "EVENT"    "0,table"  "tEv"         "0,id"  "ev_id"          "0,title"  "desc"\
		              "max_level" 7}

	## Get Select Site Options
	get_channel_grp_list

	set INIT 1
}



proc go_seo_main args {

	_init

	variable SEO

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
 		asPlayFile -nocache error_rpt.html
 		return
	}

	set SubmitName [reqGetArg SubmitName]

	switch $SubmitName {

		"changeLang" {
			if {[reqGetArg from] == "pkw"} {
				go_seo_pkws
			} else {
				go_seo_tags
			}
			return
		}

		"goSpecific" {
			set SEO(specific) 1
			go_seo_tags
			return
		}

		"showTags" {
			go_seo_tags
			return
		}

		"saveTags" {
			save_seo_tags
			return
		}

		"deleteTag" {
			delete_seo_tag
			return
		}

		"addPKW" {
			add_seo_pkw
			return
		}

		"deletePKW" {
			delete_seo_pkw
			return
		}

		"Back" {

			# Bind for Go Specific Levels on Main Page
			bind_levels_list "h" 5
			bind_channel_grp_list

			# This will ensure the user is taken back to the correct page.
			if {[lsearch {seo tags pkw} [reqGetArg from]] == -1} {
				set back_cmd "ADMIN::[reqGetArg back_proc] [reqGetArg back_proc_args]"

				set names  [split [reqGetArg back_proc_args_name] " "]
				set values [split [reqGetArg back_proc_args_value] " "]
				set pairs  [list]

				if {[llength $names] > 0 && [llength $values] > 0} {

					for {set i 0} {$i < [llength $names]} {incr i} {
						lappend pairs [lindex $names  $i]
						lappend pairs [lindex $values $i]
					}
	
					foreach {eachName eachValue} $pairs {
						reqSetArg $eachName $eachValue
					}
				}

				eval $back_cmd
				return
			}
		}

		default {
			# Bind for Go Specific Levels on Main Page
			bind_levels_list "h" 5
		}
	}

	bind_channel_grp_list

	asPlayFile seo_main.html
}



#
# Displays the generic SEO tag editor
#
proc go_seo_tags args {

	_init

	variable HIERARCHY
	variable SEO

	global DB STATICS TAGS SELECT_SITE

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
		asPlayFile -nocache error_rpt.html
 		return
	}

	get_html_args

	if {$SEO(level_id) == ""} {
		set SEO(level_id) -1
	}

	if {$SEO(level) == "Static"} {

		tpSetVar static "Y"
		set SEO(tag_level) "Global"

		#
		# Get list of statics for select box drop down
		#
		set sql [subst {
			select
				static_id,
				static_name,
				static_url
			from
				tMetaTagsStatic
			where
				channel_id = '$SEO(channel_id)'
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		set numStatic [db_get_nrows $rs]

		for {set i 0} {$i < $numStatic} {incr i} {
			set STATICS($i,static_id)   [db_get_col $rs $i static_id]
			set STATICS($i,static_name) [db_get_col $rs $i static_name]
			set STATICS($i,static_url)  [db_get_col $rs $i static_url]
		}

                db_close $rs
  
		set sql [subst {
			select
				static_url,
				static_name
			from
				tMetaTagsStatic
			where
				static_id = $SEO(level_id)
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		if {[db_get_nrows $rs] > 0} {
			tpBindString STATIC_URL      [db_get_col $rs 0 static_url]
			tpBindString STATIC_NAME_SEL [db_get_col $rs 0 static_name]
		}

                db_close $rs

		if {[reqGetArg static_edit] == "Y"} {
			tpBindString STATIC_EDIT    "Y"
			tpBindString STATIC_CHECKED checked
			tpSetVar     STATIC_SEL     $SEO(level_id)
		}

		tpSetVar   numStatic     $numStatic
		tpBindVar  STATIC_ID     STATICS   static_id     static_idx
		tpBindVar  STATIC_NAME   STATICS   static_name   static_idx
	}

	if {$SEO(level) == "Home"} {
		tpSetVar HomePage  "Y"
		set SEO(level_id)  0
		set SEO(tag_level) "Global"
	}

	#
	# Get the tag for the currently selected level
	#

	set sql [subst {
		select
			t.text,
			t.text_2,
			t.text_3
		from
			tMetaTagsID   i,
			tMetaTagsText t
		where
			i.level           = '[string toupper $SEO(level)]'     and
			i.tag_level       = '[string toupper $SEO(tag_level)]' and
			i.id              =  $SEO(level_id)                    and
			i.tag_type        = ?                                  and
			t.lang            = '$SEO(language)'                   and
			i.tag_template_id = t.tag_template_id                  and
			i.channel_id      = '$SEO(channel_id)'                 and
			t.channel_id      = '$SEO(channel_id)'
	}]

	foreach tagType {TITLE DESC KEY H1H2} {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $tagType]

		if {[db_get_nrows $rs] > 0} {
			set tag_text    [db_get_col $rs 0 text]
			append tag_text [db_get_col $rs 0 text_2]
			append tag_text [db_get_col $rs 0 text_3]
			tpBindString ${tagType}_TAG $tag_text
			tpSetVar     TAGS_EXIST     1
		} else {
			tpSetVar     TAGS_EXIST     0
		}

		inf_close_stmt $stmt
                db_close $rs
	}

	#
	# languages
	#
	bind_languages
	tpBindString LangSel $SEO(language)

	#
	# Bind a list of;
	#  Current hierarchy level -> Event
	#  Class -> Event
	#
	set level_number [get_level_number $SEO(level)]
	bind_levels_list "h"   $level_number
	bind_levels_list "dki" 5

	if {[info exists SEO(specific)]} {

		set sql [subst {
			select
				NVL([set HIERARCHY($level_number,title)],'') as title
			from
				[set HIERARCHY($level_number,table)]
			where
				[set HIERARCHY($level_number,id)] = $SEO(level_id)
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] > 0} {
			set SEO(level_title) [db_get_col $rs 0 title]
		} else {
			tpSetVar INVALID 1
		}

                db_close $rs
		unset SEO(specific)
	}

	tpSetVar        SEL_LEVEL            $SEO(tag_level)

	tpBindString    LEVEL                $SEO(level)
	tpBindString    LEVEL_ID             $SEO(level_id)
	tpBindString    LEVEL_TITLE          $SEO(level_title)

	tpBindString    FROM                 [reqGetArg from]
	tpBindString    BACK_PROC            [reqGetArg back_proc]
	tpBindString    BACK_PROC_ARGS       [reqGetArg back_proc_args]
	tpBindString    BACK_PROC_ARGS_NAME  [reqGetArg back_proc_args_name]
	tpBindString    BACK_PROC_ARGS_VALUE [reqGetArg back_proc_args_value]

	bind_channel_grp_list

	asPlayFile seo_tags.html
}


# bind active languages
proc bind_languages {{displayed_only N}} {

	global DB
	global LANGUAGES

	set sql [subst {
		select
			lang,
			name
		from
			tLang
		where
			displayed in ('Y','$displayed_only')
		order by
			disporder
	}]

	# retrieve language codes and descriptions
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt  $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set LANGUAGES($i,lang_code) [db_get_col $rs $i lang]
		set LANGUAGES($i,lang_name) [db_get_col $rs $i name]
	}

	db_close $rs

	tpSetVar NumLangs $nrows

	# bind data
	tpBindVar lang_code LANGUAGES lang_code lang_idx
	tpBindVar lang_name LANGUAGES lang_name lang_idx

	return
}


#
# Returns the hierarchy level number as defined in HIERARCHY array
#  for a given name
#   eg Category would return 4
#
proc get_level_number {name} {

	variable HIERARCHY
	variable SEO

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
        	asPlayFile -nocache error_rpt.html
 		return
	}

	for {set i 0} {$i < $HIERARCHY(max_level)} {incr i} {
		if {[string toupper $name] == $HIERARCHY($i,name)} {
			break
		}
	}

	return $i
}


proc bind_levels_list {{id "LEVEL"} {level 0}} {

	global   ${id}_BIND
	variable HIERARCHY

	for {set i 0} {$i <= $level} {incr i} {
		set ${id}_BIND($i,name) $HIERARCHY([expr $level - $i],name)
	}

	tpSetVar  num_${id}_Levels [expr $level + 1]
	tpBindVar ${id}_NAME    ${id}_BIND    name    ${id}_idx
}




proc save_seo_tags args {

	global DB
	variable SEO

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
		asPlayFile -nocache error_rpt.html
 		return
	}

	get_html_args
	if {[llength $args] > 0} {
		foreach eachArg {level level_id tag_level skip_seo_return} {
			if {[lsearch $args $eachArg] >= 0} {
				set SEO($eachArg) [lindex $args [expr [lsearch $args $eachArg] + 1]]
			}
		}
	}

	# If the tags are all blank then we delete the tag
	if { $SEO(title_tag) == "" && \
		$SEO(desc_tag)  == "" && \
		$SEO(key_tag)   == "" && \
		$SEO(h1h2_tag) == "" } {

		delete_seo_tag
		return
	}

	if {$SEO(level_id) == ""} {
		set SEO(level_id) 0
	}

	#
	# If static page we need a static id.
	#  this is either retrieved or created
	#
	if {$SEO(level) == "Static"} {

		set sql [subst {
			execute procedure pInsMetaStatic (
				p_static_id   = ?,
				p_static_name = ?,
				p_static_url  = ?,
				p_channel_id  = ?
			);
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set rs [inf_exec_stmt $stmt             \
                                                  $SEO(level_id)    \
                                                  $SEO(static_name) \
                                                  $SEO(static_url)  \
                                                  $SEO(channel_id)]} msg]} {
                 ob_log::write WARNING $msg

		} else {
			set msg "Static pages inserted / updated"

		}

		# Get the static_id
		set SEO(level_id)  [db_get_coln $rs 0 0]
		set SEO(tag_level) "GLOBAL"
                db_close $rs
	}

	if {$SEO(level) == "Home"} {
		set SEO(tag_level) "Global"
	}

	set sql [subst {
		execute procedure pInsMetaTags (
			p_level        = ?,
			p_id           = ?,
			p_tag_level    = ?,
			p_lang         = ?,
			p_title_text   = ?,
			p_title_text_2 = ?,
			p_title_text_3 = ?,
			p_desc_text    = ?,
			p_desc_text_2  = ?,
			p_desc_text_3  = ?,
			p_key_text     = ?,
			p_key_text_2   = ?,
			p_key_text_3   = ?,
			p_h1h2_text    = ?,
			p_h1h2_text_2  = ?,
			p_h1h2_text_3  = ?,
			p_channel_id_1 = ?,
			p_channel_id_2 = ?
		);
	}]

	set stmt [inf_prep_sql $DB $sql]

	# Split texts into 3 parts of 255 (there is code for this for the message codes)
	set title_tag_parts [split_to_pieces 255 $SEO(title_tag) 3 M]
	set desc_tag_parts  [split_to_pieces 255 $SEO(desc_tag)  3 M]
	set key_tag_parts   [split_to_pieces 255 $SEO(key_tag)   3 M]
	set h1h2_tag_parts  [split_to_pieces 255 $SEO(h1h2_tag)  3 M]

	if {[catch {set rs [inf_exec_stmt $stmt                            \
	                                  [string toupper $SEO(level)]     \
	                                  $SEO(level_id)                   \
	                                  [string toupper $SEO(tag_level)] \
	                                  $SEO(language)                  \
	                                  [lindex $title_tag_parts 0]     \
	                                  [lindex $title_tag_parts 1]     \
	                                  [lindex $title_tag_parts 2]     \
	                                  [lindex $desc_tag_parts 0]      \
	                                  [lindex $desc_tag_parts 1]      \
	                                  [lindex $desc_tag_parts 2]      \
	                                  [lindex $key_tag_parts 0]       \
	                                  [lindex $key_tag_parts 1]       \
	                                  [lindex $key_tag_parts 2]       \
	                                  [lindex $h1h2_tag_parts 0]      \
	                                  [lindex $h1h2_tag_parts 1]      \
	                                  [lindex $h1h2_tag_parts 2]      \
					  $SEO(channel_id)                \
					  $SEO(channel_id)]} msg]} {
               ob_log::write WARNING $msg
	} else {
		set msg "tags added successfully"
                db_close $rs
	}

	inf_close_stmt $stmt

	if {$SEO(skip_seo_return) == "Y"} {
		return
	} else {
		go_seo_tags
	}

}



proc delete_seo_tag args {

	global DB
	variable SEO

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
		asPlayFile -nocache error_rpt.html
 		return
	}

	get_html_args

	if {$SEO(level) == "Static"} {
		set sql [subst {
			delete
				tMetaTagsStatic
			where
				static_id   = $SEO(level_id) and
				channel_id  = '$SEO(channel_id)'
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
                        ob_log::write WARNING $msg
		} else {
			set msg "static page removed"
                        db_close $rs
		}

		inf_close_stmt $stmt
	}

	set sql [subst {
		execute procedure pDelMetaTag (
			p_id         = $SEO(level_id),
			p_level      = '[string toupper $SEO(level)]',
			p_tag_level  = '[string toupper $SEO(tag_level)]',
			p_lang       = '$SEO(language)',
			p_channel_id = '$SEO(channel_id)'
		);
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
                ob_log::write WARNING $msg
	} else {
		 set msg "tags deleted successfully"
                 db_close $rs
	}

	inf_close_stmt $stmt

	go_seo_tags
}



#
# Displays the PKW edit page
#
proc go_seo_pkws {{msg ""}} {

	global DB PKW
	variable SEO

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
             	asPlayFile -nocache error_rpt.html
 		return
	}

	get_html_args

	#
	# get all PKWs in selected language
	#  order alphabetically
	#
	set sql [subst {
		select
			pkw_id,
			pkw
		from
			tMetaTagsPKW
		where
			lang = '$SEO(language)'
		order by
			pkw
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set numPKW [db_get_nrows $rs]

	for {set i 0} {$i < $numPKW} {incr i} {
		set PKW($i,pkw_id) [db_get_col $rs $i pkw_id]
		set PKW($i,pkw)    [db_get_col $rs $i pkw]
	}

        db_close $rs
	#
	# languages
	#
	bind_languages
	tpBindString LangSel $SEO(language)

	#
	# Bind remaining shizzle
	#
	tpBindString MSG     $msg

	tpSetVar     numPKW    $numPKW
	tpBindVar    PKW_ID    PKW    pkw_id    pkw_idx
	tpBindVar    PKW       PKW    pkw       pkw_idx

	asPlayFile seo_pkws.html

}


#
# Add a new problem key word to the DB
#
proc add_seo_pkw args {

	global DB

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
		asPlayFile -nocache error_rpt.html
 		return
	}

	set pkw  [reqGetArg pkw]
	set language [reqGetArg language]

	set sql [subst {
		insert into tMetaTagsPKW(
			pkw,
			lang
		)
		values (
			'[string tolower $pkw]',
			'$language'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
               ob_log::write WARNING $msg
	} else {
		set msg "<b>[string tolower $pkw]</b> successfully added"
	}

        db_close $rs
	inf_close_stmt $stmt


	go_seo_pkws $msg

}

#
# Remove a problem key word from the DB
#
proc delete_seo_pkw args {

	global DB

	if {![op_allowed SeoTags]} {
 		err_bind "You do not have permission to edit SEO tags"
             	asPlayFile -nocache error_rpt.html
 		return
	}

	set pkw_id [reqGetArg pkwID]

	set sql [subst {
		delete from
			tMetaTagsPKW
		where
			pkw_id = $pkw_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		set msg $msg
	} else {
		set msg "PKW successfully removed"
                db_close $rs
	}

	inf_close_stmt $stmt
ADMIN::SEO::GoSEOMain
	go_seo_pkws $msg

}


proc get_html_args args {

	variable SEO

	set SEO(SubmitName)      [reqGetArg SubmitName]

	set SEO(level)           [reqGetArg level]
	set SEO(level_id)        [reqGetArg level_id]
	set SEO(level_title)     [reqGetArg level_title]

	set SEO(static_id)       [reqGetArg static_id]
	set SEO(static_name)     [reqGetArg static_name]
	set SEO(static_url)      [reqGetArg static_url]

	set SEO(title_tag)       [string trim [reqGetArg title_tag]]
	set SEO(desc_tag)        [string trim [reqGetArg desc_tag]]
	set SEO(key_tag)         [string trim [reqGetArg key_tag]]
	set SEO(h1h2_tag)        [string trim [reqGetArg h1h2_tag]]

	set SEO(tag_level)       [reqGetArg tag_level]

	set SEO(language)        [reqGetArg language]

	set SEO(skip_seo_return) [reqGetArg go_skip_seo_return]

	set SEO(channel_id)      [reqGetArg channel_id]

	# Default language to english, tag_level to Global,
	# level_id to 0
	if {$SEO(language) == ""}  {set SEO(language) "en"}
	if {$SEO(tag_level) == ""} {set SEO(tag_level) $SEO(level)}
}


proc get_channel_grp_list args {

	global DB
	global SELECT_SITE

 	#
	# get all channels for the INT(ernet) Group
	#
	set sql [subst {
		select
			c.channel_id,
			c.desc
		from
			tChannel     c,
			tChanGrpLink g
		where
			c.channel_id = g.channel_id and
			g.channel_grp = "INT"
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set SELECT_SITE($i,channel_id) [db_get_col $rs $i channel_id]
		set SELECT_SITE($i,desc) [db_get_col $rs $i desc]
	}
        db_close $rs
	set SELECT_SITE(nrows) $nrows
}

proc bind_channel_grp_list args {

	global SELECT_SITE
	variable SEO

	# Dislay selected channel
	if {[info exists SEO(channel_id)]} {
		for {set i 0} {$i < $SELECT_SITE(nrows)} {incr i} {
			if {$SELECT_SITE($i,channel_id) == $SEO(channel_id)} {
				tpBindString CHANNEL_ID $SEO(channel_id)
				tpBindString CHANNEL_DESC $SELECT_SITE($i,desc)
				break
			}
		}
		
	}

	tpSetVar  num_sites    $SELECT_SITE(nrows)
	tpBindVar channel_id   SELECT_SITE channel_id site_idx
	tpBindVar channel_desc SELECT_SITE desc       site_idx
}


# End ADMIN::SEO namespace
}
