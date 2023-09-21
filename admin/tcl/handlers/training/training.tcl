

# Init pre handler
core::controller::add_pre_handler \
    -name    REQ_INIT \
    -handler req_init \
    -is_auth 1 \
    -args    [list \
				[list -type header -name HTTP_ACCEPT_LANGUAGE                          -check STRING] \
				[list -type header -name HTTP_COOKIE                                   -check STRING] \
				[list -type header -name HTTP_HOST                        -mandatory 1 -check ASCII] \
				[list -type header -name REQUEST_URI                      -mandatory 1 -check ASCII] \
				[list -type header -name SERVER_PORT                      -mandatory 1 -check UINT] \
				[list -type header -name CONTENT_TYPE                                  -check ASCII] \
				[list -type arg    -name SubmitName                                    -check ASCII] \
				[list -type cookie -name [OT_CfgGet LOGIN_COOKIE_NAME]                 -check STRING] \
				[list -type arg    -name uid                                           -check UINT] \
				[list -type arg    -name action                                        -check STRING] \
			]

# post handler for binding request information
	core::controller::add_post_handler \
		-name    REQ_END \
		-handler req_end \
		-args   [list \
				[list -type header -name HTTP_ACCEPT_LANGUAGE                          -check STRING] \
				[list -type header -name HTTP_COOKIE                                   -check STRING] \
				[list -type header -name HTTP_HOST                        -mandatory 1 -check ASCII] \
				[list -type header -name REQUEST_URI                      -mandatory 1 -check ASCII] \
				[list -type header -name SERVER_PORT                      -mandatory 1 -check UINT] \
				[list -type header -name CONTENT_TYPE                                  -check ASCII] \
				[list -type arg    -name SubmitName                                    -check ASCII] \
				[list -type cookie -name [OT_CfgGet LOGIN_COOKIE_NAME]                 -check STRING] \
				[list -type arg    -name uid                                           -check UINT] \
				[list -type arg    -name action                                        -check STRING] \
			]

core::controller::add_handler \
	-action        TRAINING_PlayPageNew \
	-handler       TRAINING::go_play_page_new \
	-pre_handlers  REQ_INIT \
	-post_handlers REQ_END \
	-req_type      GLOBAL

		
core::controller::add_handler \
	-action        TRAINING_tpBindStringNew \
	-handler       TRAINING::go_tpBindString_new \
	-pre_handlers  REQ_INIT \
	-post_handlers REQ_END \
	-req_type      GLOBAL

core::controller::add_handler \
	-action        TRAINING_go_reqGetArgNew \
	-handler       TRAINING::go_reqGetArg_new \
	-pre_handlers  REQ_INIT \
	-post_handlers REQ_END \
	-req_type      GLOBAL
	
core::controller::add_handler \
	-action        TRAINING_do_reqGetArgNew \
	-handler       TRAINING::do_reqGetArg_new \
	-pre_handlers  REQ_INIT \
	-post_handlers REQ_END \
	-req_type      GLOBAL \
	-args   [list \
				[list -type arg -name cust_id            -check UINT] \
			]