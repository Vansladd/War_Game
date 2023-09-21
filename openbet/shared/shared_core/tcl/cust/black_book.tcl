# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Customer black book functionality and interfaces
#
set pkg_version 1.0
package provide core::cust::black_book $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::cust::black_book \
	-version   $pkg_version \
	-desc      {API for Black Book Functionality} \
	-dependent [list \
		core::cust \
		core::log \
		core::args \
		core::check] \
	-docs xml/cust/black_book.xml

namespace eval core::cust::black_book {
	
}

# Register customer session.
core::args::register \
	-interface core::cust::black_book::init

# Load the Black Book entries for a customer from
# the database and store within a cache (BB array)
#
# Returns a list of all the follower competitor ids
#
#   cust_id  - customer id
#   force    - force reloading of rules for the same customer
#
core::args::register \
	-interface core::cust::black_book::load \
	-desc      {Loads BlackBook Preferences} \
	-returns   ASCII \
	-args [list \
		[list -arg -cust_id    -mand 1 -check INT  -desc {Customer's id}] \
		[list -arg -force      -mand 0 -check BOOL -default 0  -desc {Force Reloading Rules}] \
	]


# Retrieve data about a followed competitor
#
# competitor_id - The competitor follower id
# key           - The name of the attribute that we want to retrieve
#
core::args::register \
	-interface core::cust::black_book::get \
	-desc      {Retrieve data about a followed competitor} \
	-returns   ASCII \
	-args [list \
		[list -arg -competitor_id -mand 1 -check INT -desc {Competitor's id}] \
		[list -arg -key           -mand 1 -check ANY -desc {Attribute we want to retrieve}] \
	]


# Follow a competitor
#
# cust_id       - Customer id
# sort          - Denotes how the entry was populated (M)anually or (A)utomatically
# ref_type      - The type of competitor we want to follow
# ref_data      - The competitor name
# ev_class_sort - Class sort
# comments      - Comments for the particular following.
#
# Should retun [list OK] in success [list ERROR msg] in failure!!!

core::args::register \
	-interface core::cust::black_book::follow \
	-desc      {Follow a competitor} \
	-returns   ASCII \
	-args [list \
		[list -arg -cust_id       -mand 1 -check INT   -desc {Customer's Id}] \
		[list -arg -sort          -mand 0 -check ASCII -default M -desc {The way entry popoulated (Manually/Automatically)}] \
		[list -arg -ref_type      -mand 1 -check ASCII -desc {Type of competitor we want to follow}] \
		[list -arg -ref_data      -mand 1 -check ASCII -desc {The competitor's name}] \
		[list -arg -ev_class_sort -mand 1 -check ASCII -desc {Class Sort}] \
		[list -arg -comments      -mand 0 -check ASCII -default {} -desc {Comments for the particular following}] \
	]


# Update a competitor
#
# cust_id              - Customer id
# follow_competitor_id - competitor/subscription id
# sort                 - Denotes how the entry was populated (M)anually or (A)utomatically
# ref_type             - The type of competitor we want to follow
# ref_data             - The competitor name
# ev_class_sort        - Class sort
# comments             - Comments for the particular following.
#
 
core::args::register \
        -interface core::cust::black_book::update \
        -desc      {Update a competitor} \
  		-return_data [list \
                        [list -arg -follow_competitor_id -mand 1 -check UINT -desc {Competitor's Id}] \
        ] \
    	-args	[list \
                [list -arg -cust_id              -mand 1 -check UINT   -desc {Customer's Id}] \
                [list -arg -follow_competitor_id -mand 1 -check UINT   -desc {Competitor's Id}] \
                [list -arg -sort                 -mand 1 -check ASCII -desc {The way entry populated (Manually/Automatically)}] \
                [list -arg -ref_type             -mand 1 -check ASCII -desc {Type of competitor we want to follow}] \
                [list -arg -ref_data             -mand 1 -check ASCII -desc {The competitor's name}] \
                [list -arg -ev_class_sort        -mand 1 -check ASCII -desc {Class Sort}] \
                [list -arg -comments             -mand 0 -check ASCII -default {} -desc {Comments for the particular following}] \
        ] \
        -errors [list SERVER_ERROR OB_ERR_CUST_NOT_FOUND INVALID_UPDATE_ID UNKNOWN_COMPETITOR INVALID_SORT INVALID_ACTION INVALID_ARGS] 

# Stop following a competitor
#
# cust_id              - The customer
# follow_competitor_id - The following
#
# Should retun [list OK] in success [list ERROR msg] in failure!!!

core::args::register \
	-interface core::cust::black_book::unfollow \
	-desc      {Stop Following a competitor} \
	-returns   ASCII \
	-args [list \
		[list -arg -cust_id              -mand 1 -check INT -desc {Customer's Id}] \
		[list -arg -follow_competitor_id -mand 1 -check INT -desc {Competitor's Id}] \
	]
	



	
