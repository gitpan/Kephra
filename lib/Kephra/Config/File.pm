package Kephra::Config::File;
our $VERSION = '0.06';

use strict;

#
# internal
#
sub _get_type {
	my $name = shift;
	return unless $name;
	my $file_end = substr $name, index($name , '.') + 1 , 1;
	return $file_end eq 'y' 
		? 'yaml'
		: 'conf';
}

#
# API 2 App
#
sub load_from_config_node_data {
	my $node = shift;
	return unless defined $node->{file} and $node->{node};
	load_node( Kephra::Config::filepath( $node->{file} ), $node->{node} );
}


sub load_node{
	my $file_name = shift;
	my $start_node = shift;
	my $config_tree = load($file_name);
	return defined $start_node 
		? Kephra::Config::Tree::get_subtree( $config_tree, $start_node )
		: $config_tree;
}


# !!! -NI
sub store_node{
	my $file_name = shift;
	my $start_node = shift;
}


sub load {
	my $file_name = shift;
	return unless -e $file_name;
	my $type = _get_type($file_name);
	if    ($type eq 'conf') { load_conf($file_name) }
	elsif ($type eq 'yaml') { load_yaml($file_name) }
}


sub store {
	my $file_name = shift;
	my $config = shift;
	my $type = _get_type($file_name);
	if    ($type eq 'conf') { store_conf($file_name, $config) }
	elsif ($type eq 'yaml') { store_yaml($file_name, $config) }
	Kephra::File::_remember_save_moment($file_name);
}


#
# API 2 YAML
#

sub load_yaml  { &YAML::LoadFile }
sub store_yaml { &YAML::DumpFile }

#
# API 2 General::Config 
#

sub load_conf {
	my ( $configfilename, %config ) = shift;
	my $error_msg = $Kephra::localisation{dialog}{error};
	if ( -e $configfilename ) {
		eval {
			$Kephra::app{config}{parser} = Config::General->new(
				-AutoTrue              => 1,
				-UseApacheInclude      => 1,
				-IncludeRelative       => 1,
				-InterPolateVars       => 0,
				-AllowMultiOptions     => 1,
				-MergeDuplicateOptions => 0,
				-MergeDuplicateBlocks  => 0,
				-ConfigFile            => $configfilename,
				-SplitPolicy           => 'equalsign'
			);
			%config = $Kephra::app{config}{parser}->getall;
		};
		Kephra::Dialog::warning_box (undef,
			"$configfilename: \n $@", $error_msg->{config_read})
				if $@ or !%config;
	} else {
		Kephra::Dialog::warning_box (undef,
			$error_msg->{config_read}."-".$configfilename, $error_msg->{file});
	}
	\%config;
}

sub store_conf {
	my ( $configfilename, $config ) = @_;
	$Kephra::app{config}{parser}->save_file( $configfilename, $config );
}

1;
