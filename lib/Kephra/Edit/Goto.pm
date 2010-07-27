package Kephra::Edit::Goto;
our $VERSION = '0.10';

use strict;
use warnings;
#
# internal calls
#
sub _ep_ref       { Kephra::App::EditPanel::_ref() }
sub _center_caret { Kephra::Edit::_center_caret() }
sub _pos {
	my $ep  = _ep_ref();
	my $pos = shift;
	$pos += $ep->GetLength if $pos < 0;
	$ep->GotoPos($pos);
	$ep->EnsureCaretVisible();
}
#
# simple jump calls
#
sub pos { position(@_) }
sub position {
	my $pos = shift;
	return unless $pos;
	my $ep  = _ep_ref();
	my $max = $ep->GetLength;
	my $fvl = $ep->GetFirstVisibleLine;
	my $visible = $ep->GetLineVisible( $ep->LineFromPosition($pos) );

	$pos += $max if $pos < 0;
	$pos = 0 if $pos < 0;
	$pos = $max if $pos > $max;
	$ep->SetCurrentPos($pos);
	$ep->SetSelection ($pos, $pos);
	$ep->SearchAnchor;
	#$visible ? $ep->ScrollToLine($fvl) : _center_caret();
	$ep->EnsureCaretVisible;
	$ep->EnsureVisible($ep->LineFromPosition($pos));
	_center_caret();
}
sub next_visible_pos {
	my $ep  = _ep_ref();
	my $line = $ep->GetCurrentLine();
	return if $ep->GetLineVisible($line);
	$line = $ep->GetFoldParent($line) until $ep->GetLineVisible($line);
	$ep->GotoLine($line);
	_center_caret();
}

sub line    {
	my $ep = _ep_ref();
	my $l18n = Kephra::API::localisation()->{dialog}{edit};
	my $line = Kephra::Dialog::get_number( 
		$l18n->{goto_line_input},
		$l18n->{goto_line_headline},
		$ep->GetCurrentLine + 1
	);
	line_nr( $line - 1) unless $line == &Wx::wxCANCEL;
}
sub line_nr { position( _ep_ref()->PositionFromLine( shift ) ) }

sub last_edit {
	my $pos = Kephra::Document::Data::attr('edit_pos');
	position( $pos ) if defined $pos;
}

#
# block navigation
#
sub prev_block{ _ep_ref()->CmdKeyExecute(&Wx::wxSTC_CMD_PARAUP)   }
sub next_block{ _ep_ref()->CmdKeyExecute(&Wx::wxSTC_CMD_PARADOWN) }
#
# brace navigation
#
sub prev_brace{
	my $ep  = _ep_ref();
	my $pos = $ep->GetCurrentPos;
	$ep->GotoPos($pos - 1) if $ep->BraceMatch($pos) > -1;
	$ep->GotoPos($pos - 2) if $ep->BraceMatch($pos - 1) > -1;
	$ep->SearchAnchor();
	my $newpos = $ep->SearchPrev(&Wx::wxSTC_FIND_REGEXP, '[{}()\[\]]');
	$newpos++ if $ep->BraceMatch($newpos) > $newpos;
	$newpos > -1 ? $ep->GotoPos($newpos) : $ep->GotoPos($pos);
}

sub next_brace{
	my $ep  = _ep_ref();
	my $pos = $ep->GetCurrentPos;
	$ep->GotoPos($pos + 1);
	$ep->SearchAnchor();
	my $newpos = $ep->SearchNext(&Wx::wxSTC_FIND_REGEXP, '[{}()\[\]]');
	$newpos++ if $ep->BraceMatch($newpos) > $newpos;
	$newpos > -1 ? $ep->GotoPos($newpos) : $ep->GotoPos($pos);
}

sub prev_related_brace{
	my $ep  = _ep_ref();
	my $pos = $ep->GetCurrentPos;
	my $matchpos = $ep->BraceMatch(--$pos);
	$matchpos = $ep->BraceMatch(++$pos) if $matchpos == -1;
	if ($matchpos == -1) { prev_brace() }
	else {
		if ($matchpos < $pos) { $ep->GotoPos($matchpos+1) }
		else{
			my $open_char = chr $ep->GetCharAt($pos);
			my $close_char = chr $ep->GetCharAt($matchpos);
			$ep->GotoPos($pos);
			$ep->SearchAnchor();
			my $next_open = $ep->SearchPrev(0, $open_char);
			$ep->GotoPos($pos);
			$ep->SearchAnchor();
			my $next_close = $ep->SearchPrev(0, $close_char);
			if ($next_open < $next_close) { $ep->GotoPos( $next_open + 1 ) }
			else						  { $ep->GotoPos( $next_close	) }
		}
	}
}

sub next_related_brace{
	my $ep  = _ep_ref();
	my $pos = $ep->GetCurrentPos;
	my $matchpos = $ep->BraceMatch($pos);
	$matchpos = $ep->BraceMatch(--$pos) if $matchpos == -1;
	if ($matchpos == -1) { next_brace() }
	else {
		if ($matchpos > $pos) { $ep->GotoPos($matchpos) }
		else{
			my $open_char = chr $ep->GetCharAt($matchpos);
			my $close_char = chr $ep->GetCharAt($pos);
			$ep->GotoPos($pos + 1);
			$ep->SearchAnchor();
			my $next_open = $ep->SearchNext(0, $open_char);
			$ep->GotoPos($pos + 1);
			$ep->SearchAnchor();
			my $next_close = $ep->SearchNext(0, $close_char);
			if ($next_open < $next_close) { $ep->GotoPos( $next_open + 1 ) }
			else						  { $ep->GotoPos( $next_close	) }
		}
	}
}

1;

=head1 NAME

Kephra::App::Goto - caret jump functions

=head1 DESCRIPTION

=cut