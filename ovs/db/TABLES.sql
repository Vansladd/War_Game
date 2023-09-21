--
------------------------------------------------------------------------------
-- $Id: TABLES.sql,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
-- $Name:  $
--
-- Verification Server table schema
-- Copyright (c) 2005 Orbis Technology Ltd. All rights reserved
------------------------------------------------------------------------------
--



-------------------------------------------------------------------------------
-- CHECKING DEFINITION SECTION
--
-- This section deals with the definition of checks
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- tVrfPrflDef
--
-- Table containing profile definitions. Profiles allow a series of checks to
-- be grouped together for specific purposes.
--
-- vrf_prfl_def_id - PK
-- vrf_prfl_code   - Unique identifying four character code (easier than an ID
--                   to remember
-- cr_date         - time row was created
-- status          - whether the profile is 'A'ctive or 'S'uspended
-- desc            - short description of the profile definition
-- blurb           - detailed description of the profile definition
-- channels        - channels to which this profile definition applies
-------------------------------------------------------------------------------

!echo creating tVrfPrflDef
create table tVrfPrflDef (
	vrf_prfl_def_id serial                         not null,
	vrf_prfl_code   char(4)                        not null,
	cr_date         datetime year to second
	                default current year to second not null,
	status          char(1) default 'A'            not null,
	desc            varchar(80,0)                  not null,
	blurb           varchar(255),
	channels        varchar(32,0)
)
	extent size 8 next size 8
	lock mode row;

create unique index iVrfPrflDef_x1 on tVrfPrflDef (vrf_prfl_def_id);
create unique index iVrfPrflDef_x2 on tVrfPrflDef (desc);
create unique index iVrfPrflDef_x3 on tVrfPrflDef (vrf_prfl_code);

alter table tVrfPrflDef add constraint (
	primary key (vrf_prfl_def_id)
		constraint cVrfPrflDef_pk
);
alter table tVrfPrflDef add constraint (
	unique (desc)
		constraint cVrfPrflDef_u1
);
alter table tVrfPrflDef add constraint (
	unique (vrf_prfl_code)
		constraint cVrfPrflDef_u2
);



-------------------------------------------------------------------------------
-- tVrfPrflAct
--
-- Table containing profile actions. Profile actions allow any number of
-- actions to be taken based on the score of the profile.
--
-- Actions can either put a customer into a pending state, (ie do nothing to
-- the customer, and mark it for the attention of an operator), suspend the
-- account, do nothing.or reactivate the account
--
-- vrf_prfl_act_id - PK
-- vrf_prfl_def_id - FK to tVrfPrflDef.vrf_prfl_def_id
-- cr_date         - time row was created
-- action          - what action to perform on the customer account
-- high_score      - upper boundary for the action, which can be null for
--                   actions without an upper limit
-------------------------------------------------------------------------------
!echo creating tVrfPrflAct
create table tVrfPrflAct (
	vrf_prfl_act_id serial                         not null,
	vrf_prfl_def_id integer                        not null,
	cr_date         datetime year to second
	                default current year to second not null,
	action          char(1)                        not null,
	high_score      integer
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfPrflAct_x1 on tVrfPrflAct (vrf_prfl_act_id);
create        index iVrfPrflAct_x2 on tVrfPrflAct (vrf_prfl_def_id);

alter table tVrfPrflAct add constraint (
	primary key (vrf_prfl_act_id)
		constraint cVrfPrflAct_pk
);
alter table tVrfPrflAct add constraint (
	foreign key (vrf_prfl_def_id)
		references tVrfPrflDef
			constraint cVrfPrflAct_fk
);
alter table tVrfPrflAct add constraint (
	check (action in (
		'A', -- (A)ctivate
		'P', -- (P) - Restricted
		'S', -- (S)uspend
		'U', -- (U)nderage
		'N'  -- (N)othing
		)
	)
	constraint cVrfPrflAct_c1
);

-------------------------------------------------------------------------------
-- tVrfPrflEx
--
-- Table containing profile actions. Profile actions allow any number of
-- actions to be taken based on the score of the profile. The score must be an
-- exact match.
--
-- Actions can either put a customer into a pending state, (ie do nothing to
-- the customer, and mark it for the attention of an operator), suspend the
-- account, do nothing.or reactivate the account
--
-- vrf_prfl_act_id - PK
-- vrf_prfl_def_id - FK to tVrfPrflDef.vrf_prfl_def_id
-- cr_date         - time row was created
-- action          - what action to perform on the customer account
-- high_score      - exact match for the action
-------------------------------------------------------------------------------
!echo creating tVrfPrflEx
create table tVrfPrflEx (
	vrf_prfl_ex_id  serial                         not null,
	vrf_prfl_def_id integer                        not null,
	cr_date         datetime year to second
	                default current year to second not null,
	action          char(1)                        not null,
	score           integer
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfPrflEx_x1 on tVrfPrflEx (vrf_prfl_ex_id);
create        index iVrfPrflEx_x2 on tVrfPrflEx (vrf_prfl_def_id);

alter table tVrfPrflEx add constraint (
	primary key (vrf_prfl_ex_id)
		constraint cVrfPrflEx_pk
);
alter table tVrfPrflEx add constraint (
	foreign key (vrf_prfl_def_id)
		references tVrfPrflDef
			constraint cVrfPrflEx_fk
);
alter table tVrfPrflEx add constraint (
	check (action in (
		'A', -- (A)ctivate
		'P', -- (P) - Restricted
		'S', -- (S)uspend
		'U',  -- (U)nderage
		'N'  -- (N)othing
		)
	)
	constraint cVrfPrflEx_c1
);



-------------------------------------------------------------------------------
-- tVrfPrflCty
--
-- Determines the countries for which a profile applies
--
-- vrf_prfl_def_id - FK to tVrfPrflDef.vrf_prfl_def_id
-- country_code    - FK to tCountry.country_code
-- status          - 'A'ctive     => Does and AV check
--                   'G'race      => Just sets the grace period to the customer.
--                   'S'uspended  => Does nothing!
-------------------------------------------------------------------------------

!echo creating tVrfPrflCty
create table tVrfPrflCty (
	vrf_prfl_def_id integer           not null,
	country_code    char(2)           not null,
	status          char(1)           not null,
	grace_days      integer default 0 not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfPrflCty_x1 on tVrfPrflCty (vrf_prfl_def_id, country_code);
create        index iVrfPrflCty_x2 on tVrfPrflCty (vrf_prfl_def_id);
create        index iVrfPrflCty_x3 on tVrfPrflCty (country_code);

alter table tVrfPrflCty add constraint (
	primary key (vrf_prfl_def_id,country_code)
		constraint cVrfPrflCty_pk
);
alter table tVrfPrflCty add constraint (
	foreign key (vrf_prfl_def_id)
		references tVrfPrflDef
			constraint cVrfPrflCty_fk1
);
alter table tVrfPrflCty add constraint (
	foreign key (country_code)
		references tCountry
			constraint cVrfPrflCty_fk2
);
alter table tVrfPrflCty add constraint (
	check (status in ('A','S','G'))
		constraint cVrfPrflCty_c1
);



-------------------------------------------------------------------------------
-- tVrfChkClass
-- Verification Sub Check Class
--
-- Contains all available classes for each of the tests.
--
-- vrf_chk_class - PK class of check, currently either
--                 URU for ProveURU checks
--                 IP for GeoPoint IP checks
--                 CARD for OpenBet credit card checks
--                 AUTH_PRO for Authenticate Pro checks.
-- description   - detail description of the class
-------------------------------------------------------------------------------
!echo creating tVrfChkClass
create table tVrfChkClass (
	vrf_chk_class  char(8)         not null,
	description   varchar(255,100) not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfChkClass_x1 on tVrfChkClass (vrf_chk_class);

alter table tVrfChkClass add constraint (
	primary key (vrf_chk_class)
		constraint cVrfChkClass_pk
);



-------------------------------------------------------------------------------
-- tVrfChkType
-- Verification Sub Check Type
--
-- Contains all available tests, such as address, telephone number or credit
-- card. Needs to be configured for each customer on loading
--
-- vrf_chk_type  - PK
-- vrf_chk_class - fk tVrfChkClass.
-- description   - detail description of the check
-- name          - unique descriptive identifier
-------------------------------------------------------------------------------

!echo creating tVrfChkType
create table tVrfChkType (
	vrf_chk_type  varchar(32,8)    not null,
	vrf_chk_class char(8)          not null,
	description   varchar(255,100) not null,
	name          varchar(80,0)    not null
)
	extent size 32 next size 32
	lock mode row;

create unique index iVrfChkType_x1 on tVrfChkType (vrf_chk_type);

alter table tVrfChkType add constraint (
	primary key (vrf_chk_type)
		constraint cVrfChkType_pk
);
alter table tVrfChkType add constraint (
	foreign key (vrf_chk_class)
		references tVrfChkClass
			constraint cVrfChkType_fk1
);


-------------------------------------------------------------------------------
-- tVrfChkDef
--
-- Represents a check defined by its vrf_chk_type.
-- Can chain together different checks based on a pass score if desired.
--
-- vrf_chk_def_id   - PK
-- vrf_prfl_def_id  - FK to tVrfPrflDef.vrf_prfl_def_id
-- vrf_chk_type     - FK to tVrfChkType.vrf_chk_type
-- cr_date          - Date row was inserted
-- status           - Status of 'A'ctive or 'S'uspended
-- channels         - channels for which this check is performed
-- check_no         - order check appears in the check group
-------------------------------------------------------------------------------

!echo creating tVrfChkDef
create table tVrfChkDef (
	vrf_chk_def_id  serial                         not null,
	vrf_prfl_def_id integer                        not null,
	vrf_chk_type    varchar(32,8)                  not null,
	cr_date         datetime year to second
	                default current year to second not null,
	status          char(1) default 'A'            not null,
	channels        varchar(32,0),
	check_no        integer                        not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfChkDef_x1 on tVrfChkDef (vrf_chk_def_id);
create        index iVrfChkDef_x2 on tVrfChkDef (vrf_prfl_def_id);
create        index iVrfChkDef_x3 on tVrfChkDef (vrf_chk_type);
create unique index iVrfChkDef_x5 on tVrfChkDef (vrf_prfl_def_id, vrf_chk_type);

alter table tVrfChkDef add constraint (
	primary key (vrf_chk_def_id)
		constraint cVrfChkDef_pk
);
alter table tVrfChkDef add constraint (
	foreign key (vrf_prfl_def_id)
		references tVrfPrflDef
			constraint cVrfChkDef_fk1
);
alter table tVrfChkDef add constraint (
	foreign key (vrf_chk_type)
		references tVrfChkType
			constraint cVrfChkDef_fk2
);
alter table tVrfChkDef add constraint (
	unique (vrf_prfl_def_id,check_no)
		constraint cVrfChkDef_u1
);
alter table tVrfChkDef add constraint (
	unique (vrf_prfl_def_id,vrf_chk_type)
		constraint cVrfChkDef_u2
);
-- check numbers start from 1
alter table tVrfChkDef add constraint (
	check (check_no >= 0)
		constraint cVrfChkDef_c1
);



-------------------------------------------------------------------------------
-- Provider Section
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfExtProv
--
-- Table containing provider definitions. Profiles allow a series of checks to
-- be grouped together for specific purposes.
--
-- vrf_ext_prov_id         - PK
-- name                    - Name of the service provider
-- status                  - whether the provider is 'A'ctive or 'S'uspended
-- priority                - Determines the order the suppliers should be used when both
--                           have the same services
-------------------------------------------------------------------------------

!echo "creating tVrfExtProv"
create table tVrfExtProv
(
	vrf_ext_prov_id    serial                  not null,
	name               varchar(50)             not null,
	code               varchar(16)             not null,
	status             char(1) default 'A'     not null,
	priority           integer                 not null
)
	extent size 16 next size 16
	lock mode row;

alter table tVrfExtProv add constraint (
	primary key(vrf_ext_prov_id)
		constraint cVrfExtProv_pk
);
alter table tVrfExtProv add constraint (
	unique (name)
		constraint cVrfExtProv_u1
);
alter table tVrfExtProv add constraint (
	check (status in ('A','S'))
		constraint cVrfExtProv_c1
);
alter table tVrfExtProv add constraint (
	check (priority < 1000)
		constraint cVrfExtProv_c2
);



-------------------------------------------------------------------------------
-- tVrfExtProvConn
--
-- Table containing connection parameters for each provider. This includes connection
-- specific information such as SOAP endpoint and SOAP action.
--
-- vrf_ext_conn_id      - PK
-- vrf_ext_prov_id     - FK to tVrfExtProv
-- uri             - The location of the check (or endpoint in the case of SOAP)
-- action          - any identifier set that may need appended to the uri to
--                   identify the check type etc.. SOAP action
-- uname           - any username used for the service
-- password        - any password used for the service
-- status          - whether the provider is 'A'ctive or 'S'uspended
-- type            - Whether the setup is for check authenication (A), getting
--                   an authernication log (L) or some other unforseen provider
--                   connection type (O)
-------------------------------------------------------------------------------

!echo "creating tVrfExtProvConn"
create table tVrfExtProvConn
(
	vrf_ext_conn_id    serial                  not null,
	vrf_ext_prov_id    integer                 not null,
	uri                varchar(255),
	action             varchar(255),
	uname              varchar(50),
	password           varchar(50),
	status             char(1) default 'S'     not null,
	type               char(1)                 not null
)
	extent size 16 next size 16
	lock mode row;

alter table tVrfExtProvConn add constraint (
	primary key(vrf_ext_conn_id)
		constraint cVrfExtProvConn_pk
);
alter table tVrfExtProvConn add constraint (
	foreign key(vrf_ext_prov_id) references tVrfExtProv(vrf_ext_prov_id)
		constraint cVrfExtProvConn_f1
);
alter table tVrfExtProvConn add constraint (
	check (status in ('A','S'))
		constraint cVrfExtProvConn_c1
);
alter table tVrfExtProvConn add constraint (
	check (type in ('A','L','O'))
		constraint cVrfExtProvConn_c2
);



-------------------------------------------------------------------------------
-- tVrfExtProfDef
--
-- Table containing profile to provider mappings. Every provider can have multiple
-- profiles (a profile represents a collection of checks),  which extra information
-- be grouped together for specific purposes.
--
-- vrf_ext_pdef_id - PK
-- vrf_ext_prov_id - (FK) The id of the supplier that the profile belongs to
-- prov_prf_id     - A unique string which identifies the profile.  e.g. a 32
--                   character UUID is used by PROVEURU to determine what data
--                   to expect and from which customer it came from.  The string
--                   NR is used is such functionality is not required.
-- status          - whether the provider is 'A'ctive or 'S'uspended
-- description     - A sentance describing the function of the profile
-------------------------------------------------------------------------------

!echo "creating tVrfExtPrflDef"
create table tVrfExtPrflDef
(
	vrf_ext_pdef_id        serial                  not null,
	vrf_ext_prov_id        integer                 not null,
	prov_prf_id            varchar(50),
	status                 char(1) default 'A'     not null,
	description            varchar(255)
)
	extent size 16 next size 16
	lock mode row;

alter table tVrfExtPrflDef add constraint (
	primary key(vrf_ext_pdef_id)
		constraint cVrfExtPrflDef_pk
);
alter table tVrfExtPrflDef add constraint (
	foreign key(vrf_ext_prov_id) references tVrfExtProv(vrf_ext_prov_id)
		constraint cVrfExtPrflDef_f1
);
alter table tVrfExtPrflDef add constraint (
	check (status in ('A','S'))
		constraint cVrfExtPrflDef_c2
);



-------------------------------------------------------------------------------
-- tVrfExtChkDef
--
-- Table containing check to profile mappings. Every provider can have multiple
-- profiles (a profile represents a collection of checks),  which extra information
-- be grouped together for specific purposes.
--
-- vrf_ext_cdef_id        - PK
-- vrf_chk_type           - The string code representation of a OVS check type.  These
--                          should be identical to the ones used in tVrfChkType.
-- vrf_ext_pdef_id        - (FK) The id of the profile the check belongs to
-------------------------------------------------------------------------------
!echo "creating tVrfExtChkDef"
create table tVrfExtChkDef
(
	vrf_ext_cdef_id    serial                  not null,
	vrf_chk_type       varchar(32,8)           not null,
	vrf_ext_pdef_id    integer                 not null,
	status             char(1) default 'A'     not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfExtChkDef_x1 on tVrfExtChkDef (vrf_ext_pdef_id, vrf_chk_type);

alter table tVrfExtChkDef add constraint (
	primary key(vrf_ext_cdef_id)
		constraint cVrfExtChkDef_pk
);
alter table tVrfExtChkDef add constraint (
	foreign key(vrf_ext_pdef_id) references tVrfExtPrflDef(vrf_ext_pdef_id)
		constraint cVrfExtChkDef_f1
);
alter table tVrfExtChkDef add constraint (
	foreign key(vrf_chk_type) references tVrfChkType(vrf_chk_type)
		constraint cVrfExtChkDef_f2
);
alter table tVrfExtChkDef add constraint (
	check (status in ('A','S'))
		constraint cVrfExtChkDef_c1
);


-------------------------------------------------------------------------------
-- CHECKING SECTION
--
-- This section deals with the recording of the actual performance of checks
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfPrfl
--
-- Represents the information regarding the result of a check group.
-- Each individual check that forms part of a check group on a customer is in
-- tVrfChk.
-- This table wraps every check, whether it is an automated series of checks,
-- an automated single check, or a one-off manual check.
--
-- vrf_prfl_id     - PK
-- vrf_prfl_def_id - FK to tVrfPrflDef.vrf_prfl_def_id
-- cr_date         - time row was created
-- cust_id         - FK to tCustomer.cust_id
-- check_type      - 'M'anual    (ie, generated by an operator)
--                   'A'utomatic (ie, generated by code)
-- action          - 'S'uspended customer
--                   'A'ctivated customer
--                   'N'o action taken
--                   'P'arked customer
--                   [NULL] - assume no action was performed, or operator
--                   navigated away (if a manual check)
-- action_desc     - description of action performed (either auto- or by
--                   operator)
-- user_id         - admin user id of person that performed check
--                   If manual. this should be populated, if automated,
--                   will be blank
-------------------------------------------------------------------------------

!echo creating tVrfPrfl
create table tVrfPrfl (
	vrf_prfl_id     serial                         not null,
	vrf_prfl_def_id integer                        not null,
	cr_date         datetime year to second
	                default current year to second not null,
	cust_id         integer                        not null,
	check_type      char(1)                        not null,
	action          char(1),
	action_desc     varchar(255,0),
	user_id         integer
)
	extent size 131072 next size 131072
	lock mode row;

create unique index iVrfPrfl_x1 on tVrfPrfl (vrf_prfl_id);
create        index iVrfPrfl_x2 on tVrfPrfl (vrf_prfl_def_id);
create        index iVrfPrfl_x3 on tVrfPrfl (cust_id);

alter table tVrfPrfl add constraint (
	primary key (vrf_prfl_id)
		constraint cVrfPrfl_pk
);
alter table tVrfPrfl add constraint (
	foreign key (vrf_prfl_def_id)
		references tVrfPrflDef
			constraint cVrfPrfl_fk1
);
alter table tVrfPrfl add constraint (
	foreign key (cust_id)
		references tCustomer
			constraint cVrfPrfl_fk2
);
alter table tVrfPrfl add constraint (
	check (action in (
		'S', --Suspended
		'A', --Activated
		'N', --Nothing
		'P'  --Parked
		) or action is null
	)
		constraint cVrfPrfl_c2
);



-------------------------------------------------------------------------------
-- tVrfPrflPark
--
-- Lookup table to represent the verification profiles parked pending a
-- decision
--
-- vrf_prfl_id - FK to tVrfPrfl.vrf_prfl_id
-------------------------------------------------------------------------------

!echo creating tVrfPrflPark
create table tVrfPrflPark (
	vrf_prfl_id integer not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfPrflPark_x1 on tVrfPrflPark (vrf_prfl_id);

alter table tVrfPrflPark add constraint (
	primary key (vrf_prfl_id)
		constraint cVrfPrflPark_pk
);
alter table tVrfPrflPark add constraint (
	foreign key (vrf_prfl_id)
		references tVrfPrfl
			constraint cVrfPrflPark_fk1
);



-------------------------------------------------------------------------------
-- tVrfPrflModel
--
-- Maps a payment method to a country for a given profile definition. The
-- existance of an entry in this table enables payment method for the profile
-- definition.
--
-- vrf_prfl_model_id    -
-- vrf_prfl_def_id      - profile id.
-- pay_mthd             - type of payment method eg NTLR, PPAL etc...
-- country_code         - country code.
-- type                 - generic type.
-- grace_days           - number of grace days
-- action               - decides what to do:
--						(S)tatus (defaults to a status code, see tVrfPrflModel.status)
--						(C)heck
-- status               - The status to default to.
--						(A)ctive
--						(P)ending
--						(S)usupended
--						(U)nderage
-- pmt_sort             - Whether to trigger the AV stuff on Deposit or Wtd
-------------------------------------------------------------------------------
!echo creating tVrfPrflModel
create table tVrfPrflModel (
	vrf_prfl_model_id    serial                not null,
	vrf_prfl_def_id      integer               not null,
	pay_mthd             char(4)               not null,
	country_code         char(2)               not null,
	type                 char(1) default '',
	grace_days           integer default 0     not null,
	action               char(1) default 'S',
	status               char(1) default 'P',
	pmt_sort             char(1) default 'D'
)
	extent size 64 next size 64
	lock mode row;

create unique index iVrfPrflModel_x1 on tVrfPrflModel (vrf_prfl_model_id);
create unique index iVrfPrflModel_x2 on tVrfPrflModel (vrf_prfl_def_id, pay_mthd, country_code, type);
create        index iVrfPrflModel_x3 on tVrfPrflModel (pay_mthd);
create        index iVrfPrflModel_x4 on tVrfPrflModel (country_code);

alter table tVrfPrflModel add constraint (
	primary key (vrf_prfl_def_id,pay_mthd,country_code,type)
		constraint cVrfPrflModel_pk
);
alter table tVrfPrflModel add constraint (
	foreign key (vrf_prfl_def_id)
		references tVrfPrflDef (vrf_prfl_def_id)
			constraint cVrfPrflModel_fk1
);
alter table tVrfPrflModel add constraint (
	foreign key (country_code)
		references tCountry (country_code)
			constraint cVrfPrflModel_fk3
);

alter table tVrfPrflModel add constraint (
    check (action in ('C','S'))
	        constraint cVrfPrflModel_c1
);

alter table tVrfPrflModel add constraint (
    check (status in ('A','P','S','U'))
	        constraint cVrfPrflModel_c2
);

alter table tVrfPrflModel add constraint (
	check ( pmt_sort in ('D','W','N'))
		constraint cVrfPrflModel_c3
);

alter table tVrfPrflModel add constraint (
	unique (vrf_prfl_model_id)
		constraint cVrfPrflModel_u1
);



-------------------------------------------------------------------------------
-- tVrfChk
--
-- Represents an individual check that forms part of a check group (see
-- tVrfPrfl). Each individual check is numbered (check_no).
-- Based on the verification sub check type (vrf_chk_type), different tables
-- will be referenced, eg those beginning URU will reference tVrfURUChk
--
-- vrf_check_id    - PK
-- vrf_prfl_id     - FK to tVrfPrfl.vrf_prfl_id
-- cr_date         - time row was created
-- check_no        - order in which check was performed within the check group
-- vrf_chk_type    - verification sub check type
-- vrf_ext_cdef_id - the profile ID that the check was run against (is used to determine
--		     check provider then connection)
-------------------------------------------------------------------------------

!echo creating tVrfChk
create table tVrfChk (
	vrf_check_id      serial                         not null,
	vrf_prfl_id       integer                        not null,
	vrf_chk_def_id    integer                        not null,
	cr_date           datetime year to second
	                  default current year to second not null,
	check_no          smallint                       not null,
	vrf_chk_type      varchar(32,8)                  not null,
	vrf_ext_cdef_id   integer                        not null,
	vrf_prfl_model_id integer  default null
)
	extent size 131072 next size 131072
	lock mode row;

create unique index iVrfChk_x1 on tVrfChk (vrf_check_id);
create unique index iVrfChk_x2 on tVrfChk (vrf_prfl_id, check_no);
create        index iVrfChk_x3 on tVrfChk (vrf_prfl_id);
create        index iVrfChk_x4 on tVrfChk (vrf_chk_def_id);
create        index iVrfChk_x5 on tVrfChk (vrf_chk_type);

alter table tVrfChk add constraint (
	primary key (vrf_check_id)
		constraint cVrfChk_pk
);
alter table tVrfChk add constraint (
	unique (vrf_prfl_id,check_no)
		constraint cVrfChk_u1
);
alter table tVrfChk add constraint (
	foreign key (vrf_prfl_id)
		references tVrfPrfl
			constraint cVrfChk_fk1
);
alter table tVrfChk add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfChk_fk2
);
alter table tVrfChk add constraint (
	foreign key (vrf_chk_type)
		references tVrfChkType
			constraint cVrfChk_fk3
);
alter table tVrfChk add constraint (
	foreign key (vrf_ext_cdef_id)
		references tVrfExtChkDef
			constraint cVrfChk_fk4
);
alter table tVrfChk add constraint (
	foreign key (vrf_prfl_model_id)
		references tVrfPrflModel (vrf_prfl_model_id)
			constraint cVrfChk_fk5
);
alter table tVrfChk add constraint (
	check (check_no >= 0)
		constraint cVrfChk_c1
);



-------------------------------------------------------------------------------
-- IP SECTION
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfIPDef
--
-- Stores scoring value of mismatch between IP address and registered country
--
-- vrf_ip_def_id  - PK
-- vrf_chk_def_id - FK to tVrfChkDef.vrf_chk_def_id
-- cr_date        - time row was created
-- response_type  - whether IP address matches customer country
--                  'U'nknown IP address
--                  'M'atch between IP address and country
--                  'N'o match between IP address and country
-- score          - score awarded
-- country_code   - customer's registered country
-------------------------------------------------------------------------------

!echo creating tVrfIPDef
create table tVrfIPDef (
	vrf_ip_def_id  serial                         not null,
	vrf_chk_def_id integer                        not null,
	cr_date        datetime year to second
	               default current year to second not null,
	response_type  char(1)                        not null,
	score          integer default 0              not null,
	country_code   char(2) default '--'           not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfIPDef_x1 on tVrfIPDef (vrf_ip_def_id);
create        index iVrfIPDef_x2 on tVrfIPDef (vrf_chk_def_id);
create        index iVrfIPDef_x3 on tVrfIPDef (country_code);

alter table tVrfIPDef add constraint (
	primary key (vrf_ip_def_id)
		constraint cVrfIPDef_pk
);
alter table tVrfIPDef add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfIPDef_fk1
);
alter table tVrfIPDef add constraint (
	foreign key (country_code)
		references tCountry
			constraint cVrfIPDef_fk2
);
alter table tVrfIPDef add constraint (
	check (response_type in (
		'U', --'U'nknown
		'M', --'M'atch
		'N'  --'N'o match
		)
	)
		constraint cVrfIPDef_c1
);



-------------------------------------------------------------------------------
-- tVrfIPChk
--
-- Represents an IP check on a customer
--
-- vrf_ip_chk_id - PK
-- vrf_check_id  - FK to tVrfChk.vrf_check_id
-- cr_date       - time row was created
-- expected_ctry - country the user is expected to be from (??) if unknown
-- ip_ctry       - ip address determined by country country_code (??) if
--                 unknown
-- score         - score given to user for this check
--
-- country codes are not foreign keyed as either might be unknown
-------------------------------------------------------------------------------

!echo creating tVrfIPChk
create table tVrfIPChk (
	vrf_ip_chk_id serial                         not null,
	vrf_check_id  integer                        not null,
	vrf_ip_def_id integer                        not null,
	cr_date       datetime year to second
	              default current year to second not null,
	expected_ctry char(2)                        not null,
	ip_ctry       char(2)                        not null,
	score         integer default 0              not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfIPChk_x1 on tVrfIPChk (vrf_ip_chk_id);
create        index iVrfIPChk_x2 on tVrfIPChk (vrf_check_id);
create        index iVrfIPChk_x3 on tVrfIPChk (vrf_ip_def_id);

alter table tVrfIPChk add constraint (
	primary key (vrf_ip_chk_id)
		constraint cVrfIPChk_pk
);
alter table tVrfIPChk add constraint (
	foreign key (vrf_check_id)
		references tVrfChk
			constraint cVrfIPChk_fk1
);
alter table tVrfIPChk add constraint (
	foreign key (vrf_ip_def_id)
		references tVrfIPDef
			constraint cVrfIPChk_fk2
);



-------------------------------------------------------------------------------
-- OPENBET CHECK SECTION
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfObDef
--
-- Stores scoring value of Openbet internal card BIN check
--
-- vrf_card_id    - PK
-- vrf_chk_def_id - FK to tVrfChkDef.vrf_chk_def_id
-- cr_date        - date row was inserted
-- response_no    - PK, response code from Openbet (eg 101)
-- response_type  - type of response this represents
--                  (Comment, Warning, Match, No match)
-- score          - score modifier for this scheme
-------------------------------------------------------------------------------

!echo creating tVrfObDef
create table tVrfObDef (
	vrf_ob_def_id   serial                         not null,
	vrf_chk_def_id  integer                        not null,
	cr_date         datetime year to second
	                default current year to second not null,
	response_no     char(4)                        not null,
	response_type   char(1)                        not null,
	score           integer default 0              not null,
	description     varchar(255,100)               not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfObDef_x1 on tVrfObDef (vrf_ob_def_id);
create        index iVrfObDef_x2 on tVrfObDef (vrf_chk_def_id);


alter table tVrfObDef add constraint (
	primary key (vrf_ob_def_id)
		constraint cVrfObDef_pk
);
alter table tVrfObDef add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfObDef_f1
);
alter table tVrfObDef add constraint (
	check (response_type in (
		'C', --'C'omment
		'W', --'W'arning
		'M', --'M'atch
		'N'  --'N'o match
		)
	)
		constraint cVrfObDef_c3
);



-------------------------------------------------------------------------------
-- tVrfObType
-- Verification Openbet Sub Check Type
--
-- Contains all Openbet check verification responses
--
-- vrf_chk_type  - PK, check type
-- response_no   - PK, response code from Openbet (eg 101)
-- response_type - type of response this represents
--                  (Comment, Warning, Match, No match)
-- description   - detail description of the check
-------------------------------------------------------------------------------

!echo creating tVrfObType
create table tVrfObType (
	vrf_chk_type  varchar(32,8)    not null,
	response_no   char(4)          not null,
	response_type char(1)          not null,
	description   varchar(255,100) not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfObType_x1 on tVrfObType (vrf_chk_type, response_no);

alter table tVrfObType add constraint (
	primary key (vrf_chk_type, response_no)
		constraint cVrfObType_pk
);
alter table tVrfObType add constraint (
	check (vrf_chk_type in (
		'OB_CARD_BIN'
		)
	)
		constraint cVrfObType_c1
);
alter table tVrfObType add constraint (
	check (response_type in ('C','M','N','W'))
		constraint cVrfObType_c2
);



-------------------------------------------------------------------------------
-- CARD SCHEME SECTION
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfCardDef
--
-- Stores scoring value of card scheme against a particular check definition
--
-- vrf_card_id    - PK
-- vrf_chk_def_id - FK to tVrfChkDef.vrf_chk_def_id
-- cr_date        - date row was inserted
-- scheme         - FK to tCardInfo.scheme
-- score          - score modifier for this scheme
-------------------------------------------------------------------------------

!echo creating tVrfCardDef
create table tVrfCardDef (
	vrf_card_def_id serial                         not null,
	vrf_chk_def_id  integer                        not null,
	cr_date         datetime year to second
	                default current year to second not null,
	scheme          char(4)                        not null,
	score           integer default 0              not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfCardDef_x1 on tVrfCardDef (vrf_card_def_id);
create        index iVrfCardDef_x2 on tVrfCardDef (vrf_chk_def_id);
create        index iVrfCardDef_x3 on tVrfCardDef (scheme);

alter table tVrfCardDef add constraint (
	primary key (vrf_card_def_id)
		constraint cVrfCardDef_pk
);
alter table tVrfCardDef add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfCardDef_fk1
);
alter table tVrfCardDef add constraint (
	foreign key (scheme)
		references tCardSchemeInfo
			constraint cVrfCardDef_fk2
);



-------------------------------------------------------------------------------
-- tVrfCardChk
--
-- Represents a Card Scheme check.
--
-- vrf_card_chk_id - PK
-- vrf_check_id    - FK to tVrfChk.vrf_check_id
-- vrf_card_def_id - FK to tVrfCardDef.vrf_card_def_id
-- cr_date         - time row was created
-- score           - score resulting from this check
-------------------------------------------------------------------------------

!echo creating tVrfCardChk
create table tVrfCardChk (
	vrf_card_chk_id serial                         not null,
	vrf_check_id    integer                        not null,
	vrf_card_def_id integer                        not null,
	cr_date         datetime year to second
	                default current year to second not null,
	score           integer                        not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfCardChk_x1 on tVrfCardChk (vrf_card_chk_id);
create        index iVrfCardChk_x2 on tVrfCardChk (vrf_check_id);
create        index iVrfCardChk_x3 on tVrfCardChk (vrf_card_def_id);

alter table tVrfCardChk add constraint (
	primary key (vrf_card_chk_id)
		constraint cVrfCardChk_pk
);
alter table tVrfCardChk add constraint (
	foreign key (vrf_check_id)
		references tVrfChk
			constraint cVrfCardChk_fk1
);
alter table tVrfCardChk add constraint (
	foreign key (vrf_card_def_id)
		references tVrfCardDef
			constraint cVrfCardChk_fk2
);



-------------------------------------------------------------------------------
-- CARD BIN SECTION
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfCardBinDef
--
-- Stores scoring value of card scheme against a particular check definition
--
-- vrf_card_bin_def_id    - PK
-- vrf_chk_def_id         - FK to tVrfChkDef.vrf_chk_def_id
-- cr_date                - Date row was inserted
-- bin_lo                 - The low end of the BIN range
-- bin_hi                 - The high end of the BIN range
-- score                  - score modifier for this scheme
-------------------------------------------------------------------------------

!echo creating tVrfCardBinDef
create table tVrfCardBinDef (
	vrf_cbin_def_id       serial                         not null,
	vrf_chk_def_id        integer                        not null,
	cr_date               datetime year to second
	                      default current year to second not null,
	bin_lo                integer                        not null,
	bin_hi                integer                        not null,
	score                 integer default 0              not null,
	status                char(1) default 'A'            not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfCardBinDef_x1 on tVrfCardBinDef (vrf_cbin_def_id);
create        index iVrfCardBinDef_x2 on tVrfCardBinDef (vrf_chk_def_id);

alter table tVrfCardBinDef add constraint (
	primary key (vrf_cbin_def_id)
		constraint cVrfCardBinDef_pk
);
alter table tVrfCardBinDef add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfCardBinDef_f1
);
alter table tVrfCardBinDef add constraint (
	check (status in ('A','S'))
		constraint cVrfCardBinDef_c1
);



-------------------------------------------------------------------------------
-- tVrfCardBinChk
--
-- Stores scoring value of card scheme against a particular check definition
--
-- vrf_card_id    - PK
-- vrf_chk_def_id - FK to tVrfChkDef.vrf_chk_def_id
-- cr_date        - date row was inserted
-- scheme         - FK to tCardInfo.scheme
-- score          - score modifier for this scheme
-------------------------------------------------------------------------------

!echo creating tVrfCardBinChk
create table tVrfCardBinChk (
	vrf_cbin_chk_id      serial                         not null,
	vrf_check_id         integer                        not null,
	vrf_cbin_def_id      integer                        not null,
	cr_date              datetime year to second
	                     default current year to second not null,
	card_bin             integer                        not null,
	score                integer default 0              not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfCardBinChk_x1 on tVrfCardBinChk (vrf_cbin_chk_id);
create        index iVrfCardBinChk_x2 on tVrfCardBinChk (vrf_check_id);
create        index iVrfCardBinChk_x3 on tVrfCardBinChk (vrf_cbin_def_id);

alter table tVrfCardBinChk add constraint (
	primary key (vrf_cbin_chk_id)
		constraint cVrfCardBinChkf_pk
);
alter table tVrfCardBinChk add constraint (
	foreign key (vrf_check_id)
		references tVrfChk
			constraint cVrfCardBinChk_f1
);
alter table tVrfCardBinChk add constraint (
	foreign key (vrf_cbin_def_id)
		references tVrfCardBinDef
			constraint cVrfCardBinChk_f2
);



-------------------------------------------------------------------------------
-- AUTH_PRO SECTION
-------------------------------------------------------------------------------

--
-- tVrfAuthProType
--
!echo creating tVrfAuthProType
create table tVrfAuthProType (
	vrf_chk_type  varchar(32,8)    not null,
	response_no   char(40)         not null,
	response_type char(1)          not null,
	description   varchar(255,100) not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfAuthProType_x1 on tVrfAuthProType (vrf_chk_type, response_no);

alter table tVrfAuthProType add constraint (
	primary key (vrf_chk_type, response_no)
		constraint cVrfAuthProType_pk
);
alter table tVrfAuthProType add constraint (
	check (response_type in ('C','M','N','W'))
		constraint cVrfAuthProType_c2
);

--
-- tVrfAuthProDef
--
!echo creating tVrfAuthProDef
create table tVrfAuthProDef (
	vrf_auth_pro_def_id serial                          not null,
	vrf_chk_def_id      integer                         not null,
	cr_date             datetime year to second
	                    default current year to second  not null,
	response_no         char(40)                        not null,
	response_type       char(1)                         not null,
	score               integer default 0               not null,
	description         varchar(255,0)
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfAuthProDef_x1 on tVrfAuthProDef (vrf_auth_pro_def_id);
create        index iVrfAuthProDef_x2 on tVrfAuthProDef (vrf_chk_def_id);

alter table tVrfAuthProDef add constraint (
	primary key (vrf_auth_pro_def_id)
		constraint cVrfAuthProDef_pk
);
alter table tVrfAuthProDef add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfAuthProDef_fk1
);
alter table tVrfAuthProDef add constraint (
	check (response_type in (
		'C', --'C'omment
		'W', --'W'arning
		'M', --'M'atch
		'N'  --'N'o match
		)
	)
		constraint cVrfAuthProDef_c1
);


--
-- tVrfAuthProChk
--
!echo creating tVrfAuthProChk
create table tVrfAuthProChk (
	vrf_auth_pro_chk_id serial                         not null,
	vrf_check_id        integer                        not null,
	vrf_auth_pro_def_id integer                        not null,
	cr_date             datetime year to second
	                    default current year to second not null,
	resp_value          varchar(255,0)                 not null,
	score               integer
)
	extent size 131072 next size 131072
	lock mode row;

create unique index iVrfAuthProChk_x1 on tVrfAuthProChk (vrf_auth_pro_chk_id);
create        index iVrfAuthProChk_x2 on tVrfAuthProChk (vrf_check_id);
create        index iVrfAuthProChk_x3 on tVrfAuthProChk (vrf_auth_pro_def_id);

alter table tVrfAuthProChk add constraint (
	primary key (vrf_auth_pro_chk_id)
		constraint cVrfAuthProChk_pk
);
alter table tVrfAuthProChk add constraint (
	foreign key (vrf_check_id)
		references tVrfChk
			constraint cVrfAuthProChk_fk1
);
alter table tVrfAuthProChk add constraint (
	foreign key (vrf_auth_pro_def_id)
		references tVrfAuthProDef
			constraint cVrfAuthProChk_fk2
);




-------------------------------------------------------------------------------
-- URU SECTION
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfURUType
-- Verification URU Sub Check Type
--
-- Contains all URU verification responses
--
-- vrf_chk_type  - PK, check type
-- response_no   - PK, response code from URU (eg 1001)
-- response_type - type of response this represents
--                  (Comment, Warning, Match, No match)
-- description   - detail description of the check
-------------------------------------------------------------------------------

!echo creating tVrfURUType
create table tVrfURUType (
	vrf_chk_type  varchar(32,8)    not null,
	response_no   char(4)          not null,
	response_type char(1)          not null,
	description   varchar(255,100) not null
)
	extent size 64 next size 64
	lock mode row;

create unique index iVrfURUType_x1 on tVrfURUType (vrf_chk_type, response_no);

alter table tVrfURUType add constraint (
	primary key (vrf_chk_type, response_no)
		constraint cVrfURUType_pk
);
alter table tVrfURUType add constraint (
	check (vrf_chk_type in (
		'URU_UK_MIN_ADDRESS',
		'URU_UK_MAX_ADDRESS',
		'URU_UK_DRIVERS',
		'URU_UK_ELECTRICITY',
		'URU_UK_PHONE',
		'URU_UK_PASSPORT',
		'URU_UK_MORTALITY',
		'URU_UK_DOB',
		'URU_UK_RESIDENCY',
		'URU_UK_CREDIT_DEBIT',
		'URU_UK_ELECTORAL_ROLL',
		'URU_UK_CALLID'
		)
	)
		constraint cVrfURUType_c1
);
alter table tVrfURUType add constraint (
	check (response_type in ('C','M','N','W'))
		constraint cVrfURUType_c2
);



-------------------------------------------------------------------------------
-- tVrfURUDef
--
-- Stores the score for each individual item returned by URU.
-- It's important to note that the response numbers are not unique - they
-- depend on the kind of request made. eg code 0101 is used by the electoral
-- roll and drivers' licence requests for different purposes. Hence the PK is
-- the number and the vrf_chk_def_id taken together.
--
-- vrf_uru_def_id - PK
-- vrf_chk_def_id - FK to tVrfChkDef.vrf_chk_def_id
-- cr_date        - creation time of row
-- response_no    - response code from URU (eg 1001)
-- response_type  - type of response this represents
--                  (Comment, Warning, Match, No match)
-- score          - positive or negative score for this result
-- description    - associated uru description
-------------------------------------------------------------------------------

!echo creating tVrfURUDef
create table tVrfURUDef (
	vrf_uru_def_id serial                         not null,
	vrf_chk_def_id integer                        not null,
	cr_date        datetime year to second
	               default current year to second not null,
	response_no    char(4)                        not null,
	response_type  char(1)                        not null,
	score          integer default 0              not null,
	description    varchar(255,0)
)
	extent size 16 next size 128
	lock mode row;

create unique index iVrfURUDef_x1 on tVrfURUDef (vrf_uru_def_id);
create        index iVrfURUDef_x2 on tVrfURUDef (vrf_chk_def_id);

alter table tVrfURUDef add constraint (
	primary key (vrf_uru_def_id)
		constraint cVrfURUDef_pk
);
alter table tVrfURUDef add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfURUDef_fk1
);
alter table tVrfURUDef add constraint (
	check (response_type in (
		'C', --'C'omment
		'W', --'W'arning
		'M', --'M'atch
		'N'  --'N'o match
		)
	)
		constraint cVrfURUDef_c1
);



-------------------------------------------------------------------------------
-- tVrfURUChk
--
-- Represents a URU check.
--
-- vrf_uru_chk_id - PK
-- vrf_check_id   - FK to tVrfChk.vrf_check_id
-- cr_date        - time row was created
-- score          - score resulting from this check
-- uru_reference  - GUID reference returned from URU for this request
--                  This reference is used to reference the details of the
--                  search from the proveURU interface
-------------------------------------------------------------------------------

!echo creating tVrfURUChk
create table tVrfURUChk (
	vrf_uru_chk_id serial                         not null,
	vrf_check_id   integer                        not null,
	vrf_uru_def_id integer                        not null,
	cr_date        datetime year to second
	               default current year to second not null,
	score          integer                        not null,
	uru_reference  varchar(255,0)                 not null
)
	extent size 16 next size 128
	lock mode row;

create unique index iVrfURUChk_x1 on tVrfURUChk (vrf_uru_chk_id);
create        index iVrfURUChk_x2 on tVrfURUChk (vrf_check_id);
create        index iVrfURUChk_x3 on tVrfURUChk (vrf_uru_def_id);

alter table tVrfURUChk add constraint (
	primary key (vrf_uru_chk_id)
		constraint cVrfURUChk_pk
);
alter table tVrfURUChk add constraint (
	foreign key (vrf_check_id)
		references tVrfChk
			constraint cVrfURUChk_fk1
);
alter table tVrfURUChk add constraint (
	foreign key (vrf_uru_def_id)
		references tVrfURUDef
			constraint cVrfURUChk_fk2
);



-------------------------------------------------------------------------------
-- GENERIC SECTION
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- tVrfGenType
-- Verification Generic Sub Check Type
--
-- Contains all generic harness verification responses
--
-- vrf_chk_type  - PK, check type
-- response_no   - PK, response code from URU (eg 1001)
-- response_type - type of response this represents
--                  (Warning, Match, No match)
-- description   - detail description of the check
-------------------------------------------------------------------------------

!echo creating tVrfGenType
create table tVrfGenType (
	vrf_chk_type  varchar(32,8)    not null,
	response_no   char(4)          not null,
	response_type char(1)          not null,
	description   varchar(255,100) not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfGenType_x1 on tVrfGenType (vrf_chk_type, response_no);

alter table tVrfGenType add constraint (
	primary key (vrf_chk_type, response_no)
		constraint cVrfGenType_pk
);
alter table tVrfGenType add constraint (
	check (vrf_chk_type in (
		'GENERIC_ADDRESS',
		'GENERIC_PHONE'
		)
	)
		constraint cVrfGenType_c1
);
alter table tVrfGenType add constraint (
	check (response_type in ('M','N','W'))
		constraint cVrfGenType_c2
);



-------------------------------------------------------------------------------
-- tVrfGenDef
--
-- Stores the score for each individual item returned by test harness.
--
-- vrf_gen_def_id - PK
-- vrf_chk_def_id - FK to tVrfChkDef.vrf_chk_def_id
-- cr_date        - creation time of row
-- response_no    - response code from URU (eg 1001)
-- response_type  - type of response this represents
--                  (Comment, Warning, Match, No match)
-- score          - positive or negative score for this result
-- description    - associated description
-------------------------------------------------------------------------------

!echo creating tVrfGenDef
create table tVrfGenDef (
	vrf_gen_def_id serial                         not null,
	vrf_chk_def_id integer                        not null,
	cr_date        datetime year to second
	               default current year to second not null,
	response_no    integer                        not null,
	response_type  char(1)                        not null,
	score          integer default 0              not null,
	description    varchar(255,0)
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfGenDef_x1 on tVrfGenDef (vrf_gen_def_id);
create        index iVrfGenDef_x2 on tVrfGenDef (vrf_chk_def_id);

alter table tVrfGenDef add constraint (
	primary key (vrf_gen_def_id)
		constraint cVrfGenDef_pk
);
alter table tVrfGenDef add constraint (
	foreign key (vrf_chk_def_id)
		references tVrfChkDef
			constraint cVrfGenDef_fk1
);
alter table tVrfGenDef add constraint (
	check (response_type in (
		'W', --'W'arning
		'M', --'M'atch
		'N'  --'N'o match
		)
	)
		constraint cVrfGenDef_c1
);



-------------------------------------------------------------------------------
-- tVrfGenChk
--
-- Represents a generic check.
--
-- vrf_gen_chk_id - PK
-- vrf_check_id   - FK to tVrfChk.vrf_check_id
-- cr_date        - time row was created
-- score          - score resulting from this check
-------------------------------------------------------------------------------

!echo creating tVrfGenChk
create table tVrfGenChk (
	vrf_gen_chk_id serial                         not null,
	vrf_check_id   integer                        not null,
	vrf_gen_def_id integer                        not null,
	cr_date        datetime year to second
	               default current year to second not null,
	score          integer                        not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfGenChk_x1 on tVrfGenChk (vrf_gen_chk_id);
create        index iVrfGenChk_x2 on tVrfGenChk (vrf_check_id);
create        index iVrfGenChk_x3 on tVrfGenChk (vrf_gen_def_id);

alter table tVrfGenChk add constraint (
	primary key (vrf_gen_chk_id)
		constraint cVrfGenChk_pk
);
alter table tVrfGenChk add constraint (
	foreign key (vrf_check_id)
		references tVrfChk
			constraint cVrfGenChk_fk1
);
alter table tVrfGenChk add constraint (
	foreign key (vrf_gen_def_id)
		references tVrfGenDef
			constraint cVrfGenChk_fk2
);



-------------------------------------------------------------------------------
-- tVrfCustQueue
--
-- Lookup table storing the IDs of customers awaiting verification and the
-- profile definition to verify them against.
--
-- vrf_prfl_def_id - FK to tVrfPrflDef.vrf_prfl_def_id
-------------------------------------------------------------------------------

!echo creating tVrfCustQueue
create table tVrfCustQueue (
	vrf_prfl_def_id     integer     not null,
	cust_id             integer     not null,
	vrf_prfl_model_id   integer     default null,
	last_process_at     datetime year to second
)
	extent size 4096 next size 4096
	lock mode row;

create unique index iVrfCustQueue_x1 on tVrfCustQueue
											(cust_id, vrf_prfl_def_id);
create        index iVrfCustQueue_x2 on tVrfCustQueue (cust_id);
create        index iVrfCustQueue_x3 on tVrfCustQueue (vrf_prfl_def_id);

alter table tVrfCustQueue add constraint (
	primary key (cust_id,vrf_prfl_def_id)
		constraint cVrfCustQueue_pk
);
alter table tVrfCustQueue add constraint (
	foreign key (cust_id)
		references tCustomer
			constraint cVrfCustQueue_fk1
);
alter table tVrfCustQueue add constraint (
	foreign key (vrf_prfl_def_id)
		references tVrfPrflDef
			constraint cVrfCustQueue_fk2
);
alter table tVrfCustQueue add constraint (
	foreign key (vrf_prfl_model_id)
		references tVrfPrflModel (vrf_prfl_model_id)
			constraint cVrfCustQueue_fk3
);



------------------------------------------------------------------------------
-- Available reasons for an Age Verification status
--
--   reason_code - unique 3 character code for reason
--   desc        - description of reason
--   status      - the status to associate the reason with
--                 (A)ctive, (R) - Pending, (S)uspended, (U)nderage.
--
!echo "create table tVrfCustReason"
create table tVrfCustReason
(
	reason_code    char(3)               not null,
	desc           varchar(255)          not null,
	status         char(1)   default "A" not null
)
	extent size 16 next size 16
	lock mode row;

create unique index iVrfCustReason_x1 on tVrfCustReason(reason_code);

alter table tVrfCustReason add constraint (
	primary key(reason_code)
		constraint cVrfCustReason_pk
);
alter table tVrfCustReason add constraint (
	check (status in ('A','P','S','U'))
		constraint cVrfCustReason_c1
);



------------------------------------------------------------------------------
-- Record details of a customers Age Verification status
--
--    cust_id - customer identifier - foreign key to tCustomer
--    status  - Age Verification status
--               'A' -- (A)ctivate
--               'P' -- (P) - Restricted
--               'S' -- (S)uspend
--               'N' -- (N)othing
--               'U' -- (U)nderage - can only be put into via admin user...
--    reason  - reason code for a status - foreign key to tVrfCustReason
--
--
--
!echo "create table tVrfCustStatus"
create table tVrfCustStatus
(
	cust_id        integer                       not null,
	vrf_prfl_code  char(4)                       not null,
	status         char(1)   default "P"         not null,
	reason_code    char(3),
	notes          varchar(255),
	cust_flag_id   int,
	expiry_date    datetime year to second default current year to second not null
)
	extent size 262144 next size 65536
	lock mode row;

create unique index iVrfCustStatus_x1 on tVrfCustStatus(cust_id);
create        index iVrfCustStatus_x2 on tVrfCustStatus(reason_code);
create        index iVrfCustStatus_x3 on tVrfCustStatus(vrf_prfl_code);
create        index iVrfCustStatus_x4 on tVrfCustStatus(cust_flag_id);

alter table tVrfCustStatus add constraint (
	primary key (cust_id)
		constraint cVrfCustStatus_pk
);
alter table tVrfCustStatus add constraint (
	foreign key (cust_id) references tCustomer(cust_id)
		constraint cVrfCustStatus_f1
);
alter table tVrfCustStatus add constraint (
	foreign key (reason_code) references tVrfCustReason(reason_code)
		constraint cVrfCustStatus_f2
);
alter table tVrfCustStatus add constraint (
	foreign key (vrf_prfl_code) references tVrfPrflDef(vrf_prfl_code)
		constraint cVrfCustStatus_f3
);
alter table tVrfCustStatus add constraint (
	foreign key (cust_flag_id) references tCustStatusFlag (cust_flag_id)
		constraint cVrfCustStatus_f4
);
alter table tVrfCustStatus add constraint (
	check (status in ('A','P','S','N','U'))
		constraint cVrfCustStatus_c1
);
