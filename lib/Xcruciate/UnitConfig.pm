#! /usr/bin/perl -w

package Xcruciate::UnitConfig;
use Exporter;
@ISA = ('Exporter');
@EXPORT = qw();
our $VERSION = 0.03;

use strict;
use Xcruciate::Utils;

=head1 NAME

Xcruciate::UnitConfig - OO API for reading xacerbate/xteriorize unit config files.

=head1 SYNOPSIS

my $config=Xcruciate::UnitConfig->new('unit.conf');

my $cm=$config->chime_multiplier;

my @mdf=$config->modifiable_data_files;


=head1 DESCRIPTION

Xcruciate::UnitConfig is part of the Xcruciate project (F<http://www.xcruciate.co.uk>). It provides an
OO interface to an xacerbate/xteriorize unit configuration file.

Accessor functions return scalars for <scalar/> entry types and lists for <list/> entry types.
The values returned are those found in the config file, with the exception of yes_no datatypes
which are converted into perlish boolean values (1 or 0).

All xte*() methods will return an undefined value unless the xte_start entry is set.

The entry() method can be used to access any entry including unofficial extensions. However,
it is safer to use the named methods where possible, to avoid inventing unofficial extensions through typos.

=head1 AUTHOR

Mark Howe, E<lt>melonman@cpan.orgE<gt>

=head2 EXPORT

None

=cut

#Records fields:
#  scalar/list
#  Optional? (1 means 'yes')
#  data type
#  data type specific fields:
#     min, max for numbers
#     required permissions for files/directories

my $xac_settings =
{
    'accept_from',                ['scalar',0,'ip'],
    'access_log_path',            ['scalar',0,'abs_create','rw'],
    'boot_log_path',              ['scalar',0,'abs_create','rw'],
    'chime_multiplier',           ['scalar',0,'integer', 2],
    'clean_states_path',          ['scalar',0,'path'],
    'config_type',                ['scalar',0,'word'],
    'current_states_path',        ['scalar',0,'path'],
    'debug_level',                ['scalar',0,'integer' ,0,    127],
    'debug_log_path',             ['scalar',0,'abs_create','rw'],
    'error_log_path',             ['scalar',0,'abs_create','rw'],
    'listen_on',                  ['scalar',0,'ip'],
    'log_file_paths',             ['list',  0,'abs_create','rw'],
    'max_buffer_size',            ['scalar',0,'integer', 1],
    'max_connections',            ['scalar',0,'integer', 1],
    'max_input_frequency',        ['scalar',0,'integer', 0],
    'max_input_length',           ['scalar',0,'integer', 1],
    'modifiable_data_files',      ['list',  0,'xml_leaf'],
    'modifiable_transform_files', ['list',  0,'xsl_leaf'],
    'outer_read_timeout',         ['scalar',0,'float',   0],
    'path',                       ['scalar',1,'abs_dir', 'r'],
    'peel_multiplier',            ['scalar',0,'integer' ,2],
    'persistent_modifiable_files',['list',  1,'xml_leaf'],
    'port',                       ['scalar',0,'integer', 1,   65535],
    'start_xte',                  ['scalar',0,'yes_no'],
    'startup_commands',           ['list',  0,'xml_leaf'],
    'startup_files_path',         ['scalar',0,'path'],
    'tick_interval',              ['scalar',0,'float',   0.01],
    'transform_xsl',              ['scalar',0,'xsl_leaf'],
    'transform_xsl_path',         ['scalar',0,'path']
};

my $xte_settings =
{
    'xte_check_for_waiting',     ['scalar',1,'integer',0],
    'xte_cidr_allow',            ['list',  1,'cidr'],
    'xte_cidr_deny',             ['list',  1,'cidr'],
    'xte_docroot',               ['scalar',0,'abs_dir','rw'],
    'xte_enable_static_serving', ['scalar',0,'yes_no'],
    'xte_from_address',          ['scalar',0,'email'],
    'xte_gateway_auth',          ['scalar',0,'word'],
    'xte_group',                 ['scalar',1,'word'],
    'xte_host',                  ['scalar',0,'ip'],
    'xte_log_file',              ['scalar',1,'abs_create','rw'],
    'xte_log_level',             ['scalar',1,'integer',0,    4],
    'xte_max_requests',          ['scalar',1,'integer',1],
    'xte_max_servers',           ['scalar',1,'integer',1],
    'xte_max_spare_servers',     ['scalar',1,'integer',1],
    'xte_mimetype_path',         ['scalar',1,'abs_file','r'],
    'xte_min_servers',           ['scalar',1,'integer',1],
    'xte_min_spare_servers',     ['scalar',1,'integer',1],
    'xte_port',                  ['scalar',0,'integer', 1,   65535],
    'xte_post_max',              ['scalar',0,'integer',1],
    'xte_smtp_charset',          ['scalar',0],
    'xte_smtp_encoding',         ['scalar',0],
    'xte_smtp_host',             ['scalar',0,'ip'],
    'xte_smtp_port',             ['scalar',0,'integer', 1,   65535],
    'xte_static_directories',    ['list',  1,'word'],
    'xte_splurge_input',         ['scalar',1,'yes_no'],
    'xte_user',                  ['scalar',1,'word'],
    'xte_xac_timeout',           ['scalar',0,'integer',1],

    'xca_path',                   ['scalar',1,'abs_dir', 'r'],
    'xca_time_display_function',  ['scalar',1,'function_name']
};

=head1 CREATOR METHODS

=head2 new(config_file_path [,verbose])

Creates and returns an Xcruciate::XcruciateConfig object which can then be queried.
If the optional verbose argument is perlishly true it  will show its working to STDOUT.
At present it looks for configuration errors and die noisily if it finds any.
This is useful behaviour for management scripts - continuing to set up server daemons
on the basis of broken configurations is not best practice - but non-fatal error
reporting could be provided if/when an application requires it.

=cut

sub new {
    my $class = shift;
    my $path = shift;
    my $verbose = 0;
    $verbose = shift if defined $_[0];
    my $self = {};

    Xcruciate::Utils::check_path('unit config file',$path,'r');
    print "Attempting to parse xacd config file... " if $verbose;
    my $parser = XML::LibXML->new();
    my $xac_dom = $parser->parse_file($path);
    print "done\n" if $verbose;
    my @config = $xac_dom->findnodes("/config/scalar");
    die "Config file doesn't look anything like a config file - 'xcruciate file_help' for some clues" unless $config[0];
    my @config_type = $xac_dom->findnodes("/config/scalar[\@name='config_type']/text()");
    die "config_type entry not found in unit config file" unless $config_type[0];
    my $config_type = $config_type[0]->toString;
    die "config_type in unit config file is '$config_type' (should be 'unit') - are you confusing xcruciate and unit config files?" unless $config_type eq 'unit';
    my @errors = ();
    foreach my $entry ($xac_dom->findnodes("/config/*[(local-name() = 'scalar') or (local-name() = 'list')]")) {
	push @errors,sprintf("No name attribute for element '%s'",$entry->nodeName) unless $entry->hasAttribute('name');
	my $entry_record = $xac_settings->{$entry->getAttribute('name')} ||  $xte_settings->{$entry->getAttribute('name')};
	if (not defined $entry_record) {
	    next;
	} elsif (not($entry->nodeName eq $entry_record->[0])){
	    push @errors,sprintf("Entry called %s should be a %s not a %s",$entry->getAttribute('name'),$entry_record->[0],$entry->nodeName);
	} elsif ((not $entry->textContent) and ((not $entry_record->[1]) or $entry->textContent!~/^\s*$/s)) {
	    push @errors,sprintf("Entry called %s requires a value",$entry->getAttribute('name'))
	} elsif (($entry->nodeName eq 'scalar')  and $entry_record->[2] and ((not $entry_record->[1]) or $entry->textContent!~/^\s*$/s or $entry->textContent)){
	    push @errors,Xcruciate::Utils::type_check($self,$entry->getAttribute('name'),$entry->textContent,$entry_record);
	} elsif (($entry->nodeName eq 'list') and $entry_record){
	    my @items = $entry->findnodes('item/text()');
	    push @errors,sprintf("Entry called %s requires at least one item",$entry->getAttribute('name')) if ((not $entry_record->[2]) and (not @items));
	    my $count = 1;
	    foreach my $item (@items) {
		push @errors,Xcruciate::Utils::type_check($self,$entry->getAttribute('name'),$item->textContent,$entry_record,$count);
		$count++;
	    }
	}
	push @errors,sprintf("Duplicate entry called %s",$entry->getAttribute('name')) if defined $self->{$entry->getAttribute('name')};
	if ($entry->nodeName eq 'scalar') {
	    $self->{$entry->getAttribute('name')} = $entry->textContent;
	} else {
	    $self->{$entry->getAttribute('name')} = [] unless defined $self->{$entry->getAttribute('name')};
	    foreach my $item ($entry->findnodes('item/text()')) {
		push @{$self->{$entry->getAttribute('name')}},$item->textContent;
	    }
	    }
    }
    foreach my $entry (keys %{$xac_settings}) {
	push @errors,sprintf("No xacerbate entry called %s",$entry) unless ((defined $self->{$entry}) or ($xac_settings->{$entry}->[1]));
    }
    if ((defined $self->{start_xte}) and ($self->{start_xte} eq "yes")) {
	foreach my $entry (keys %{$xte_settings}) {
	    push @errors, sprintf("No xteriorize entry called %s",$entry) unless ((defined $self->{$entry}) or ($xte_settings->{$entry}->[1]));
	}
    }
    if (@errors) {
	print join "\n",@errors;
	print "\n";
	die "Errors in unit config file - cannot continue";
    } else {
	bless($self,$class);
	return $self;
    }
}

=head1 UTILITY METHODS

=head2 xac_file_format_description()

Returns multi-lined human-friendly description of the xac config file

=cut

sub xac_file_format_description {
    my $self = shift;
    my $ret = '';
    foreach my $entry (sort (keys %{$xac_settings},keys %{$xte_settings})) {
	my $record = $xac_settings->{$entry} ||  $xte_settings->{$entry};
	$ret .= "$entry (";
	$ret .= "optional " if $record->[1];
	$ret .="$record->[0])";
	if (not $record->[2]) {
	} elsif (($record->[2] eq 'integer') or ($record->[2] eq 'float')) {
	    $ret .= " - $record->[2]";
	    $ret .= " >= $record->[3]" if defined $record->[3];
	    $ret .= " and <= $record->[4]" if defined $record->[4];
	} elsif ($record->[2] eq 'ip') {
	    $ret .= " - ip address";
	} elsif ($record->[2] eq 'word') {
	    $ret .= " - word (ie no whitespace)";
	} elsif ($record->[2] eq 'path') {
	    $ret .= " - path (currently a word)";
	} elsif ($record->[2] eq 'xml_leaf') {
	    $ret .= " - filename with an xml suffix";
	} elsif ($record->[2] eq 'xsl_leaf') {
	    $ret .= " - filename with an xsl suffix";
	} elsif ($record->[2] eq 'yes_no') {
	    $ret .= " - 'yes' or 'no'";
	} elsif ($record->[2] eq 'email') {
	    $ret .= " - email address";
	} elsif ($record->[2] eq 'abs_dir') {
	    $ret .= " - absolute directory path with $record->[3] permissions";
	} elsif ($record->[2] eq 'abs_file') {
	    $ret .= " - absolute file path with $record->[3] permissions";
	} elsif ($record->[2] eq 'abs_create') {
	    $ret .= " - absolute file path with $record->[3] permissions for directory";
	}
	$ret .= "\n";
    }
    return $ret;
}

=head1 ACCESSOR METHODS

=head2 accept_from()

Returns the ip range from which connections are accepted.

=cut

sub accept_from {
    my $self= shift;
    return $self->{accept_from};
}

=head2 access_log_path()

Returns the path to the access log.

=cut

sub access_log_path {
    my $self= shift;
    return $self->{access_log_path};
}

=head2 boot_log_path()

Returns the path to the boot log.

=cut

sub boot_log_path {
    my $self= shift;
    return $self->{boot_log_path};
}

=head2 chime_multiplier()

Returns the number of ticks per chime

=cut

sub chime_multiplier {
    my $self= shift;
    return $self->{chime_multiplier};
}

=head2 clean_states_path()

Returns the path to the directory containing clean versions of modifiable files.

=cut

sub clean_states_path {
    my $self= shift;
    return $self->{clean_states_path};
}

=head2 config_type()

Returns the type of config file, which in this case should always be 'unit'.

=cut

sub config_type {
    my $self= shift;
    return $self->{config_type};
}

=head2 current_states_path()

Returns the path to the directory containing current versions of modifiable files.

=cut

sub current_states_path {
    my $self= shift;
    return $self->{current_states_path};
}

=head2 debug_level()

Returns the xacerbate debug level.

=cut

sub debug_level {
    my $self= shift;
    return $self->{debug_level};
}

=head2 debug_log_path()

Returns the path to the xacerbate debug log.

=cut

sub debug_log_path {
    my $self= shift;
    return $self->{debug_log_path};
}

=head2 entry(name)

Returns the entry called name. Lists will be returned by reference. Use named methods in preference to this one where possible.

=cut

sub entry {
    my $self= shift;
    my $name=shift;
    return $self->{$name};
}

=head2 error_log_path()

Returns the path to the xacerbate error log.

=cut

sub error_log_path {
    my $self= shift;
    return $self->{error_log_path};
}

=head2 listen_on()

Returns the address on which xacerbate listens.

=cut

sub listen_on {
    my $self= shift;
    return $self->{listen_on};
}

=head2 log_file_paths()

Returns a list of locations to which xacerbate application code can write logs.

=cut

sub log_file_paths {
    my $self= shift;
    return @{$self->{log_file_paths} || ()};
}

=head2 max_buffer_size()

Returns the maximum buffer size allowed for any one connection.

=cut

sub max_buffer_size {
    my $self= shift;
    return $self->{max_buffer_size};
}

=head2 max_connections()

Returns the maximum number of connections accepted by xacerbate.

=cut

sub max_connections {
    my $self= shift;
    return $self->{max_connections};
}

=head2 max_input_frequency()

Returns the maximum number of XML documents allowed per second and per connection.

=cut

sub max_input_frequency {
    my $self= shift;
    return $self->{max_input_frequency};
}

=head2 max_input_length()

Returns the maximum character length of each XML document.

=cut

sub max_input_length {
    my $self= shift;
    return $self->{max_input_length};
}

=head2 modifiable_data_files()

Returns a list of modifiable data filenames.

=cut

sub modifiable_data_files {
    my $self= shift;
    return @{$self->{modifiable_data_files} || ()};
}

=head2 modifiable_transform_files()

Returns a list of modifiable XSL filenames.

=cut

sub modifiable_transform_files {
    my $self= shift;
    return @{$self->{modifiable_transform_files} || ()};
}

=head2 outer_read_timeout()

Returns the maximum wait time for the xacerbate outer loop.

=cut

sub outer_read_timeout {
    my $self= shift;
    return $self->{outer_read_timeout};
}

=head2 path()

Returns the path that is prefixed by xacerbate to various other settings.

=cut

sub path {
    my $self= shift;
    return $self->{path};
}

=head2 peel_multiplier()

Returns the number of chimes per peel.

=cut

sub peel_multiplier {
    my $self= shift;
    return $self->{peel_multiplier};
}

=head2 port()

Returns the port used by xacerbate.

=cut

sub port {
    my $self= shift;
    return $self->{port};
}

=head2 persistent_modifiable_files()

Returns a list of modifiable files that should persist from session to session, ie they are not overwritten from clean on startup.

=cut

sub persistent_modifiable_files {
    my $self= shift;
    return @{$self->{persistent_modifiable_files} || ()};
}

=head2 start_xte()

Returns start_xte value (true or false), ie whether xteriorize should be started alongside xacerbate.

=cut

sub start_xte {
    my $self= shift;
    if (lc($self->{start_xte}) eq 'yes') {
	return 1
    } else {return 0}
}

=head2 startup_commands()

Returns a list of startup command filenames.

=cut

sub startup_commands {
    my $self= shift;
    return @{$self->{startup_commands} || ()};
}

=head2 startup_files_path()

Returns the path to the startup command files.

=cut

sub startup_files_path {
    my $self= shift;
    return $self->{startup_files_path};
}

=head2 tick_interval()

Returns the interval between ticks (or twice the interval between a tick and a tock).

=cut

sub tick_interval {
    my $self= shift;
    return $self->{tick_interval};
}

=head2 transform_xsl()

Returns the name of the main transform file used by xacerbate.

=cut

sub transform_xsl {
    my $self= shift;
    return $self->{transform_xsl};
}

=head2 transform_xsl_path()

Returns the path of the directory containing the main transform file used by xacerbate.

=cut

sub transform_xsl_path {
    my $self= shift;
    return $self->{transform_xsl_path};
}

=head2 xca_path()

Returns the path to the directory containing xcathedra (if defined).

=cut

sub xca_path {
    my $self= shift;
    return $self->{xca_path};
}

=head2 xca_time_display_function()

Returns the function used to turn XSLT-format timestamps into something readable.

=cut

sub xca_time_display_function {
    my $self= shift;
    return $self->{xca_time_display_function};
}

=head2 xte_check_for_waiting()

Returns the xte_check_for_waiting value (time to wait before revising number of child processes).

=cut

sub xte_check_for_waiting {
    my $self= shift;
    return $self->{xte_check_for_waiting};
}

=head2 xte_cidr_allow()

Returns a list of allowed ip ranges for xteriorize

=cut

sub xte_cidr_allow {
    my $self= shift;
    if (($self->{start_xte} eq 'yes') and $self->{xte_cidr_allow}) {
	return @{$self->{xte_cidr_allow}};
    } else {
	return ();
    }
}

=head2 xte_cidr_deny()

Returns a list of denied ip ranges for xteriorize

=cut

sub xte_cidr_deny {
    my $self= shift;
    if (($self->{start_xte} eq 'yes') and $self->{xte_cidr_deny}) {
	return @{$self->{xte_cidr_deny}};
    } else {
	return ();
    }
}

=head2 xte_docroot()

Returns the docroot used by xteriorize.

=cut

sub xte_docroot {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_docroot};
    } else {
	return undef;
    }
}

=head2 xte_enable_static_serving()

Returns true if direct static file serving (ie without xacerbate) is enabled.

=cut

sub xte_enable_static_serving {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return not(not $self->{xte_enable_static_serving});
    } else {
	return undef;
    }
}

=head2 xte_from_address()

Returns the from address for emails sent by xteriorize

=cut

sub xte_from_address {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_from_address};
    } else {
	return undef;
    }
}

=head2 xte_gateway_auth()

Returns the from code expected by xacerbate to authorize gateway connections.

=cut

sub xte_gateway_auth {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_gateway_auth};
    } else {
	return undef;
    }
}

=head2 xte_group()

Returns the un*x group to use for xteriorize child processes. May be undefined.

=cut

sub xte_group {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_group};
    } else {
	return undef;
    }
}

=head2 xte_host()

Returns the ip on which xteriorize will listen.

=cut

sub xte_host {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_host};
    } else {
	return undef;
    }
}

=head2 xte_log_file()

Returns the path to the xte log file.

=cut

sub xte_log_file {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_log_file};
    } else {
	return undef;
    }
}

=head2 xte_log_level()

Returns the xteriorize log level.

=cut

sub xte_log_level {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_log_level};
    } else {
	return undef;
    }
}

=head2 xte_max_servers()

Returns the Net::Prefork max_servers value for xteriorize.

=cut

sub xte_max_servers {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_max_servers};
    } else {
	return undef;
    }
}

=head2 xte_max_requests()

Returns the Net::Prefork max_requests value for xteriorize.

=cut

sub xte_max_requests {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_max_requests};
    } else {
	return undef;
    }
}

=head2 xte_max_spare_servers()

Returns the Net::Prefork max_spare_servers value for xteriorize.

=cut

sub xte_max_spare_servers {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_max_spare_servers};
    } else {
	return undef;
    }
}

=head2 xte_mimetype_path()

Returns the path to the mimetype lookup table for direct static file serving.

=cut

sub xte_mimetype_path {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_mimetype_path};
    } else {
	return undef;
    }
}

=head2 xte_min_servers()

Returns the Net::Prefork min_servers value for xteriorize.

=cut

sub xte_min_servers {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_min_servers};
    } else {
	return undef;
    }
}

=head2 xte_min_spare_servers()

Returns the Net::Prefork min_spare_servers value for xteriorize.

=cut

sub xte_min_spare_servers {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_min_spare_servers};
    } else {
	return undef;
    }
}

=head2 xte_port()

Returns the port used by xteriorize.

=cut

sub xte_port {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_port};
    } else {
	return undef;
    }
}

=head2 xte_post_max()

Returns the maximum character size of an http request received by xteriorize.

=cut

sub xte_post_max {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_post_max};
    } else {
	return undef;
    }
}

=head2 xte_smtp_charset()

Returns the charset used for smtp by xteriorize.

=cut

sub xte_smtp_charset {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_smtp_charset};
    } else {
	return undef;
    }
}

=head2 xte_smtp_encoding()

Returns the encoding used for smtp by xteriorize.

=cut

sub xte_smtp_encoding {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_smtp_encoding};
    } else {
	return undef;
    }
}

=head2 xte_smtp_host()

Returns the host used for smtp by xteriorize.

=cut

sub xte_smtp_host {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_smtp_host};
    } else {
	return undef;
    }
}

=head2 xte_smtp_port()

Returns the port used for smtp by xteriorize.

=cut

sub xte_smtp_port {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_smtp_port};
    } else {
	return undef;
    }
}

=head2 xte_splurge_input()

Returns true if xte_splurge_input is enabled (copies XML sent from xteriorize to xacerbate to STDERR).

=cut

sub xte_splurge_input {
    my $self= shift;
    if (not $self->{start_xte}) {
	return undef;
    } elsif (lc($self->{xte_splurge_input}) eq 'yes') {
	return 1
    } else {return 0}
}

=head2 xte_static_directories()

Returns a list of directories under docroot from which files will be served directly by Xteriorized.

=cut

sub xte_static_directories {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return @{$self->{xte_static_directories} || ()};
    } else {
	return undef;
    }
}

=head2 xte_user()

Returns the un*x user to use for xteriorize child processes. May be undefined.

=cut

sub xte_user {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_user};
    } else {
	return undef;
    }
}

=head2 xte_xac_timeout()

Returns the delay for a response to xteriorize by xacerbate, after which xteriorize will issue a 504 ('gateway time-out') error.

=cut

sub xte_xac_timeout {
    my $self= shift;
    if ($self->{start_xte} eq 'yes') {
	return $self->{xte_xac_timeout};
    } else {
	return undef;
    }
}

=head1 BUGS

The best way to report bugs is via the Xcruciate bugzilla site (F<http://www.xcruciate.co.uk/bugzilla>).

=head1 PREVIOUS VERSIONS

=over

B<0.01>: First upload

B<0.03>: First upload including module

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2009 by SARL Cyberporte/Menteith Consulting

This library is distributed under the BSD licence (F<http://www.xcruciate.co.uk/licence-code>).

=cut

1;
