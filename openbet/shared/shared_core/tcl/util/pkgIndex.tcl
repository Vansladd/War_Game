# Core Util Package Index
variable TCL

set pkg_list [list \
	core::assert          1.0  assert \
	core::bitwise         1.0  bitwise \
	core::control         1.0  control \
	core::date            1.0  date \
	core::dynatrace       1.0  dynatrace \
	core::email           1.0  email \
	core::gc              1.0  gc \
	core::handicap        1.0  handicap \
	core::interface       1.0  interface \
	core::json            1.0  json \
	core::lock            1.0  lock \
	core::queue           1.0  queue \
	core::plugin          1.0  plugin \
	core::price           1.0  price \
	core::profile         1.0  profile \
	core::random          1.0  random\
	core::safe            1.0  safe \
	core::soap            1.0  soap \
	core::socket          1.0  socket \
	core::socket::appserv 1.0  socket_appserv \
	core::socket::client  1.0  socket_client \
	core::standalone      1.0  standalone \
	core::util            1.0  util \
	core::xl              1.0  xl \
	core::xml             1.0  xml \
	core::timezone        1.0  timezone \
	core::blurb           1.0  blurb \
	core::uuid            1.0  uuid \
	core::multitenant     1.0  multitenant \
]

foreach {pkg version name} $pkg_list {

	set file [file join $dir $name]

	if {[file exists $file.tbc]} {
		set file  $file.tbc
	} elseif {[file exists $file.tcl]} {
		set file  $file.tcl
	} else {
		error "Can't load package $pkg version $version from file $file.{tbc,tcl}"
	}

	set TCL($pkg,filename) $file
	set TCL($pkg,dir)      $dir
	set TCL($pkg,version)  $version

	package ifneeded $pkg $version [list source $file]
}
