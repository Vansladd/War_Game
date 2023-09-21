# $Id: build_xml.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#########################################################################################
#                                                                                       #
# TCL script providing an API for  constructing XML documents                           #
#                                                                                       #
# Usage: All nodes are stored along with associated unique IDs. These IDs are used      #
#        to store the structure. When a new node is added, its id is returned to the    #
#        caller, who should store it if attributes or child elements are to be added    #
#        to the node. An exmaple is below:                                              #
#                                                                                       #
#        xml_init                                                                       #
#        set rootId [addRootNode "APersonTag"]                                          #
#        addChildNode $rootId "Name" "Stuart"                                           #
#        set descId [addChildNode $rootId "Description"]                                #
#        addAttributes $descId [list "Height" "5'10" \                                  #
#                                    "HairColour" "Blonde"]                             #
#        set xml [build_string 1]                                                       #
#                                                                                       #
#        This would produce the following XML:                                          #
#                                                                                       #
#        <?xml version='1.0'?>                                                          #
#        <APersonTag>                                                                   #
#               <Name>Stuart</Name>                                                     #
#             <Description Height="5'10" HairColour="Blonde"/>                          #
#           </APersonTag>                                                               #
#                                                                                       #
#########################################################################################

namespace eval build_xml {

	#Namespace variables
	variable next_id
	variable XML_DATA
	variable xml_version
	variable xml_doctype

	#
	# Resets the Data array and sets the next id to 1	
	#
	proc xmlInit {} {	
	
		variable XML_DATA
		variable next_id
		variable xml_version
		variable xml_doctype

		#Reset array and id
		catch {unset XML_DATA}
		set XML_DATA(roots) [list]
		set next_id 1
		
		#Default version and doctype
		set xml_version "1.0"
		set xml_doctype ""
	}

	#
	# Unsets the data
	#
	proc xmlReset {} {			
		catch {unset next_id}
		catch {unset XML_DATA}
		catch {unset xml_version}
		catch {unset xml_doctype}		
	}
	
	#
	# Used to add a root node
	#
	# Arguments: Name of the node
	#	
	proc addRootNode {name} {	
		
		variable next_id
		variable XML_DATA
		
		#Obtain a node id
		set node_id $build_xml::next_id
		incr next_id
		
		#Store the node
		set XML_DATA($node_id) $name
		set XML_DATA($node_id,data) ""
		set XML_DATA($node_id,child_ids) [list]
		set XML_DATA($node_id,attributes) [list]	    
		
		#Add the root node reference 
		lappend XML_DATA(roots) $node_id
		
		return $node_id
	}
	
	#
	# Used to add a child node
	#
	# Arguments: Id of the parent node
	#            Name of the node
	#            Node Content (optional)
	#	
	proc addChildNode {parent_id name {content ""}} {
	
		variable next_id
		variable XML_DATA

		#Obtain a node id
		set node_id $next_id
		incr next_id
		
		#Store the node
		set XML_DATA($node_id) $name
		set XML_DATA($node_id,data) ""
		set XML_DATA($node_id,child_ids) [list]
		set XML_DATA($node_id,attributes) [list]	    	 
		
		#Store reference to the parent
		lappend XML_DATA(${parent_id},child_ids) $node_id
		
		#If content is not empty then store
		if {$content != ""} {
			set XML_DATA($node_id,data) $content
		}
		
		return $node_id
	}
	
	#
	# Used to set a nodes internal data
	#
	# Arguments: Id of the node
	#            The content
	#
	proc addNodeContent {node_id content} {
	
		variable XML_DATA

		set XML_DATA($node_id,data) $content
	}
	
	#
	# Used to add an attribute to a node
	#
	# Arguments: Id if the node
	#            List of attribute name-value pairs (attributes with no values
	#                                   can be added by passing empty string as the
	#                                   value)
	#	
	proc addAttributes {node_id attr_list} {
	
		variable XML_DATA

		#Cycle the attribute list
		foreach {attr_name attr_value} $attr_list {			
		
			#Build the attribute string
			if {$attr_value != ""}  {	    
				set attr_str "${attr_name}=\"${attr_value}\""
			} else {
				set attr_str "${attr_name}"	    
			}

			#Store attribute
			lappend XML_DATA($node_id,attributes) $attr_str
		}
	}
	
	#
	# Used to specify the xml version to go in the header
	#
	# Arguments: The XML version no. (set by default to 1.0)
	#
	proc setVersion {version} {	    

		variable xml_version
		set xml_version $version
	}
	
	#
	# Used to specify the doc-type declaration tag (defaults to null)
	#
	# Arguments: The DOCTYPE declaration to use
	#
	proc setDoctype {doctype_tag} {
		
		variable xml_doctype
		set xml_doctype $doctype_tag
	}
	
	#
	# Builds the XML string. The lineBreak argument specifies whether to format
	# the XML for viewing
	#
	# Arguments: Flag indicating whether the XML should be formatted (true) or 
	#            output on a songle line (false)
	#
	proc buildString {{line_break 0}} {

		variable XML_DATA
		variable xml_version
		variable xml_doctype
	 
		#Initialise the stack string
		set stack_string ""

		#Output version and doctype
		set stack_string "<?xml version='${xml_version}'?>"
		if {$xml_doctype != ""} {
			if {$line_break} {
				set sep "\n"
			} else {
				set sep " "
			}
			set stack_string "${stack_string}${sep}${xml_doctype}"
		}

		#Iterate over the root nodes	    
		foreach root $XML_DATA(roots) {
			set stack_string [outputNode $root 0 $stack_string $line_break]
		}
			   
		return $stack_string
	}
	
	#
	# Recursively called internally to iterate down the node tree
	#
	# Arguments: Id of the node to output
	#            The call depth (for formatting purposes)
	#            The string to append the node to 
	#            Formatting flag
	#
	proc outputNode {node_id depth stack_string line_break} {
	
		variable XML_DATA
	
		#Set the line break char
		if {$line_break} {
			set sep "\n"
		} else {
			set sep " "
		}
		
		#First set the pad depth (for line_break = true option)
		set pad ""
		if {$line_break} {
			for {set i 0} {$i < $depth} {incr i} {
				set pad "$pad    "
			}
		}
		
		#Build the node tag
		set node_open_tag "<$XML_DATA($node_id)"
		foreach attr $XML_DATA($node_id,attributes) {
			set node_open_tag "$node_open_tag $attr"
		}
		if {[llength $XML_DATA($node_id,child_ids)] > 0 || $XML_DATA($node_id,data) != ""} {
			set node_open_tag "${node_open_tag}>"
			set empty 0
		} else {
			set node_open_tag "${node_open_tag}/>"
			set empty 1
		}   
		
		#Add opening tag to the stach
		set stack_string "${stack_string}${sep}${pad}${node_open_tag}"
		
		if {!$empty} {
		
			#Recurse into any children
			foreach child_id $XML_DATA($node_id,child_ids) {
				set stack_string [outputNode $child_id [expr $depth + 1] $stack_string $line_break]
			}

			#Add content
			set stack_string "$stack_string$XML_DATA($node_id,data)"	    

			#Add the closing tag
			set node_close_tag "</$XML_DATA($node_id)>"
			if {$XML_DATA($node_id,data) == ""} {
				set close_sep "${sep}${pad}"
			} else {
				set close_sep ""
			}
			set stack_string "${stack_string}${close_sep}${node_close_tag}"
		}
		
		#Return the stack_string
		return $stack_string	
	}
}
