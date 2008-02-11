package Kephra::App::EditPanel::Margin;
$VERSION = '0.03';

# 

use strict;
use Wx qw(
	wxSTC_STYLE_LINENUMBER
	wxSTC_MARGIN_SYMBOL wxSTC_MARGIN_NUMBER
	wxSTC_MASK_FOLDERS
);
#wxSTC_MARK_MINUS wxSTC_MARK_PLUS wxSTC_MARK_CIRCLE wxSTC_MARK_BOXPLUS
#wxSTC_MARKNUM_FOLDEREND wxSTC_MARK_SHORTARROW
#wxSTC_FOLDFLAG_LINEBEFORE_CONTRACTED

sub _get_ep            {  Kephra::App::EditPanel::_get() }
sub _get_config        { $Kephra::config{editpanel}{margin} }
sub _get_line_config   { $Kephra::config{editpanel}{margin}{linenumber} }
sub _get_marker_config { $Kephra::config{editpanel}{margin}{marker} }

sub apply_settings{
	my $ep = _get_ep();
	# build
	$ep->SetMarginType( 0, wxSTC_MARGIN_SYMBOL );
	$ep->SetMarginType( 1, wxSTC_MARGIN_NUMBER );
	$ep->SetMarginType( 2, wxSTC_MARGIN_SYMBOL );
	$ep->SetMarginMask( 0, 0x01FFFFFF );
	$ep->SetMarginMask( 1, 0 );
	$ep->SetMarginMask( 2, wxSTC_MASK_FOLDERS );
	$ep->SetMarginSensitive( 0, 1 );
	$ep->SetMarginSensitive( 1, 0 );
	$ep->SetMarginSensitive( 2, 1 );

	$Kephra::temp{margin_linemax} = 0;
	show_marker();
	apply_line_number_width();
	apply_color();
	show_fold();
	apply_text_width();
}


# line number margin
sub line_number_visible{ _get_line_config->{visible} }

sub switch_line_number {
	_get_line_config->{visible} ^= 1;
	apply_line_number_width()
}

sub set_line_number_width{
	my $config = _get_line_config();
	$config->{width} = shift;
	apply_line_number_width();
}

sub apply_line_number_width {
	my $config = _get_line_config();
	my $width = $config->{visible}
		? $config->{width} * $Kephra::config{editpanel}{font}{size}
		: 0;
	_get_ep->SetMarginWidth( 1, $width);
	if ($config->{autosize} and $config->{visible}) {
		Kephra::API::EventTable::add_call ('document.text.change', 
			'autosize_line_number', \&line_number_autosize_update);
	} else {
		Kephra::API::EventTable::del_call
			('document.text.change', 'autosize_line_number');
	}
}

sub reset_line_number_width{
	my $config = _get_line_config();
	my ($width, $doc_line_with);

	if ( $config->{start_with_min} ) {
		$width = $config->{min_width};
		if ((ref $Kephra::document{open} eq 'ARRAY') and $config->{autosize}) {
			my $ep = &_get_ep;
			my $doc_nr = Kephra::Document::_get_current_nr();
			for ( 0 .. $#{ $Kephra::document{open} } ) {
				Kephra::Document::Internal::change_pointer($_);
				$doc_line_with = length $ep->GetLineCount;
				$width = $doc_line_with if $doc_line_with > $width;
			}
			Kephra::Document::Internal::change_pointer($doc_nr);
		}
		$config->{width} = $width;
		$Kephra::temp{margin_linemax} = 10 ** $width - 1;
	}
	apply_line_number_width();
}


sub autosize_line_number {
	my $config = _get_line_config();
	return unless $config->{autosize};
	my $need = length _get_ep->GetLineCount;
	set_line_number_width($need) if $need > $config->{width};
	$Kephra::temp{margin_linemax} = 10 ** $need - 1;
}
sub line_number_autosize_update {
	autosize_line_number()
		if _get_ep->GetLineCount > $Kephra::temp{margin_linemax};
}

sub apply_color {
	my $ep     = _get_ep();
	my $config = _get_line_config();
	my $color  = \&Kephra::Config::color;
	$ep->StyleSetForeground(wxSTC_STYLE_LINENUMBER,&$color($config->{fore_color}));
	$ep->StyleSetBackground(wxSTC_STYLE_LINENUMBER,&$color($config->{back_color}));
}


# marker margin

sub marker_visible{ _get_marker_config->{visible} }
sub show_marker {
	marker_visible()
		? _get_ep->SetMarginWidth(0, 16)
		: _get_ep->SetMarginWidth(0,  0);
}
sub switch_marker {
	_get_marker_config->{visible} ^= 1;
	show_marker();
}


# fold margin
sub fold_visible{ _get_config->{fold} }
sub show_fold {
	my $width = fold_visible() ? 16 : 0;
	_get_ep->SetMarginWidth( 2, $width );
}
sub switch_fold {
	_get_config->{fold} ^= 1;
	show_fold();
}

# extra text margin
sub get_text_width { _get_config->{text} }
sub set_text_width {
	_get_config->{text} = shift;
	apply_text_width();
}
sub apply_text_width {
	my $width = get_text_width();
	_get_ep->SetMargins( $width, $width );
}



1;