package Kephra::App::EditPanel;
our $VERSION = '0.13';

use strict;
use warnings; 
#
# internal API to config und app pointer
#
my $ref;
sub _ref     { $ref }
sub _set_ref { $ref = $_[0] if is($_[0]) }
sub _all_ref { Kephra::Document::Data::get_all_ep() }
sub is       { 1 if ref $_[0] eq 'Wx::StyledTextCtrl'}
sub _config  { Kephra::API::settings()->{editpanel} }
sub _indicator_config { _config()->{indicator} }

sub new { 
	my $ep = Wx::StyledTextCtrl->new( Kephra::App::Window::_ref() );
	$ep->DragAcceptFiles(1) if Wx::wxMSW();
	return $ep;
}
sub gets_focus { Wx::Window::SetFocus( _ref() ) if is( _ref() ) }

# general settings
sub apply_settings_here {
	my $ep        = shift || _ref() || _create();
	return unless is($ep);
	my $conf      = _config();
	my $indicator = _indicator_config();
	my $color     = \&Kephra::Config::color;

	# text visuals: font whitespaces
	load_font($ep);
	apply_whitespace_settings_here($ep);
	$ep->SetWhitespaceForeground
		( 1, &$color( $indicator->{whitespace}{color} ) );

	# indicators: caret, selection, ...
	$ep->SetCaretLineBack( &$color( $indicator->{caret_line}{color} ) );
	$ep->SetCaretPeriod( $indicator->{caret}{period} );
	$ep->SetCaretWidth( $indicator->{caret}{width} );
	$ep->SetCaretForeground( &$color( $indicator->{caret}{color} ) );
	if ( $indicator->{selection}{fore_color} ne '-1' ) {
		$ep->SetSelForeground
			( 1, &$color( $indicator->{selection}{fore_color} ) );
	}
	$ep->SetSelBackground( 1, &$color( $indicator->{selection}{back_color}));
	apply_EOL_settings_here($ep);
	apply_LLI_settings_here($ep);
	apply_caret_line_settings_here($ep);
	apply_indention_guide_settings_here($ep);

	# Margins on left side
	Kephra::App::EditPanel::Margin::apply_settings_here($ep);

	#misc: scroll width, codepage, wordchars
	apply_autowrap_settings_here($ep);

	$ep->SetScrollWidth($conf->{scroll_width})
		unless $conf->{scroll_width} eq 'auto';
	#wxSTC_CP_UTF8 Wx::wxUNICODE()
	$ep->SetCodePage(65001);#
	set_word_chars_here($ep);
	apply_bracelight_settings_here();

	# internal
	$ep->SetLayoutCache(&Wx::wxSTC_CACHE_PAGE);
	$ep->SetBufferedDraw(1);
	$conf->{contextmenu}{visible} eq 'default'
		? $ep->UsePopUp(1) : $ep->UsePopUp(0);

	Kephra::Edit::eval_newline_sub();
	Kephra::Edit::Marker::define_marker($ep);
	connect_events($ep);
	Kephra::EventTable::add_call ( 'editpanel.focus', 'editpanel', sub { 
		Wx::Window::SetFocus( $ep ) unless $Kephra::temp{dialog}{active};
	} ) if $conf->{auto}{focus};
}

sub connect_events {
	my $ep = shift || _ref();
	my $trigger = \&Kephra::EventTable::trigger;
	my $config = _config();

	# override sci presets
	Wx::Event::EVT_DROP_FILES       ($ep, \&Kephra::File::add_dropped);
	Wx::Event::EVT_ENTER_WINDOW     ($ep,  sub {&$trigger('editpanel.focus')} );
	Wx::Event::EVT_LEFT_DOWN        ($ep,  sub {
		my ($ep, $event) = @_;
		my $nr = Kephra::App::EditPanel::Margin::in_nr( $event->GetX, $ep );
		if ($nr == -1) {
			Kephra::Edit::copy() if clicked_on_selection($event);
		}
		$event->Skip;
	});
	Wx::Event::EVT_MIDDLE_DOWN      ($ep,  sub {
		my ($ep, $event) = @_;
		my $nr = Kephra::App::EditPanel::Margin::in_nr( $event->GetX, $ep );
		if ($nr == -1) {
			if ($event->LeftIsDown){
				Kephra::Edit::paste();
				set_caret_on_cursor($event);
			} else {
				my $txt = $ep->GetSelectedText();
				if ($txt){
					my $pos = $ep->PositionFromPointClose($event->GetX, $event->GetY);
					$pos = $ep->GetLineEndPosition(
						$ep->LineFromPosition(
							$ep->PositionFromPointClose(
								Kephra::App::EditPanel::Margin::width() + 2,
								$event->GetY
					))) if $pos == -1;
					$ep->InsertText($pos, $txt) if $pos > -1;
				} else {
					
				}
			}
		} else {
			Kephra::App::EditPanel::Margin::on_middle_click($ep, $event, $nr)
		}
	});
	Wx::Event::EVT_RIGHT_DOWN       ($ep,  sub {
		my ($ep, $event) = @_;
		my $nr = Kephra::App::EditPanel::Margin::in_nr( $event->GetX, $ep );
		if ($nr == -1) {
			if ($event->LeftIsDown){
				Kephra::Edit::cut();
				set_caret_on_cursor($event);
			} else {
				my $mconf = $config->{contextmenu};
				if ($mconf->{visible} eq 'custom'){
					my $menu_id = Kephra::Document::Data::attr('text_selected')
						? $mconf->{ID_selection} : $mconf->{ID_normal};
					my $menu = Kephra::App::ContextMenu::get($menu_id);
					$ep->PopupMenu($menu, $event->GetX, $event->GetY) if $menu;
				}
			} 
		} else {Kephra::App::EditPanel::Margin::on_right_click($ep, $event, $nr)}
	});
	#Wx::EVT_SET_FOCUS              ($ep,  sub {});
	Wx::Event::EVT_STC_SAVEPOINTREACHED($ep, -1, \&Kephra::File::savepoint_reached);
	Wx::Event::EVT_STC_SAVEPOINTLEFT($ep, -1, \&Kephra::File::savepoint_left);
	Wx::Event::EVT_STC_MARGINCLICK  ($ep, -1, \&Kephra::App::EditPanel::Margin::on_left_click);
	Wx::Event::EVT_STC_CHANGE       ($ep, -1, sub {
		Kephra::Document::Data::attr('edit_pos', $_[0]->GetCurrentPos());
		&$trigger('document.text.change');
	});

	Wx::Event::EVT_STC_UPDATEUI     ($ep, -1, sub {
		my ( $ep, $event) = @_;
		my ( $sel_beg, $sel_end ) = $ep->GetSelection;
		my $is_sel = $sel_beg != $sel_end;
		my $was_sel = Kephra::Document::Data::attr('text_selected');
		Kephra::Document::Data::attr('text_selected', $is_sel);
		&$trigger('document.text.select') if $is_sel xor $was_sel;
		&$trigger('caret.move');
	});

	Wx::Event::EVT_KEY_DOWN         ($ep,     sub {
		my ($ep, $event) = @_;
		#$ep = _ref(); 
		my $key = $event->GetKeyCode +
			1000 * ($event->ShiftDown + $event->ControlDown*2 + $event->AltDown*4);
		# reacting on shortkeys that are defined in the Commanlist

		return if Kephra::CommandList::run_cmd_by_keycode($key);
		# reacting on Enter
		if ($key ==  &Wx::WXK_RETURN) {
			if ($config->{auto}{brace}{indention}) {
				my $pos  = $ep->GetCurrentPos - 1;
				my $char = $ep->GetCharAt($pos);
				if      ($char == 123) {
					return Kephra::Edit::Format::blockindent_open($pos);
				} elsif ($char == 125) {
					return Kephra::Edit::Format::blockindent_close($pos);
				}
			}
			$config->{auto}{indention}
				? Kephra::Edit::Format::autoindent()
				: $ep->CmdKeyExecute(&Wx::wxSTC_CMD_NEWLINE) ;
		}
		# scintilla handles the rest of the shortkeys
		else { $event->Skip }
		#SCI_SETSELECTIONMODE
		#($key == 350){use Kephra::Ext::Perl::Syntax; Kephra::Ext::Perl::Syntax::check()};
	});
}
sub set_caret_on_cursor {
	my $event = shift;
	my $ep = shift || _ref();
	return unless ref $event eq 'Wx::MouseEvent' and is($ep);
	my $pos = $ep->PositionFromPointClose($event->GetX, $event->GetY);
	$pos = $ep->GetCurrentPos() if $pos == -1;
	$ep->SetSelection( $pos, $pos );
}
sub clicked_on_selection {
	my $event = shift;
	my $ep = shift || _ref();
	return unless ref $event eq 'Wx::MouseEvent' and is($ep);
	my ($start, $end) = $ep->GetSelection();
	my $pos = $ep->GetCurrentPos;
	return 1 if $start != $end and $pos >= $start and $pos <= $end;
}

sub disconnect_events {
	my $ep = shift || _ref();
	Wx::Event::EVT_STC_CHANGE  ($ep, -1, sub {});
	Wx::Event::EVT_STC_UPDATEUI($ep, -1, sub {});
}

sub set_contextmenu_custom  { set_contextmenu('custom') }
sub set_contextmenu_default { set_contextmenu('default')}
sub set_contextmenu_none    { set_contextmenu('none')   }
sub set_contextmenu {
	my $mode = shift;
	$mode = 'custom' unless $mode;
	my $ep = _ref();
	$mode eq 'default' ? $ep->UsePopUp(1) : $ep->UsePopUp(0);
	_config()->{contextmenu}{visible} = $mode;
}
sub get_contextmenu { _config()->{contextmenu}{visible} }
#
sub set_word_chars { set_word_chars_here($_) for @{_all_ref()} }
sub set_word_chars_here { 
	my $ep = shift || _ref();
	my $conf = _config();
	if ( $conf->{word_chars} ) {
		$ep->SetWordChars( $conf->{word_chars} );
	} else {
		$ep->SetWordChars( '$%&-@_abcdefghijklmnopqrstuvwxyz����ABCDEFGHIJKLMNOPQRSTUVWXYZ���0123456789' );
	}
}


# line wrap
sub apply_autowrap_settings { apply_autowrap_settings_here($_) for @{_all_ref()} }
sub apply_autowrap_settings_here {
	my $ep = shift || _ref();
	$ep->SetWrapMode( _config()->{line_wrap} );
	Kephra::EventTable::trigger('editpanel.autowrap');
}

sub get_autowrap_mode { _config()->{line_wrap} == &Wx::wxSTC_WRAP_WORD}
sub switch_autowrap_mode {
	_config()->{line_wrap} = get_autowrap_mode()
		? &Wx::wxSTC_WRAP_NONE
		: &Wx::wxSTC_WRAP_WORD;
	apply_autowrap_settings();
}

# bracelight
sub bracelight_visible { _indicator_config()->{bracelight}{visible} }
sub switch_bracelight {
	bracelight_visible() ? set_bracelight_off() : set_bracelight_on();
}
sub set_bracelight_on {
	_indicator_config()->{bracelight}{visible} = 1;
	apply_bracelight_settings()
}
sub set_bracelight_off {
	_indicator_config()->{bracelight}{visible} = 0;
	apply_bracelight_settings()
}#{bracelight}{mode} = 'adjacent'|'surround';

sub apply_bracelight_settings { 
	apply_bracelight_settings_here($_) for @{_all_ref()}
}
sub apply_bracelight_settings_here {
	my $ep = shift || _ref();
	if (bracelight_visible()){
		Kephra::EventTable::add_call
			('caret.move', 'bracelight', \&paint_bracelight);
		paint_bracelight($ep);
	} else {
		Kephra::EventTable::del_call('caret.move', 'bracelight');
		$ep->BraceHighlight( -1, -1 );
	}
}

sub paint_bracelight {
	my $ep       = shift || _ref();
	my $pos      = $ep->GetCurrentPos;
	my $tab_size = Kephra::Document::Data::get_attribute('tab_size');
	my $matchpos = $ep->BraceMatch(--$pos);
	$matchpos = $ep->BraceMatch(++$pos) if $matchpos == -1;

	$ep->SetHighlightGuide(0);
	if ( $matchpos > -1 ) {
		# highlight braces
		$ep->BraceHighlight($matchpos, $pos);
		# asign pos to opening brace
		$pos = $matchpos if $matchpos < $pos;
		my $indent = $ep->GetLineIndentation( $ep->LineFromPosition($pos) );
		# highlighting indenting guide
		$ep->SetHighlightGuide($indent)
			if $indent and $tab_size and $indent % $tab_size == 0;
	} else {
		# disbale all highlight
		$ep->BraceHighlight( -1, -1 );
		$ep->BraceBadLight($pos-1)
			if $ep->GetTextRange($pos-1,$pos) =~ /{|}|\(|\)|\[|\]/;
		$ep->BraceBadLight($pos)
			if $pos < $ep->GetTextLength
			and $ep->GetTextRange( $pos, $pos + 1 ) =~ tr/{}()\[\]//;
	}
}

# indention guide
sub indention_guide_visible { 
	_indicator_config()->{indent_guide}{visible} 
}
sub apply_indention_guide_settings {
	apply_indention_guide_settings_here($_) for @{_all_ref()}
}
sub apply_indention_guide_settings_here {
	my $ep = shift || _ref();
	$ep->SetIndentationGuides( indention_guide_visible() )
}
sub switch_indention_guide_visibility {
	_indicator_config()->{indent_guide}{visible} ^= 1;
	apply_indention_guide_settings();
}

# caret line
sub caret_line_visible {
	_indicator_config()->{caret_line}{visible} 
}
sub apply_caret_line_settings_here {
	my $ep = shift || _ref();
	$ep->SetCaretLineVisible( caret_line_visible() );
}
sub apply_caret_line_settings {
	apply_caret_line_settings_here($_) for @{_all_ref()}
}
sub switch_caret_line_visibility {
	_indicator_config()->{caret_line}{visible} ^= 1;
	apply_caret_line_settings();
}

# LLI = long line indicator = right margin
sub LLI_visible { 
	_indicator_config()->{right_margin}{style} == &Wx::wxSTC_EDGE_LINE
}
sub apply_LLI_settings_here {
	my $ep = shift || _ref();
	my $config = _indicator_config()->{right_margin};
	my $color   = \&Kephra::Config::color;
	$ep->SetEdgeColour( &$color( $config->{color} ) );
	$ep->SetEdgeColumn( $config->{position} );
	show_LLI( $config->{style}, $ep);
}
sub show_LLI {
	my $style = shift;
	my $ep = shift || _ref();
	$ep->SetEdgeMode( $style );
}
sub apply_LLI_settings { apply_LLI_settings_here($_) for @{_all_ref()} }
sub switch_LLI_visibility {
	my $style = _indicator_config()->{right_margin}{style} = LLI_visible()
		? &Wx::wxSTC_EDGE_NONE
		: &Wx::wxSTC_EDGE_LINE;
	apply_LLI_settings($style);
}

# EOL = end of line marker
sub EOL_visible { 
	_indicator_config()->{end_of_line_marker}
}
sub switch_EOL_visibility {
	_config()->{indicator}{end_of_line_marker} ^= 1;
	apply_EOL_settings();
}
sub apply_EOL_settings { apply_EOL_settings_here($_) for @{_all_ref()} }
sub apply_EOL_settings_here {
	my $ep = shift || _ref();
	$ep->SetViewEOL( EOL_visible() );

}

# whitespace
sub whitespace_visible { 
	_indicator_config()->{whitespace}{visible} 
}
sub apply_whitespace_settings_here {
	my $ep = shift || _ref();
	$ep->SetViewWhiteSpace( whitespace_visible() )
}
sub apply_whitespace_settings { 
	apply_whitespace_settings_here($_) for @{_all_ref()}
}
sub switch_whitespace_visibility {
	my $v = _indicator_config()->{whitespace}{visible} ^= 1;
	apply_whitespace_settings();
	return $v;
}

# font settings
sub load_font {
	my $ep = shift || _ref();
	my ( $fontweight, $fontstyle ) = ( &Wx::wxNORMAL, &Wx::wxNORMAL );
	my $font = _config()->{font};
	$fontweight = &Wx::wxLIGHT  if $font->{weight} eq 'light';
	$fontweight = &Wx::wxBOLD   if $font->{weight} eq 'bold';
	$fontstyle  = &Wx::wxSLANT  if $font->{style}  eq 'slant';
	$fontstyle  = &Wx::wxITALIC if $font->{style}  eq 'italic';
	my $wx_font = Wx::Font->new( $font->{size}, &Wx::wxDEFAULT, 
		$fontstyle, $fontweight, 0, $font->{family} );
	$ep->StyleSetFont( &Wx::wxSTC_STYLE_DEFAULT, $wx_font ) if $wx_font->Ok > 0;
}
sub change_font {
	my ( $fontweight, $fontstyle ) = ( &Wx::wxNORMAL, &Wx::wxNORMAL );
	my $font_config = _config()->{font};
	$fontweight = &Wx::wxLIGHT  if ( $$font_config{weight} eq 'light' );
	$fontweight = &Wx::wxBOLD   if ( $$font_config{weight} eq 'bold' );
	$fontstyle  = &Wx::wxSLANT  if ( $$font_config{style}  eq 'slant' );
	$fontstyle  = &Wx::wxITALIC if ( $$font_config{style}  eq 'italic' );
	my $oldfont = Wx::Font->new( $$font_config{size}, &Wx::wxDEFAULT, $fontstyle,
		$fontweight, 0, $$font_config{family} );
	my $newfont = Kephra::Dialog::get_font( $oldfont );

	if ( $newfont->Ok > 0 ) {
		($fontweight, $fontstyle) = ($newfont->GetWeight, $newfont->GetStyle);
		$$font_config{size}   = $newfont->GetPointSize;
		$$font_config{family} = $newfont->GetFaceName;
		$$font_config{weight} = 'normal';
		$$font_config{weight} = 'light' if $fontweight == &Wx::wxLIGHT;
		$$font_config{weight} = 'bold' if $fontweight == &Wx::wxBOLD;
		$$font_config{style}  = 'normal';
		$$font_config{style}  = 'slant' if $fontstyle == &Wx::wxSLANT;
		$$font_config{style}  = 'italic' if $fontstyle == &Wx::wxITALIC;
		Kephra::Document::SyntaxMode::reload($_) for @{Kephra::Document::Data::all_nr()};
		Kephra::App::EditPanel::Margin::apply_line_number_width();
	}
}

1;

#EVT_STC_CHARADDED EVT_STC_MODIFIED
#wxSTC_CP_UTF8 wxSTC_CP_UTF16 Wx::wxUNICODE()
#wxSTC_WS_INVISIBLE wxSTC_WS_VISIBLEALWAYS
#$ep->StyleSetForeground (wxSTC_STYLE_CONTROLCHAR, Wx::Colour->new(0x55, 0x55, 0x55));
#$ep->CallTipShow(3,"testtooltip\n next line"); #tips
#SetSelectionMode(wxSTC_SEL_RECTANGLE);

=head1 NAME

Kephra::App::EditPanel - visual and event settings of the editing canvas

=head1 DESCRIPTION

=cut