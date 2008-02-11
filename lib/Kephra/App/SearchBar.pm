package Kephra::App::SearchBar;
$VERSION = '0.11';

use strict;
use Wx qw( 
	wxTOP wxBOTTOM wxGROW 
	wxSTC_CMD_LINESCROLLUP wxSTC_CMD_LINESCROLLDOWN 
	wxSTC_CMD_CHARLEFT wxSTC_CMD_CHARRIGHT
	wxSTC_CMD_PAGEUP wxSTC_CMD_PAGEDOWN
	wxSTC_CMD_DOCUMENTSTART wxSTC_CMD_DOCUMENTEND
	WXK_ESCAPE WXK_RETURN WXK_F3
	WXK_UP WXK_DOWN  WXK_LEFT WXK_RIGHT WXK_HOME WXK_END
);
use Wx::Event qw( 
	EVT_TEXT EVT_KEY_DOWN EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_COMBOBOX
);


sub _get{ Kephra::App::ToolBar::_get('search' ) }
sub _set{ Kephra::App::ToolBar::_set('search', $_[0] ) }
sub _get_config { $Kephra::config{app}{toolbar}{search} }


sub create {
	# load searchbar definition
	my $config = _get_config();
	my $file_name = Kephra::Config::filepath( $config->{file} );
	my $bar_def = Kephra::Config::File::load($file_name);
	$bar_def = Kephra::Config::Tree::get_subtree( $bar_def, $config->{node});
	# create searchbar with buttons
	my $rest_widgets = Kephra::App::ToolBar::create_new( 'search', $bar_def);
	my $bar = _get();
	# apply special searchbar widgets
	for my $item_data (@$rest_widgets){
		if ($item_data->{type} eq 'combobox' and $item_data->{id} eq 'find'){
			my $find_input = $bar->{find_input} = Wx::ComboBox->new
				($bar , -1, '', [-1,-1],[$item_data->{size},-1],[],,1);
			$find_input->SetDropTarget( SearchInputTarget->new($find_input, 'find'));
			$find_input->SetValue( Kephra::Edit::Search::get_find_item() );
			$find_input->SetSize($item_data->{size},-1) if $item_data->{size};
			if ( $Kephra::config{search}{history}{use} ){
				$find_input->Append($_)
					for @{$Kephra::config{search}{history}{find_item}}
			}
			$bar->InsertControl( $item_data->{pos}, $find_input );

			EVT_TEXT( $bar, $find_input, sub {
				my ($bar, $event) = @_;
				my $old = Kephra::Edit::Search::get_find_item();
				my $new = $find_input->GetValue;
				if ($new ne $old){
					Kephra::Edit::Search::set_find_item( $new );
					colour_find_input( Kephra::Edit::Search::first_increment() )
						if $Kephra::config{search}{attribute}{incremental}
						and Wx::Window::FindFocus() eq $find_input;
				}
			} );
			EVT_KEY_DOWN( $find_input, sub {
				my ( $fi, $event ) = @_;
				my $found_something;
				my $key = $event->GetKeyCode;
				my $ep = Kephra::App::EditPanel::_get();

				if      ( $key == WXK_RETURN ) {
					if    ( $event->ControlDown and $event->ShiftDown)   
												 {Kephra::Edit::Search::find_last() }
					elsif ( $event->ControlDown ){Kephra::Edit::Search::find_first()}
					elsif ( $event->ShiftDown )  {Kephra::Edit::Search::find_prev() }
					else                         {Kephra::Edit::Search::find_next() }
					refresh_find_input($Kephra::temp{search}{history}{refresh})
						if $Kephra::config{search}{history}{use};
				} elsif ( $key == WXK_F3 ){
					$event->ShiftDown 
						? Kephra::Edit::Search::find_prev()
						: Kephra::Edit::Search::find_next();
				} elsif ( $key == WXK_ESCAPE ) { # escape
					give_editpanel_focus_back()
				} elsif ( $key == 70 ) { # F
					give_editpanel_focus_back() if $event->ControlDown;
				} elsif ( $key == 81 ) { # Q
					switch_visibility() if $event->ControlDown;
				} elsif ( $key == WXK_LEFT ){
					if ($event->ControlDown) {
						$ep->CmdKeyExecute( wxSTC_CMD_CHARLEFT ); return;
					}
				} elsif ( $key == WXK_RIGHT ){
					if ($event->ControlDown) {
						$ep->CmdKeyExecute( wxSTC_CMD_CHARRIGHT ); return;
					}
				} elsif ( $key == WXK_UP ){
					if ($event->ControlDown) {
						$ep->CmdKeyExecute( wxSTC_CMD_LINESCROLLUP ); return;
					}
				} elsif ( $key == WXK_DOWN ){
					if ($event->ControlDown) {
						$ep->CmdKeyExecute( wxSTC_CMD_LINESCROLLDOWN ); return;
					}
				} elsif ( $key == 312 ){ # page up
					if ($event->ControlDown){
						my $pos = $bar->{find_input}->GetInsertionPoint;
						Kephra::Document::Change::tab_left();
						Wx::Window::SetFocus($bar->{find_input});
						$bar->{find_input}->SetInsertionPoint($pos);
					} else {
						$ep->CmdKeyExecute( wxSTC_CMD_PAGEUP );
					}
					return;
				} elsif ( $key == 313 ){ # page down
					if ($event->ControlDown){
						my $pos = $bar->{find_input}->GetInsertionPoint;
						Kephra::Document::Change::tab_right();
						Wx::Window::SetFocus($bar->{find_input});
						$bar->{find_input}->SetInsertionPoint($pos);
					} else {
						$ep->CmdKeyExecute( wxSTC_CMD_PAGEDOWN );
					}
					return;
				} elsif ( $key == WXK_HOME ){
					if ($event->ControlDown) {
						$ep->CmdKeyExecute( wxSTC_CMD_DOCUMENTSTART ); return;
					}
				} elsif ( $key == WXK_END ){
					if ($event->ControlDown) {
						$ep->CmdKeyExecute( wxSTC_CMD_DOCUMENTEND ); return;
					}
				} else  { 
					#print "$key\n";
				}
				$event->Skip;
			} );
			#EVT_COMBOBOX( $find_input, -1, sub{ } );
			EVT_ENTER_WINDOW( $find_input, sub{
				Wx::Window::SetFocus($find_input) if _get_config()->{autofocus};
				disconnect_find_input();
			});
			EVT_LEAVE_WINDOW( $find_input, sub{ connect_find_input($find_input) });
			connect_find_input($find_input);
		}
	}
	$bar->Realize;
	EVT_LEAVE_WINDOW($bar, \&leave_focus);
	show();
}

sub destroy{ Kephra::App::ToolBar::destroy ('search') }

sub connect_find_input{
	my $find_input = shift;
	Kephra::API::EventTable::add_call( 'find.item.changed', 'search_bar', sub {
			my $value = Kephra::Edit::Search::get_find_item();
			return if $value eq $find_input->GetValue;
			$find_input->SetValue( $value );
			my $pos = $find_input->GetLastPosition;
			$find_input->SetSelection($pos,$pos);
			colour_find_input( 1 );
	});
}
sub disconnect_find_input{
	Kephra::API::EventTable::del_call('find.item.changed','search_bar');
}

sub refresh_find_input {
	my $find_input     = _get()->{find_input};
	my $new_find_item  = shift;
	my $value  = $find_input->GetValue;
	if ($new_find_item and $find_input->GetString(0) ne $value){
			my $pos = $find_input->GetInsertionPoint;
			$find_input->Clear();
			$find_input->Append($_) for @{ $Kephra::config{search}{history}{find_item} };
			$find_input->SetValue(Kephra::Edit::Search::get_find_item());
			$find_input->SetInsertionPoint($pos);
	}
	colour_find_input( $new_find_item );
	Wx::Window::SetFocus( $find_input );
}

sub colour_find_input{
	my $find_input      = _get()->{find_input};
	my $found_something = shift;
	if ($found_something){
		$find_input->SetForegroundColour( Wx::Colour->new( 0x00, 0x00, 0x33 ) );
		$find_input->SetBackgroundColour( Wx::Colour->new( 0xff, 0xff, 0xff ) );
	} else {
		$find_input->SetForegroundColour( Wx::Colour->new( 0xff, 0x33, 0x33 ) );
		$find_input->SetBackgroundColour( Wx::Colour->new( 0xff, 0xff, 0xff ) );
	}
	$find_input->Refresh;
}

sub enter_focus{
	my $bar = _get();
	switch_visibility() unless get_visibility();
	Wx::Window::SetFocus($bar->{find_input}) if defined $bar->{find_input};
}
sub leave_focus{ switch_visibility() if _get_config()->{autohide} }

sub give_editpanel_focus_back{
	leave_focus();
	Wx::Window::SetFocus( Kephra::App::EditPanel::_get() );
}


# set visibility
sub show {
	_get()->Show( get_visibility() );
	my $sizer = Kephra::App::Window::_get()->GetSizer;
	$sizer->Layout() if $sizer;
}

sub get_visibility    { _get_config()->{visible} }
sub switch_visibility { _get_config()->{visible} ^= 1;
	show();
}


sub position {
	my $bar   = _get();
	my $sizer = Kephra::App::Window::_get()->GetSizer;
	#$sizer->Detach($bar);
	if (_get_config()->{position} eq 'below') {
		$sizer->Add($bar, 0, wxBOTTOM|wxGROW);
	} else {
		$sizer->Add($bar, 0, wxTOP|wxGROW);
	}
	$sizer->Layout;
}

1;