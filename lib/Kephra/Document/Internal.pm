package Kephra::Document::Internal;
$VERSION = '0.09';

use strict;
use Wx qw(wxYES wxNO);


# make document empty and reset all document properties to default
sub reset {
	my $edit_panel = Kephra::App::EditPanel::_get();
	Kephra::Document::set_readonly(0);
	$edit_panel->ClearAll;
	$edit_panel->EmptyUndoBuffer;
	$edit_panel->SetSavePoint;
	Kephra::Document::set_file_path('');
	reset_properties();
	eval_properties();
}

# restore once opened file from his settings
sub restore {
	my %file_settings = %{ shift; };
	my $file_name = $file_settings{file_path};
	if ( -e $file_name ) {

		# open only text files and empty files
		return if !-z $file_name and -B $file_name
			and ( $Kephra::config{file}{open}{only_text} == 1 );
		# check if file is already open and goto this already opened
		if ( $Kephra::config{file}{open}{each_once} == 1 ){
			for ( 0 .. Kephra::Document::_get_last_nr() ) {
				return if $Kephra::document{open}[$_]{file_path} eq $file_name;
			}
		}

		my $doc_nr = new_if_allowed('restore');
		load_in_current_buffer($file_name);
		%{ $Kephra::document{open}[$doc_nr] } = %file_settings;
		Kephra::App::TabBar::refresh_label()
	}
}


# add newly opened file
sub add {
	my $file_name = shift;
	if ( defined $file_name and -e $file_name ) {

		# open only text files and empty files
		return if ( !-z $file_name and -B $file_name
			and $Kephra::config{file}{open}{only_text} == 1 );

		# check if file is already open and goto this already opened
		if ( $Kephra::config{file}{open}{each_once} == 1 ){
			for ( 0 .. Kephra::Document::_get_last_nr() ) {
				if ( $Kephra::document{open}[$_]{file_path} eq $file_name ){
					Kephra::Document::Change::to_number($_);
					return;
				}
			}
		}
		save_properties();
		my $doc_nr = new_if_allowed('add');
		$file_name = File::Spec->canonpath( $file_name );
		load_in_current_buffer($file_name);
		Kephra::Document::_set_current_nr($doc_nr);
		reset_properties();
		eval_properties();
		Kephra::App::Window::refresh_title();
		Kephra::App::EditPanel::Margin::autosize_line_number();
		Kephra::API::EventTable::trigger('document.list');
	}

}

# create a new document if settings allow it
sub new_if_allowed {
	my $mode = shift;	# new(empty), add(open) restore(open session)
	my $ep  = Kephra::App::EditPanel::_get();
	my $file_name = Kephra::Document::_get_current_file_path();
	my $old_doc_nr= Kephra::Document::_get_current_nr();
	my $doc_nr    = $Kephra::temp{document}{buffer};
	my $config    = $Kephra::config{file}{open};

	# check settings
	# in single doc mode close previous doc first
	if ( $config->{single_doc} == 1 ) {
		Kephra::File::close_current();
		return 0;
	}
	unless ( $mode eq 'new' ) {
		if ($ep->GetText eq '' 
		and $ep->GetModify == 0 
		and ( !$file_name or !-e $file_name ) ){
			return $old_doc_nr
				if ($config->{into_empty_doc} == 1)
				or ($config->{into_only_empty_doc} == 1
					and $Kephra::temp{document}{buffer} == 1 );
		}
	}

	# still there? ok now we make a new document
	$Kephra::temp{document}{open}[$doc_nr]{pointer}= $ep->CreateDocument;
	$Kephra::temp{document}{buffer}++;

	change_pointer($doc_nr);
	Kephra::App::TabBar::add_page();
	Kephra::App::TabBar::set_current_page($doc_nr);
	return $doc_nr;
}


sub load_in_current_buffer {
	my $file_name = shift || '';
	my $edit_panel = Kephra::App::EditPanel::_get();
	$edit_panel->ClearAll();
	Kephra::File::IO::open_pipe($file_name);
	$edit_panel->EmptyUndoBuffer;
	$edit_panel->SetSavePoint;
	Kephra::Document::set_file_path($file_name);
	$Kephra::temp{document}{loaded}++;
}


sub check_b4_overwite {
	my $filename = shift;
	$filename = Kephra::Document::_get_current_file_path() unless $filename;
	my $allow = $Kephra::config{file}{save}{overwrite};
	if ( -e $filename ) {
		my $frame = &Kephra::App::Window::_get();
		my $label = $Kephra::localisation{dialog};
		if ( $allow eq 'ask' ) {
			my $answer = Kephra::Dialog::get_confirm_2( $frame,
				"$label->{general}{overwrite} $filename ?",
				$label->{file}{overwrite},
				-1, -1
			);
			return 1 if $answer == wxYES;
			return 0 if $answer == wxNO;
		} else {
			Kephra::Dialog::info_box( $frame,
				$label->{general}{dont_allow},
				$label->{file}{overwrite}
			) unless $allow;
			return $allow;
		}
	} else { return -1 }
}

# set the config default to the selected document
sub reset_properties {
	my $doc_nr = shift;
	$doc_nr = $Kephra::document{current_nr} unless $doc_nr;
	my $defaults  = $Kephra::config{file}{defaultsettings};
	my $doc_attr  = $Kephra::document{open}[$doc_nr];
	my $file_name = $doc_attr->{file_path};

	$doc_attr->{syntaxmode} = $defaults->{syntaxmode} eq 'auto'
		? Kephra::Document::SyntaxMode::_get_auto($doc_nr)
		: $defaults->{syntaxmode};

	if ($file_name and ( -e $file_name )) 
		 {$doc_attr->{EOL} = $defaults->{EOL_open}}
	else {$doc_attr->{EOL} = $defaults->{EOL_new};
		Kephra::Document::set_EOL_mode( $doc_attr->{EOL} );
	}
	$doc_attr->{tab_use}  = $defaults->{tab_use};
	$doc_attr->{tab_size} = $defaults->{tab_size};
	$doc_attr->{codepage} = $defaults->{codepage};
	$doc_attr->{readonly} = $defaults->{readonly};
	$doc_attr->{cursor_pos} = 
		$defaults->{cursor_pos} ? $defaults->{cursor_pos} : 0;
	$doc_attr->{edit_pos} = -1;
}


sub eval_properties {
	my $doc_nr = shift;
	$doc_nr = Kephra::Document::_get_current_nr() if ( !$doc_nr );
	my $doc_attr = \%{$Kephra::document{open}[$doc_nr]};
	my $doc_data = \%{$Kephra::temp{document}{open}[$doc_nr]};
	my $ep = Kephra::App::EditPanel::_get();

	$doc_attr->{syntaxmode} = "none" unless $doc_attr->{syntaxmode};
	Kephra::Document::SyntaxMode::change_to( $doc_attr->{syntaxmode} );
	Kephra::Document::set_EOL_mode( $doc_attr->{EOL} );
	Kephra::Document::set_tab_mode( $doc_attr->{tab_use} );
	Kephra::Document::set_tab_size( $doc_attr->{tab_size} );
	Kephra::Document::set_readonly( $doc_attr->{readonly} );

	# setting selection and caret position
	if ($doc_data->{selstart} and $doc_data->{selstart}) {
		$doc_attr->{cursor_pos} < $doc_data->{selend}
			? $ep->SetSelection( $doc_data->{selend},$doc_data->{selstart})
			: $ep->SetSelection( $doc_data->{selstart},$doc_data->{selend});
	} else { $ep->GotoPos( $doc_attr->{cursor_pos} ) }
	if ($Kephra::config{file}{open}{in_current_dir}){
		$Kephra::config{file}{current}{directory} = $doc_data->{directory}
			if $doc_data->{directory};
	} else { $Kephra::config{file}{current}{directory} = '' }
	Kephra::Edit::_let_caret_visible();
	#Kephra::App::StatusBar::refresh();
	Kephra::App::EditPanel::set_word_chars();
	Kephra::App::EditPanel::paint_bracelight()
		if $Kephra::config{editpanel}{indicator}{bracelight}{visible};
	Wx::Window::SetFocus($ep) unless $Kephra::temp{dialog}{control};
	
	# is that really necesary ?
	Kephra::API::EventTable::trigger('document.savepoint','document.text.change');
}


sub save_properties {
	my $doc_nr = shift;
	$doc_nr = $Kephra::document{current_nr} unless $doc_nr;
	my $doc_attr = $Kephra::document{open}[$doc_nr];
	my $doc_data = $Kephra::temp{document}{open}[$doc_nr];
	my $ep = Kephra::App::EditPanel::_get();

	$doc_attr->{cursor_pos}= $ep->GetCurrentPos;
	$doc_data->{selstart}  = $ep->GetSelectionStart;
	$doc_data->{selend}    = $ep->GetSelectionEnd;
}


sub change_pointer {
	my $newtab = shift;
	$newtab = 0 unless $newtab ;
	my $oldtab  = Kephra::Document::_get_current_nr();
	my $docsdata = $Kephra::temp{document}{open};
	my $ep      = Kephra::App::EditPanel::_get();
	$ep->AddRefDocument( $docsdata->[$oldtab]{pointer} );
	$ep->SetDocPointer( $docsdata->[$newtab]{pointer} );
	$ep->ReleaseDocument( $docsdata->[$newtab]{pointer} );
	Kephra::Document::_set_current_nr($newtab);
}

# various helper
sub dissect_path {
	my ($file_path, $doc_nr) = @_;
	my $doc_data = $Kephra::temp{document}{open}[$doc_nr];
	my ($volume, $directories, $file) = File::Spec->splitpath( $file_path );
	$directories = $volume.$directories if $volume;
	$doc_data->{directory} = $directories;
	$doc_data->{name}      = $file;

	if ( length($file) > 0 ) {
		my @filenameparts = split /\./, $file ;
		$doc_data->{ending} = pop @filenameparts if @filenameparts > 1;
		$doc_data->{firstname} = join '.', @filenameparts;
	}
}

# depreciated
sub set_path_slashes_to_OS_standart{ File::Spec->canonpath( shift ) }

1;