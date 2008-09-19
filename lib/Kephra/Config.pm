package Kephra::Config;
our $VERSION = '0.33';

use strict;
use warnings;

# low level config manipulation

use Cwd();
use File::Spec ();
use Wx qw( wxBITMAP_TYPE_ANY );

##################################
# Files and Dirs
##################################

sub init {
	my $basedir;
	#$Kephra::temp{path}{user} = $ENV{HOME};
	# set locations of boot files
	$Kephra::temp{file}{config}{auto}      = 'global/autosaved.conf';
	$Kephra::temp{file}{img}{splashscreen} = 'interface/icon/splash/start_kephra.jpg';

	if ($Kephra::STANDALONE) {
		$basedir = Cwd::cwd();
		$basedir = File::Spec->catdir($basedir, 'share')
			if $Kephra::STANDALONE eq 'dev';
	} else {
		my $copy_defaults;
		$basedir = Kephra::configdir();
		if (not -d $basedir) {$copy_defaults = 1 }
		else {
			my $bootfile = File::Spec->catfile
				( $basedir, 'config', $Kephra::temp{file}{config}{auto} );
			if (-r $bootfile) {
				my $config_tree = Kephra::Config::File::load($bootfile);
				$copy_defaults = 1 if not defined $config_tree->{about}{version}
				                   or $config_tree->{about}{version} ne $Kephra::VERSION;
			}
		}
		Kephra::user_config() if $copy_defaults;
		my $testfile = File::Spec->catfile( $basedir, 'config', 'syntaxmode', 'perl.conf');
		if (-e $testfile and not -w $testfile) {
			File::Find::find( sub {chmod(0700, $_)  if -f $_}, ($basedir));
		}
	}
	$Kephra::temp{path}{config} = File::Spec->catdir($basedir, 'config');
	$Kephra::temp{path}{help} = File::Spec->catdir($basedir, 'help');
	$Kephra::temp{path}{logger} = File::Spec->catdir($basedir, 'log');

	# make config files acessable
	# absolete when real syntax modes work
	push @INC, $Kephra::temp{path}{config};
}

# Generate a path to a configuration file
sub filepath { File::Spec->catfile( $Kephra::temp{path}{config}, @_ ) if $_[0] }

sub existing_filepath {
	my $path = filepath( @_ );
	unless ( -f $path ) {
		warn("The config file '$path' does not exist");
	}
	return $path;
}

sub dirpath { File::Spec->catdir( $Kephra::temp{path}{config}, @_ ) if $_[0] }

sub existing_dirpath {
	my $path = dirpath( @_ );
	unless ( -d $path ) {
		warn("The config directory '$path' does not exist");
	}
	return $path;
}

sub standartize_path_slashes { File::Spec->canonpath( shift ) }

sub path_matches {
	my $given = shift;
	for (@_) { return 1 if $given eq standartize_path_slashes($_) }
	return 0;
}
##################################
# Wx GUI Stuff
##################################

# Create a Wx::Colour from a config string
# Either hex "0066FF" or decimal "0,128,255" is allowed.
sub color {
	my $string = shift;
	unless ( defined $string ) {
		die "Color string is not defined";
	}

	# Handle hex format
	$string = lc $string;
	if ( $string =~ /^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i ) {
		return Wx::Colour->new( hex $1, hex $2, hex $3 );
	}

	# Handle comma-seperated
	if ( $string =~ /^(\d+),(\d+),(\d+)$/ ) {
		return Wx::Colour->new( $1 + 0, $2 + 0, $3 + 0 );
	}

	# Unknown
	die "Unknown color string '$string'";
}

# Create an icon bitmap Wx::Bitmap for a named icon
sub icon_bitmap {
	# Find the path from the name
	my $name = shift;
	unless ( defined $name ) {
		warn "Did not provide an icon name to icon_bitmap";
		return;
	}
	$name .= '.xpm' unless $name =~ /\.xpm$/ ;

	my $path = filepath( $Kephra::config{app}{iconset_path}, $name );
	return Wx::Bitmap->new(16,16) unless -e $path;

	my $bitmap = Wx::Bitmap->new( $path, wxBITMAP_TYPE_ANY );
	unless ( $bitmap ) {
		warn "Failed to create bit map from $path";
		return;
	}
	return $bitmap;
}


sub set_xp_style {
	my $xp_def_file = "$^X.manifest";
	if ( $^O eq 'MSWin32' ) {
		if (    ( $Kephra::config{app}{xp_style} eq '1' )
			and ( !-r $xp_def_file ) ) {
			Kephra::Config::Default::drop_xp_style_file($xp_def_file);
		}
		if (    ( $Kephra::config{app}{xp_style} eq '0' )
			and ( -r $xp_def_file ) ) {
			unlink $xp_def_file;
		}
	}
}

##################################
# misc helper stuff
##################################

sub build_fileendings2syntaxstyle_map {
	foreach ( keys %{ $Kephra::config{file}{endings} } ) {
		my $language_id = $_;
		my @fileendings
			= split( /\s+/, $Kephra::config{file}{endings}{$language_id} );
		foreach ( @fileendings ) {
			$Kephra::temp{file}{end2langmap}{$_} = $language_id;
		}
	}
}

sub build_fileendings_filterstring {
	my $files = $Kephra::localisation{dialog}{file}{files};
	my $all   = "$Kephra::localisation{dialog}{general}{all} $files (*.*)|*.*";
	$Kephra::temp{file}{filterstring}{all} = $all;
	foreach ( keys %{ $Kephra::config{file}{group} } ) {
		my ( $filter_id, $file_filter ) = ( $_, '' );
		my $filter_name = ucfirst($filter_id);
		my @language_ids
			= split( /\s+/, $Kephra::config{file}{group}{$filter_id} );
		foreach ( @language_ids ) {
			my @fileendings
				= split( /\s+/, $Kephra::config{file}{endings}{$_} );
			foreach (@fileendings) { $file_filter .= "*.$_;"; }
		}
		chop($file_filter);
		$Kephra::temp{file}{filterstring}{all}
			.= "|$filter_name $files ($file_filter)|$file_filter";
	}
	$Kephra::temp{file}{filterstring}{config}
		= "Config $files (*.conf;*.yaml)|*.conf;*.yaml|$all";
	$Kephra::temp{file}{filterstring}{scite}
		= "Scite $files (*.ses)|*.ses|$all";
}

sub _map2hash {
	my ( $style, $types_str ) = @_;
	my $stylemap = {};                        # holds the style map
	my @types = split( /\s+/, $types_str );
	foreach (@types) { $$stylemap{$_} = $style; }
	return ($stylemap);
}

sub _lc_utf {
	my $uc = shift;
	my $lc = "";
	for ( 0 .. length($uc) - 1 ) {
		$lc .= lcfirst( substr( $uc, $_, 1 ) );
	}
	$lc;
}
#pce:dialog::msg_box(undef,$mode,''); #Wx::wxUNICODE()

1;
