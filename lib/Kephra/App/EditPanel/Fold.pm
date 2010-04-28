package Kephra::App::EditPanel::Fold;
our $VERSION = '0.03';

use strict;
use warnings;
#
sub _ep_ref {
	Kephra::App::EditPanel::is($_[0]) ? $_[0] : Kephra::App::EditPanel::_ref()   
}
sub _config { Kephra::App::EditPanel::Margin::_config()->{fold} }
sub _attribute { 'folded_lines' }
#
sub _is_head { # is this the fold level of a head node ?
	my $level = shift;
	return 1 if ($level % 1024) < (($level >> 16) % 1024);
}
sub _get_line { # 
	my ($ep, $event ) = @_;
	$ep = _ep_ref();
	my $line;
	if (defined $event) {
		my $x = Kephra::App::EditPanel::Margin::width($ep)+5;
		my ($y, $max_y) = ($event->GetY, $ep->GetSize->GetHeight);
		my $pos = $ep->PositionFromPointClose($x, $y);
		while ($pos < 0 and $y+10 < $max_y) {
			$pos = $ep->PositionFromPointClose($x, $y += 10);
		}
		$line = $ep->LineFromPosition($pos);
	} else { $line = $ep->GetCurrentLine() }
	return $line;
}
#
sub store {
	for my $doc_nr (@{Kephra::Document::Data::all_nr()}) {
		my $ep = Kephra::Document::Data::_ep($doc_nr);
		my @lines;
		for (0 .. $ep->GetLineCount()-1) {
			push @lines, $_ unless $ep->GetFoldExpanded( $_ );
		}
		Kephra::Document::Data::set_attribute( _attribute(), \@lines, $doc_nr);
	}
}

sub restore {
	my $doc_nr = Kephra::Document::Data::valid_or_current_doc_nr(shift);
	my $ep     = Kephra::Document::Data::_ep($doc_nr);
	return if $doc_nr < 0 or not ref $ep;
	my $lines = Kephra::Document::Data::get_attribute( _attribute(), $doc_nr);
	return unless ref $lines eq 'ARRAY';
	$ep->ToggleFold($_) for @$lines;
}
#
# folding functions
#
sub toggle_here {
	# params you get if triggered by mouse click
	my ($ep, $event ) = @_;
	$ep = _ep_ref();
	my $line = defined $event
		? $ep->LineFromPosition( $event->GetPosition() )
		: $ep->GetCurrentLine();
	$ep->ToggleFold($line);
	Kephra::Edit::Goto::next_visible_pos() if _config()->{keep_caret_visible}
	                                       and not $ep->GetFoldExpanded($line);
}
sub toggle_recursively {
	my $ep = _ep_ref();
	my $line = _get_line(@_);
	my $level = $ep->GetFoldLevel($line);
	unless ( _is_head( $ep->GetFoldLevel($line) ) ) {
		$line = $ep->GetFoldParent($line);
		return if $line == -1;
	}
	my $xp = not $ep->GetFoldExpanded($line);
	my $cursor = $ep->GetLastChild($line, -1);
	while ($cursor >= $line) {
		$ep->ToggleFold($cursor) if $ep->GetFoldExpanded($cursor) xor $xp;
		$cursor--;
	}
	Kephra::Edit::Goto::next_visible_pos() if _config()->{keep_caret_visible};
}
sub toggle_siblings         { toggle_siblings_of_line( _get_line(@_) ) }
sub toggle_siblings_of_line {
	my $ep = _ep_ref();
	my $line = shift;
	return if $line < 0 or $line > ($ep->GetLineCount()-1);
	my $level = $ep->GetFoldLevel($line);
	my $parent = $ep->GetFoldParent($line);
	my $xp = not $ep->GetFoldExpanded($line);
	my $first_line = $parent;
	my $cursor = $ep->GetLastChild($parent, -1 );
	($first_line, $cursor) = (-1, $ep->GetLineCount()-2) if $parent == -1;
	while ($cursor > $first_line){
		$ep->ToggleFold($cursor) if $ep->GetFoldLevel($cursor) == $level
		                         and ($ep->GetFoldExpanded($cursor) xor $xp);
		$cursor--;
	}
	Kephra::Edit::Goto::next_visible_pos() if _config()->{keep_caret_visible}
	                                       and not $xp;
	$ep->EnsureCaretVisible;
}

sub toggle_level {
	my $ep = _ep_ref();
	my $line = _get_line(@_);
	return if $line < 0 or $line > ($ep->GetLineCount()-1);
	my $level = $ep->GetFoldLevel($line);
	my $xp = not $ep->GetFoldExpanded($line);
	for (0 .. $ep->GetLineCount()-1) {
		$ep->ToggleFold($_) if $ep->GetFoldLevel($_) == $level
		                    and ($ep->GetFoldExpanded($_) xor $xp);
	}
	Kephra::Edit::Goto::next_visible_pos() if _config()->{keep_caret_visible}
	                                       and not $xp;
	$ep->EnsureCaretVisible;
}

sub toggle_all {
	my $ep = _ep_ref();
	my $line = $ep->GetLineCount() - 1;
	# looking for the head of heads // capi di capi
	$line = $ep->GetFoldParent($line) while $ep->GetFoldParent($line) > -1;
	my $xp = $ep->GetFoldExpanded($line);
	$xp ? fold_all() : unfold_all();
	Kephra::Edit::Goto::next_visible_pos() if _config()->{keep_caret_visible}
	                                       and $xp;
}
sub fold_all {
	my $ep  = _ep_ref();
	my $cursor = $ep->GetLineCount()-1;
	while ($cursor > -1) {
		$ep->ToggleFold($cursor) if $ep->GetFoldExpanded($cursor);
		$cursor--;
	}
}
sub unfold_all {
	my $ep  = _ep_ref();
	my $cursor = $ep->GetLineCount()-1;
	while ($cursor > -1) {
		$ep->ToggleFold($cursor) unless $ep->GetFoldExpanded($cursor);
		$cursor--;
	}
}
sub show_folded_children {
	#my $ep = _ep_ref();
	#my $parent = _get_line(@_);
	#unless ( _is_head( $ep->GetFoldLevel($parent) ) ) {
		#$parent = $ep->GetFoldParent($parent);
		#return if $parent == -1;
	#}
	#$ep->ToggleFold($parent) unless $ep->GetFoldExpanded($parent);
	#my $cursor = $ep->GetLastChild( $parent, -1 );
	#my $level = $ep->GetFoldLevel($parent) >> 16;
	#while ($cursor > $parent) {
		#$ep->ToggleFold($cursor) if $ep->GetFoldLevel($cursor) % 2048 == $level
		                         #and $ep->GetFoldExpanded($cursor);
		#$cursor--;
	#}
}

1;

=head1 NAME

Kephra::App::EditPanel::Fold - code folding functions

=head1 DESCRIPTION

=cut