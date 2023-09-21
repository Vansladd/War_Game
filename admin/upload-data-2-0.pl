#!/usr/local/bin/perl

# SLOBS %Z%%M% %R%.%L% %E%

use File::Basename;

##+++
##     CGI Lite v1.62
##     Last modified: January 17, 1996
##
##     Copyright (c) 1995 by Shishir Gundavaram
##     All Rights Reserved
##
##     E-Mail: shishir@ora.com
##
##     Permission  to  use,  copy, and distribute is hereby granted,
##     providing that the above copyright notice and this permission
##     appear in all copies and in supporting documentation.
##--

package CGI_Lite;

sub new
{
    my $self = {};

    bless $self;
    $self->initialize ();
    return $self;
}

sub initialize
{
    my ($self) = @_;

    $self{'multipart_directory'} = undef;
    $self{'default_directory'} = "/tmp";
    $self{'file_type'} = "name";
    $self{'platform'} = "UNIX";
    $self{'form_data'} = {};
}

sub set_directory
{
    my ($self, $directory) = @_;

    stat ($directory);

    if ( (-d _) && (-e _) && (-r _) && (-w _) ) {
        $self{'multipart_directory'} = $directory;
        return (1);
    } else {
        return (0);
    }
}

sub set_platform
{
    my ($self, $platform) = @_;

    if ( ($platform eq "PC") || ($platform eq "Macintosh") ) {
        $self{'platform'} = $platform;
    } else {
        $self{'platform'} = "UNIX";
    }
}

sub set_file_type
{
    my ($self, $type) = @_;

    if ($type =~ /^handle$/i) {
        $self{'file_type'} = $type;
    } else {
        $self{'file_type'} = 'name';
    }
}

sub parse_form_data
{
    my ($self) = @_;
    my ($request_method, $content_length, $content_type, $query_string,
    $first_line, $multipart_boundary, $post_data);

    $request_method = $ENV{'REQUEST_METHOD'};
    $content_length = $ENV{'CONTENT_LENGTH'};
    $content_type   = $ENV{'CONTENT_TYPE'};

    if ($request_method =~ /^(get|head)$/i) {

        $query_string = $ENV{'QUERY_STRING'};
        $self->decode_url_encoded_data (\$query_string);

        return wantarray ? (%{$$self{'form_data'}}) : ($$self{'form_data'});

    } elsif ($request_method =~ /^post$/i) {

        if ($content_type eq "application/x-www-form-urlencoded") {
            read (STDIN, $post_data, $content_length);
            $self->decode_url_encoded_data (\$post_data);

            return wantarray ? (%{$$self{'form_data'}}) : ($$self{'form_data'});

        } elsif ($content_type =~ /multipart\/form-data/) {
            ($multipart_boundary) = $content_type =~ /boundary=(\S+)$/;
            $self->parse_multipart_data ($content_length, $multipart_boundary);

            return wantarray ? (%{$$self{'form_data'}}) : ($$self{'form_data'});
        } else {
            $self->return_error (500, "Server Error",
                    "Server uses unsupported MIME type for POST.");
        }

    } else {
        $self->return_error (500, "Server Error",
            "Server uses unsupported method.");
    }
}

sub decode_url_encoded_data
{
    my ($self, $form_data) = @_;
    my (@key_value_pairs, $key_value, $key, $value);

    @key_value_pairs = ();

    $$form_data =~ tr/+/ /;
    @key_value_pairs = split (/&/, $$form_data);
        
    foreach $key_value (@key_value_pairs) {
        ($key, $value) = split (/=/, $key_value);

        $key   =~ s/%([0-9a-fA-F][0-9a-fA-F])/pack("C", hex($1))/eg;
        $value =~ s/%([0-9a-fA-F][0-9a-fA-F])/pack("C", hex($1))/eg;
    
        if ( defined ($$self{'form_data'}->{$key}) ) {
            $$self{'form_data'}->{$key} =
                    join ("", $$self{'form_data'}->{$key}, "\0", $value);
        } else {
            $$self{'form_data'}->{$key} = $value;
        }
    }
}

sub determine_package
{
    my ($self) = @_;
    my ($frame, $this_package, $find_package);

    $frame = -1;
    ($this_package) = split (/=/, $self);

    do {
        $find_package = caller (++$frame);
    } until ($find_package !~ /^$this_package/);

    return ($find_package);
}

sub get_date_stamp
{
    my ($self) = @_;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

    return sprintf "%4d-%02d-%02d_%02d:%02d:%02d",
        $year+1900,$mon+1,$mday,$hour,$min,$sec;
}

sub parse_multipart_data
{
    my ($self, $total_bytes, $boundary) = @_;
    my ($package, $boundary_length, $block_size, $previous_block, $byte_count,
    $time, @data_stream, $field_name, $file, $time, $bytes_left,
    $combination, $binary_status, $package, $handle, $eol_chars);

    $package = $self->determine_package ();

    $boundary_length = length ($boundary);
    $block_size = $boundary_length * 2;
    $previous_block = undef;

    $byte_count = 0;
    $time = $self->get_date_stamp();

    while (<STDIN>) {
        $byte_count += length;
        $_ = join ("", $previous_block, $_);
        undef $previous_block;

        if (/[Cc]ontent-[Dd]isposition: [^\r\n]+\r{0,1}\n{0,1}/) {
            undef @data_stream;
            $binary_status = 0;

            $previous_block = $';

            ($field_name) = /name="([^"]+)"/;

            if ( ($file) = /filename="(\S+)"/) {
                # chop off crappy dos leading DRV: rubbish
                $file =~ s/^[A-Za-z]://;
                # change crappy dos backslashes to unix-style
                $file =~ s|\\|/|g;
		# lose any suspicious characters
		$file =~ s/[]\000-\040\177-\377:*?"<>|[]/-/g;
                $file = substr ($file, rindex ($file, "/") + 1);
                $file = join ("_", $file, $time);
            }
            
            unless ($previous_block) {
                while (<STDIN>) {
                    $byte_count += length;
                    last if (/^\s*$/);

                    $binary_status = 1 if (!/Content-[Tt]ype:\s+text/);
                }
            }

            while ($byte_count < $total_bytes) {
                $bytes_left = $total_bytes - $byte_count;
                $block_size = $bytes_left if ($bytes_left < $block_size);

                read (STDIN, $_, $block_size);
                $byte_count += $block_size;

                $combination = join ("", $previous_block, $_);
        
                if ($combination =~ /\r{0,1}\n{0,1}$boundary/o) {
                    push (@data_stream, $`);
                    $previous_block = $';
                    last;
                } else {
                    push (@data_stream, $previous_block) 
                    if (defined($previous_block));
                        $previous_block = $_;
                }
            }

            $data_stream[$[] =~ s/^\r{0,1}\n{0,1}//;
            $data_stream[$#data_stream] =~ s/\r{0,1}\n{0,1}--//;
            
            if (defined ($file)) {
                if ($self{'multipart_directory'}) {
                    $file = join ("/", $self{'multipart_directory'}, $file);
                } else {
                    $file = join ("/", $self{'default_directory'}, $file);
                }

                open  (DATA, ">" . $file);

                unless ($binary_status) {
                    if ($self{'platform'} eq "Macintosh") {
                        $eol_chars = "\r";
                    } elsif ($self{'platform'} eq "PC") {
                        $eol_chars = "\r\n";
                    } else {
                        $eol_chars = "\n";
                    }

                    grep (s/\r{0,1}\n/$eol_chars/g, @data_stream);
                    grep (s/\r/$eol_chars/g, @data_stream);
                }

                print DATA @data_stream;
                close (DATA);

                if ($self{'file_type'} eq "handle") {
                    $handle = "$package\:\:$file";
                    open ($handle, "<" . $file);
                    $$self{'form_data'}->{$field_name} = $file;
                } else {
                    $$self{'form_data'}->{$field_name} = $file; 
                }

            } else {
                $$self{'form_data'}->{$field_name} = join ("", @data_stream);
            }
        }
        last if ($byte_count >= $total_bytes);
    }
}

sub print_form_data
{
    my ($self) = @_;
    my ($key);

    foreach $key (keys %{$$self{'form_data'}}) {
        print $key, " = ", $$self{'form_data'}->{$key}, "\n";
    }
}

sub embed_form_data
{
    my ($self) = @_;
    my ($key);

    foreach $key (keys %{$$self{'form_data'}}) {
        print "<input type=\"hidden\" name=\"$key\" value=\"$$self{'form_data'}->{$key}\">\n";
#        print $key, " = ", $$self{'form_data'}->{$key}, "\n";
    }
}

sub return_error
{
    my ($self, $status, $keyword, $message) = @_;

    print "Content-type: text/html", "\n";
    print "Status: ", $status, " ", $keyword, "\n\n";

    print "<TITLE>", "CGI Program - Unexpected Error", "</TITLE>", "\n";
    print "<H1>", $keyword, "</H1>", "\n";
    print "<HR>", $message, "<HR>", "\n";
    print "Please contact the webmaster for more information.", "\n";

    exit(1);
}

1;


#
# Main code starts here
#

$cgi = new CGI_Lite ();

$cgi->set_platform ("UNIX");
$cgi->set_file_type("file");

$status = $cgi->set_directory("/opt/openbet/admin/upload/tmp");

if ($status != 1) {
    print "Content-type: text/html\n\n";
    print "The upload program is misconfigured<br>\n";
    print "<br>\n";
    print "Please inform the system administrator.";

    exit (0);
}

$cgi->parse_form_data ();

$returl = $cgi->{'form_data'}{'returl'};
$filename = $cgi->{'form_data'}{'filename'};
$filetype = $cgi->{'form_data'}{'filetype'};
$retaction = $cgi->{'form_data'}{'retaction'};

if (!defined($filename) || !defined($filetype)) {
    print "Content-type: text/plain\n\n";
    print "Error filename/filetype not defined";
    exit(1);
}

$dirname  = File::Basename::dirname ($filename);
$basename = File::Basename::basename($filename);

print STDERR "$dirname -- $basename\n";

$dirname =~ s/tmp$/$filetype/;

rename $filename, "$dirname/$basename";

print "Content-type: text/html\n";
print "\n";
print "<html>\n";
print "<head><title>Uploading File</title></head>\n";
print "<body bgcolor=white text=black onload=\"document.uplform.submit();\">\n";
#print "<body bgcolor=white text=black\">\n";
print "<font face=verdana,arial,helvetica>\n";
print "<font size=+1>\n";
print "Uploading file... please wait.\n";

print "o filename: $filename\n";
print "filename: $dirname/$basename\n";
print "filetype: $filetype\n";
print "</font>\n";
print "</font>\n";
print "<form method=post name=\"uplform\" action=\"$returl\">\n";
print "<input type=\"hidden\" name=\"action\" value=\"$retaction\">\n";
print "<input type=\"hidden\" name=\"SubmitName\" value=\"uploaded\">\n";
$cgi->embed_form_data ();
print "</form>\n";
print "</body>\n";
print "</html>\n";

#print "FILENAME = ", $cgi->{'form_data'}{'filename'},"\n";
#print "DIRNAME  = ", $dirname, "\n";
#print "BASENAME = ", $basename, "\n";

exit (0);
