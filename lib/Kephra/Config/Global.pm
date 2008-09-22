package Kephra::Config::Global;
our $VERSION = '0.24';

use strict;
use warnings;

# handling main config files under /config/global/

sub _conf_sub_path {'global'}
sub _current_file  {Kephra::Config::filepath( $Kephra::temp{file}{config}{auto});
}
sub load_autosaved {
	my $autosave = _current_file();
	my $backup = $autosave . '~';
	#$main::logger->debug("load_autosaved");

	for my $file ($autosave, $backup) {
		if ( -e $file ) {
			my $config_tree = Kephra::Config::File::load($file);
			%Kephra::config = %$config_tree if ref $config_tree eq 'HASH';
			last if %Kephra::config;
			rename $file, $file . '.failed';
		}
	}
	# emergency program if configs missing
	unless ( %Kephra::config ) {
		%Kephra::config = %{ Kephra::Config::Default::global_settings() };
	}
}

sub save_autosaved {
	#$main::logger->debug("save_autosaved");
	my $file_name = _current_file();
	rename $file_name, $file_name . '~';
	Kephra::Config::File::store( $file_name, \%Kephra::config );
}


sub open_current_file {
	save_current();
	Kephra::Document::Internal::add( _current_file() );
	#Kephra::File::reload_current();
	Kephra::Document::set_attribute('config_file',1);
	Kephra::App::TabBar::refresh_current_label();
}

sub load_backup_file { reload( _current_file().'~' ) }

sub load_defaults {
	require Kephra::Config::Embedded;
	%Kephra::config = %{ Kephra::Config::Embedded::global_settings() };
	evaluate();
}

sub load_from {
	my $filename = Kephra::Dialog::get_file_open(
		Kephra::App::Window::_ref(),
		$Kephra::localisation{dialog}{config_file}{load},
		Kephra::Config::dirpath( _conf_sub_path() ),
		$Kephra::temp{file}{filterstring}{config}
	);
	reload($filename) if -e $filename;
}

sub update {
	Kephra::App::Window::save_positions();
	Kephra::Document::Internal::save_properties();
	Kephra::Edit::Bookmark::save_all();
	Kephra::Extension::Notepad::save();
	Kephra::Extension::Output::save();
}

sub evaluate {
	my $t0 = new Benchmark;

	Kephra::API::EventTable::delete_all();
	Kephra::API::EventTable::stop_timer();

	Kephra::Config::Interface::load();
	my $t1 = new Benchmark;
print "  iface cnfg:", Benchmark::timestr( Benchmark::timediff( $t1, $t0 ) ), "\n"
	if $Kephra::BENCHMARK;

	# set interna to default
	$Kephra::app{GUI}{masterID}     = 20;
	$Kephra::temp{dialog}{control}  = 0;
	Kephra::Document::SyntaxMode::_ID('none');
	Kephra::Edit::Search::_init_history();
	Kephra::Edit::Search::_refresh_search_flags();
	Kephra::Config::build_fileendings2syntaxstyle_map();
	Kephra::Config::build_fileendings_filterstring();
	my $t2 = new Benchmark;
print "  prep. data:", Benchmark::timestr( Benchmark::timediff( $t2, $t1 ) ), "\n"
	if $Kephra::BENCHMARK;

	# main window components
	Kephra::App::Window::apply_settings();
	Kephra::App::ContextMenu::create_all();
	Kephra::App::MenuBar::create();
	Kephra::App::MainToolBar::create();
	Kephra::App::SearchBar::create();
	Kephra::App::TabBar::create();
	Kephra::App::StatusBar::create();

	Kephra::Extension::Notepad::create();
	Kephra::Extension::Output::create();

	Kephra::App::assemble_layout();

	my $t3 = new Benchmark;
print "  create gui:", Benchmark::timestr( Benchmark::timediff( $t3, $t2 ) ), "\n"
	if $Kephra::BENCHMARK;

	Kephra::App::ContextMenu::connect_all();
	Kephra::App::EditPanel::apply_settings();
	Kephra::Edit::Bookmark::define_marker();
	my $t4 = new Benchmark;
print "  apply sets:", Benchmark::timestr( Benchmark::timediff( $t4, $t3 ) ), "\n"
	if $Kephra::BENCHMARK;

	Kephra::Config::Interface::del_temp_data();
	Kephra::API::CommandList::del_temp_data();
	#Kephra::API::EventTable::thaw_all();
	#Kephra::App::clean_acc_table();

	return 1;
}


sub reload {
	my $configfile = shift || _current_file();
	if ( -e $configfile ) {
		Kephra::Document::Internal::save_properties();
		my %test_hash = %{ Kephra::Config::File::load($configfile) };
		if (%test_hash) {
			%Kephra::config = %test_hash;
			reload_tree();
		} else {
			save();
			Kephra::File::reload_current();
		}
	} else {
		my $err_msg = $Kephra::localisation{dialog}{error};
		Kephra::Dialog::warning_box( undef, 
			$err_msg->{file_find} . "\n $configfile", $err_msg->{config_read} );
	}
}

sub reload_tree {
	update();
	evaluate();
	Kephra::App::TabBar::refresh_all_label();
	Kephra::Document::Internal::eval_properties();
}

sub reload_current { reload( _current_file() ) }

sub eval_config_file {
	my $file_path   = Kephra::Config::standartize_path_slashes( shift );
	my $config_path = Kephra::Config::dirpath();
	my $l_path = length $config_path;
	if ($config_path eq substr( $file_path, 0, $l_path)){
		$file_path = substr $file_path, $l_path+1;
	}
	my $conf = $Kephra::config{app};
	my $match = \&Kephra::Config::path_matches;

	if ( &$match( $file_path, 
		$Kephra::temp{file}{config}{auto},
		$conf->{localisation_file},
		$conf->{commandlist}{file}        )) {
		return reload();
	}
	if ( &$match( $file_path, $conf->{menubar}{file} ) ) {
		return Kephra::App::MenuBar::create() 
	}
	if ( &$match( $file_path, $conf->{toolbar}{main}{file} ) ) {
		return Kephra::App::MainToolBar::create();
	} 
	if ( &$match( $file_path, $conf->{toolbar}{search}{file} ) ) {
		Kephra::App::SearchBar::create();
		Kephra::App::SearchBar::position();
		return;
	}
	# reload template menu wenn template file changed
	my $cfg = $Kephra::config{file}{templates};
	my $path = File::Spec->catfile( $cfg->{directory}, $cfg->{file} );
	if ( substr($file_path, - length $path) eq $path ) {
		Kephra::App::Menu::set_absolete('file_insert_templates');
		Kephra::App::Menu::ready('file_insert_templates');
	}
}

#
sub save {
	my $file_name = shift || _current_file();
	update();
	Kephra::Config::File::store( $file_name, \%Kephra::config );
}

sub save_as {
	my $file_name = Kephra::Dialog::get_file_save(
		Kephra::App::Window::_ref(),
		$Kephra::localisation{dialog}{config_file}{save},
		Kephra::Config::dirpath(  _conf_sub_path() ),
		$Kephra::temp{file}{filterstring}{config}
	);
	save($file_name) if ( length($file_name) > 0 );
}

sub save_current { save( _current_file() ) }

#
sub merge_with {
	my $filename = Kephra::Dialog::get_file_open( 
		Kephra::App::Window::_ref(),
		$Kephra::localisation{dialog}{config_file}{load},
		Kephra::Config::dirpath( _conf_sub_path(), 'sub'),
		$Kephra::temp{file}{filterstring}{config}
	);
	load_subconfig($filename);
}

#
sub load_subconfig {
	my $file = shift;
	if ( -e $file ) {
		%Kephra::config = %{ Kephra::Config::Tree::merge
			(Kephra::Config::File::load($file), \%Kephra::config) };
		reload_tree();
	}
}


1;
