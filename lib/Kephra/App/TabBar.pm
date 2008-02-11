package Kephra::App::TabBar;    # notebook file selector
$VERSION = '0.11';

###############################################################################
# Tabbar is the visual element in top area of the main window which displays  #
# end enables selection between all curently opened documents                 #
###############################################################################

use strict;
use Wx qw(
	wxTOP wxLEFT wxRIGHT wxHORIZONTAL wxVERTICAL wxALIGN_CENTER_VERTICAL
	wxGROW wxLI_HORIZONTAL wxTAB_TRAVERSAL
	wxBU_AUTODRAW wxNO_BORDER wxWHITE
);
use Wx::Event qw(
	EVT_LEFT_UP EVT_LEFT_DOWN EVT_MIDDLE_UP EVT_BUTTON
	EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_NOTEBOOK_PAGE_CHANGED
);

sub _get      { $Kephra::app{window}{tabbar} }
sub _get_tabs { $Kephra::app{window}{tabbar}{tabs} }
sub _set_tabs { $Kephra::app{window}{tabbar}{tabs} = shift }
sub _get_sizer{ $Kephra::app{window}{tabbar}{sizer} }
sub _set_sizer{ $Kephra::app{window}{tabbar}{sizer} = shift }
sub _get_config{$Kephra::config{app}{tabbar} }
#sub new{ return Kephra::App::Window::_get()->{notebook} = Wx::Notebook->new($frame, -1, [0,0], [1,1],)}

sub create {
	my $win = Kephra::App::Window::_get();

	# create notebook if there is none
	unless ( ref _get_tabs() eq 'Wx::Notebook' ) {
		_set_tabs( Wx::Notebook->new($win, -1, [0,0], [-1,24]) );
		add_page();
	}
	my $tabbar = _get();
	my $tabbar_h_sizer = $tabbar->{h_sizer} = Wx::BoxSizer->new(wxHORIZONTAL);
	my $colour = $tabbar->{tabs}->GetBackgroundColour();
	$tabbar_h_sizer->Add( $tabbar->{tabs} , 1, wxLEFT | wxGROW , 0 );

	# create icons above panels
	my $cmd_new_data = Kephra::API::CommandList::get_cmd_properties('file-new');
	if (ref $cmd_new_data->{icon} eq 'Wx::Bitmap'){
		my $new_btn = $tabbar->{button}{new} = Wx::BitmapButton->new
			($win, -1, $cmd_new_data->{icon}, [-1,-1], [-1,-1], wxNO_BORDER );
		$new_btn->SetToolTip( $cmd_new_data->{label} );
		$new_btn->SetBackgroundColour( $colour );
		$tabbar_h_sizer->Prepend($new_btn, 0, wxLEFT|wxALIGN_CENTER_VERTICAL, 2);
		EVT_BUTTON($win, $new_btn, $cmd_new_data->{call} );
		EVT_ENTER_WINDOW( $new_btn, sub {
			Kephra::App::StatusBar::info_msg( $cmd_new_data->{help} )
		});
		EVT_LEAVE_WINDOW( $new_btn, \&Kephra::App::StatusBar::refresh_info_msg );
	}

	my $cmd_close_data = Kephra::API::CommandList::get_cmd_properties('file-close');
	if (ref $cmd_close_data->{icon} eq 'Wx::Bitmap'){
		my $close_btn = $tabbar->{button}{close} = Wx::BitmapButton->new
			($win, -1, $cmd_close_data->{icon}, [-1,-1], [-1,-1], wxNO_BORDER );
		$close_btn->SetToolTip( $cmd_close_data->{label} );
		$close_btn->SetBackgroundColour( $colour );
		$tabbar_h_sizer->Add($close_btn, 0, wxRIGHT|wxALIGN_CENTER_VERTICAL, 2);
		EVT_BUTTON($win, $close_btn, $cmd_close_data->{call} );
		EVT_ENTER_WINDOW($close_btn, sub {
			Kephra::App::StatusBar::info_msg( $cmd_close_data->{help} )
		});
		EVT_LEAVE_WINDOW( $close_btn, \&Kephra::App::StatusBar::refresh_info_msg );
	}

	#
	$tabbar->{seperator_line} = Wx::StaticLine->new
		($win, -1, [-1,-1],[-1,2], wxLI_HORIZONTAL);
	$tabbar->{seperator_line}->SetBackgroundColour(wxWHITE);

	# assemble tabbar seperator line
	my $tabbar_v_sizer = $tabbar->{v_sizer} = Wx::BoxSizer->new(wxVERTICAL);
	$tabbar_v_sizer->Add( $tabbar->{seperator_line}, 0, wxTOP | wxGROW , 0 );
	$tabbar_v_sizer->Add( $tabbar_h_sizer          , 1, wxTOP | wxGROW , 0 );

	EVT_LEFT_UP(   $tabbar->{tabs}, \&left_off_tabs);
	EVT_LEFT_DOWN( $tabbar->{tabs}, \&left_on_tabs);
	# Optional middle click over the tabs
	if ( _get_config()->{middle_click} ) {
		EVT_MIDDLE_UP(
			$tabbar->{tabs},
			Kephra::API::CommandList::get_cmd_property
				( _get_config()->{middle_click}, 'call' )
		);
	}
	EVT_NOTEBOOK_PAGE_CHANGED($win,$tabbar->{tabs}, \&change_tab);

	_set_sizer($tabbar_v_sizer);
	refresh_layout();
}

sub left_on_tabs {
	my ($tabs, $event) = @_;
	$Kephra::temp{document}{b4tabchange} = $tabs->GetSelection;
	$event->Skip;
}
sub left_off_tabs {
	my ($tabs, $event) = @_;
	Kephra::Document::Change::switch_back()
		if $Kephra::temp{document}{b4tabchange} == $tabs->GetSelection;
	$event->Skip;
}
sub change_tab {
	my ( $frame, $event ) = @_;
	Kephra::Document::Change::to_number( $event->GetSelection );
	$event->Skip;
}

#
sub add_page {
	my $tabs = _get_tabs();
	$tabs->AddPage( Wx::Panel->new( $tabs, -1, [ -1, -1 ], [ -1, 0 ] ), '', 0 );
}
sub delete_page { _get_tabs()->DeletePage(shift) }
sub set_current_page { 
	my $nr = shift;
	my $tabbar = _get_tabs();
	$tabbar->SetSelection($nr) unless $nr == $tabbar->GetSelection;
}

# refresh the label of given number
sub refresh_label {
	my $doc_nr = shift;
	$doc_nr = Kephra::Document::_get_current_nr() unless defined $doc_nr;
	return unless defined $Kephra::temp{document}{open}[$doc_nr];

	my $config   = _get_config();
	my $doc_info = $Kephra::temp{document}{open}[$doc_nr];
	my $label    = $doc_info->{ $config->{file_info} } ||
		"<$Kephra::localisation{app}{general}{untitled}>";

	# shorten too long filenames
	my $max_width = $config->{max_tab_width};
	if ( length($label) > $max_width and $max_width > 7 ) {
		$label = substr( $label, 0, $max_width - 3 ) . '...';
	}
	# set config files in square brackets
	if (    $config->{mark_configs} 
		and Kephra::Document::get_attribute('config_file', $doc_nr)
		and $Kephra::config{file}{save}{reload_config}              ) {
		$label = '$ ' . $label;
	}
	$label = ( $doc_nr + 1 ) . " $label" if $config->{number_tabs};
	$doc_info->{label} = $label;
	if ( $config->{info_symbol} ) {
		$label .= ' #' if $doc_info->{readonly};
		$label .= ' *' if $doc_info->{modified};
	}
	_get_tabs()->SetPageText( $doc_nr, $label );
}

sub refresh_current_label{ refresh_label(Kephra::Document::_get_current_nr()) }

sub refresh_all_label {
	if ( $Kephra::temp{document}{loaded} ) {
		refresh_label($_) for 0 .. Kephra::Document::_get_last_nr();
		set_current_page( Kephra::Document::_get_current_nr() );
	}
}

# set tabbar visibility
sub get_visibility { _get_config()->{visible} }
sub switch_visibility {
	_get_config()->{visible} ^= 1;
	show();
}
sub show {
	my $main_sizer = Kephra::App::Window::_get()->GetSizer;

	$main_sizer->Show( _get()->{v_sizer}, get_visibility() );
	refresh_layout();
	$main_sizer->Layout();
}

# visibility of parts
sub refresh_layout{
 my $tabbar     = _get();
 my $tab_config = _get_config();
 my $v          = $tab_config->{visible};
	if ($tabbar->{seperator_line}) {
		$tabbar->{seperator_line}->Show( $v && $tab_config->{seperator_line});
	}
	if ($tabbar->{button}{new}   ) {
		$tabbar->{button}{new}   ->Show( $v && $tab_config->{button}{new}   );
	}
	if ($tabbar->{button}{close} ) {
		$tabbar->{button}{close} ->Show( $v && $tab_config->{button}{close} );
	}
}

1;